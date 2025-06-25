const std = @import("std");
const movy = @import("movy");
const movy_video = @import("movy_video");
const stdout = std.io.getStdOut().writer();

const c = @cImport({
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libswscale/swscale.h");
    @cInclude("libavutil/imgutils.h");
});

const target_width: usize = 140;
const target_height: usize = 100;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = true,
    }){};

    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // -- Setup movy screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(
        allocator,
        target_width,
        target_height / 2,
    );
    defer screen.deinit(allocator);

    screen.setScreenMode(movy.Screen.Mode.bgcolor);

    // -- init render surface for output, and add to screen
    var surface = try movy.RenderSurface.init(
        allocator,
        target_width,
        target_height,
        movy.core.types.Rgb{ .r = 0xff, .g = 0, .b = 0 },
    );
    defer surface.deinit(allocator);

    surface.x = 0;
    surface.y = 0;

    try screen.addRenderSurface(surface);

    // -- Parse args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try stdout.print("Error: missing filename\n", .{});
        return error.MissingFileName;
    }

    const file_name = args[1];
    try stdout.print("Working with filename '{s}'\n", .{file_name});

    // Initialize the decoder
    const decoder =
        try movy_video.VideoDecoder.init(allocator, file_name, surface);
    defer decoder.deinit(allocator);

    const MAX_VIDEO_QUEUE = 600;
    const SYNC_WINDOW_NS: i64 = 80_000_000;

    while (true) {
        if (try movy.input.get()) |event| {
            if (event == .key and event.key.type == .Escape) break;
        }

        // FIRST: Chck if a frame is ready to render (even before decoding more)
        if (decoder.video.queue_count > 0) {
            if (decoder.video.peekFrame()) |head| {
                const playback_time_ns = decoder.getAudioClock(); // already relative
                const head_pts_i64 = @as(i64, @intCast(head.pts_ns));
                const audio_i64 = @as(i64, @intCast(playback_time_ns));
                const diff = head_pts_i64 - audio_i64;

                // std.debug.print("PEEK PTS: {}\n", .{head.pts_ns});
                // std.debug.print("  head.pts_ns = {}, audio_played = {}, diff = {}\n", .{
                //     head.pts_ns,
                //     playback_time_ns,
                //     diff,
                // });

                if (diff <= SYNC_WINDOW_NS and diff >= -SYNC_WINDOW_NS) {
                    if (decoder.video.popFrameForRender()) |frame_ptr| {
                        // std.debug.print("POPPED  q-size: {}\n", .{decoder.video.queue_count});
                        // std.debug.print("POPPED PTS: {}\n", .{frame_ptr.*.pts});
                        // std.debug.print("POPPED new tail index: {}\n", .{decoder.video.queue_tail});
                        decoder.video.renderFrameToSurface(frame_ptr, surface);
                        screen.render();
                        try screen.output();
                        c.av_frame_free(
                            @as(
                                [*c][*c]c.AVFrame,
                                @constCast(@ptrCast(&frame_ptr)),
                            ),
                        );
                    }
                }
            }
        }

        // THEN: Decode only if queue is not full
        if (decoder.video.queue_count < MAX_VIDEO_QUEUE) {
            var frame_decoded = false;
            while (!frame_decoded) {
                switch (try decoder.processNextPacket()) {
                    .eof => break,
                    .handled_video => frame_decoded = true,
                    .handled_audio => {},
                    .skipped => break,
                }
            }
        }

        // Small sleep to yield
        std.time.sleep(100_000); // 0.1ms
    }
}
