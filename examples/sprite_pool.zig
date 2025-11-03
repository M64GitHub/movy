/// Sprite Pool Example
///
/// Demonstrates efficient sprite management using SpritePool:
/// - Creating and initializing a sprite pool
/// - Loading multiple sprites into the pool
/// - Getting sprites from the pool for use
/// - Pooling for memory efficiency and reuse
///
/// This example shows how to manage multiple sprites efficiently
/// using the sprite pool pattern for better performance.

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

    var sprite_pool = movy.graphic.SpritePool.init();
    defer sprite_pool.deinit(allocator);

    for (0..8) |_| {
        var sprite = try Sprite.initFromPng(
            allocator,
            "examples/assets/sprite16x16-16frames.png",
            "sprite",
        );

        try sprite.splitByWidth(allocator, 16);
        try sprite.addAnimation(
            allocator,
            "flash",
            Sprite.FrameAnimation.init(1, 16, .loopForward, 2),
        );
        try sprite.startAnimation("flash");
        try sprite_pool.addSprite(allocator, sprite);
    }

    const sprite1 = sprite_pool.get() orelse return error.NoSpritesAvailable;
    const sprite2 = sprite_pool.get() orelse return error.NoSpritesAvailable;
    sprite1.setXY(10, 10);
    sprite2.setXY(30, 15);

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

        sprite1.stepActiveAnimation();
        sprite2.stepActiveAnimation();

        try screen.addRenderSurface(
            allocator,
            try sprite1.getCurrentFrameSurface(),
        );
        try screen.addRenderSurface(
            allocator,
            try sprite2.getCurrentFrameSurface(),
        );

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
