/// Rotation Angles Example
///
/// Demonstrates rotation at different angles:
/// - Shows 6 rotations: 0, 45, 90, 135, 180, 270 degrees
/// - Top row: nearest_neighbor algorithm
/// - Bottom row: bilinear algorithm
/// - Compares interpolation quality
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

    // Load original asteroid image
    const original = try movy.RenderSurface.createFromPng(
        allocator,
        "examples/assets/asteroid_small.png",
    );
    defer original.deinit(allocator);

    // Define rotation angles to display
    const angles = [_]f32{ 0, 45, 90, 135, 180, 270 };
    const algorithms = [_]movy.core.RotateAlgorithm{
        .nearest_neighbor,
        .bilinear,
    };
    const algorithm_names = [_][]const u8{ "Nearest Neighbor", "Bilinear" };

    // Pre-allocate 12 rotated surfaces (6 angles * 2 algorithms)
    var rotated_surfaces: [12]*movy.RenderSurface = undefined;
    for (0..12) |i| {
        rotated_surfaces[i] = try movy.RenderSurface.init(
            allocator,
            original.w,
            original.h,
            movy.color.BLACK,
        );
    }
    defer for (rotated_surfaces) |surf| surf.deinit(allocator);

    // Pre-allocate angle labels (6)
    var angle_labels: [6]*movy.RenderSurface = undefined;
    for (0..6) |i| {
        angle_labels[i] = try movy.RenderSurface.init(
            allocator,
            20,
            2,
            movy.color.BLACK,
        );
    }
    defer for (angle_labels) |label| label.deinit(allocator);

    // Pre-allocate algorithm labels (2)
    var algo_labels: [2]*movy.RenderSurface = undefined;
    for (0..2) |i| {
        algo_labels[i] = try movy.RenderSurface.init(
            allocator,
            30,
            2,
            movy.color.BLACK,
        );
    }
    defer for (algo_labels) |label| label.deinit(allocator);

    // Pre-allocate title
    var title = try movy.RenderSurface.init(
        allocator,
        80,
        2,
        movy.color.BLACK,
    );
    defer title.deinit(allocator);
    title.z = 100;
    _ = title.putStrXY(
        "Rotation Angles - Q/ESC: Quit",
        2,
        0,
        movy.color.WHITE,
        movy.color.BLACK,
    );

    // Calculate positions (3 columns, 2 rows for each algorithm)
    const x_start: i32 = 10;
    const y_start: i32 = 10;
    const spacing_x: i32 = 50;
    const spacing_y: i32 = 25;

    // Perform all rotations
    var angle_buf: [32]u8 = undefined;
    for (angles, 0..) |angle, angle_idx| {
        const angle_radians = movy.RenderSurface.degreesToRadians(angle);
        const col = angle_idx % 3;
        const row = angle_idx / 3;

        for (algorithms, 0..) |algorithm, algo_idx| {
            const surf_idx = angle_idx + algo_idx * 6;
            const surf = rotated_surfaces[surf_idx];

            // Copy and rotate
            try surf.resize(allocator, original.w, original.h);
            try surf.copy(original);
            try surf.rotateInPlaceCentered(
                allocator,
                angle_radians,
                .autoenlarge,
                algorithm,
            );

            // Position
            surf.x = x_start + @as(i32, @intCast(col)) * spacing_x;
            surf.y = y_start + @as(i32, @intCast(algo_idx * 2 + row)) *
                spacing_y;
            surf.z = 1;
        }

        // Set angle label
        const label = angle_labels[angle_idx];
        const label_text = std.fmt.bufPrint(
            &angle_buf,
            "{d: >3.0}deg",
            .{angle},
        ) catch unreachable;
        _ = label.putStrXY(
            label_text,
            0,
            0,
            movy.color.WHITE,
            movy.color.BLACK,
        );
        label.x = x_start + @as(i32, @intCast(col)) * spacing_x;
        label.y = y_start + @as(i32, @intCast(row)) * spacing_y - 4;
        if (@as(usize, @intCast(label.y)) % 2 == 1) label.y -= 1;
        label.z = 100;
    }

    // Set algorithm labels
    for (algorithm_names, 0..) |name, idx| {
        const label = algo_labels[idx];
        _ = label.putStrXY(name, 0, 0, movy.color.CYAN, movy.color.BLACK);
        label.x = 2;
        label.y = y_start + @as(i32, @intCast(idx * 2)) * spacing_y - 4;
        label.z = 100;
    }

    // Main loop (static display)
    while (true) {
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

        // Render
        try screen.renderInit();
        for (rotated_surfaces) |surf| {
            try screen.addRenderSurface(allocator, surf);
        }
        for (angle_labels) |label| {
            try screen.addRenderSurface(allocator, label);
        }
        for (algo_labels) |label| {
            try screen.addRenderSurface(allocator, label);
        }
        try screen.addRenderSurface(allocator, title);
        screen.render();
        try screen.output();

        std.Thread.sleep(16_666_667); // 60 FPS
    }
}
