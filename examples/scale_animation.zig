/// Scale Animation Example
///
/// Demonstrates continuous scaling animation:
/// - Loads asteroid_huge.png (48x48)
/// - Animates scaling from 10% to 120% and back
/// - Keeps sprite centered on screen
/// - Shows smooth size transitions using nearest_neighbor algorithm
///
/// This example demonstrates real-time scaling effects for
/// breathing/pulsing animations in games.
///
/// Controls:
/// - Q/ESC: Quit

const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Use fixed terminal size
    const terminal_width: usize = 120;
    const terminal_height: usize = 80;

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    movy.terminal.cursorOff();
    defer movy.terminal.cursorOn();

    var screen = try movy.Screen.init(
        allocator,
        terminal_width,
        terminal_height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Load original asteroid image (48x48)
    const original = try movy.RenderSurface.createFromPng(
        allocator,
        "examples/assets/asteroid_huge.png",
    );
    defer original.deinit(allocator);

    // Pre-allocate animated surface
    var animated = try movy.RenderSurface.init(allocator, original.w, original.h, movy.color.BLACK);
    defer animated.deinit(allocator);
    animated.z = 1;

    // Pre-allocate title
    var title = try movy.RenderSurface.init(allocator, 80, 2, movy.color.BLACK);
    defer title.deinit(allocator);
    title.z = 100;
    _ = title.putStrXY(
        "Scale Animation - Q/ESC: Quit",
        2,
        0,
        movy.color.WHITE,
        movy.color.BLACK,
    );

    // Pre-allocate info display
    var info = try movy.RenderSurface.init(allocator, 40, 2, movy.color.BLACK);
    defer info.deinit(allocator);
    info.y = 4;
    info.z = 100;
    var info_buf: [64]u8 = undefined;

    // Animation state
    var scale_percent: f32 = 10.0; // Start at 10%
    var growing: bool = true; // Start growing
    const scale_step: f32 = 1.0; // 1% per frame
    const min_scale: f32 = 10.0;
    const max_scale: f32 = 120.0;

    const frame_delay_ns = 17 * std.time.ns_per_ms; // ~60 FPS

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Handle input (quit only)
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    switch (key.type) {
                        .Escape => break,
                        .Char => {
                            if (key.sequence.len > 0) {
                                const ch = key.sequence[0];
                                if (ch == 'q' or ch == 'Q') break;
                            }
                        },
                        else => {},
                    }
                },
                .mouse => {},
            }
        }

        // Update scale animation
        if (growing) {
            scale_percent += scale_step;
            if (scale_percent >= max_scale) {
                scale_percent = max_scale;
                growing = false;
            }
        } else {
            scale_percent -= scale_step;
            if (scale_percent <= min_scale) {
                scale_percent = min_scale;
                growing = true;
            }
        }

        // Calculate target dimensions
        const scale_factor = scale_percent / 100.0;
        const target_w = @as(usize, @intFromFloat(48.0 * scale_factor));
        const target_h = @as(usize, @intFromFloat(48.0 * scale_factor));

        // Scale the surface
        try animated.resize(allocator, original.w, original.h);
        try animated.copy(original);
        try animated.scale(allocator, target_w, target_h, .nearest_neighbor);

        // Center the scaled surface on screen
        const center_x = @as(i32, @intCast(terminal_width / 2)) - @as(i32, @intCast(target_w / 2));
        const center_y = @as(i32, @intCast(terminal_height / 2)) - @as(i32, @intCast(target_h / 2));
        animated.x = center_x;
        animated.y = center_y;
        animated.z = 1;

        try screen.renderInit();

        // Update info text
        const info_text = try std.fmt.bufPrint(
            &info_buf,
            "Scale: {d:.0}% ({s})",
            .{ scale_percent, if (growing) "growing" else "shrinking" },
        );
        _ = info.putStrXY(info_text, 2, 0, movy.color.YELLOW, movy.color.BLACK);

        // Add surfaces
        try screen.addRenderSurface(allocator, title);
        try screen.addRenderSurface(allocator, info);
        try screen.addRenderSurface(allocator, animated);

        screen.render();
        try screen.output();

        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }

    movy.terminal.clear();
}
