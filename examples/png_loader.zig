/// PNG Loader Example
///
/// Demonstrates loading and displaying PNG images:
/// - createFromPng() function
/// - Automatic PNG alpha channel loading
/// - Positioning loaded sprites
/// - Basic display workflow
/// - Working with assets
///
/// This example shows the essential workflow for loading image files
/// and displaying them on the terminal using movy.

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

    // Clear screen surfaces
    try screen.renderInit();

    // Load a PNG file into a RenderSurface
    // createFromPng() automatically:
    // - Reads RGB color data
    // - Reads alpha channel into shadow_map (0-255)
    // - Sets dimensions to match the PNG file
    var sprite_surface = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/movy.png",  // Load the movy logo
    );
    defer sprite_surface.deinit(allocator);

    // Position the loaded sprite
    sprite_surface.x = 5;   // 5 characters from the left
    sprite_surface.y = 3;   // 3 lines from the top
    sprite_surface.z = 1;   // Layer 1

    // Add the loaded surface to screen
    try screen.addRenderSurface(allocator, sprite_surface);

    // Add a text label to show info
    var text_surface = try movy.RenderSurface.init(
        allocator,
        terminal_size.width,
        4,  // 2 lines tall
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer text_surface.deinit(allocator);

    const white = movy.core.types.Rgb{ .r = 255, .g = 255, .b = 255 };
    const black = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };

    _ = text_surface.putStrXY(
        "PNG Loader Example - Image loaded from assets/movy.png",
        0,
        0,  // Even y coordinate
        white,
        black,
    );

    text_surface.y = 0;
    text_surface.z = 10;

    try screen.addRenderSurface(allocator, text_surface);

    // Render and output
    screen.render();
    try screen.output();
}
