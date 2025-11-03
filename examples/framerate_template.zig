/// Framerate Template Example
///
/// A minimal template for building frame-based applications:
/// - Terminal initialization (raw mode, alternate screen)
/// - 60 FPS game loop with frame timing
/// - Keyboard input handling
/// - Render cycle (renderInit, render, output)
///
/// This is a starting point for building games and animations
/// with consistent frame timing.

const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.getSize();

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );

    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.DARKER_GRAY;

    var frame_counter: usize = 0;
    const frame_delay_ns = 17 * std.time.ns_per_ms; // ~60 FPS

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Handle input
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    switch (key.type) {
                        .Escape => break,
                        .Char => {
                            if (key.sequence.len > 0 and
                                key.sequence[0] == 'q') break;
                        },
                        else => {},
                    }
                },
                .mouse => {}, // Ignore mouse input
            }
        }

        try screen.renderInit();

        screen.render();
        try screen.output();

        frame_counter += 1;

        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
