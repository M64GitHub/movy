const std = @import("std");
const movy = @import("movy");

// include ffmpeg-dev for video decoding
const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libswscale/swscale.h");
    @cInclude("libavutil/imgutils.h");
    @cInclude("libswresample/swresample.h"); // audio
});

// include sdl2 for audio
const SDL = @cImport({
    @cInclude("SDL2/SDL.h");
});

const AVERROR_EAGAIN = -11;

fn printFFmpegError(code: c_int) void {
    var err_buf: [256]u8 = undefined;
    _ = c.av_strerror(code, &err_buf, err_buf.len);
    std.debug.print("FFmpeg error: {s}\n", .{std.mem.sliceTo(&err_buf, 0)});
}

fn thunkGetAudioClock(ctx: *anyopaque) i128 {
    const self: *VideoDecoder = @ptrCast(@alignCast(ctx));
    return self.getAudioClock();
}

pub const VideoDecoder = struct {
    surface: *movy.RenderSurface,

    video: VideoState,
    audio: ?AudioState = null, // optional: null when no audio stream

    pub fn init(
        allocator: std.mem.Allocator,
        filename: []const u8,
        surface: *movy.RenderSurface,
    ) !*VideoDecoder {
        const decoder = try allocator.create(VideoDecoder);
        errdefer allocator.destroy(decoder);

        _ = c.av_log_set_level(c.AV_LOG_QUIET); // or AV_LOG_QUIET

        var video = try VideoState.init(allocator, filename, surface);
        errdefer video.deinit(allocator);

        const fmt_ctx = video.fmt_ctx; // pull it from the initialized VideoState

        const start_time_ns = std.time.nanoTimestamp();

        var audio: ?AudioState = null;
        const audio_stream_index = findStreamIndex(fmt_ctx, c.AVMEDIA_TYPE_AUDIO) catch null;
        if (audio_stream_index) |idx| {
            audio = try AudioState.init(allocator, fmt_ctx, idx);
            errdefer audio.deinit(allocator); // in case something fails after
            audio.?.start_time_ns = start_time_ns;
        }

        video.start_time_ns = start_time_ns;
        video.getAudioClockFn = if (audio != null) thunkGetAudioClock else null;
        video.getAudioClockCtx = if (audio != null) @ptrCast(decoder) else null;
        video.has_audio = (audio != null);

        decoder.* = .{
            .surface = surface,
            .video = video,
            .audio = audio,
        };

        return decoder;
    }

    pub fn deinit(self: *VideoDecoder, allocator: std.mem.Allocator) void {
        self.video.deinit(allocator);
        if (self.audio) |*audio_state| {
            audio_state.deinit(allocator);
        }
        allocator.destroy(self);
    }

    pub fn decodeNextVideoFrame(self: *VideoDecoder) !bool {
        // Try draining from decoder first
        if (try self.video.decodeFrame(null)) return true;

        // If a pending packet exists, try to send it again
        if (self.video.pending_pkt) |*pkt| {
            const send_result = c.avcodec_send_packet(self.video.codec_ctx, pkt);
            if (send_result == AVERROR_EAGAIN) {
                return false; // still not ready
            } else if (send_result < 0) {
                return error.FailedToSendPacket;
            }
            c.av_packet_unref(pkt);
            self.video.pending_pkt = null;
        }

        // Read a new packet
        var pkt: c.AVPacket = undefined;
        const res = c.av_read_frame(self.video.fmt_ctx, &pkt);
        if (res == c.AVERROR_EOF) return false;
        if (res < 0) return error.ReadFailed;

        defer c.av_packet_unref(&pkt);

        if (pkt.stream_index != @as(c_int, @intCast(self.video.stream_index))) return false;

        const send_result = c.avcodec_send_packet(self.video.codec_ctx, &pkt);
        if (send_result == AVERROR_EAGAIN) {
            self.video.pending_pkt = pkt;
            return false;
        } else if (send_result < 0) {
            return error.FailedToSendPacket;
        }

        // Try to receive again after sending
        return try self.video.decodeFrame(null);
    }

    pub fn decodeNextAudioPacket(self: *VideoDecoder) !void {
        if (self.audio) |*audio| {
            var pkt: c.AVPacket = undefined;
            if (c.av_read_frame(self.video.fmt_ctx, &pkt) < 0) return;
            defer c.av_packet_unref(&pkt);

            if (pkt.stream_index == @as(c_int, @intCast(audio.stream_index))) {
                try audio.decodePacket(&pkt);
            }
        }
    }

    pub fn processNextPacket(self: *VideoDecoder) !enum {
        eof,
        handled_video,
        handled_audio,
        skipped,
    } {
        var pkt: c.AVPacket = undefined;
        const res = c.av_read_frame(self.video.fmt_ctx, &pkt);
        if (res == c.AVERROR_EOF) return .eof;
        if (res < 0) return error.ReadFailed;

        defer c.av_packet_unref(&pkt);

        if (pkt.stream_index == @as(c_int, @intCast(self.video.stream_index))) {
            try self.video.sendAndDecode(&pkt, if (self.audio) |*a| a else null);
            return .handled_video;
        } else if (self.audio) |*a| {
            if (pkt.stream_index == a.stream_index) {
                try a.sendAndDecode(&pkt);
                return .handled_audio;
            }
        }

        return .skipped;
    }

    // old, not used
    pub fn readAndDispatchNextPacket(self: *VideoDecoder) !enum {
        eof,
        packet_ok,
        no_packet_yet,
    } {
        if (self.video.pending_pkt != null) {
            // We still need to drain it first!
            return .no_packet_yet;
        }

        var pkt: c.AVPacket = undefined;
        const res = c.av_read_frame(self.video.fmt_ctx, &pkt);
        if (res == c.AVERROR_EOF) return .eof;
        if (res < 0) return error.ReadFailed;

        defer c.av_packet_unref(&pkt);

        // if (pkt.stream_index != @as(c_int, @intCast(self.video.stream_index))) {
        //     return .no_packet_yet; // ignore non-video packets
        // }
        //
        // const send_result = c.avcodec_send_packet(self.video.codec_ctx, &pkt);
        // if (send_result == AVERROR_EAGAIN) {
        //     self.video.pending_pkt = pkt; // 🧠 stash it until next time
        //     return .no_packet_yet;
        // } else if (send_result < 0) {
        //     return error.SendFailed;
        // }
        //
        // return .packet_ok;

        if (pkt.stream_index == @as(c_int, @intCast(self.video.stream_index))) {
            const send_result = c.avcodec_send_packet(self.video.codec_ctx, &pkt);
            if (send_result == AVERROR_EAGAIN) {
                self.video.pending_pkt = pkt;
                return .no_packet_yet;
            } else if (send_result < 0) {
                return error.SendFailed;
            }
            return .packet_ok;
        } else if (self.audio != null and pkt.stream_index == self.audio.?.stream_index) {
            const send_result = c.avcodec_send_packet(self.audio.?.codec_ctx, &pkt);
            if (send_result == AVERROR_EAGAIN) {
                // Optional: add audio.pending_pkt = pkt if you want same buffering
                return .no_packet_yet;
            } else if (send_result < 0) {
                return error.SendFailed;
            }
            return .packet_ok;
        } else {
            // Drop unknown packet types (subs, data streams, etc.)
            return .no_packet_yet;
        }
    }

    pub fn tryReceiveVideoFrame(self: *VideoDecoder) !bool {
        return try self.video.tryReceiveFrame();
    }

    pub fn renderCurrentFrame(self: *VideoDecoder) void {
        self.video.convertFrameToSurface(self.surface);
    }

    pub fn seekToTimestamp(self: *VideoDecoder, timestamp_ns: i64) !void {
        const timestamp = @divTrunc(timestamp_ns * self.video.time_base.den, self.video.time_base.num * 1_000_000_000);

        if (c.av_seek_frame(self.video.fmt_ctx, self.video.stream_index, timestamp, c.AVSEEK_FLAG_BACKWARD) < 0)
            return error.SeekFailed;

        _ = c.avcodec_flush_buffers(self.video.codec_ctx);
        if (self.audio) |*audio| {
            _ = c.avcodec_flush_buffers(audio.codec_ctx);
        }
    }

    pub fn getAudioClock(self: *VideoDecoder) i128 {
        // return std.time.nanoTimestamp() - self.video.start_time_ns;
        if (self.audio) |*a| {
            return a.getAudioClock();
        } else {
            return std.time.nanoTimestamp() - self.video.start_time_ns;
        }
    }

    fn findStreamIndex(fmt_ctx: *c.AVFormatContext, media_type: c.enum_AVMediaType) !usize {
        var i: usize = 0;
        while (i < fmt_ctx.nb_streams) : (i += 1) {
            const stream = fmt_ctx.streams[i];
            if (stream.*.codecpar.*.codec_type == media_type)
                return i;
        }
        return error.StreamNotFound;
    }

    pub fn syncFrame(self: *VideoDecoder) bool {
        const now_ns = self.getAudioClock(); // current audio time in nanoseconds
        const frame_time = self.video.frame_pts_ns;

        if (frame_time > now_ns + 15_000_000) {
            // Too early: wait! Let the main loop skip this frame render call for now
            return false;
        }

        // Otherwise, time to show this frame
        return true;
    }
};

