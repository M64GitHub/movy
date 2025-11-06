/// Scaling Up and Down Example
///
/// Demonstrates RenderSurface scaling capabilities:
/// - Load small PNG asset (asteroid_small.png: 16x16)
/// - Display original size and progressively scaled versions side-by-side
/// - Cycle through different scale factors with keypresses
/// - Compare visual quality at different sizes
/// - Use nearest_neighbor algorithm for pixel art preservation
///
/// Controls:
/// - SPACE: Cycle through scale factors (1x, 2x, 3x, 4x)
/// - Q/ESC: Quit
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Use fixed terminal size to avoid IoctlFailed error
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

    // Load original asteroid image (16x16)
    const original = try movy.RenderSurface.createFromPng(
        allocator,
        "examples/assets/asteroid_small.png",
    );
    defer original.deinit(allocator);

    // State: current scale factor index
    var scale_index: usize = 0;
    var last_scale_index: usize = 999; // Force initial scaling
    const scale_factors = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const scale_labels = [_][]const u8{
        "1x (16x16)",
        "2x (32x32)",
        "3x (48x48)",
        "4x (64x64)",
    };

    const frame_delay_ns = 17 * std.time.ns_per_ms; // ~60 FPS

    // Pre-allocate all UI surfaces
    // Title
    var title = try movy.RenderSurface.init(allocator, 80, 4, movy.color.BLACK);
    defer title.deinit(allocator);
    title.y = 0;
    title.z = 100;
    _ = title.putStrXY(
        "Scaling Up/Down Demo - SPACE: Next Scale | Q: Quit",
        2,
        0,
        movy.color.WHITE,
        movy.color.BLACK,
    );

    // Original label
    var label1 = try movy.RenderSurface.init(allocator, 30, 2, movy.color.BLACK);
    defer label1.deinit(allocator);
    label1.x = 5;
    label1.y = 8;
    label1.z = 100;
    _ = label1.putStrXY(
        "Original (16x16):",
        0,
        0,
        movy.color.YELLOW,
        movy.color.BLACK,
    );

    // Display original
    var original_display = try movy.RenderSurface.init(
        allocator,
        original.w,
        original.h,
        movy.color.BLACK,
    );
    defer original_display.deinit(allocator);
    try original_display.copy(original);
    original_display.x = 10;
    original_display.y = 12;
    original_display.z = 1;

    // Scaled label
    var label2 = try movy.RenderSurface.init(allocator, 40, 2, movy.color.BLACK);
    defer label2.deinit(allocator);
    label2.x = 45;
    label2.y = 8;
    label2.z = 100;
    var buf: [64]u8 = undefined;

    // Pre-allocate scaled surface
    var scaled = try movy.RenderSurface.init(
        allocator,
        original.w,
        original.h,
        movy.color.BLACK,
    );
    defer scaled.deinit(allocator);
    scaled.x = 50;
    scaled.y = 12;
    scaled.z = 1;

    // Info text
    var info = try movy.RenderSurface.init(allocator, 80, 2, movy.color.BLACK);
    defer info.deinit(allocator);
    info.y = 70;
    info.z = 100;
    _ = info.putStrXY(
        "Nearest neighbor algorithm preserves pixel art look",
        5,
        0,
        movy.color.GRAY,
        movy.color.BLACK,
    );

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Handle input
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    switch (key.type) {
                        .Escape => break,
                        .Char => {
                            if (key.sequence.len > 0) {
                                const ch = key.sequence[0];
                                if (ch == 'q' or ch == 'Q') break;
                                if (ch == ' ') {
                                    scale_index = (scale_index + 1) %
                                        scale_factors.len;
                                }
                            }
                        },
                        else => {},
                    }
                },
                .mouse => {},
            }
        }

        // Re-scale surface only when scale factor changes
        if (scale_index != last_scale_index) {
            const current_scale = scale_factors[scale_index];
            const scaled_w = @as(
                usize,
                @intFromFloat(
                    @as(f32, @floatFromInt(original.w)) * current_scale,
                ),
            );
            const scaled_h = @as(
                usize,
                @intFromFloat(
                    @as(f32, @floatFromInt(original.h)) * current_scale,
                ),
            );

            try scaled.resize(allocator, original.w, original.h);
            try scaled.copy(original);
            try scaled.scale(allocator, scaled_w, scaled_h, .nearest_neighbor);
            // Restore position after copy (copy overwrites x, y, z)
            scaled.x = 50;
            scaled.y = 12;
            scaled.z = 1;

            last_scale_index = scale_index;
        }

        try screen.renderInit();

        // Update scaled label text
        const scaled_label = try std.fmt.bufPrint(
            &buf,
            "Scaled {s}:",
            .{scale_labels[scale_index]},
        );
        _ = label2.putStrXY(
            scaled_label,
            0,
            0,
            movy.color.CYAN,
            movy.color.BLACK,
        );

        // Add all pre-allocated surfaces
        try screen.addRenderSurface(allocator, title);
        try screen.addRenderSurface(allocator, label1);
        try screen.addRenderSurface(allocator, label2);
        try screen.addRenderSurface(allocator, original_display);
        try screen.addRenderSurface(allocator, scaled);
        try screen.addRenderSurface(allocator, info);

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
