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

        var audio: ?AudioState = null;
        const audio_stream_index = findStreamIndex(fmt_ctx, c.AVMEDIA_TYPE_AUDIO) catch null;
        if (audio_stream_index) |idx| {
            audio = try AudioState.init(allocator, fmt_ctx, idx);
            errdefer audio.deinit(allocator); // in case something fails after
        }

        const start_time_ns = std.time.nanoTimestamp();
        video.start_time_ns = start_time_ns;

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
            try self.video.sendAndDecode(&pkt);
            return .handled_video;
        } else if (self.audio) |*a| {
            if (pkt.stream_index == a.stream_index) {
                try a.sendAndDecode(&pkt);
                return .handled_audio;
            }
        }

        return .skipped;
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

    pub fn shouldRenderNow(self: *VideoDecoder) bool {
        const audio_time = self.getAudioClock();
        const frame_time = self.video.frame_pts_ns;

        // only render when audio has reached or passed the frame
        return frame_time <= audio_time;
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

    target_width: usize,
    target_height: usize,

    // av sync
    pending_pkt: ?c.AVPacket = null,
    start_time_ns: i128 = 0,
    frame_duration_ns: u64 = 41_666_666, // fallback: ~24fps

    frame_ready: bool = false,
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
            .target_width = surface.w,
            .target_height = surface.h,
            .pending_pkt = null,
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

    pub fn sendAndDecode(self: *VideoState, pkt: *const c.AVPacket) !void {
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
        // const pts = frame.pts;

        const pts = if (frame.*.pts != c.AV_NOPTS_VALUE)
            frame.*.pts
        else
            frame.*.best_effort_timestamp;

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
    has_started_playing: bool = false,
    last_audio_ns: i128 = 0,

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
        const audio_buf = try allocator.alloc(u8, 256 * 2);

        // open SDL audio device
        var want: SDL.SDL_AudioSpec = .{
            .freq = 44100,
            .format = SDL.AUDIO_S16SYS,
            .channels = 2,
            .samples = 256,
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

    pub fn getAudioClock(self: *AudioState) i128 {
        const now = std.time.nanoTimestamp();

        // const bytes_per_sample = @as(i128, @intCast(c.av_get_bytes_per_sample(c.AV_SAMPLE_FMT_S16)));
        // const bytes_per_sec: i128 = self.audio_sample_rate * bytes_per_sample * self.audio_channels;
        //
        // if (bytes_per_sec == 0) return 0;
        //
        // const queued_bytes: i128 = @intCast(SDL.SDL_GetQueuedAudioSize(self.audio_device));
        // const time_remaining_ns = @divTrunc(queued_bytes * 1_000_000_000, bytes_per_sec);
        //
        // const raw_ns = now - self.start_time_ns - time_remaining_ns;
        // self.last_audio_ns = raw_ns;
        self.last_audio_ns = now - self.start_time_ns;

        // Smooth against previous to avoid jumps (e.g., with EMA)
        // self.last_audio_ns = @divTrunc(self.last_audio_ns * 7 + raw_ns * 3, 10);
        return self.last_audio_ns;
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
        // while (true) {
        const res_recv = c.avcodec_receive_frame(self.codec_ctx, self.frame);
        // if (res_recv == c.AVERROR_EOF or res_recv == AVERROR_EAGAIN) break;
        if (res_recv < 0) return error.ReceiveFailed;

        // Push it into your SDL queue or audio buffer
        self.pushDecodedAudio(self.frame) catch {
            std.log.err("Failed to push decoded audio!", .{});
        };
        // }
    }

    pub fn pushDecodedAudio(self: *AudioState, frame: *c.AVFrame) !void {
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

        if (!self.has_started_playing) {
            SDL.SDL_PauseAudioDevice(self.audio_device, 0); // start playback
            const start_time_ns = std.time.nanoTimestamp();
            self.start_time_ns = start_time_ns;
            self.has_started_playing = true;
        }
    }
};