const VideoState = struct {
    fmt_ctx: *c.AVFormatContext,
    stream_index: usize,
    codec_ctx: *c.AVCodecContext,
    sws_ctx: *c.SwsContext,

    frame: *c.AVFrame,
    rgb_frame: *c.AVFrame,
    rgb_buf: []u8,

    time_base: c.AVRational,
    current_pts: i64,

    target_width: usize,
    target_height: usize,

    // av sync
    pending_pkt: ?c.AVPacket = null,
    start_time_ns: i128 = 0,
    has_audio: bool = false,
    getAudioClockFn: ?*const fn (*anyopaque) i128 = null,
    getAudioClockCtx: ?*anyopaque = null,
    frame_duration_ns: u64 = 41_666_666, // fallback: ~24fps
    last_frame_time: u64 = 0,

    frame_ready: bool = false,
    last_pts: i64 = -1,
    last_frame_time_ns: i128 = 0,
    last_clock_ns: i128 = 0,
    has_reference_error: bool = false,
    has_seen_keyframe: bool = false,
    frame_pts_ns: u64 = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        filename: []const u8,
        surface: *movy.RenderSurface,
    ) !VideoState {
        var fmt_ctx: ?*c.AVFormatContext = null;
        if (c.avformat_open_input(&fmt_ctx, filename.ptr, null, null) != 0) {
            return error.CouldNotOpenFile;
        }
        if (c.avformat_find_stream_info(fmt_ctx.?, null) < 0)
            return error.StreamInfoFailed;
        const stream_index = try findStreamIndex(fmt_ctx.?, c.AVMEDIA_TYPE_VIDEO);

        // std.debug.print("Video stream index is: {d}\n", .{stream_index});

        const stream = fmt_ctx.?.streams[stream_index];

        const codec_params = stream.*.codecpar;

        const codec = c.avcodec_find_decoder(codec_params.*.codec_id) orelse return error.UnknownCodec;
        const codec_ctx = c.avcodec_alloc_context3(codec) orelse return error.AllocFailed;

        if (c.avcodec_parameters_to_context(codec_ctx, codec_params) < 0)
            return error.CodecContextFailed;

        if (c.avcodec_open2(codec_ctx, codec, null) < 0)
            return error.CodecOpenFailed;

        const sws_ctx = c.sws_getContext(
            codec_ctx.*.width,
            codec_ctx.*.height,
            codec_ctx.*.pix_fmt,
            @as(i32, @intCast(surface.w)),
            @as(i32, @intCast(surface.h)),
            c.AV_PIX_FMT_RGB24,
            c.SWS_BILINEAR,
            null,
            null,
            null,
        ) orelse return error.SwsInitFailed;

        const frame = c.av_frame_alloc() orelse return error.AllocFailed;
        const rgb_frame = c.av_frame_alloc() orelse return error.AllocFailed;

        const rgb_buf_size: usize = @intCast(c.av_image_get_buffer_size(
            c.AV_PIX_FMT_RGB24,
            @as(c_int, @intCast(surface.w)),
            @as(c_int, @intCast(surface.h)),
            1,
        ));

        const rgb_buf = try allocator.alignedAlloc(u8, 32, rgb_buf_size);

        if (c.av_image_fill_arrays(
            &rgb_frame.*.data[0],
            &rgb_frame.*.linesize[0],
            rgb_buf.ptr,
            c.AV_PIX_FMT_RGB24,
            @as(c_int, @intCast(surface.w)),
            @as(c_int, @intCast(surface.h)),
            1,
        ) < 0)
            return error.FillArrayFailed;

        const time_base = stream.*.time_base;
        var frame_duration_ns: u64 =
            @as(u64, @intCast(@divTrunc(1_000_000_000 * time_base.num, time_base.den)));

        const framerate = stream.*.avg_frame_rate;
        if (framerate.num != 0) {
            frame_duration_ns = @divTrunc(
                1_000_000_000 * @as(u64, @intCast(framerate.den)),
                @as(u64, @intCast(framerate.num)),
            );
        }
        const last_frame_time: u64 =
            @as(u64, @intCast(std.time.nanoTimestamp()));

        return VideoState{
            .fmt_ctx = fmt_ctx.?,
            .stream_index = stream_index,
            .codec_ctx = codec_ctx,
            .sws_ctx = sws_ctx,
            .frame = frame,
            .rgb_frame = rgb_frame,
            .rgb_buf = rgb_buf,
            .time_base = time_base,
            .frame_duration_ns = @as(u64, @intCast(frame_duration_ns)),
            .current_pts = 0,
            .target_width = surface.w,
            .target_height = surface.h,
            .pending_pkt = null,
            .last_frame_time = last_frame_time,
        };
    }

    pub fn deinit(self: *VideoState, allocator: std.mem.Allocator) void {
        if (self.rgb_buf.len > 0) {
            allocator.free(self.rgb_buf);
        }

        c.av_frame_free(@as([*c][*c]c.AVFrame, @ptrCast(&self.frame)));
        c.av_frame_free(@as([*c][*c]c.AVFrame, @ptrCast(&self.rgb_frame)));
        c.sws_freeContext(self.sws_ctx);

        c.avcodec_free_context(
            @as([*c][*c]c.AVCodecContext, @ptrCast(&self.codec_ctx)),
        );
        c.avformat_close_input(
            @as([*c][*c]c.AVFormatContext, @ptrCast(&self.fmt_ctx)),
        );
    }

    pub fn findStreamIndex(fmt_ctx: *c.AVFormatContext, media_type: c.enum_AVMediaType) !usize {
        var i: usize = 0;
        while (i < fmt_ctx.nb_streams) : (i += 1) {
            if (fmt_ctx.streams[i].*.codecpar.*.codec_type == media_type)
                return i;
        }
        return error.StreamNotFound;
    }

    // pub fn decodeFrame(self: *VideoState, pkt: ?*const c.AVPacket) !bool {
    //     self.frame_ready = false;
    //
    //     if (pkt) |p| {
    //         if (c.avcodec_send_packet(self.codec_ctx, p) < 0)
    //             return false;
    //     }
    //
    //     while (c.avcodec_receive_frame(self.codec_ctx, self.frame) == 0) {
    //         const stream = self.fmt_ctx.streams[self.stream_index];
    //         const time_base = stream.*.time_base;
    //         const pts = self.frame.*.pts;
    //         if (pts < 0) continue;
    //
    //         // 💥 Skip corrupt frames
    //         if ((self.frame.*.flags & c.AV_FRAME_FLAG_CORRUPT) != 0) {
    //             // std.log.debug("Skipping corrupt frame (flags={})", .{self.frame.*.flags});
    //             continue;
    //         }
    //
    //         const frame_time_ns = @divTrunc(pts * 1_000_000_000 * time_base.num, time_base.den);
    //
    //         if (self.start_time_ns == 0) {
    //             const now = std.time.nanoTimestamp();
    //             self.start_time_ns = now;
    //
    //             if (self.getAudioClockCtx) |ctx_any| {
    //                 const ctx: *AudioState = @ptrCast(@alignCast(ctx_any));
    //                 ctx.start_time_ns = now;
    //             }
    //         }
    //
    //         // 🕒 Get current clock
    //         const now = std.time.nanoTimestamp();
    //         var clock: i128 = 0;
    //         if (self.has_audio) {
    //             if (self.getAudioClockFn) |clock_fn| {
    //                 clock = clock_fn(self.getAudioClockCtx.?);
    //             } else {
    //                 clock = now - self.start_time_ns;
    //             }
    //         } else {
    //             clock = now - self.start_time_ns;
    //         }
    //
    //         // 💨 Skip frame if it's waaaay too early (avoid huge stalls)
    //         const delta_ns = frame_time_ns - clock;
    //         if (delta_ns > 100_000_000) { // more than 100ms early
    //             // std.log.debug("Skipping early frame by {}ns", .{delta_ns});
    //             continue;
    //         }
    //
    //         // 💤 Wait gently up to max threshold
    //         var waited_ns: i128 = 0;
    //         const max_total_wait_ns: i128 = 50_000_000; // 50ms
    //
    //         while (frame_time_ns > clock + 5_000_000 and waited_ns < max_total_wait_ns) {
    //             const wait_ns = frame_time_ns - clock;
    //             const sleep_ns = @min(wait_ns, 1_000_000); // sleep max 1ms
    //             std.time.sleep(@as(u64, @intCast(sleep_ns)));
    //             waited_ns += sleep_ns;
    //
    //             if (self.has_audio) {
    //                 if (self.getAudioClockFn) |clock_fn| {
    //                     clock = clock_fn(self.getAudioClockCtx.?);
    //                 } else {
    //                     clock = std.time.nanoTimestamp() - self.start_time_ns;
    //                 }
    //             } else {
    //                 clock = std.time.nanoTimestamp() - self.start_time_ns;
    //             }
    //         }
    //
    //         self.last_pts = pts;
    //         self.frame_ready = true;
    //         return true;
    //     }
    //
    //     return false;
    // }

    pub fn decodeFrame(self: *VideoState, pkt: ?*const c.AVPacket) !bool {
        if (pkt) |p| {
            if (c.avcodec_send_packet(self.codec_ctx, p) < 0)
                return false;
        }

        // while (c.avcodec_receive_frame(self.codec_ctx, self.frame) == 0) {
        //     // Detect reference picture errors via side_data or log level (hard to check in C)
        //     // So instead, we conservatively detect if we’re too far off in sync
        //
        //     const stream = self.fmt_ctx.streams[self.stream_index];
        //     const time_base = stream.*.time_base;
        //     const pts = self.frame.*.pts;
        //     if (pts < 0) continue;
        //
        //     const frame_time_ns = @divTrunc(pts * 1_000_000_000 * time_base.num, time_base.den);
        //     const now = std.time.nanoTimestamp();
        //
        //     var clock: i128 = now - self.start_time_ns;
        //     if (self.getAudioClockFn) |clock_fn| {
        //         clock = clock_fn(self.getAudioClockCtx.?);
        //     }
        //
        //     // 💥 If frame is TOO FAR ahead, then probably a ref frame is missing
        //     if (frame_time_ns > clock + 1_000_000_000) {
        //         self.has_reference_error = true;
        //         return false; // 🛑 Skip frame, don’t render junk
        //     }
        //
        //     // Optional sleep (if desired):
        //     // ...
        //
        //     self.last_pts = pts;
        //     self.frame_ready = true;
        //     self.has_reference_error = false; // ✅ Clear if this frame is ok
        //     return true;
        // }
        //
        // return false;

        while (c.avcodec_receive_frame(self.codec_ctx, self.frame) == 0) {
            var is_keyframe = self.frame.*.key_frame == 1;

            is_keyframe = is_keyframe and self.frame.*.pict_type == c.AV_PICTURE_TYPE_I;

            if (!self.has_seen_keyframe) {
                if (!is_keyframe) {
                    // 💔 not a keyframe yet, skip it
                    continue;
                }

                // 💘 first keyframe seen — mark it
                self.has_seen_keyframe = true;
                std.debug.print("✨ First keyframe accepted!\n", .{});
            }

            // 🥰 now we’re good to process this frame

            const stream = self.fmt_ctx.streams[self.stream_index];
            const time_base = stream.*.time_base;
            const pts = self.frame.*.pts;
            if (pts < 0) continue;

            const frame_time_ns = @divTrunc(pts * 1_000_000_000 * time_base.num, time_base.den);

            var clock: i128 = std.time.nanoTimestamp() - self.start_time_ns;
            if (self.getAudioClockFn) |clock_fn| {
                clock = clock_fn(self.getAudioClockCtx.?);
            }

            if (frame_time_ns > clock + 1_000_000_000) {
                self.has_reference_error = true;
                return false;
            }

            self.last_pts = pts;
            self.frame_ready = true;
            self.has_reference_error = false;
            return true;
        }
        return false;
    }

    pub fn sendPacket(self: *VideoState, pkt: *c.AVPacket) !void {
        const result = c.avcodec_send_packet(self.codec_ctx, pkt);
        if (result == AVERROR_EAGAIN) return error.WouldBlock;
        if (result < 0) {
            printFFmpegError(result);
            return error.DecodeSendFailed;
        }
    }

    pub fn tryReceiveFrame(self: *VideoState) !bool {
        const result = c.avcodec_receive_frame(self.codec_ctx, self.frame);
        if (result == AVERROR_EAGAIN) return false;
        if (result == c.AVERROR_EOF) return false;
        if (result < 0) return error.DecodeReceiveFailed;

        return true;
    }

    //    pub fn sendAndDecode(self: *VideoState, pkt: *const c.AVPacket) !void {

    pub fn sendAndDecode(self: *VideoState, pkt: *c.AVPacket, audio: ?*AudioState) !void {
        const res_send = c.avcodec_send_packet(self.codec_ctx, pkt);
        if (res_send == AVERROR_EAGAIN) return error.SendAgain;
        if (res_send < 0) return error.SendFailed;

        // Now receive until we can't
        while (true) {
            const res_recv = c.avcodec_receive_frame(self.codec_ctx, self.frame);
            if (res_recv == AVERROR_EAGAIN or res_recv == c.AVERROR_EOF) break;
            if (res_recv < 0) return error.ReceiveFailed;

            // yay! we got a frame!
            self.frame_ready = true;

            const frame_pts_ns = try self.getFramePtsNS(self.frame);

            if (audio) |a| {
                const audio_now = a.getAudioClock();

                // Wait if we're too early (max 10ms)
                if (frame_pts_ns > audio_now) {
                    const diff = frame_pts_ns - audio_now;
                    std.time.sleep(@as(u64, @intCast(@min(diff, 10_000_000))));
                }

                // Skip frame if way too late (500ms)
                if (audio_now - frame_pts_ns > 500_000_000) {
                    return;
                }
            }

            self.frame_pts_ns = frame_pts_ns;

            // Check for reference errors or skipped frames
            if (self.frame.*.pict_type == c.AV_PICTURE_TYPE_NONE) {
                self.has_reference_error = true;
            } else {
                self.has_reference_error = false;
            }

            break; // just one frame for now!
        }
    }

    pub fn getFramePtsNS(self: *VideoState, frame: *c.AVFrame) !u64 {
        const pts = frame.pts;
        if (pts == c.AV_NOPTS_VALUE) {
            return error.MissingPTS;
        }

        const stream = self.fmt_ctx.*.streams[self.stream_index];
        const time_base = stream.*.time_base;

        // Convert pts (in stream's time_base) to nanoseconds

        const num_f64 = @as(f64, @floatFromInt(time_base.num));
        const den_f64 = @as(f64, @floatFromInt(time_base.den));
        const pts_f64 = @as(f64, @floatFromInt(pts));

        const seconds = pts_f64 * num_f64 / den_f64;

        return @intFromFloat(seconds * 1_000_000_000.0); // to nanoseconds
    }

    pub fn convertFrameToSurface(self: *VideoState, surface: *movy.RenderSurface) void {
        const src_data: [*c]const [*c]const u8 = @ptrCast(&self.frame.*.data[0]);
        const dst_data: [*c][*c]u8 = @ptrCast(&self.rgb_frame.*.data[0]);

        const src_stride: [*c]const c_int = &self.frame.*.linesize[0];
        const dst_stride: [*c]c_int = &self.rgb_frame.*.linesize[0];

        _ = c.sws_scale(
            self.sws_ctx,
            src_data,
            src_stride,
            0,
            self.codec_ctx.height,
            dst_data,
            dst_stride,
        );

        const pitch: usize = @as(usize, @intCast(self.rgb_frame.*.linesize[0]));
        var y: usize = 0;
        while (y < self.target_height) : (y += 1) {
            var x: usize = 0;
            while (x < self.target_width) : (x += 1) {
                const offset = y * pitch + x * 3;
                const r = self.rgb_buf[offset];
                const g = self.rgb_buf[offset + 1];
                const b = self.rgb_buf[offset + 2];

                surface.color_map[y * self.target_width + x] =
                    movy.core.types.Rgb{ .r = r, .g = g, .b = b };
            }
        }
    }
};

