/// Movy Blender Demo
///
/// A visual showcase demonstrating:
/// - 8 semi-transparent animated sprites with 2D wave motion (sine + cosine)
/// - 16 animated sprites in rotating circle with 2D wave motion and pulsing alpha
/// - Logo with OutlineRotator effect and sine wave motion
/// - Continuously scrolling text with 2D wave motion and transparency animation
/// - Flashing text
/// - Smooth 60 FPS animation
///
/// Controls:
/// - ESC or 'q': Exit
///
/// Requirements:
/// - Terminal size minimum: 120x60
/// - Assets: demos/assets/sprite1.png
///           demos/assets/sprite10x10-16.png
///           demos/assets/movy-logo2.png
///           demos/assets/alpha_scroller.png
const std = @import("std");
const movy = @import("movy");

// Helper function: Calculate position on circle
fn calculateCirclePosition(
    center_x: i32,
    center_y: i32,
    radius: i32,
    angle_deg: f32,
) struct { x: i32, y: i32 } {
    const angle_rad = angle_deg * std.math.pi / 180.0;
    const x = center_x + @as(
        i32,
        @intFromFloat(@round(@as(f32, @floatFromInt(radius)) * @cos(angle_rad))),
    );
    const y = center_y + @as(
        i32,
        @intFromFloat(@round(@as(f32, @floatFromInt(radius)) * @sin(angle_rad))),
    );
    return .{ .x = x, .y = y };
}

