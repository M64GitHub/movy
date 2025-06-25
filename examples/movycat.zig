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
    const decoder = try movy_video.VideoDecoder.init(allocator, file_name, surface);
    defer decoder.deinit(allocator);

    for (0..5) |_| {
        switch (try decoder.processNextPacket()) {
            .eof => break,
            .handled_video => {},
            .handled_audio => {
                if (decoder.audio.?.has_started_playing and decoder.video.start_time_ns == 0) {
                    decoder.video.start_time_ns = decoder.audio.?.start_time_ns;
                }
            },
            .skipped => std.time.sleep(100_000),
        }
    }

    while (true) {
        if (try movy.input.get()) |event| {
            if (event == .key and event.key.type == .Escape) break;
        }

        if (decoder.video.frame_ready) {
            if (!decoder.shouldRenderNow()) {
                std.time.sleep(500); // just wait a little and check again
                continue;
            }

            decoder.renderCurrentFrame();
            screen.render();
            try screen.output();
            decoder.video.frame_ready = false;
        }

        //  At this point: either no frame yet, or time to decode another
        switch (try decoder.processNextPacket()) {
            .eof => break,
            .handled_video => {},
            .handled_audio => {
                if (decoder.audio.?.has_started_playing and decoder.video.start_time_ns == 0) {
                    decoder.video.start_time_ns = decoder.audio.?.start_time_ns;
                }
            },
            .skipped => std.time.sleep(1_000),
        }

        std.time.sleep(1_000); // wait a bit, let audio catch up
    }
}
