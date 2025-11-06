// Rotoscale Demo - Combined rotation, scaling, and alpha effects
//
// Features:
// - Huge asteroid with synchronized rotation, scaling, and alpha pulsing
// - Rotation continuously spins the asteroid 360 degrees
// - Scaling pulses from 10% to 120% and back
// - Alpha transparency pulses with sine wave
// - Scrolling text banner with vertical bobbing and alpha pulsing
// - Smooth 60 FPS rendering
//
// Controls:
// - esc, q: quit
//
// Requirements:
// - Minimum terminal: 120x80
// - PNG assets in demos/assets/ and examples/assets/

const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    // Setup allocator and constants
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_width: usize = 120;
    const terminal_height: usize = 80;

    // Setup terminal for raw input and alternate screen buffer
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    movy.terminal.cursorOff();
    defer movy.terminal.cursorOn();

    var screen = try movy.Screen.init(allocator, terminal_width, terminal_height);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Load original asteroid image (48x48)
    const original_asteroid = try movy.RenderSurface.createFromPng(
        allocator,
        "examples/assets/asteroid_huge.png",
    );
    defer original_asteroid.deinit(allocator);

    // Pre-allocate working surface for transformations
    var asteroid_working = try movy.RenderSurface.init(
        allocator,
        original_asteroid.w,
        original_asteroid.h,
        movy.color.BLACK,
    );
    defer asteroid_working.deinit(allocator);
    asteroid_working.z = 1;

    // Setup scrolltext
    var scroller = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/scaling_and_rotation.png",
        "scroller",
    );
    defer scroller.deinit(allocator);

    const scroller_surface = try scroller.getCurrentFrameSurface();
    const scroller_width = @as(i32, @intCast(scroller_surface.w));
    const scroller_height = @as(i32, @intCast(scroller_surface.h));

    // Start scroller off-screen to the right
    var scroller_x = @as(i32, @intCast(terminal_width)) + 30;
    const scroller_y = @divTrunc(@as(i32, @intCast(terminal_height)), 2) + 20;
    scroller.setXY(scroller_x, scroller_y);

    // Sine waves for scroller alpha pulsing and vertical bobbing
    var scroller_sine = movy.animation.TrigWave.init(150, 250);
    var scroller_vertical_sine = movy.animation.TrigWave.init(
        120,
        scroller_height + 10,
    );

    // Setup title and info surfaces
    var title = try movy.RenderSurface.init(allocator, 80, 2, movy.color.BLACK);
    defer title.deinit(allocator);
    title.z = 100;
    _ = title.putStrXY(
        "Rotoscale Demo - Q/ESC: Quit",
        2,
        0,
        movy.color.WHITE,
        movy.color.BLACK,
    );

    var info = try movy.RenderSurface.init(allocator, 70, 2, movy.color.BLACK);
    defer info.deinit(allocator);
    info.y = 4;
    info.z = 100;
    var info_buf: [128]u8 = undefined;

    // Animation state - rotation
    var angle_degrees: f32 = 0.0;
    const rotation_step: f32 = 2.0; // 2 degrees per frame

    // Animation state - scaling
    var scale_percent: f32 = 10.0; // Start at 10%
    var growing: bool = true;
    const scale_step: f32 = 1.0; // 1% per frame
    const min_scale: f32 = 10.0;
    const max_scale: f32 = 120.0;

    // Animation state - alpha pulsing
    var alpha_sine = movy.animation.TrigWave.init(420, 127); // Range: 128 +/- 127 = 1 to 255

    // Main loop
    const frame_delay_ns = 17 * std.time.ns_per_ms; // ~60 FPS
    var frame: usize = 0;

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Input handling
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    switch (key.type) {
                        .Escape => break,
                        .Char => {
                            if (key.sequence.len > 0 and
                                (key.sequence[0] == 'q' or key.sequence[0] == 'Q')) break;
                        },
                        else => {},
                    }
                },
                .mouse => {},
            }
        }

        // Update rotation angle
        angle_degrees += rotation_step;
        if (angle_degrees >= 360.0) angle_degrees -= 360.0;

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

        // Calculate target dimensions after scaling
        const scale_factor = scale_percent / 100.0;
        const target_w = @as(usize, @intFromFloat(48.0 * scale_factor));
        const target_h = @as(usize, @intFromFloat(48.0 * scale_factor));

        // Apply transformations: rotation then scaling
        try asteroid_working.resize(
            allocator,
            original_asteroid.w,
            original_asteroid.h,
        );
        try asteroid_working.copy(original_asteroid);

        // First: rotate the asteroid
        const angle_radians = movy.RenderSurface.degreesToRadians(angle_degrees);
        try asteroid_working.rotateInPlaceCentered(
            allocator,
            angle_radians,
            .autoenlarge,
            .bilinear,
        );

        // Second: scale the rotated result
        try asteroid_working.scale(
            allocator,
            target_w,
            target_h,
            .bicubic,
        );

        // Third: apply alpha pulsing
        const alpha_offset = alpha_sine.tickSine();
        const asteroid_alpha = @as(u8, @intCast(128 + alpha_offset));

        for (asteroid_working.shadow_map) |*alpha| {
            if (alpha.* != 0) {
                alpha.* = asteroid_alpha;
            }
        }

        // Center the transformed asteroid on screen
        const center_x = @as(i32, @intCast(terminal_width / 2)) -
            @as(i32, @intCast(asteroid_working.w / 2));
        const center_y = @as(i32, @intCast(terminal_height / 2)) -
            @as(i32, @intCast(asteroid_working.h / 2));
        asteroid_working.x = center_x;
        asteroid_working.y = center_y;

        // Update scrolling text position
        if (frame % 2 == 0) {
            scroller_x -= 2;
            if (scroller_x <= -(scroller_width + 30)) {
                scroller_x = @as(i32, @intCast(terminal_width)) + 30;
            }
        }

        // Apply vertical sine wave to scroller
        const scroller_y_offset = scroller_vertical_sine.tickSine();
        scroller.setXY(scroller_x, scroller_y + scroller_y_offset);

        // Update scroller alpha transparency
        const scroller_alpha_offset = scroller_sine.tickSine();
        const scroller_alpha = @as(u8, @intCast(128 + scroller_alpha_offset));

        for (scroller.output_surface.shadow_map, 0..) |*alpha, idx| {
            const original_alpha = scroller_surface.shadow_map[idx];
            if (original_alpha != 0) {
                alpha.* = scroller_alpha;
            }
        }

        // Update info display
        const info_text = try std.fmt.bufPrint(
            &info_buf,
            "Rotation: {d: >6.1} deg | Scale: {d:.0}% | Alpha: {d}",
            .{ angle_degrees, scale_percent, asteroid_alpha },
        );
        _ = info.putStrXY(info_text, 2, 0, movy.color.YELLOW, movy.color.BLACK);

        // Render all elements with alpha blending
        try screen.renderInit();
        try screen.addRenderSurface(allocator, title);
        try screen.addRenderSurface(allocator, info);
        try screen.addRenderSurface(allocator, asteroid_working);
        // try screen.addRenderSurface(allocator, scroller.output_surface);

        screen.renderWithAlpha();
        try screen.output();

        frame += 1;

        // Maintain constant frame rate
        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }

    movy.terminal.clear();
}
