// Stars Demo - Animated starfield
//
// Features:
// - 300 animated stars with depth-based movement
// - Depth-based color gradient and sizing
// - Smooth 60 FPS rendering
// - Help text overlay
//
// Controls:
// - esc, q: quit

const std = @import("std");
const movy = @import("movy");
const Starfield = @import("Starfield.zig").Starfield;

pub fn main() !void {
    // -- Init
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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
    screen.bg_color = movy.color.BLACK;

    // Create starfield
    const starfield = try Starfield.init(allocator, &screen);
    defer starfield.deinit(allocator);

    // Create help text overlay
    const help_surface = try movy.RenderSurface.init(
        allocator,
        terminal_size.width,
        2,  // 2 pixel rows = 1 terminal line
        movy.color.DARKER_BLUE,
    );
    defer help_surface.deinit(allocator);
    help_surface.y = @intCast((terminal_size.height - 1) * 2);

    _ = help_surface.putStrXY(
        "<ESC>, q: Quit",
        2,
        0,
        movy.color.WHITE,
        movy.color.DARKER_BLUE,
    );

    // -- Main loop
    var frame_counter: usize = 0;
    const frame_delay_ns = 17 * std.time.ns_per_ms;  // ~60 FPS

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Input
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
                .mouse => {},
            }
        }

        // Update starfield animation
        starfield.update();

        // Render
        try screen.renderInit();
        try screen.addRenderSurface(allocator, help_surface);
        try screen.addRenderSurface(allocator, starfield.out_surface);
        screen.render();
        try screen.output();

        frame_counter += 1;

        // Frame timing for constant 60 FPS
        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
