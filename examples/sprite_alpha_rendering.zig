/// Sprite Alpha Rendering Example
///
/// Demonstrates the minimal workflow for alpha-blended sprite rendering:
/// - Loading a sprite with transparency
/// - Applying custom alpha values (50% opacity)
/// - Splitting sprite sheet into frames
/// - Adding and stepping animation
/// - Rendering with screen.renderAlpha()
///
/// This is a single-shot example (no loop) showing the essential steps
/// for alpha-blended sprite rendering with movy.

const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get terminal size
    const terminal_size = try movy.terminal.getSize();
    const screen_width = terminal_size.width;
    const screen_height = terminal_size.height;

    // Initialize screen
    var screen = try movy.Screen.init(
        allocator,
        screen_width,
        screen_height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Clear screen surfaces
    try screen.renderInit();

    // Load sprite from PNG
    var sprite = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/sprite1.png",
        "sprite_alpha_demo",
    );
    defer sprite.deinit(allocator);

    // CRITICAL: Apply 50% transparency BEFORE splitting
    // This demonstrates how to set custom alpha values on sprites
    const current_frame = try sprite.getCurrentFrameSurface();
    for (current_frame.shadow_map) |*alpha| {
        alpha.* = 128; // 50% opacity (0 = transparent, 255 = opaque)
    }

    // Split sprite sheet by width (16px per frame)
    // This creates 16 individual frames from the sprite sheet
    try sprite.splitByWidth(allocator, 16);

    // Add animation definition
    // Frames 1-16, loop forward, speed 4
    const frame_anim = movy.graphic.Sprite.FrameAnimation.init(
        1, // start frame
        16, // end frame
        .loopForward,
        4, // speed
    );
    try sprite.addAnimation(allocator, "default", frame_anim);

    // Start the animation
    try sprite.startAnimation("default");

    // Step animation once (advances to next frame)
    sprite.stepActiveAnimation();

    // Position sprite in center of screen
    const sprite_x = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const sprite_y = @divTrunc(@as(i32, @intCast(screen_height * 2)), 2);
    sprite.setXY(sprite_x, sprite_y);

    // Add sprite to screen
    try screen.addRenderSurface(
        allocator,
        try sprite.getCurrentFrameSurface(),
    );

    // Render with alpha blending (NEW METHOD)
    // This uses the new renderAlpha() function that properly handles
    // the shadow_map (alpha channel) for semi-transparent rendering
    screen.renderAlpha();

    // Output to terminal
    try screen.output();

    // Wait 2 seconds so user can see the result
    std.Thread.sleep(2 * std.time.ns_per_s);

    // Cleanup happens automatically via defer
}
