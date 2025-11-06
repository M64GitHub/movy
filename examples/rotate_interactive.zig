/// Interactive Rotation Example
///
/// Demonstrates user-controlled rotation:
/// - Arrow Left/Right: Rotate by +/-15 degrees
/// - R: Reset to 0 degrees
/// - A: Toggle algorithm (nearest_neighbor vs bilinear)
/// - M: Toggle mode (clip vs autoenlarge)
/// - Shows current angle, algorithm, and mode on screen
///
/// Controls:
/// - LEFT/RIGHT: Rotate
/// - R: Reset angle
/// - A: Toggle algorithm
/// - M: Toggle mode
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

    // Load original asteroid image
    const original = try movy.RenderSurface.createFromPng(
        allocator,
        // "examples/assets/asteroid_huge.png",
        "examples/assets/m64logo.png",
    );
    defer original.deinit(allocator);

    // Pre-allocate rotated surface
    var rotated = try movy.RenderSurface.init(
        allocator,
        original.w,
        original.h,
        movy.color.BLACK,
    );
    defer rotated.deinit(allocator);
    rotated.z = 1;

    // Pre-allocate title
    var title = try movy.RenderSurface.init(allocator, 80, 8, movy.color.BLACK);
    defer title.deinit(allocator);
    title.z = 100;
    _ = title.putStrXY(
        "Interactive Rotation",
        2,
        0,
        movy.color.WHITE,
        movy.color.BLACK,
    );
    _ = title.putStrXY(
        "LEFT/RIGHT: Rotate  R: Reset  A: Algorithm  M: Mode  Q/ESC: Quit",
        2,
        2,
        movy.color.YELLOW,
        movy.color.BLACK,
    );

    // Pre-allocate info display
    var info = try movy.RenderSurface.init(allocator, 60, 4, movy.color.BLACK);
    defer info.deinit(allocator);
    info.y = 10;
    info.z = 100;
    var info_buf1: [64]u8 = undefined;
    var info_buf2: [64]u8 = undefined;
    var info_buf3: [64]u8 = undefined;

    // State
    var angle_degrees: f32 = 0.0;
    const rotation_step: f32 = 5.0; // 5 degrees per key press
    var current_algorithm: movy.core.RotateAlgorithm = .nearest_neighbor;
    var current_mode: movy.core.RotateMode = .autoenlarge;

    // Frame timing
    var last_frame_time = std.time.nanoTimestamp();
    const frame_time_ns: u64 = 16_666_667; // 60 FPS

    // Initial rotation
    var needs_rotation = true;

    // Main loop
    main_loop: while (true) {
        const current_time = std.time.nanoTimestamp();
        const elapsed = current_time - last_frame_time;

        if (elapsed >= frame_time_ns) {
            last_frame_time = current_time;

            // Handle input
            if (try movy.input.get()) |in| {
                switch (in) {
                    .key => |key| {
                        switch (key.type) {
                            .Escape => break :main_loop,
                            .Char => {
                                if (key.sequence.len > 0) {
                                    const ch = key.sequence[0];
                                    if (ch == 'q' or ch == 'Q') {
                                        break :main_loop;
                                    } else if (ch == 'r' or ch == 'R') {
                                        angle_degrees = 0.0;
                                        needs_rotation = true;
                                    } else if (ch == 'a' or ch == 'A') {
                                        current_algorithm = if (current_algorithm == .nearest_neighbor)
                                            .bilinear
                                        else
                                            .nearest_neighbor;
                                        needs_rotation = true;
                                    } else if (ch == 'm' or ch == 'M') {
                                        current_mode = if (current_mode == .clip)
                                            .autoenlarge
                                        else
                                            .clip;
                                        needs_rotation = true;
                                    }
                                }
                            },
                            .Right => {
                                angle_degrees += rotation_step;
                                if (angle_degrees >= 360.0) {
                                    angle_degrees -= 360.0;
                                }
                                needs_rotation = true;
                            },
                            .Left => {
                                angle_degrees -= rotation_step;
                                if (angle_degrees < 0.0) {
                                    angle_degrees += 360.0;
                                }
                                needs_rotation = true;
                            },
                            else => {},
                        }
                    },
                    .mouse => {},
                }
            }

            // Perform rotation if needed
            if (needs_rotation) {
                const angle_radians =
                    movy.RenderSurface.degreesToRadians(angle_degrees);

                // Copy original and rotate
                try rotated.resize(allocator, original.w, original.h);
                try rotated.copy(original);
                try rotated.rotateInPlaceCentered(
                    allocator,
                    angle_radians,
                    current_mode,
                    current_algorithm,
                );

                // Center the rotated surface
                const center_x = @as(i32, @intCast(terminal_width / 2)) -
                    @as(i32, @intCast(rotated.w / 2));
                const center_y = @as(i32, @intCast(terminal_height / 2)) -
                    @as(i32, @intCast(rotated.h / 2));
                rotated.x = center_x;
                rotated.y = center_y;

                needs_rotation = false;
            }

            // Update info display
            const algo_name = if (current_algorithm == .nearest_neighbor) "Nearest Neighbor" else "Bilinear";
            const mode_name = if (current_mode == .clip) "Clip" else "Auto-Enlarge";

            const info_text1 = std.fmt.bufPrint(
                &info_buf1,
                "Angle: {d: >6.1} degrees",
                .{angle_degrees},
            ) catch unreachable;
            const info_text2 = std.fmt.bufPrint(
                &info_buf2,
                "Algorithm: {s}",
                .{algo_name},
            ) catch unreachable;
            const info_text3 = std.fmt.bufPrint(
                &info_buf3,
                "Mode: {s}",
                .{mode_name},
            ) catch unreachable;

            info.clearColored(movy.color.BLACK);
            _ = info.putStrXY(info_text1, 2, 0, movy.color.WHITE, movy.color.BLACK);
            _ = info.putStrXY(info_text2, 2, 1, movy.color.WHITE, movy.color.BLACK);
            _ = info.putStrXY(info_text3, 2, 2, movy.color.WHITE, movy.color.BLACK);

            // Render
            try screen.renderInit();
            try screen.addRenderSurface(allocator, rotated);
            try screen.addRenderSurface(allocator, title);
            try screen.addRenderSurface(allocator, info);
            screen.render();
            try screen.output();
        }

        std.Thread.sleep(1_000_000); // Sleep 1ms
    }
}