const AudioState = struct {
    stream_index: usize,
    codec_ctx: *c.AVCodecContext,
    swr_ctx: *c.SwrContext,

    audio_buf: []u8,
    audio_device: SDL.SDL_AudioDeviceID,
    audio_sample_rate: u32,
    audio_channels: u32,

    start_time_ns: i128 = 0,

    frame: *c.AVFrame,

    pub fn init(
        allocator: std.mem.Allocator,
        fmt_ctx: *c.AVFormatContext,
        stream_index: usize,
    ) !AudioState {
        const stream = fmt_ctx.streams[stream_index];
        const codecpar = stream.*.codecpar;

        const decoder = c.avcodec_find_decoder(codecpar.*.codec_id) orelse
            return error.UnsupportedCodec;

        const codec_ctx = c.avcodec_alloc_context3(decoder) orelse
            return error.AllocFailed;

        if (c.avcodec_parameters_to_context(codec_ctx, codecpar) < 0)
            return error.CodecParameterFailure;

        if (c.avcodec_open2(codec_ctx, decoder, null) < 0)
            return error.OpenCodecFailed;

        // init SDL audio
        if (SDL.SDL_Init(SDL.SDL_INIT_AUDIO) != 0)
            return error.SDLInitFailed;
        // defer SDL.SDL_Quit(); // Clean up at the end

        const audio_sample_rate = @as(u32, @intCast(codec_ctx.*.sample_rate));
        const audio_channels = @as(u32, @intCast(codec_ctx.*.channels));

        const swr_ctx = c.swr_alloc_set_opts(
            null,
            c.av_get_default_channel_layout(@as(c_int, @intCast(audio_channels))),
            c.AV_SAMPLE_FMT_S16,
            codec_ctx.*.sample_rate,
            c.av_get_default_channel_layout(@as(c_int, @intCast(audio_channels))),
            codec_ctx.*.sample_fmt,
            codec_ctx.*.sample_rate,
            0,
            null,
        ) orelse return error.SwrAllocFailed;

        if (c.swr_init(swr_ctx) < 0)
            return error.SwrInitFailed;

        // allocate audio buffer (~64KB)
        const audio_buf = try allocator.alloc(u8, 2048 * 32);

        // open SDL audio device
        var want: SDL.SDL_AudioSpec = .{
            .freq = 44100,
            .format = SDL.AUDIO_S16SYS,
            .channels = 2,
            .samples = 16384,
            .callback = null,
            .userdata = null,
        };
        var have: SDL.SDL_AudioSpec = undefined;
        const audio_device = SDL.SDL_OpenAudioDevice(
            null,
            0,
            &want,
            &have,
            0,
        );
        if (audio_device == 0) return error.SDLAudioFailed;

        const audio_frame = c.av_frame_alloc() orelse return error.OutOfMemory;

        SDL.SDL_PauseAudioDevice(audio_device, 0); // start playback

        return AudioState{
            .stream_index = stream_index,
            .codec_ctx = codec_ctx,
            .swr_ctx = swr_ctx,
            .audio_buf = audio_buf,
            .audio_device = audio_device,
            .audio_sample_rate = audio_sample_rate,
            .audio_channels = audio_channels,
            .frame = audio_frame,
        };
    }

    pub fn decodePacket(self: *AudioState, pkt: *const c.AVPacket) !void {
        if (c.avcodec_send_packet(self.codec_ctx, pkt) < 0) return;

        var frame = c.av_frame_alloc() orelse return;
        defer c.av_frame_free(&frame);

        while (c.avcodec_receive_frame(self.codec_ctx, frame) == 0) {
            const audio_buf_ptr: [*c][*c]u8 = @ptrCast(&self.audio_buf);
            const out_samples = c.swr_convert(
                self.swr_ctx,
                audio_buf_ptr,
                4096,
                @ptrCast(&frame.*.data[0]),
                frame.*.nb_samples,
            );

            const bytes: u32 = @as(u32, @intCast(out_samples)) *
                @as(u32, @intCast(c.av_get_bytes_per_sample(c.AV_SAMPLE_FMT_S16))) *
                self.audio_channels;

            _ = SDL.SDL_QueueAudio(self.audio_device, self.audio_buf.ptr, @intCast(bytes));
        }
    }

    pub fn sendPacket(self: *AudioState, pkt: *c.AVPacket) !void {
        const result = c.avcodec_send_packet(self.codec_ctx, pkt);
        if (result < 0) {
            printFFmpegError(result);
            return error.FailedToSendPacket;
        }
    }

    // pub fn getAudioClock(self: *AudioState) i128 {
    //     const bytes_per_sec: i128 =
    //         self.audio_sample_rate *
    //         @as(i128, @intCast(c.av_get_bytes_per_sample(c.AV_SAMPLE_FMT_S16))) *
    //         self.audio_channels;
    //
    //     if (bytes_per_sec == 0) return 0;
    //
    //     const queued_bytes: i128 = SDL.SDL_GetQueuedAudioSize(self.audio_device);
    //
    //     // 🛑 Don't sync to audio until there's enough queued
    //     if (queued_bytes < 2048) {
    //         return std.time.nanoTimestamp() - self.start_time_ns;
    //     }
    //
    //     const time_remaining_ns = @divTrunc(queued_bytes * 1_000_000_000, bytes_per_sec);
    //     return std.time.nanoTimestamp() - time_remaining_ns - self.start_time_ns;
    // }
    //

    pub fn getAudioClock(self: *AudioState) i128 {
        const now = std.time.nanoTimestamp();

        const bytes_per_sample = @as(i128, @intCast(c.av_get_bytes_per_sample(c.AV_SAMPLE_FMT_S16)));
        const bytes_per_sec: i128 = self.audio_sample_rate * bytes_per_sample * self.audio_channels;

        if (bytes_per_sec == 0) return 0;

        // const queued_bytes: i128 = @intCast(SDL.SDL_GetQueuedAudioSize(self.audio_device));
        // const time_remaining_ns = @divTrunc(queued_bytes * 1_000_000_000, bytes_per_sec);

        // Time already elapsed since audio started playing
        const time_elapsed_ns = now - self.start_time_ns;

        // We subtract what’s still buffered to get what has actually been played
        // return time_elapsed_ns - time_remaining_ns;
        return time_elapsed_ns;
    }

    pub fn deinit(self: *AudioState, allocator: std.mem.Allocator) void {
        allocator.free(self.audio_buf);
        SDL.SDL_CloseAudioDevice(self.audio_device);
        c.swr_free(@as([*c]?*c.SwrContext, @ptrCast(&self.swr_ctx)));
        c.avcodec_free_context(
            @as([*c][*c]c.AVCodecContext, @ptrCast(&self.codec_ctx)),
        );

        SDL.SDL_Quit();
    }

    pub fn sendAndDecode(self: *AudioState, pkt: *const c.AVPacket) !void {
        const res_send = c.avcodec_send_packet(self.codec_ctx, pkt);
        if (res_send == AVERROR_EAGAIN) return error.SendAgain;
        if (res_send < 0) return error.SendFailed;

        // Now decode all available audio frames
        while (true) {
            const res_recv = c.avcodec_receive_frame(self.codec_ctx, self.frame);
            if (res_recv == c.AVERROR_EOF or res_recv == AVERROR_EAGAIN) break;
            if (res_recv < 0) return error.ReceiveFailed;

            // Push it into your SDL queue or audio buffer
            self.pushDecodedAudio(self.frame) catch {
                std.log.err("Failed to push decoded audio!", .{});
            };
        }
    }

    pub fn pushDecodedAudio(self: *AudioState, frame: *c.AVFrame) !void {
        // const nb_samples = frame.nb_samples;
        // const bytes_per_sample = 2;
        // const num_channels = frame.channels;

        // if (bytes_per_sample <= 0) return error.UnsupportedSampleFormat;
        //
        // const data_size = nb_samples * bytes_per_sample * num_channels;
        //
        // // Assuming packed audio (no planar formats like FLTP)
        // const buffer = frame.data[0]; // pointer to audio data
        //
        // const queued = c.SDL_QueueAudio(self.device_id, buffer, @intCast(u32, data_size));
        // if (queued != 0) {
        //     return error.SDLQueueFailed;
        // }

        const audio_buf_ptr: [*c][*c]u8 = @ptrCast(&self.audio_buf);
        const out_samples = c.swr_convert(
            self.swr_ctx,
            audio_buf_ptr,
            4096,
            @ptrCast(&frame.*.data[0]),
            frame.*.nb_samples,
        );

        const bytes: u32 = @as(u32, @intCast(out_samples)) *
            @as(u32, @intCast(c.av_get_bytes_per_sample(c.AV_SAMPLE_FMT_S16))) *
            self.audio_channels;

        _ = SDL.SDL_QueueAudio(self.audio_device, self.audio_buf.ptr, @intCast(bytes));
    }

    pub fn maybeDecodeMore(self: *AudioState, decoder: *VideoDecoder) void {
        const BYTES_PER_SAMPLE = 2;
        const bytes_per_sec: i128 =
            self.audio_sample_rate * BYTES_PER_SAMPLE * self.audio_channels;

        if (bytes_per_sec == 0) return;

        const queued_bytes: u32 = SDL.SDL_GetQueuedAudioSize(self.audio_device);
        const queued_ns = @divTrunc(@as(i128, queued_bytes) * 1_000_000_000, bytes_per_sec);

        if (queued_ns >= 500_000_000) return;

        _ = decoder.decodeNextAudioPacket() catch {};
    }
};
