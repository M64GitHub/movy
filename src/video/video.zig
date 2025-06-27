const std = @import("std");
const movy = @import("movy");

const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libswscale/swscale.h");
    @cInclude("libavutil/imgutils.h");
    @cInclude("libswresample/swresample.h"); // audio
});

// SDL2 for audio
const SDL = @cImport({
    @cInclude("SDL2/SDL.h");
});

const AVERROR_EAGAIN = -11; // missing ffmpeg error definition

const SAMPLE_BUF_SIZE = 1024; // SLD2 audio buffer size
pub const DECODE_TIMEOUT_NS = 8_000_000;

/// Represents one decoded video frame, along with its timestamp in nanoseconds.
/// This is used for queueing and sync comparisons during video playback.
const VideoFrame = struct {
    frame: *c.AVFrame,
    pts_ns: u64,
};

/// Top-level AV decoder interface used by the player.
///
/// Holds everything needed to decode video (and optionally audio) from a
/// media file.
/// Internally wraps:
/// - `VideoState`: required for all decoding, surface rendering, and timing
/// - `AudioState`: optional, used when an audio stream exists
/// - A pointer to the render surface where decoded frames are displayed
///
/// Use `init()` to set up decoding, then `processNextPacket()` repeatedly
/// to drive playback.
///
/// # Typical Usage Flow
/// ```zig
/// const decoder = try VideoDecoder.init(alloc, "myvideo.mp4", surface);
/// while (true) {
///     switch (try decoder.processNextPacket(...)) {
///         .eof => break,
///         .handled_video => {},
///         .handled_audio => {},
///         .skipped => {},
///     }
/// }
/// ```
pub const VideoDecoder = struct {
    surface: *movy.RenderSurface,
    video: VideoState,
    audio: ?AudioState = null,

    /// Opens the given video file for decoding and prepares all resources.
    ///
    /// Detects both video and audio streams (if available), and initializes
    /// render output and synchronization clocks.
    pub fn init(
        allocator: std.mem.Allocator,
        filename: []const u8,
        surface: *movy.RenderSurface,
    ) !*VideoDecoder {
        const decoder = try allocator.create(VideoDecoder);
        errdefer allocator.destroy(decoder);

        _ = c.av_log_set_level(c.AV_LOG_QUIET); // silence FFmpeg logs

        var video = try VideoState.init(allocator, filename, surface);
        errdefer video.deinit(allocator);

        const fmt_ctx = video.fmt_ctx;

        var audio: ?AudioState = null;
        const audio_stream_index = findStreamIndex(fmt_ctx, c.AVMEDIA_TYPE_AUDIO) catch null;
        if (audio_stream_index) |idx| {
            audio = try AudioState.init(allocator, fmt_ctx, idx);
            errdefer audio.deinit(allocator);
        }

        // Set video sync clock reference
        video.start_time_ns = std.time.nanoTimestamp();

        decoder.* = .{
            .surface = surface,
            .video = video,
            .audio = audio,
        };

        return decoder;
    }

    /// Frees all resources, buffers, and decoder contexts.
    ///
    /// Should be called once playback or decoding is complete.
    pub fn deinit(self: *VideoDecoder, allocator: std.mem.Allocator) void {
        self.video.deinit(allocator);
        if (self.audio) |*audio_state| {
            audio_state.deinit(allocator);
        }
        allocator.destroy(self);
    }

    /// Reads the next packet from the media stream and dispatches it.
    ///
    /// This is the main function to advance decoding. It automatically routes packets
    /// to either the video or audio decoder, or skips unknown packets.
    pub fn processNextPacket(
        self: *VideoDecoder,
        sync_window: i32,
        audio_time_ns: i128,
    ) !enum {
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
            try self.video.processVideoPacket(&pkt, sync_window, audio_time_ns);
            return .handled_video;
        } else if (self.audio) |*a| {
            if (pkt.stream_index == a.stream_index) {
                try a.processAudioPacket(&pkt);
                return .handled_audio;
            }
        }

        return .skipped;
    }

    /// Seeks to the given timestamp (in nanoseconds).
    ///
    /// Automatically flushes decoder buffers for both video and audio streams.
    pub fn seekToTimestamp(self: *VideoDecoder, timestamp_ns: i64) !void {
        const timestamp = @divTrunc(
            timestamp_ns * self.video.time_base.den,
            self.video.time_base.num * 1_000_000_000,
        );

        if (c.av_seek_frame(
            self.video.fmt_ctx,
            self.video.stream_index,
            timestamp,
            c.AVSEEK_FLAG_BACKWARD,
        ) < 0)
            return error.SeekFailed;

        _ = c.avcodec_flush_buffers(self.video.codec_ctx);
        if (self.audio) |*audio| {
            _ = c.avcodec_flush_buffers(audio.codec_ctx);
        }
    }

    /// Returns the current playback clock (in nanoseconds).
    ///
    /// If audio is available, returns `audio.getAudioClock()`.
    /// Otherwise, uses the video reference start time.
    pub fn getAudioClock(self: *VideoDecoder) i128 {
        if (self.audio) |*a| {
            return a.getAudioClock();
        } else {
            return std.time.nanoTimestamp() - self.video.start_time_ns;
        }
    }

    /// Helper to find the first stream index of a given media type.
    fn findStreamIndex(
        fmt_ctx: *c.AVFormatContext,
        media_type: c.enum_AVMediaType,
    ) !usize {
        var i: usize = 0;
        while (i < fmt_ctx.nb_streams) : (i += 1) {
            const stream = fmt_ctx.streams[i];
            if (stream.*.codecpar.*.codec_type == media_type)
                return i;
        }
        return error.StreamNotFound;
    }

    /// Frees an allocated `AVFrame`.
    ///
    /// Used by video queue cleanup.
    pub fn freeAVFrame(frame: *c.AVFrame) void {
        c.av_frame_free(@as([*c][*c]c.AVFrame, @constCast(@ptrCast(&frame))));
    }
};

