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

    // while (true) {
    //     if (try movy.input.get()) |event| {
    //         if (event == .key and event.key.type == .Escape) break;
    //     }
    //
    //     // Step 1: Read a packet
    //     switch (try decoder.readAndDispatchNextPacket()) {
    //         .eof => break,
    //         .packet_ok => {},
    //         .no_packet_yet => continue,
    //     }
    //
    //     // Step 2: Decode audio if needed
    //     if (decoder.audio) |*a| {
    //         a.maybeDecodeMore(decoder);
    //     }
    //
    //     // Step 3: Decode & Render video
    //     if (try decoder.decodeNextVideoFrame()) {
    //         if (decoder.video.frame_ready and !decoder.video.has_reference_error) {
    //             decoder.renderCurrentFrame();
    //             screen.render();
    //             try screen.output();
    //         }
    //     }
    // }

    // while (true) {
    //     if (try movy.input.get()) |event| {
    //         if (event == .key and event.key.type == .Escape) break;
    //     }
    //
    //     std.time.sleep(100_000);
    //
    //     switch (try decoder.processNextPacket()) {
    //         .eof => break,
    //         .handled_video => {
    //             if (decoder.video.frame_ready and !decoder.video.has_reference_error) {
    //                 decoder.renderCurrentFrame();
    //                 screen.render();
    //                 try screen.output();
    //             }
    //         },
    //         .handled_audio => {}, // decoding already happened!
    //         .skipped => {},
    //     }
    // }

    const ALLOWABLE_LEEWAY_NS = 15_000_000; // 15ms leeway (~1 frame at 60fps)

    while (true) {
        if (try movy.input.get()) |event| {
            if (event == .key and event.key.type == .Escape) break;
        }

        const audio_ns = decoder.getAudioClock();

        // Only allow reading new packets if we are not ahead
        if (decoder.video.frame_ready) {
            if (decoder.video.frame_pts_ns > audio_ns + ALLOWABLE_LEEWAY_NS) {
                std.time.sleep(10_000); // wait a bit, let audio catch up
                continue;
            }

            // Time to render the current frame!
            decoder.renderCurrentFrame();
            screen.render();
            try screen.output();
            decoder.video.frame_ready = false;
            continue;
        }

        // 🧠 At this point: either no frame yet, or time to decode another
        switch (try decoder.processNextPacket()) {
            .eof => break,
            .handled_video => {},
            .handled_audio => {},
            .skipped => std.time.sleep(100_000),
        }

        std.time.sleep(1_000); // wait a bit, let audio catch up
    }
}