// Helper function: Calculate alpha phase offset for wave pattern
fn calculateAlphaPhaseOffset(sprite_index: usize) usize {
    // Distribute phase offsets across 16 sprites
    return sprite_index * 4;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get terminal size
    const terminal_size = try movy.terminal.getSize();
    const screen_width = terminal_size.width;
    const screen_height = terminal_size.height * 2;

    // Check minimum terminal size (120x60)
    if (screen_width < 120 or screen_height < 60) {
        std.debug.print(
            "Terminal too small! Need at least 120x60, got {d}x{d}\n",
            .{ screen_width, screen_height },
        );
        std.debug.print("Please resize your terminal and try again.\n", .{});
        return;
    }

    // Set raw mode, switch to alternate screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // Initialize screen
    var screen = try movy.Screen.init(allocator, screen_width, screen_height);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // --- Load Movy Logo (Lower Third) ---
    var movy_logo = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/movy-logo2.png",
        "movy_logo",
    );
    defer movy_logo.deinit(allocator);

    // Set up OutlineRotator effect for movy logo
    var outline_rotator = movy.render.Effect.OutlineRotator{
        .start_x = 0,
        .start_y = 0,
        .direction = .left,
    };
    var rotator_effect = outline_rotator.asEffect();
    movy_logo.effect_ctx.input_surface = movy_logo.output_surface;

    // Movy logo sine wave
    const movy_amplitude = @divTrunc(@as(i32, @intCast(screen_width)), 3);
    var movy_sine = movy.animation.TrigWave.init(240, movy_amplitude);

    // Calculate movy logo position (centered)
    const movy_logo_width = @as(i32, @intCast(movy_logo.output_surface.w));
    const screen_center = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const movy_center_x = screen_center - @divTrunc(movy_logo_width, 2);
    const movy_y = @divTrunc(@as(i32, @intCast(screen_height * 3)), 4);

    // --- Load Alpha Scroller ---
    var alpha_scroller = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/alpha_scroller.png",
        "alpha_scroller",
    );
    defer alpha_scroller.deinit(allocator);

    // Get scroller dimensions
    const scroller_surface = try alpha_scroller.getCurrentFrameSurface();
    const scroller_width = @as(i32, @intCast(scroller_surface.w));
    const scroller_height = @as(i32, @intCast(scroller_surface.h));

    // Initial scroller position
    var scroller_x = @as(i32, @intCast(screen_width)) + 30;
    const scroller_y = @divTrunc(@as(i32, @intCast(screen_height)), 2) - 10;
    alpha_scroller.setXY(scroller_x, scroller_y);

    // Scroller sine wave for transparency
    var scroller_sine = movy.animation.TrigWave.init(150, 250);

    // Scroller vertical sine wave for up/down motion
    var scroller_vertical_sine = movy.animation.TrigWave.init(
        120,
        scroller_height + 10,
    );

    // --- Load and Set Up 8 Sprite1 Instances (Upper Third) ---
    const alpha_values = [8]u8{ 50, 79, 109, 138, 168, 197, 227, 255 };
    var sprites: [8]*movy.graphic.Sprite = undefined;
    var sprite_sines: [8]movy.animation.TrigWave = undefined;
    var sprite_cosines: [8]movy.animation.TrigWave = undefined;

    // Calculate sprite positioning
    // All sprites start from center
    const sprite_center_x = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    // Upper third
    const sprite_base_y = @divTrunc(@as(i32, @intCast(screen_height)), 3);

    // Amplitude gradient: front sprite (i=7) = screen_width/2,
    // back sprite (i=0) = screen_width/8
    const max_amplitude = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const min_amplitude = @divTrunc(@as(i32, @intCast(screen_width)), 8);

    // Cosine amplitude gradient for vertical movement
    const max_cosine_amplitude: i32 = 20;
    const min_cosine_amplitude: i32 = 5;

    for (0..8) |i| {
        // Load sprite
        sprites[i] = try movy.graphic.Sprite.initFromPng(
            allocator,
            "demos/assets/sprite1.png",
            try std.fmt.allocPrint(allocator, "sprite{d}", .{i}),
        );

        const current_frame = try sprites[i].getCurrentFrameSurface();
        for (current_frame.shadow_map) |*alpha| {
            if (alpha.* != 0) alpha.* = alpha_values[i];
        }

        // Split by width (16px per frame, creates 16 frames)
        try sprites[i].splitByWidth(allocator, 16);

        // Add "default" animation (all 16 frames, loop forward)
        const frame_anim = movy.graphic.Sprite.FrameAnimation.init(
            1, // start frame
            16, // end frame
            .loopForward,
            4, // speed
        );
        try sprites[i].addAnimation(allocator, "default", frame_anim);
        try sprites[i].startAnimation("default");

        // Set up sine wave with graduated amplitude
        // (back sprites = small, front sprites = large)
        const amplitude = min_amplitude +
            @divTrunc((max_amplitude - min_amplitude) *
                @as(i32, @intCast(i)), 7);

        sprite_sines[i] = movy.animation.TrigWave.init(150, amplitude);

        // Pre-tick for staggered effect (20 frames offset per sprite)
        for (0..(i * 20)) |_| {
            _ = sprite_sines[i].tickSine();
        }

        // Set up cosine wave with graduated amplitude for vertical movement
        const cosine_amplitude = min_cosine_amplitude +
            @divTrunc((max_cosine_amplitude - min_cosine_amplitude) *
                @as(i32, @intCast(i)), 7);

        sprite_cosines[i] = movy.animation.TrigWave.init(80, cosine_amplitude);

        // Pre-tick cosine for staggered effect
        // for (0..(i * 20)) |_| {
        for (0..(i * 10)) |_| {
            _ = sprite_cosines[i].tickCosine();
        }

        // Calculate base Y position
        // Vertical overlap
        const sprite_y = sprite_base_y - @as(i32, @intCast(i * 2)) + 10;
        sprites[i].setXY(sprite_center_x, sprite_y); // Start from center
    }

    // Cleanup sprites
    defer {
        for (0..8) |i| {
            sprites[i].deinit(allocator);
        }
    }

    // --- Load and Set Up 16 Circle Sprites ---
    var circle_sprites: [16]*movy.graphic.Sprite = undefined;
    var circle_sines: [16]movy.animation.TrigWave = undefined;
    var circle_cosines: [16]movy.animation.TrigWave = undefined;
    var circle_alpha_sines: [16]movy.animation.TrigWave = undefined;

    // Circle configuration
    const circle_center_x = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const circle_center_y = @divTrunc(@as(i32, @intCast(screen_height)), 2);
    const circle_radius: i32 = 40;
    var circle_rotation_angle: f32 = 0.0;

    for (0..16) |i| {
        // Load circle sprite
        circle_sprites[i] = try movy.graphic.Sprite.initFromPng(
            allocator,
            "demos/assets/sprite10x10-16.png",
            try std.fmt.allocPrint(allocator, "circle_sprite{d}", .{i}),
        );

        // Split by width (10px per frame, creates 16 frames)
        try circle_sprites[i].splitByWidth(allocator, 10);

        // Add animation (all 16 frames, loop forward, speed 1)
        const circle_anim = movy.graphic.Sprite.FrameAnimation.init(
            1, // start frame
            16, // end frame
            .loopForward,
            1, // speed
        );
        try circle_sprites[i].addAnimation(allocator, "default", circle_anim);
        try circle_sprites[i].startAnimation("default");

        // Set up wave generators
        circle_sines[i] = movy.animation.TrigWave.init(180, 10);
        circle_cosines[i] = movy.animation.TrigWave.init(120, 15);
        circle_alpha_sines[i] = movy.animation.TrigWave.init(120, 254);

        // Pre-tick alpha for phase offset
        const alpha_offset = calculateAlphaPhaseOffset(i);
        for (0..alpha_offset) |_| {
            _ = circle_alpha_sines[i].tickSine();
        }

        // Calculate initial position on circle
        // 360 / 16 = 22.5 degrees per sprite
        const angle = @as(f32, @floatFromInt(i)) * 22.5;
        const pos = calculateCirclePosition(
            circle_center_x,
            circle_center_y,
            circle_radius,
            angle,
        );
        circle_sprites[i].setXY(pos.x, pos.y);
    }

    // Cleanup circle sprites
    defer {
        for (0..16) |i| {
            circle_sprites[i].deinit(allocator);
        }
    }

    // --- Create Text Surface (Middle, Flashing) ---
    var text_surface = try movy.RenderSurface.init(
        allocator,
        screen_width,
        10, // 5 terminal lines tall
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 }, // Black background
    );
    defer text_surface.deinit(allocator);

    // Ensure text background is fully transparent
    for (text_surface.shadow_map) |*alpha| {
        alpha.* = 0;
    }

    var ty = screen_height - 5;
    if (ty % 2 == 1) ty -= 1;
    text_surface.y = @as(i32, @intCast(ty));
    text_surface.z = 100; // Top layer

    // Text flash sine wave (1.5 seconds, amplitude 70 for darker amount)
    var flash_sine = movy.animation.TrigWave.init(90, 150);

    // --- Optional: Help Text ---
    var help_surface = try movy.RenderSurface.init(
        allocator,
        screen_width,
        4, // 2 lines tall
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer help_surface.deinit(allocator);

    for (help_surface.shadow_map) |*alpha| {
        alpha.* = 0;
    }

    _ = help_surface.putStrXY(
        "Press ESC or 'q' to quit",
        2,
        0,
        movy.color.GRAY,
        movy.color.BLACK,
    );

    help_surface.y = 0;
    help_surface.z = 200; // Very top

    // --- Main Loop (60 FPS) ---
    const frame_delay_ns = 17 * std.time.ns_per_ms; // ~60 FPS
    var frame: usize = 0;

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // --- Input Handling ---
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

        // --- Update Movy Logo Position (Sine Wave) ---
        const movy_x = movy_center_x + movy_sine.tickSine();
        movy_logo.setXY(movy_x, movy_y);

        // Apply OutlineRotator effect
        try rotator_effect.run(
            allocator,
            &movy_logo.effect_ctx,
            frame,
        );

        // --- Update Sprite1 Positions ---
        for (0..8) |i| {
            // All sprites wave from center with graduated amplitudes
            const sprite_x = sprite_center_x + sprite_sines[i].tickSine();
            const sprite_y = sprite_base_y - @as(i32, @intCast(i * 4)) +
                sprite_cosines[i].tickCosine() + 4;
            // Step animation
            sprites[i].stepActiveAnimation();
            sprites[i].setXY(sprite_x, sprite_y);
        }

        // --- Update Circle Sprites ---
        // Rotate circle slowly (0.5 degrees per frame)
        circle_rotation_angle += 0.5;
        if (circle_rotation_angle >= 360.0) circle_rotation_angle -= 360.0;

        for (0..16) |i| {
            // Calculate base position on rotating circle
            const base_angle = @as(f32, @floatFromInt(i)) * 22.5 +
                circle_rotation_angle;
            const base_pos = calculateCirclePosition(
                circle_center_x,
                circle_center_y,
                circle_radius,
                base_angle,
            );

            // Apply sine/cosine wave offsets
            const wave_x = circle_sines[i].tickSine();
            const wave_y = circle_cosines[i].tickCosine();
            const final_x = base_pos.x + wave_x;
            const final_y = base_pos.y + wave_y;

            // Step animation
            circle_sprites[i].stepActiveAnimation();
            circle_sprites[i].setXY(final_x, final_y);

            // Animate alpha with sine wave (1-255 range)
            const alpha_offset = circle_alpha_sines[i].tickSine();
            const circle_alpha = @as(u8, @intCast(128 + alpha_offset));

            const circle_frame = try circle_sprites[i].getCurrentFrameSurface();
            for (circle_frame.shadow_map) |*alpha| {
                if (alpha.* != 0) {
                    alpha.* = circle_alpha;
                }
            }
        }

        // --- Update Alpha Scroller ---
        // Move scroller left every 2nd frame (2x speed)
        if (frame % 2 == 0) {
            scroller_x -= 2;
            // Reset to right when completely off-screen left
            if (scroller_x <= -(scroller_width + 30)) {
                scroller_x = @as(i32, @intCast(screen_width)) + 30;
            }
        }

        // Apply vertical sine wave for up/down motion
        const scroller_y_offset = scroller_vertical_sine.tickSine();
        alpha_scroller.setXY(scroller_x, scroller_y + scroller_y_offset);

        // Animate scroller transparency with sine wave
        const scroller_alpha_offset = scroller_sine.tickSine();
        const scroller_alpha = @as(u8, @intCast(128 + scroller_alpha_offset));

        // Update shadow_map only where alpha != 0
        for (alpha_scroller.output_surface.shadow_map, 0..) |*alpha, idx| {
            // Check original alpha from current frame surface
            const original_alpha = scroller_surface.shadow_map[idx];
            if (original_alpha != 0) {
                alpha.* = scroller_alpha;
            }
        }

        // --- Update Text Flash ---
        // Calculate darker amount from sine wave
        const flash_value = flash_sine.tickSine();
        const darker_amount = @as(u8, @intCast(@abs(flash_value)));

        // Apply darker to white
        const flash_color = movy.color.darker(movy.color.WHITE, darker_amount);

        // Center text
        const text = "< ALPHA BLEND DEMO >";
        const text_x_pos = @divTrunc(@as(i32, @intCast(screen_width)), 2) -
            @as(i32, @intCast(text.len / 2));

        _ = text_surface.putStrXY(
            text,
            @intCast(text_x_pos),
            0, // Even y coordinate
            flash_color,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );

        // --- Render All Surfaces ---
        try screen.renderInit();

        // Add in Z-order (first added = top layer)
        try screen.addRenderSurface(allocator, help_surface); // Top (z=200)
        try screen.addRenderSurface(allocator, text_surface); // z=100
        for (0..8) |i| {
            try screen.addRenderSurface(
                allocator,
                try sprites[i].getCurrentFrameSurface(),
            );
        }
        for (0..16) |i| {
            try screen.addRenderSurface(
                allocator,
                try circle_sprites[i].getCurrentFrameSurface(),
            );
        }
        try screen.addRenderSurface(allocator, movy_logo.output_surface);
        try screen.addRenderSurface(allocator, alpha_scroller.output_surface);

        screen.renderAlpha();
        try screen.output();

        frame += 1;

        // --- Frame Timing ---
        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
