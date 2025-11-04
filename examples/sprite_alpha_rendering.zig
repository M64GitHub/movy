/// Sprite Alpha Rendering Example
///
/// Demonstrates the minimal workflow for alpha-blended sprite rendering:
/// - Loading a sprite with transparency
/// - Applying custom alpha values (50% opacity)
/// - Splitting sprite sheet into frames
/// - Adding and stepping animation
/// - Rendering with screen.renderWithAlpha()
///
/// This is a single-shot example (no loop) showing the essential steps
/// for alpha-blended sprite rendering with movy.
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get terminal size
    const terminal_size = try movy.terminal.getSize();
    const screen_width = terminal_size.width;
    const screen_height = terminal_size.height;

    // Setup screen
    var screen = try movy.Screen.init(
        allocator,
        screen_width,
        screen_height,
    );
    defer screen.deinit(allocator);

    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Init screen rendering
    try screen.renderInit();

    // Load sprite from PNG
    var sprite = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/sprite1.png",
        "sprite_alpha_demo",
    );
    defer sprite.deinit(allocator);

    // Apply custom alpha value (50% transparency)
    // Set alpha BEFORE splitting frames, to apply to all frames
    // The shadow_map stores alpha/opacity: 0 = transparent, 255 = opaque
    const current_frame = try sprite.getCurrentFrameSurface();
    sprite.setAlphaCurrentFrameSurface(128); // 50% transparency

    // Split sprite sheet into frames
    // Creates 16 individual frames (16 pixels wide each)
    try sprite.splitByWidth(allocator, 16);

    // Create frame animation
    // Frames 1-16, loop forward, speed 4
    const frame_anim = movy.graphic.Sprite.FrameAnimation.init(
        1, // start frame
        16, // end frame
        .loopForward,
        4, // speed (frames to wait between updates)
    );
    try sprite.addAnimation(allocator, "default", frame_anim);

    // Start and advance animation
    try sprite.startAnimation("default");
    sprite.stepActiveAnimation(); // Advance to next frame

    // Position sprite in center
    const sprite_x = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const sprite_y = @divTrunc(@as(i32, @intCast(screen_height * 2)), 2);
    sprite.setXY(sprite_x, sprite_y);

    // Add sprite surface to screen
    try screen.addRenderSurface(
        allocator,
        try sprite.getCurrentFrameSurface(),
    );

    // Render with alpha blending
    // IMPORTANT: Use renderWithAlpha() instead of render()
    // - render() treats alpha as binary (opaque or transparent)
    // - renderWithAlpha() performs proper alpha blending
    // This enables semi-transparent rendering with smooth blending
    screen.renderWithAlpha();

    // Output to terminal
    try screen.output();

    // Wait so user can see the result
    std.Thread.sleep(2 * std.time.ns_per_s);

    // Cleanup happens automatically via defer
}
