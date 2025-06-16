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

    // -- setup movy screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(
        allocator,
        target_width + 8,
        target_height / 2 + 4,
    );
    defer screen.deinit(allocator);

    screen.setScreenMode(movy.Screen.Mode.transparent);

    // -- init render surface for output, and add to screen
    var surface = try movy.RenderSurface.init(
        allocator,
        target_width,
        target_height,
        movy.core.types.Rgb{ .r = 0xff, .g = 0, .b = 0 },
    );
    defer surface.deinit(allocator);

    surface.x = 4;
    surface.y = 4;

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

    // -- open movie

    const decoder = try movy_video.VideoDecoder.init(
        allocator,
        file_name,
        surface,
    );
    defer decoder.deinit();

    while (try decoder.readVideoFrameFrame()) {
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

        screen.render();
        try screen.output(); // blast to terminal

        // frame sync
        if (decoder.was_video_frame) decoder.syncFrame();
    }
}
