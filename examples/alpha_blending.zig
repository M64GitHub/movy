/// Alpha Blending Example
///
/// Demonstrates true alpha blending with semi-transparent surfaces:
/// - Creating surfaces with custom alpha values
/// - Using setAlpha() for transparency (0-255)
/// - renderWithAlphaToBg() for optimized alpha compositing
/// - Visual demonstration of opacity levels
///
/// This example shows a key feature of movy: true Porter-Duff alpha blending.
/// A semi-transparent red square is blended over a black background, demonstrating
/// how different opacity levels create different color intensities.
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Create output surface (opaque black background)
    var output = try movy.RenderSurface.init(
        allocator,
        80, // 80 characters wide
        40, // 40 pixel rows = 20 terminal lines
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 }, // Black
    );
    defer output.deinit(allocator);

    // Ensure background is opaque (alpha = 255)
    output.setAlpha(255);

    // Create a semi-transparent red sprite
    var sprite = try movy.RenderSurface.init(
        allocator,
        20, // 20 characters wide
        20, // 20 pixel rows = 10 lines tall
        movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 }, // Red
    );
    defer sprite.deinit(allocator);

    // Set sprite to 50% transparent (alpha = 128)
    // Alpha values: 0 = fully transparent, 255 = fully opaque
    sprite.setAlpha(128);

    sprite.x = 10; // Position at (10, 5)
    sprite.y = 5;
    sprite.z = 1; // Layer 1 (on top of background)

    // Render with alpha blending using renderWithAlphaToBg()
    // This is the RECOMMENDED function for alpha blending in movy
    var surfaces = [_]*movy.RenderSurface{sprite};
    movy.render.RenderEngine.renderWithAlphaToBg(&surfaces, output);

    // The result: a dark red square blended at 50% opacity
    // Color calculation: (255 × 128 + 0 × 127) / 255 ≈ 128 for red channel
    // Final color: approximately (128, 0, 0) - a dark red

    // Output to terminal
    const ansi = try output.toAnsi();
    try stdout.writeAll(ansi);
    try stdout.flush();
}
