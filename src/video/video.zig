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

pub const VideoDecoder = struct {
    //  state
    current_pts: i64 = 0,
    paused: bool = false,
    exit_requested: bool = false,
    loop_video: bool = true,
    was_video_frame: bool = false,

    // core
    allocator: std.mem.Allocator,
    fmt_ctx: *c.AVFormatContext,
    codec_ctx: *c.AVCodecContext,
    sws_ctx: *c.SwsContext,
    vid_stream_id: usize,

    // buffers
    frame: *c.AVFrame,
    rgb_frame: *c.AVFrame,
    rgb_buf: []u8,

    // output
    target_width: usize,
    target_height: usize,
    surface: *movy.RenderSurface,

    // audio
    audio_stream_id: usize,
    audio_codec_ctx: *c.AVCodecContext,
    swr_ctx: *c.SwrContext,
    audio_buf: []u8,
    audio_device: SDL.SDL_AudioDeviceID,
    audio_sample_rate: u32,
    audio_channels: u32,

    // frame sync
    start_time_ns: i128,
    frame_duration_ns: u64,
    last_frame_time: i128,

    const UpdateResult = struct {
        eof: bool,
        video_rendered: bool,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        filename: []const u8,
        surface: *movy.RenderSurface,
    ) !*VideoDecoder {
        const self = try allocator.create(VideoDecoder);
        errdefer allocator.destroy(self);

        self.allocator = allocator;
        self.surface = surface;
        self.target_width = surface.w;
        self.target_height = surface.h;

        // VIDEO

        // Init FFmpeg
        _ = c.avformat_network_init();
        c.av_log_set_level(c.AV_LOG_QUIET);

        // Open file
        var fmt_ctx_opt: ?*c.AVFormatContext = null;
        if (c.avformat_open_input(&fmt_ctx_opt, filename.ptr, null, null) < 0)
            return error.FileOpenFailed;
        self.fmt_ctx = fmt_ctx_opt.?;

        if (c.avformat_find_stream_info(self.fmt_ctx, null) < 0)
            return error.StreamInfoFailed;

        // Find video stream
        var vid_stream_id: ?usize = null;
        for (0..self.fmt_ctx.nb_streams) |i| {
            const stream = self.fmt_ctx.streams[i].*;
            const codecpar = stream.codecpar.*;
            if (codecpar.codec_type == c.AVMEDIA_TYPE_VIDEO) {
                vid_stream_id = i;
                break;
            }
        }
        if (vid_stream_id == null)
            return error.VideoStreamNotFound;
        self.vid_stream_id = vid_stream_id.?;

        const codecpar = self.fmt_ctx.streams.*[self.vid_stream_id].codecpar;
        const decoder = c.avcodec_find_decoder(codecpar.*.codec_id) orelse
            return error.DecoderNotFound;

        // Allocate and assign codec context
        self.codec_ctx = c.avcodec_alloc_context3(decoder) orelse
            return error.CodecContextAllocFailed;

        if (c.avcodec_parameters_to_context(self.codec_ctx, codecpar) < 0)
            return error.CodecParamCopyFailed;

        if (c.avcodec_open2(self.codec_ctx, decoder, null) < 0)
            return error.CodecOpenFailed;

        // Allocate decoding and RGB frames
        self.frame = c.av_frame_alloc() orelse return error.FrameAllocFailed;
        self.rgb_frame = c.av_frame_alloc() orelse
            return error.RgbFrameAllocFailed;

        // Allocate RGB buffer
        const rgb_buf_size: usize = @intCast(c.av_image_get_buffer_size(
            c.AV_PIX_FMT_RGB24,
            @as(c_int, @intCast(self.target_width)),
            @as(c_int, @intCast(self.target_height)),
            1,
        ));

        self.rgb_buf = try allocator.alignedAlloc(u8, 32, rgb_buf_size);

        _ = c.av_image_fill_arrays(
            &self.rgb_frame.*.data[0],
            &self.rgb_frame.*.linesize[0],
            self.rgb_buf.ptr,
            c.AV_PIX_FMT_RGB24,
            @as(c_int, @intCast(self.target_width)),
            @as(c_int, @intCast(self.target_height)),
            1,
        );

        // Create scaler context
        self.sws_ctx = c.sws_getContext(
            self.codec_ctx.width,
            self.codec_ctx.height,
            self.codec_ctx.pix_fmt,
            @as(c_int, @intCast(self.target_width)),
            @as(c_int, @intCast(self.target_height)),
            c.AV_PIX_FMT_RGB24,
            c.SWS_FAST_BILINEAR,
            null,
            null,
            null,
        ) orelse return error.ScalingInitFailed;

        const stream = self.fmt_ctx.streams[self.vid_stream_id].*;
        const framerate = stream.avg_frame_rate;
        self.frame_duration_ns = @divTrunc(
            1_000_000_000 * @as(u64, @intCast(framerate.den)),
            @as(u64, @intCast(framerate.num)),
        );
        self.last_frame_time = std.time.nanoTimestamp();

        // AUDIO
        if (SDL.SDL_Init(SDL.SDL_INIT_AUDIO) < 0) {
            std.debug.print("SDL Error: {s}\n", .{SDL.SDL_GetError()});
            return error.SDLInitFailed;
        }

        // Find audio stream
        var audio_stream_id: ?usize = null;
        for (0..self.fmt_ctx.nb_streams) |i| {
            const audio_stream = self.fmt_ctx.streams[i].*;
            if (audio_stream.codecpar.*.codec_type == c.AVMEDIA_TYPE_AUDIO) {
                audio_stream_id = i;
                break;
            }
        }
        if (audio_stream_id == null)
            return error.AudioStreamNotFound;
        self.audio_stream_id = audio_stream_id.?;

        const audiopar = self.fmt_ctx.streams[self.audio_stream_id].*.codecpar;
        const audio_decoder = c.avcodec_find_decoder(audiopar.*.codec_id) orelse
            return error.AudioDecoderNotFound;

        self.audio_codec_ctx = c.avcodec_alloc_context3(audio_decoder) orelse
            return error.AudioCodecAllocFailed;

        if (c.avcodec_parameters_to_context(self.audio_codec_ctx, audiopar) < 0)
            return error.AudioParamCopyFailed;

        if (c.avcodec_open2(self.audio_codec_ctx, audio_decoder, null) < 0)
            return error.AudioCodecOpenFailed;

        // SDL audio setup
        var want: SDL.SDL_AudioSpec = .{
            .freq = 44100,
            .format = SDL.AUDIO_S16SYS,
            .channels = 2,
            .samples = 4096,
            .callback = null,
            .userdata = null,
        };
        var have: SDL.SDL_AudioSpec = undefined;

        self.audio_device = SDL.SDL_OpenAudioDevice(null, 0, &want, &have, 0);
        if (self.audio_device == 0) return error.SDLAudioOpenFailed;

        SDL.SDL_PauseAudioDevice(self.audio_device, 0);

        // SwrContext (resampler)
        self.swr_ctx = c.swr_alloc_set_opts(
            null,
            c.av_get_default_channel_layout(have.channels),
            c.AV_SAMPLE_FMT_S16,
            have.freq,
            c.av_get_default_channel_layout(self.audio_codec_ctx.channels),
            self.audio_codec_ctx.sample_fmt,
            self.audio_codec_ctx.sample_rate,
            0,
            null,
        ) orelse return error.SwrAllocFailed;

        if (c.swr_init(self.swr_ctx) < 0)
            return error.SwrInitFailed;

        // Audio buffer
        self.audio_buf = try self.allocator.alloc(u8, 8192);

        self.audio_sample_rate = @as(u32, @intCast(self.audio_codec_ctx.sample_rate));
        self.audio_channels = @as(u32, @intCast(self.audio_codec_ctx.channels));

        self.start_time_ns = 0;

        return self;
    }

    pub fn deinit(self: *VideoDecoder) void {
        c.av_frame_free(@as([*c][*c]c.AVFrame, @ptrCast(&self.frame)));
        c.av_frame_free(@as([*c][*c]c.AVFrame, @ptrCast(&self.rgb_frame)));
        self.allocator.free(self.rgb_buf);
        c.sws_freeContext(self.sws_ctx);
        c.avcodec_free_context(
            @as([*c][*c]c.AVCodecContext, @ptrCast(&self.codec_ctx)),
        );
        c.avformat_close_input(
            @as([*c][*c]c.AVFormatContext, @ptrCast(&self.fmt_ctx)),
        );
    }

    pub fn readVideoFrame(self: *VideoDecoder) !bool {
        var pkt: c.AVPacket = undefined;
        c.av_init_packet(&pkt);

        if (c.av_read_frame(self.fmt_ctx, &pkt) < 0) {
            return false; // END OF STREAM
        }
        defer c.av_packet_unref(&pkt);

        self.was_video_frame = false;

        const stream_index = pkt.stream_index;

        if (stream_index == @as(c_int, @intCast(self.vid_stream_id))) {
            if (c.avcodec_send_packet(self.codec_ctx, &pkt) < 0)
                return error.DecodeFailed;

            while (c.avcodec_receive_frame(self.codec_ctx, self.frame) == 0) {
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

                        self.surface.color_map[y * self.target_width + x] =
                            movy.core.types.Rgb{ .r = r, .g = g, .b = b };
                    }
                }

                self.was_video_frame = true;
                return true; // video frame READY.
            }
        }

        return true;
    }

    // for video only
    pub fn syncFrame(self: *VideoDecoder) void {
        const now = std.time.nanoTimestamp();
        const delay = now - self.last_frame_time;
        if (delay < self.frame_duration_ns) {
            const ns: u64 = @as(u64, @intCast(self.frame_duration_ns - delay));
            std.time.sleep(ns);
        }

        self.last_frame_time = std.time.nanoTimestamp();
    }

    // video only atm
    pub fn seek(self: *VideoDecoder, seconds: i64) !void {
        const stream = self.fmt_ctx.streams[self.vid_stream_id];
        const timebase = stream.*.time_base;
        const offset_pts = seconds * timebase.den / timebase.num;
        const target_pts = self.current_pts + offset_pts;
        _ = c.av_seek_frame(
            self.fmt_ctx,
            @as(c_int, @intCast(self.vid_stream_id)),
            target_pts,
            c.AVSEEK_FLAG_BACKWARD,
        );
        c.avcodec_flush_buffers(self.codec_ctx);
    }

    // -- new AV sync functions

    pub fn getAudioClock(self: *VideoDecoder) u64 {
        const bytes_per_sec = self.audio_sample_rate *
            @as(u32, @intCast(c.av_get_bytes_per_sample(c.AV_SAMPLE_FMT_S16))) *
            self.audio_channels;

        const queued_bytes = SDL.SDL_GetQueuedAudioSize(self.audio_device);
        const played_time_ns: i128 = @divTrunc(queued_bytes * 1_000_000_000, bytes_per_sec);
        const diff =
            std.time.nanoTimestamp() - self.start_time_ns - played_time_ns;

        return @as(u64, @intCast(diff));
    }

    fn decodeAudioPacket(self: *VideoDecoder, pkt: *const c.AVPacket) !void {
        if (c.avcodec_send_packet(self.audio_codec_ctx, pkt) < 0)
            return;

        var frame = c.av_frame_alloc() orelse return error.FrameAllocFailed;
        defer c.av_frame_free(@as([*c][*c]c.AVFrame, @ptrCast(&frame)));

        while (c.avcodec_receive_frame(self.audio_codec_ctx, frame) == 0) {
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

    fn decodeVideoFrame(self: *VideoDecoder, pkt: *const c.AVPacket) bool {
        if (c.avcodec_send_packet(self.codec_ctx, pkt) < 0) return false;

        while (c.avcodec_receive_frame(self.codec_ctx, self.frame) == 0) {
            const frame_pts = self.frame.*.pts;
            const stream = self.fmt_ctx.streams[self.vid_stream_id];
            const time_base = stream.*.time_base;

            const frame_time_ns = @divTrunc(frame_pts * 1_000_000_000 * time_base.num, time_base.den);

            // Wait for audio clock to catch up
            while (true) {
                const audio_clock = self.getAudioClock();
                // std.debug.print("🎞️ Frame PTS={} ({}ns), Audio clock={}ns\n", .{ frame_pts, frame_time_ns, audio_clock });

                if (frame_time_ns <= audio_clock + 5_000_000) { // allow 5ms ahead
                    break;
                }
                std.time.sleep(1_000_000); // sleep 1ms
            }

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
            self.convertFrameToSurface();
            return true;
        }

        return false;
    }

    fn convertFrameToSurface(self: *VideoDecoder) void {
        const pitch = @as(usize, @intCast(self.rgb_frame.*.linesize[0]));

        var y: usize = 0;
        while (y < self.target_height) : (y += 1) {
            var x: usize = 0;
            while (x < self.target_width) : (x += 1) {
                const offset = y * pitch + x * 3;
                const r = self.rgb_buf[offset];
                const g = self.rgb_buf[offset + 1];
                const b = self.rgb_buf[offset + 2];

                self.surface.color_map[y * self.target_width + x] =
                    movy.core.types.Rgb{ .r = r, .g = g, .b = b };
            }
        }
    }

    pub fn update(self: *VideoDecoder) !UpdateResult {
        if (self.start_time_ns == 0)
            self.start_time_ns = std.time.nanoTimestamp();

        var pkt: c.AVPacket = undefined;
        if (c.av_read_frame(self.fmt_ctx, &pkt) < 0) {
            return UpdateResult{ .eof = true, .video_rendered = false };
        }
        defer c.av_packet_unref(&pkt);

        if (pkt.stream_index == @as(c_int, @intCast(self.audio_stream_id))) {
            try self.decodeAudioPacket(&pkt);
            return UpdateResult{ .eof = false, .video_rendered = false };
        }

        if (pkt.stream_index == @as(c_int, @intCast(self.vid_stream_id))) {
            const rendered = self.decodeVideoFrame(&pkt);
            return UpdateResult{ .eof = false, .video_rendered = rendered };
        }

        return UpdateResult{ .eof = false, .video_rendered = false };
    }
};
