/// Basic RenderSurface Example
///
/// Demonstrates the fundamental operations with RenderSurface:
/// - Creating a surface with init()
/// - Adding text with putStrXY() and putUtf8XY()
/// - Understanding the even y-coordinate rule for text
/// - Using Unicode characters
/// - Integrating with Screen for terminal output
///
/// This example creates a simple surface with both text and graphics,
/// showing the basic workflow for movy applications.

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

    // Create a surface with graphics (dark blue background)
    var background = try movy.RenderSurface.init(
        allocator,
        40,  // 40 characters wide
        20,  // 20 pixel rows = 10 terminal lines (height / 2)
        movy.core.types.Rgb{ .r = 0, .g = 50, .b = 100 },  // Dark blue
    );
    defer background.deinit(allocator);
    background.z = 0;

    // Define colors for text
    const white = movy.core.types.Rgb{ .r = 255, .g = 255, .b = 255 };
    const black = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };
    const yellow = movy.core.types.Rgb{ .r = 255, .g = 255, .b = 0 };
    const red = movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 };
    const cyan = movy.core.types.Rgb{ .r = 0, .g = 255, .b = 255 };

    // Add text to the surface
    // IMPORTANT: Text must be on EVEN y coordinates (0, 2, 4, 6, ...)
    // due to half-block rendering

    _ = background.putStrXY(
        "Welcome to movy!",
        2,   // X position
        2,   // Y position (line 2 - even coordinate!)
        white,
        black,
    );

    _ = background.putStrXY(
        "Text and graphics\ntogether in harmony.",
        2,
        4,  // Line 4 (even coordinate)
        white,
        black,
    );

    // Add some Unicode symbols using putUtf8XY
    // These show off movy's Unicode support
    background.putUtf8XY('★', 0, 0, yellow, black);  // Star
    background.putUtf8XY('♥', 2, 0, red, black);     // Heart
    background.putUtf8XY('♪', 4, 0, cyan, black);    // Music note

    // Render to screen
    try screen.renderInit();
    try screen.addRenderSurface(allocator, background);
    screen.render();
    try screen.output();
}
