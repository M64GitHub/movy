/// Sprite Fading Example
///
/// Demonstrates sprite alpha (transparency) animation:
/// - Loading sprites from PNG files
/// - Splitting sprite sheets by frame width
/// - Creating frame-based animations
/// - Dynamically adjusting sprite alpha/opacity
/// - Using renderWithAlpha() for proper transparency
///
/// This example shows how to fade a sprite in and out by modifying
/// its alpha channel while the sprite animation plays.

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

    var sprite1 = try Sprite.initFromPng(
        allocator,
        "examples/assets/sprite16x16-16frames.png",
        "sprite1",
    );
    defer sprite1.deinit(allocator);

    try sprite1.splitByWidth(allocator, 16);
    try sprite1.addAnimation(
        allocator,
        "flash",
        Sprite.FrameAnimation.init(1, 16, .loopForward, 2),
    );
    try sprite1.startAnimation("flash");

    var frame_counter: usize = 0;
    var alpha: u8 = 0;
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

        sprite1.stepActiveAnimation();
        sprite1.setXY(5, 5);

        // Apply fading effect by modifying alpha
        try sprite1.setAlphaCurrentFrameSurface(alpha);
        alpha = @addWithOverflow(alpha, 2)[0]; // Wraps 0→255→0

        try screen.addRenderSurface(
            allocator,
            try sprite1.getCurrentFrameSurface(),
        );

        // Use renderWithAlpha() for proper alpha blending
        screen.renderWithAlpha();
        try screen.output();

        frame_counter += 1;

        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
