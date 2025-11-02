const std = @import("std");
const movy = @import("movy");
const Starfield = @import("Starfield.zig").Starfield;

// -- MAIN

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // -- Init terminal and screen
    // Get the terminal size
    const terminal_size = try movy.terminal.getSize();

    // Set raw mode, switch to alternate screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // -- Initialize screen (height in line numbers)
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );

    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // -- create the starfield
    const starfield = try Starfield.init(allocator, &screen);
    defer starfield.deinit(allocator);

    // -- create help text
    const help_surface = try movy.RenderSurface.init(
        allocator,
        terminal_size.width,
        2, // 2 is 1 line!
        movy.color.DARKER_BLUE,
    );
    defer help_surface.deinit(allocator);
    help_surface.y = @intCast((terminal_size.height - 1) * 2);

    const help_text =
        "<ESC>, q: Quit";

    // Print help text (left side)
    _ = help_surface.putStrXY(
        help_text,
        2,
        0,
        movy.color.WHITE,
        movy.color.DARKER_BLUE,
    );

    // -- Main loop
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
        } else {
            // No input
        }

        // -- update!
        starfield.update();

        // -- Render
        try screen.renderInit();

        // add RenderSurfaces
        try screen.addRenderSurface(allocator, help_surface); // text on TOP
        try screen.addRenderSurface(allocator, starfield.out_surface);

        screen.render();
        try screen.output();

        frame_counter += 1;

        // Frame timing
        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