/// Holds all state and resources for decoding video frames with FFmpeg
/// and converting them to RGB format suitable for rendering into a movy surface.
///
/// This struct owns:
/// - The FFmpeg context, codec, scaling, and frame buffers
/// - The decode-to-RGB conversion pipeline (via `sws_scale`)
/// - A ring buffer queue of decoded frames with timestamps
/// - AV sync information and stream metadata
///
/// VIDEO DECODING FLOW:
/// 1. decoder.video.sendPacket(pkt)
/// 2. decoder.video.drainAndQueueFrames(sync_window, audio_time_ns)
///    -> internally calls tryReceiveFrame()
///    -> runs AV sync filter via shouldEnqueue()
///    -> calls enqueueDecodedFrame() if accepted
pub const VideoState = struct {
    pub const MAX_VIDEO_FRAMES = 1024; // max frame queue size
    pub const FALLBACK_FPS_NS = 41_666_666; // ~24 fps
    stream_index: usize,
    target_width: usize,
    target_height: usize,

    // av sync
    start_time_ns: i128 = 0,
    frame_duration_ns: u64 = FALLBACK_FPS_NS,

    // ffmpeg
    fmt_ctx: *c.AVFormatContext,
    codec_ctx: *c.AVCodecContext,
    sws_ctx: *c.SwsContext,

    frame: *c.AVFrame,
    rgb_frame: *c.AVFrame,
    rgb_buf: []u8,

    time_base: c.AVRational,

    // frame q
    frame_queue: [MAX_VIDEO_FRAMES]?VideoFrame = .{null} ** MAX_VIDEO_FRAMES,
    queue_tail: usize = 0,
    queue_count: usize = 0,
    last_enqueued_pts_ns: u64 = 0, // to detect duplicate frames

    /// Initializes the video decoder pipeline from a given input file and
    /// render surface.
    ///
    /// - Opens the file using FFmpeg
    /// - Locates the video stream and sets up the codec context
    /// - Initializes threaded decoding
    /// - Sets up swscale to convert frames to RGB format
    /// - Allocates buffers for decoding and RGB frames
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
        const stream_index =
            try findStreamIndex(fmt_ctx.?, c.AVMEDIA_TYPE_VIDEO);

        // std.debug.print("Video stream index is: {d}\n", .{stream_index});

        const stream = fmt_ctx.?.streams[stream_index];

        const codec_params = stream.*.codecpar;

        const codec = c.avcodec_find_decoder(codec_params.*.codec_id) orelse
            return error.UnknownCodec;
        const codec_ctx = c.avcodec_alloc_context3(codec) orelse
            return error.AllocFailed;

        if (c.avcodec_parameters_to_context(codec_ctx, codec_params) < 0)
            return error.CodecContextFailed;

        const thread_count = @as(c_int, @intCast(try std.Thread.getCpuCount()));
        codec_ctx.*.thread_count = thread_count;
        codec_ctx.*.thread_type = c.FF_THREAD_FRAME;

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
            @as(
                u64,
                @intCast(@divTrunc(
                    1_000_000_000 * time_base.num,
                    time_base.den,
                )),
            );

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
        };
    }

    /// Frees all allocated FFmpeg contexts, buffers, and RGB surfaces.
    ///
    /// Should be called once decoding is finished.
    pub fn deinit(self: *VideoState, allocator: std.mem.Allocator) void {
        allocator.free(self.rgb_buf);

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

    // -- helpers

    /// Finds the index of the first stream in the given format context
    /// that matches the requested media type.
    pub fn findStreamIndex(
        fmt_ctx: *c.AVFormatContext,
        media_type: c.enum_AVMediaType,
    ) !usize {
        var i: usize = 0;
        while (i < fmt_ctx.nb_streams) : (i += 1) {
            if (fmt_ctx.streams[i].*.codecpar.*.codec_type == media_type)
                return i;
        }
        return error.StreamNotFound;
    }

    /// Converts the presentation timestamp of the given frame to nanoseconds.
    ///
    /// Returns an error if the PTS is not available.
    pub fn getFramePtsNS(self: *VideoState, frame: *c.AVFrame) !u64 {
        const pts = if (frame.*.pts != c.AV_NOPTS_VALUE)
            frame.*.pts
        else
            frame.*.best_effort_timestamp;

        if (pts == c.AV_NOPTS_VALUE)
            return error.MissingPTS;

        // Just convert the raw pts to nanoseconds, do NOT subtract anything!
        const pts_f64 = @as(f64, @floatFromInt(pts));
        const seconds = pts_f64 * @as(f64, @floatFromInt(self.time_base.num)) /
            @as(f64, @floatFromInt(self.time_base.den));
        return @intFromFloat(seconds * 1_000_000_000.0);
    }

    // -- stream handling

    /// Sends a compressed video packet to the codec decoder.
    ///
    /// This corresponds to `avcodec_send_packet()`. It queues the packet for
    /// decoding, but does not retrieve any frames yet.
    /// Call `drainAndQueueFrames()` after this to attempt to receive and
    /// enqueue decoded frames.
    ///
    /// Errors if the decoder can't accept a packet at this moment or the
    /// send failed.
    pub fn sendPacket(self: *VideoState, pkt: *const c.AVPacket) !void {
        const res = c.avcodec_send_packet(self.codec_ctx, pkt);
        if (res == AVERROR_EAGAIN) return error.SendAgain;
        if (res < 0) return error.SendFailed;
    }

    /// Attempts to receive one decoded video frame from the codec.
    ///
    /// If a frame is available, this returns a pointer to the shared internal
    /// `self.frame`, which remains valid until the next call to this function.
    /// Returns `null` if the decoder has no frames ready yet.
    ///
    /// Note: This does not enqueue the frame — use `drainAndQueueFrames()`
    ///       for that.
    pub fn tryReceiveFrame(self: *VideoState) !?*c.AVFrame {
        const t_before = std.time.nanoTimestamp();
        const res = c.avcodec_receive_frame(self.codec_ctx, self.frame);
        const t_after = std.time.nanoTimestamp();

        const decode_ns = t_after - t_before;
        if (decode_ns > DECODE_TIMEOUT_NS) {
            return error.DecodingTooSlow;
        }

        if (res == AVERROR_EAGAIN or res == c.AVERROR_EOF) return null;
        if (res < 0) return error.ReceiveFailed;
        return self.frame;
    }

    /// Determines whether a decoded frame should be enqueued based on AV sync.
    ///
    /// Compares the frame's PTS (presentation timestamp) against the current
    /// audio clock (`audio_time_ns`). Returns true if the frame is within the
    /// acceptable sync window; otherwise, the frame is dropped.
    ///
    /// This helps reduce A/V desync by dropping outdated video frames.
    fn shouldEnqueue(
        self: *VideoState,
        frame: *c.AVFrame,
        audio_time_ns: i128,
        sync_window: i32,
    ) bool {
        const pts_ns = self.getFramePtsNS(frame) catch return false;
        const diff = @as(i64, @intCast(pts_ns)) -
            @as(i64, @intCast(audio_time_ns));
        return diff >= -sync_window * 2;
    }

    /// Attempts to dequeue up to 5 decoded frames and enqueue valid ones.
    ///
    /// This is typically called after `sendPacket()`. It runs a short receive
    // loop (max 5 iterations) and enqueues any frame that passes
    /// `shouldEnqueue()`.
    ///
    /// If a frame is late (outside sync window), it's dropped.
    /// If the queue is full, enqueueing will drop the oldest frame to
    /// make space.
    pub fn drainAndQueueFrames(
        self: *VideoState,
        sync_window: i32,
        audio_time_ns: i128,
    ) !void {
        var decode_attempts: usize = 0;
        while (decode_attempts < 5) {
            const frame = try self.tryReceiveFrame() orelse break;

            if (!self.shouldEnqueue(frame, audio_time_ns, sync_window)) {
                decode_attempts += 1;
                continue;
            }

            try self.enqueueDecodedFrame();
            decode_attempts += 1;
        }
    }

    /// High-level handler: sends one video packet and queues resulting frames.
    ///
    /// Combines `sendPacket()` and `drainAndQueueFrames()` into a single
    /// operation to process one packet completely, including AV sync enforcement
    /// and frame queue management.
    ///
    /// Use this from the main decoding loop for clean packet-by-packet handling.
    pub fn processVideoPacket(
        self: *VideoState,
        pkt: *const c.AVPacket,
        sync_window: i32,
        audio_time_ns: i128,
    ) !void {
        try self.sendPacket(pkt);
        try self.drainAndQueueFrames(sync_window, audio_time_ns);
    }

    // -- q

    pub fn enqueueDecodedFrame(self: *VideoState) !void {
        // Drop the oldest if we're full
        if (self.queue_count >= MAX_VIDEO_FRAMES) {
            const drop_idx = self.queue_tail;
            if (self.frame_queue[drop_idx]) |old_vf| {
                c.av_frame_free(@constCast(@ptrCast(&old_vf.frame)));
                self.frame_queue[drop_idx] = null;
            }
            self.queue_tail = (self.queue_tail + 1) % MAX_VIDEO_FRAMES;
            self.queue_count -= 1;
        }

        const cloned_frame = c.av_frame_alloc() orelse return error.AllocFailed;
        if (c.av_frame_ref(cloned_frame, self.frame) < 0)
            return error.RefFailed;

        const pts_ns = try self.getFramePtsNS(cloned_frame);
        if (pts_ns == self.last_enqueued_pts_ns) {
            // Still need to free cloned_frame if not used!
            c.av_frame_free(@constCast(@ptrCast(&cloned_frame)));
            return;
        }
        // std.debug.print("Enqueued frame with PTS {}\n", .{pts_ns});
        self.last_enqueued_pts_ns = pts_ns;

        const index = (self.queue_tail + self.queue_count) % MAX_VIDEO_FRAMES;
        self.frame_queue[index] = VideoFrame{
            .frame = cloned_frame,
            .pts_ns = pts_ns,
        };
        self.queue_count += 1;
    }

    pub fn clearQueue(self: *VideoState) void {
        var i: usize = 0;
        while (i < self.queue_count) : (i += 1) {
            const idx = (self.queue_tail + i) % MAX_VIDEO_FRAMES;
            if (self.frame_queue[idx]) |vf| {
                c.av_frame_free(@constCast(@ptrCast(&vf.frame)));
                self.frame_queue[idx] = null;
            }
        }
        self.queue_tail = 0;
        self.queue_count = 0;
    }

    pub fn popFrame(self: *VideoState) ?*c.AVFrame {
        if (self.queue_count == 0) return null;

        const maybe_vf = self.frame_queue[self.queue_tail];
        if (maybe_vf) |vf| {
            const frame = vf.frame;

            self.frame_queue[self.queue_tail] = null;
            self.queue_tail = (self.queue_tail + 1) % MAX_VIDEO_FRAMES;
            self.queue_count -= 1;

            return frame;
        }

        return null;
    }

    pub fn peekFrame(self: *VideoState) ?VideoFrame {
        if (self.queue_count == 0) return null;
        return self.frame_queue[self.queue_tail] orelse null;
    }

    // -- output

    /// Converts a decoded YUV video frame into RGB format and writes it into
    /// the movy render surface.
    ///
    /// This uses `sws_scale()` to convert the frame to RGB24 and then maps
    /// the RGB values onto the `surface.color_map`, ready for terminal rendering.
    pub fn renderFrameToSurface(
        self: *VideoState,
        frame: *c.AVFrame,
        surface: *movy.RenderSurface,
    ) void {
        const src_data: [*c]const [*c]const u8 = @ptrCast(&frame.*.data[0]);
        const src_stride: [*c]const c_int = &frame.*.linesize[0];

        const dst_data: [*c][*c]u8 = @ptrCast(&self.rgb_frame.*.data[0]);
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

/// Holds all state and resources for decoding audio frames with FFmpeg,
/// converting them to SDL-compatible format, and pushing them into the
/// SDL audio playback queue.
///
/// This struct owns:
/// - The FFmpeg codec and conversion pipeline (via `swr_convert`)
/// - An internal frame and buffer for resampled audio data
/// - An open SDL audio device ready for playback
/// - Timing information for A/V sync tracking
///
/// AUDIO DECODE FLOW:
/// 1. decoder.audio.sendPacket(pkt)
/// 2. decoder.audio.processAudioPacket(pkt)
///    -> internally calls tryReceiveFrame()
///    -> pushes output to SDL with convertAndQueueAudio()
pub const AudioState = struct {
    stream_index: usize,

    // A/V sync timing
    start_time_ns: i128 = 0,
    has_started_playing: bool = false,

    // SDL
    audio_buf: []u8,
    audio_device: SDL.SDL_AudioDeviceID,
    audio_sample_rate: u32,
    audio_channels: u32,

    // FFmpeg
    codec_ctx: *c.AVCodecContext,
    swr_ctx: *c.SwrContext,
    frame: *c.AVFrame,

    /// Initializes audio decoding and playback for the given stream.
    ///
    /// Sets up FFmpeg decoding, SDL audio output, and audio format conversion.
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

        const audio_sample_rate = @as(u32, @intCast(codec_ctx.*.sample_rate));
        const audio_channels = @as(u32, @intCast(codec_ctx.*.channels));

        const swr_ctx = c.swr_alloc_set_opts(
            null,
            c.av_get_default_channel_layout(
                @as(c_int, @intCast(audio_channels)),
            ),
            c.AV_SAMPLE_FMT_S16,
            codec_ctx.*.sample_rate,
            c.av_get_default_channel_layout(
                @as(c_int, @intCast(audio_channels)),
            ),
            codec_ctx.*.sample_fmt,
            codec_ctx.*.sample_rate,
            0,
            null,
        ) orelse return error.SwrAllocFailed;

        if (c.swr_init(swr_ctx) < 0)
            return error.SwrInitFailed;

        // allocate SDL audio buffer
        const audio_buf = try allocator.alloc(u8, SAMPLE_BUF_SIZE * 2);

        // init SDL audio
        if (SDL.SDL_Init(SDL.SDL_INIT_AUDIO) != 0)
            return error.SDLInitFailed;

        // open SDL audio device
        var want: SDL.SDL_AudioSpec = .{
            .format = SDL.AUDIO_S16SYS,
            .freq = @as(c_int, @intCast(audio_sample_rate)),
            .channels = @as(u8, @intCast(audio_channels)),
            .samples = SAMPLE_BUF_SIZE,
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

    /// Frees all allocated audio buffers and contexts.
    ///
    /// This should be called once audio playback is done.
    pub fn deinit(self: *AudioState, allocator: std.mem.Allocator) void {
        allocator.free(self.audio_buf);
        SDL.SDL_CloseAudioDevice(self.audio_device);
        c.swr_free(@as([*c]?*c.SwrContext, @ptrCast(&self.swr_ctx)));
        c.avcodec_free_context(
            @as([*c][*c]c.AVCodecContext, @ptrCast(&self.codec_ctx)),
        );
        c.av_frame_free(@as([*c][*c]c.AVFrame, @ptrCast(&self.frame)));
        SDL.SDL_Quit();
    }

    /// Sends a compressed audio packet to the codec decoder.
    ///
    /// This queues the packet for decoding but does not retrieve a frame yet.
    pub fn sendPacket(self: *AudioState, pkt: *const c.AVPacket) !void {
        const res = c.avcodec_send_packet(self.codec_ctx, pkt);
        if (res == AVERROR_EAGAIN) return error.SendAgain;
        if (res < 0) return error.SendFailed;
    }

    /// Attempts to receive one decoded audio frame from the codec.
    ///
    /// Returns `null` if no frame is currently available.
    pub fn tryReceiveFrame(self: *AudioState) !?*c.AVFrame {
        const res = c.avcodec_receive_frame(self.codec_ctx, self.frame);
        if (res == AVERROR_EAGAIN or res == c.AVERROR_EOF) return null;
        if (res < 0) return error.ReceiveFailed;
        return self.frame;
    }

    /// High-level helper to send + decode + push audio from a packet.
    ///
    /// Combines `sendPacket()`, `tryReceiveFrame()`, and `convertAndQueueAudio()`
    /// in one clean call.
    pub fn processAudioPacket(self: *AudioState, pkt: *const c.AVPacket) !void {
        try self.sendPacket(pkt);
        if (try self.tryReceiveFrame()) |frame| {
            try self.convertAndQueueAudio(frame);
        }
    }

    /// Converts the decoded audio to the SDL format and pushes it to the
    /// audio queue.
    ///
    /// If this is the first audio to be queued, playback is automatically
    /// started.
    pub fn convertAndQueueAudio(self: *AudioState, frame: *c.AVFrame) !void {
        const audio_buf_ptr: [*c][*c]u8 = @ptrCast(&self.audio_buf);
        const out_samples = c.swr_convert(
            self.swr_ctx,
            audio_buf_ptr,
            SAMPLE_BUF_SIZE,
            @ptrCast(&frame.*.data[0]),
            frame.*.nb_samples,
        );

        const bytes: u32 = @as(u32, @intCast(out_samples)) *
            @as(u32, @intCast(c.av_get_bytes_per_sample(c.AV_SAMPLE_FMT_S16))) *
            self.audio_channels;

        _ = SDL.SDL_QueueAudio(
            self.audio_device,
            self.audio_buf.ptr,
            @intCast(bytes),
        );

        if (!self.has_started_playing) {
            SDL.SDL_PauseAudioDevice(self.audio_device, 0);
            self.start_time_ns = std.time.nanoTimestamp();
            self.has_started_playing = true;
        }
    }

    /// Returns the current audio playback time in nanoseconds.
    ///
    /// This is used for audio-video synchronization.
    pub fn getAudioClock(self: *AudioState) i128 {
        if (!self.has_started_playing) return 0;
        return std.time.nanoTimestamp() - self.start_time_ns;
    }

    /// Pauses or resumes SDL audio playback.
    pub fn pauseAudioPlayback(self: *AudioState, pause_state: bool) void {
        SDL.SDL_PauseAudioDevice(self.audio_device, if (pause_state) 1 else 0);
    }
};
