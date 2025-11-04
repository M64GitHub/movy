/// Sprite Animation Example
///
/// Demonstrates sprite loading and frame-based animation:
/// - Loading sprites from PNG files
/// - Splitting sprite sheets by frame width
/// - Creating looping frame animations
/// - Animation control and timing
/// - Keyboard input handling
///
/// This example shows how to load a sprite sheet, define animations,
/// and step through frames in a game loop.

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

    // Load sprite from PNG file
    var sprite1 = try Sprite.initFromPng(
        allocator,
        "examples/assets/sprite16x16-16frames.png",
        "sprite1",
    );
    defer sprite1.deinit(allocator);

    // Split sprite sheet into 16x16 frames
    // Creates frames 1-16 from the horizontal strip
    try sprite1.splitByWidth(allocator, 16);

    // Create frame animation
    // Parameters: start_frame=1, end_frame=16, mode=loopForward, speed=2
    // Loop modes: .loopForward (1->2->3->1), .loopReverse (3->2->1->3),
    //             .loopPingPong (1->2->3->2->1), .once (1->2->3 stop)
    try sprite1.addAnimation(
        allocator,
        "flash",
        Sprite.FrameAnimation.init(1, 16, .loopForward, 2),
    );

    // Start the animation
    try sprite1.startAnimation("flash");

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

        // Advance animation to next frame
        // This updates the frame_idx based on the animation's loop mode and speed
        sprite1.stepActiveAnimation();

        // Position sprite on screen
        // IMPORTANT: Call setXY() AFTER stepActiveAnimation()
        // Each frame is a separate object, so position after switching frames
        sprite1.setXY(5, 5);

        // Add current frame's surface to screen
        try screen.addRenderSurface(
            allocator,
            try sprite1.getCurrentFrameSurface(),
        );

        // Render and output to terminal
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
