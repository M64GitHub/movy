/// Rotation Animation Example
///
/// Demonstrates continuous rotation animation:
/// - Loads asteroid_huge.png (48x48)
/// - Rotates continuously from 0 to 360 degrees and loops
/// - Keeps sprite centered on screen
/// - Shows smooth rotation using nearest_neighbor algorithm
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
        // "examples/assets/asteroid_huge.png",
        "examples/assets/m64logo.png",
    );
    defer original.deinit(allocator);

    // Pre-allocate rotated surface (start with original size, will auto-expand)
    var rotated = try movy.RenderSurface.init(
        allocator,
        original.w,
        original.h,
        movy.color.BLACK,
    );
    defer rotated.deinit(allocator);
    rotated.z = 1;

    // Pre-allocate title
    var title = try movy.RenderSurface.init(allocator, 80, 2, movy.color.BLACK);
    defer title.deinit(allocator);
    title.z = 100;
    _ = title.putStrXY(
        "Rotation Animation - Q/ESC: Quit",
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
    var angle_degrees: f32 = 0.0; // Start at 0 degrees
    const rotation_step: f32 = 2.0; // 2 degrees per frame (180 frames for full rotation)

    // Frame timing
    var last_frame_time = std.time.nanoTimestamp();
    const frame_time_ns: u64 = 16_666_667; // 60 FPS

    // Main loop
    main_loop: while (true) {
        const current_time = std.time.nanoTimestamp();
        const elapsed = current_time - last_frame_time;

        if (elapsed >= frame_time_ns) {
            last_frame_time = current_time;

            // Handle input (quit only)
            if (try movy.input.get()) |in| {
                switch (in) {
                    .key => |key| {
                        switch (key.type) {
                            .Escape => break :main_loop,
                            .Char => {
                                if (key.sequence.len > 0) {
                                    const ch = key.sequence[0];
                                    if (ch == 'q' or ch == 'Q') break :main_loop;
                                }
                            },
                            else => {},
                        }
                    },
                    .mouse => {},
                }
            }

            // Update rotation angle
            angle_degrees += rotation_step;
            if (angle_degrees >= 360.0) {
                angle_degrees -= 360.0; // Wrap around
            }

            // Convert to radians
            const angle_radians =
                movy.RenderSurface.degreesToRadians(angle_degrees);

            // Copy original and rotate
            try rotated.resize(allocator, original.w, original.h);
            try rotated.copy(original);
            try rotated.rotateInPlaceCentered(
                allocator,
                angle_radians,
                .autoenlarge,
                .nearest_neighbor,
            );

            // Center the rotated surface
            const center_x = @as(i32, @intCast(terminal_width / 2)) -
                @as(i32, @intCast(rotated.w / 2));
            const center_y = @as(i32, @intCast(terminal_height / 2)) -
                @as(i32, @intCast(rotated.h / 2));
            rotated.x = center_x;
            rotated.y = center_y;

            // Update info display
            const info_text = std.fmt.bufPrint(
                &info_buf,
                "Angle: {d: >6.1} degrees",
                .{angle_degrees},
            ) catch unreachable;
            info.clearColored(movy.color.BLACK);
            _ = info.putStrXY(
                info_text,
                2,
                0,
                movy.color.WHITE,
                movy.color.BLACK,
            );

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
