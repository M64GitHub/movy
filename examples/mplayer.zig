// this is a proof of concept version of a commandline video player
// please note: it is completely unpolished, and was the foundation to
// movy_video.VideoDecoder - see movycat as an example

const std = @import("std");
const movy = @import("movy");

const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libswscale/swscale.h");
    @cInclude("libavutil/imgutils.h");
});

const target_width: usize = 200;
const target_height: usize = 112;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};

    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // -- setup movy screen

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    // try movy.terminal.beginAlternateScreen();
    // defer movy.terminal.endAlternateScreen();
    movy.terminal.cursorOff();
    defer movy.terminal.cursorOn();

    var screen = try movy.Screen.init(
        allocator,
        target_width + 8,
        target_height / 2 + 4,
    );
    defer screen.deinit(allocator);

    screen.setScreenMode(movy.Screen.Mode.transparent);

    // -- m64

    // m64 logo
    var sprite_m64_logo = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/movy-logo3.png",
        "sprite 1",
    );
    defer sprite_m64_logo.deinit(allocator);

    // print some text onto our sprite
    var data_surface = try sprite_m64_logo.getCurrentFrameSurface();

    _ = data_surface.putStrXY(
        "ANSI ON PNG!",
        32,
        8,
        movy.color.WHITE,
        movy.color.DARK_GRAY,
    );

    // apply frame- to output-surface
    try sprite_m64_logo.applyCurrentFrame();

    // configure an outlineRotator effect
    var outline_rotator = movy.render.Effect.OutlineRotator{
        .start_x = 0,
        .start_y = 0,
        .direction = .left,
    };
    var rotator_effect = outline_rotator.asEffect();
    sprite_m64_logo.effect_ctx.input_surface = sprite_m64_logo.output_surface;
    var sine_wave = movy.animation.TrigWave.init(120, 50);

    try screen.addRenderSurface(allocator, sprite_m64_logo.output_surface);

    // -- Parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 1) {
        try stdout.print("Error: missing filename\n", .{});
        return;
    }

    const file_name = args[1];
    try stdout.print("Working with filename '{s}'\n", .{file_name});

    // -- init ffmpeg
    _ = c.avformat_network_init();
    defer _ = c.avformat_network_deinit();
    c.av_log_set_level(c.AV_LOG_QUIET); // disable terminal output

    // -- open video file
    var fmt_ctx: ?*c.AVFormatContext = null;
    if (c.avformat_open_input(&fmt_ctx, file_name, null, null) < 0) {
        std.debug.print("Error: Cannot open file '{s}'\n", .{file_name});
        return;
    }
    defer c.avformat_close_input(&fmt_ctx);

    // -- check stream info
    if (c.avformat_find_stream_info(fmt_ctx.?, null) < 0)
        return;

    // -- find video stream id
    var vid_stream_id: ?usize = undefined;
    for (0..fmt_ctx.?.nb_streams) |i| {
        if (fmt_ctx.?.streams.*[i].codecpar.*.codec_type ==
            c.AVMEDIA_TYPE_VIDEO)
        {
            vid_stream_id = i;
            break;
        }
    }

    if (vid_stream_id) |i| {
        try stdout.print("Video stream id: {d}\n", .{i});
    } else {
        try stdout.print("Error: unable to get video stream id\n", .{});
        return;
    }

    // -- get decoder
    const codec_par = fmt_ctx.?.streams.*[vid_stream_id.?].codecpar;
    const decoder = c.avcodec_find_decoder(codec_par.*.codec_id);
    if (decoder == null) return;

    // -- allocate codec context
    var codec_ctx = c.avcodec_alloc_context3(decoder);
    if (codec_ctx == null) {
        std.debug.print("Error: could not allocate codec context\n", .{});
        return;
    }
    defer c.avcodec_free_context(&codec_ctx);

    // -- copy stream parameters into codec context
    if (c.avcodec_parameters_to_context(codec_ctx, codec_par) < 0) {
        std.debug.print("Error: could not copy codec parameters\n", .{});
        return;
    }

    // -- open the codec
    if (c.avcodec_open2(codec_ctx, decoder, null) < 0) {
        std.debug.print("Error: could not open codec\n", .{});
        return;
    }

    const width = codec_ctx.*.width;
    const height = codec_ctx.*.height;

    try stdout.print("Video resolution: {d}x{d}\n", .{ width, height });

    // -- init render surface for output
    var surface = try movy.RenderSurface.init(
        allocator,
        target_width,
        target_height,
        movy.core.types.Rgb{ .r = 0xff, .g = 0, .b = 0 },
    );
    defer surface.deinit(allocator);

    surface.x = 4;
    surface.y = 4;

    try screen.addRenderSurface(allocator, surface);

    // setup rgb frame and scaler

    var rgb_frame = c.av_frame_alloc();
    defer c.av_frame_free(&rgb_frame);

    // set size for RGB frame
    const rgb_buf_size: usize = @intCast(c.av_image_get_buffer_size(
        c.AV_PIX_FMT_RGB24,
        target_width,
        target_height,
        1,
    ));

    // allocate raw buffer
    const rgb_buf = try allocator.alignedAlloc(u8, 32, rgb_buf_size);
    defer allocator.free(rgb_buf);

    _ = c.av_image_fill_arrays(
        &rgb_frame.*.data[0],
        &rgb_frame.*.linesize[0],
        rgb_buf.ptr,
        c.AV_PIX_FMT_RGB24,
        target_width,
        target_height,
        1,
    );

    // setup scaler
    const sws_ctx = c.sws_getContext(
        codec_ctx.*.width,
        codec_ctx.*.height,
        codec_ctx.*.pix_fmt,
        target_width,
        target_height,
        c.AV_PIX_FMT_RGB24,
        c.SWS_FAST_BILINEAR,
        null,
        null,
        null,
    );
    if (sws_ctx == null) return error.ScalingInitFailed;
    defer c.sws_freeContext(sws_ctx);

    // Allocate the frame used to hold the original data
    var frame = c.av_frame_alloc();
    defer c.av_frame_free(&frame);

    // Prepare packet
    var pkt: c.AVPacket = undefined;
    c.av_init_packet(&pkt);

    // -- setup frame sync

    const stream = fmt_ctx.?.streams[vid_stream_id.?];
    const framerate = stream.*.avg_frame_rate;
    const frame_duration_ns: u64 = @divTrunc(
        1_000_000_000 * @as(u64, @intCast(framerate.den)),
        @as(u64, @intCast(framerate.num)),
    );
    var last_frame_time = std.time.nanoTimestamp();

    var frame_nr: usize = 0;

    // -- main decode loop: read packets and convert frames to RGB
    while (c.av_read_frame(fmt_ctx.?, &pkt) >= 0) {
        // -- ESC to exit
        if (try movy.input.get()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.type == .Escape) {
                        break;
                    } else {}
                },
                else => {},
            }
        }

        // if video packet
        if (pkt.stream_index == @as(c_int, @intCast(vid_stream_id.?))) {
            // send to the decoder
            if (c.avcodec_send_packet(codec_ctx, &pkt) == 0) {
                //
                while (c.avcodec_receive_frame(codec_ctx, frame) == 0) {
                    //  Scale and convert to RGB24
                    const src_data: [*c]const [*c]const u8 =
                        @ptrCast(&frame.*.data[0]);
                    const dst_data: [*c][*c]u8 = @ptrCast(&rgb_frame.*.data[0]);

                    const src_stride: [*c]const c_int = &frame.*.linesize[0];
                    const dst_stride: [*c]c_int = &rgb_frame.*.linesize[0];

                    _ = c.sws_scale(
                        sws_ctx,
                        src_data,
                        src_stride,
                        0,
                        codec_ctx.*.height,
                        dst_data,
                        dst_stride,
                    );

                    // Fill the RenderSurface with RGB values
                    const pitch: usize =
                        @as(usize, @intCast(rgb_frame.*.linesize[0]));
                    var y: usize = 0;
                    while (y < target_height) : (y += 1) {
                        var x: usize = 0;
                        while (x < target_width) : (x += 1) {
                            const offset = y * pitch + x * 3;
                            const r = rgb_buf[offset];
                            const g = rgb_buf[offset + 1];
                            const b = rgb_buf[offset + 2];

                            surface.color_map[y * target_width + x] =
                                movy.core.types.Rgb{
                                    .r = r,
                                    .g = g,
                                    .b = b,
                                };
                        }
                    }

                    frame_nr += 1;

                    sprite_m64_logo.setXY(70 + sine_wave.tickSine(), 88);
                    // Apply effect
                    try rotator_effect.run(
                        allocator,
                        &sprite_m64_logo.effect_ctx,
                        frame_nr,
                    );

                    // render surface
                    screen.render();
                    // blast to terminal
                    try screen.output();
                    const now = std.time.nanoTimestamp();
                    const delay = now - last_frame_time;
                    if (delay < frame_duration_ns) {
                        const ns: u64 = @as(u64, @intCast(frame_duration_ns - delay));
                        std.Thread.sleep(ns);
                    }

                    last_frame_time = std.time.nanoTimestamp();
                }
            }
        }

        // Clean up packet after processing
        c.av_packet_unref(&pkt);
    }
}
