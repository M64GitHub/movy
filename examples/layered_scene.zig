/// Layered Scene Example
///
/// Demonstrates multi-layer scene composition with z-ordering:
/// - Multiple surfaces with different z-indices
/// - Z-ordering and layering (back to front)
/// - Loading PNG images
/// - Combining opaque and semi-transparent layers
/// - Real-world scene structure (background, characters, UI)
///
/// This example shows how to build a scene with multiple layers,
/// similar to a game with background, player sprites, and UI overlays.
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.getSize();

    // Initialize screen
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    try screen.renderInit();

    // Layer 0: Background (loaded from PNG)
    // If you have a background.png in assets/, it will be loaded
    // Otherwise, we create a simple colored background
    var background = movy.RenderSurface.createFromPng(
        allocator,
        "assets/movy.png",
    ) catch try movy.RenderSurface.init(
        allocator,
        80,
        40,
        movy.core.types.Rgb{ .r = 20, .g = 40, .b = 60 }, // Dark blue fallback
    );
    defer background.deinit(allocator);
    background.z = 0; // Back layer

    // Layer 10: Player sprite (also from PNG or fallback)
    var player = movy.RenderSurface.createFromPng(
        allocator,
        "assets/alien.png",
    ) catch try movy.RenderSurface.init(
        allocator,
        15,
        15,
        movy.core.types.Rgb{ .r = 0, .g = 255, .b = 0 }, // Green fallback
    );
    defer player.deinit(allocator);
    player.x = 20; // Position in center-ish area
    player.y = 10;
    player.z = 10; // Middle layer

    // Layer 100: UI overlay (semi-transparent)
    var ui_overlay = try movy.RenderSurface.init(
        allocator,
        80,
        10, // 5 lines tall
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 100 }, // Dark blue
    );
    defer ui_overlay.deinit(allocator);

    // Make UI semi-transparent (75% opacity)
    ui_overlay.setAlpha(192); // 75% opaque, 25% transparent

    ui_overlay.y = 0; // Top of screen
    ui_overlay.z = 100; // Top layer

    // Add some text to the UI
    const white = movy.core.types.Rgb{ .r = 255, .g = 255, .b = 255 };
    const transparent = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };

    _ = ui_overlay.putStrXY(
        "Layered Scene Demo - Multiple Z-Indices",
        2,
        0, // Even y coordinate
        white,
        transparent,
    );

    _ = ui_overlay.putStrXY(
        "Background (z=0) | Player (z=10) | UI (z=100)",
        2,
        2, // Even y coordinate
        white,
        transparent,
    );

    // Add all surfaces to screen
    // They will be rendered in z-order automatically
    try screen.addRenderSurface(allocator, background);
    try screen.addRenderSurface(allocator, player);
    try screen.addRenderSurface(allocator, ui_overlay);

    // Render and output
    // screen.render() internally calls RenderEngine.render()
    // which sorts by z-index and composites all layers
    screen.render();
    try screen.output();
}
