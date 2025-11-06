/// Scaling Algorithms Comparison Example
///
/// Demonstrates all four scaling algorithms side-by-side:
/// - None: Direct pixel mapping, no interpolation
/// - Nearest Neighbor: Fast, blocky, good for pixel art
/// - Bilinear: Smooth, weighted 2x2 interpolation
/// - Bicubic: Smoothest, weighted 4x4 interpolation
///
/// This example loads asteroid_huge.png (48x48) and scales it down
/// to show how each algorithm handles downscaling quality vs performance.
///
/// Controls:
/// - SPACE: Toggle between downscale factors (0.5x, 0.33x, 0.25x)
/// - Q/ESC: Quit
const std = @import("std");
const movy = @import("movy");
const ScaleAlgorithm = movy.core.ScaleAlgorithm;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Use fixed terminal size to avoid IoctlFailed error
    const terminal_width: usize = 160;
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

    // State
    var scale_index: usize = 0;
    var last_scale_index: usize = 999; // Force initial scaling
    const scale_factors = [_]f32{ 0.5, 0.33, 0.25 };
    const scale_labels = [_][]const u8{ "0.5x (24x24)", "0.33x (16x16)", "0.25x (12x12)" };

    const frame_delay_ns = 17 * std.time.ns_per_ms; // ~60 FPS

    // Algorithm configuration
    const algorithms = [_]ScaleAlgorithm{
        .none,
        .nearest_neighbor,
        .bilinear,
        .bicubic,
    };
    const labels = [_][]const u8{ "None", "Nearest Neighbor", "Bilinear", "Bicubic" };
    const descriptions = [_][]const u8{
        "Direct mapping",
        "Pick closest pixel",
        "2x2 interpolation",
        "4x4 interpolation",
    };
    const x_positions = [_]i32{ 5, 40, 75, 110 };

    // Pre-allocate all UI surfaces
    // Title
    var title = try movy.RenderSurface.init(allocator, 80, 2, movy.color.BLACK);
    defer title.deinit(allocator);
    title.z = 100;
    _ = title.putStrXY(
        "Algorithm Comparison - SPACE: Change Scale | Q: Quit",
        2,
        0,
        movy.color.WHITE,
        movy.color.BLACK,
    );

    // Current scale info
    var info_surf = try movy.RenderSurface.init(allocator, 80, 2, movy.color.BLACK);
    defer info_surf.deinit(allocator);
    info_surf.y = 4;
    info_surf.z = 100;
    var info_buf: [64]u8 = undefined;

    // Algorithm labels (4 surfaces)
    var label_surfaces: [4]*movy.RenderSurface = undefined;
    for (0..4) |i| {
        label_surfaces[i] = try movy.RenderSurface.init(allocator, 30, 2, movy.color.BLACK);
        label_surfaces[i].x = x_positions[i];
        label_surfaces[i].y = 12;
        label_surfaces[i].z = 100;
        _ = label_surfaces[i].putStrXY(labels[i], 0, 0, movy.color.CYAN, movy.color.BLACK);
    }
    defer for (0..4) |i| label_surfaces[i].deinit(allocator);

    // Algorithm descriptions (4 surfaces)
    var desc_surfaces: [4]*movy.RenderSurface = undefined;
    for (0..4) |i| {
        desc_surfaces[i] = try movy.RenderSurface.init(allocator, 30, 2, movy.color.BLACK);
        desc_surfaces[i].x = x_positions[i];
        desc_surfaces[i].y = 16;
        desc_surfaces[i].z = 100;
        _ = desc_surfaces[i].putStrXY(descriptions[i], 0, 0, movy.color.GRAY, movy.color.BLACK);
    }
    defer for (0..4) |i| desc_surfaces[i].deinit(allocator);

    // Scaled surfaces (4 surfaces, one per algorithm)
    var scaled_surfaces: [4]*movy.RenderSurface = undefined;
    for (0..4) |i| {
        scaled_surfaces[i] = try movy.RenderSurface.init(allocator, original.w, original.h, movy.color.BLACK);
        scaled_surfaces[i].x = x_positions[i];
        scaled_surfaces[i].y = 20;
        scaled_surfaces[i].z = 1;
    }
    defer for (0..4) |i| scaled_surfaces[i].deinit(allocator);

    // Performance notes (2 surfaces)
    var note1 = try movy.RenderSurface.init(allocator, 120, 2, movy.color.BLACK);
    defer note1.deinit(allocator);
    note1.y = 70;
    note1.z = 100;
    _ = note1.putStrXY(
        "Note: None/Nearest are fastest. Bilinear is balanced. Bicubic is smoothest but slowest.",
        5,
        0,
        movy.color.GRAY,
        movy.color.BLACK,
    );

    var note2 = try movy.RenderSurface.init(allocator, 120, 2, movy.color.BLACK);
    defer note2.deinit(allocator);
    note2.y = 74;
    note2.z = 100;
    _ = note2.putStrXY(
        "For terminal graphics, differences are subtle due to half-block rendering.",
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
                                    scale_index = (scale_index + 1) % scale_factors.len;
                                }
                            }
                        },
                        else => {},
                    }
                },
                .mouse => {},
            }
        }

        // Re-scale surfaces only when scale factor changes
        if (scale_index != last_scale_index) {
            const current_scale = scale_factors[scale_index];
            const target_w = @as(usize, @intFromFloat(48.0 * current_scale));
            const target_h = @as(usize, @intFromFloat(48.0 * current_scale));

            for (algorithms, 0..4) |algo, i| {
                try scaled_surfaces[i].resize(allocator, original.w, original.h);
                try scaled_surfaces[i].copy(original);
                try scaled_surfaces[i].scale(allocator, target_w, target_h, algo);
                // Restore position after copy (copy overwrites x, y, z)
                scaled_surfaces[i].x = x_positions[i];
                scaled_surfaces[i].y = 20;
                scaled_surfaces[i].z = 1;
            }

            last_scale_index = scale_index;
        }

        try screen.renderInit();

        // Update info text
        const info_text = try std.fmt.bufPrint(
            &info_buf,
            "Downscaling from 48x48 to {s}",
            .{scale_labels[scale_index]},
        );
        _ = info_surf.putStrXY(info_text, 2, 0, movy.color.YELLOW, movy.color.BLACK);

        // Add all pre-allocated surfaces to screen
        try screen.addRenderSurface(allocator, title);
        try screen.addRenderSurface(allocator, info_surf);

        for (0..4) |i| {
            try screen.addRenderSurface(allocator, label_surfaces[i]);
            try screen.addRenderSurface(allocator, desc_surfaces[i]);
            try screen.addRenderSurface(allocator, scaled_surfaces[i]);
        }

        try screen.addRenderSurface(allocator, note1);
        try screen.addRenderSurface(allocator, note2);

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
