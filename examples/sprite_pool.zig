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
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Setup terminal
    const terminal_size = try movy.terminal.getSize();

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // Setup screen
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );
    defer screen.deinit(allocator);

    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.DARKER_GRAY;

    // Create sprite pool
    var sprite_pool = movy.graphic.SpritePool.init();
    defer sprite_pool.deinit(allocator);

    // Populate pool with 8 sprites
    // Benefit: Reuse sprites instead of creating/destroying them each frame
    for (0..8) |_| {
        var sprite = try Sprite.initFromPng(
            allocator,
            "examples/assets/sprite16x16-16frames.png",
            "sprite",
        );

        // Split sprite sheet into 16x16 frames
        try sprite.splitByWidth(allocator, 16);

        // Create and start animation
        try sprite.addAnimation(
            allocator,
            "flash",
            Sprite.FrameAnimation.init(1, 16, .loopForward, 2),
        );
        try sprite.startAnimation("flash");

        // Add to pool for later retrieval
        try sprite_pool.addSprite(allocator, sprite);
    }

    // Get sprites from pool
    // Pattern: Get sprites when needed, return them when done
    const sprite1 = sprite_pool.get() orelse return error.NoSpritesAvailable;
    const sprite2 = sprite_pool.get() orelse return error.NoSpritesAvailable;

    // Position sprites on screen
    sprite1.setXY(10, 10);
    sprite2.setXY(30, 15);

    // Setup main loop
    var frame_counter: usize = 0;
    const frame_delay_ns = 17 * std.time.ns_per_ms;  // ~60 FPS

    // Main loop
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
                .mouse => {},  // Ignore mouse input
            }
        }

        // Init screen rendering
        try screen.renderInit();

        // Animate both pooled sprites
        sprite1.stepActiveAnimation();
        sprite2.stepActiveAnimation();

        // Add sprite surfaces to screen
        // Each sprite maintains its own position and animation state
        try screen.addRenderSurface(
            allocator,
            try sprite1.getCurrentFrameSurface(),
        );
        try screen.addRenderSurface(
            allocator,
            try sprite2.getCurrentFrameSurface(),
        );

        // Render and output
        screen.render();
        try screen.output();

        frame_counter += 1;

        // Constant FPS
        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
