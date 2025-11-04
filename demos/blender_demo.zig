// Blender Demo - Comprehensive alpha blending showcase
//
// Features:
// - 8 semi-transparent sprites with 2D sine/cosine wave motion
// - 16 sprites rotating in circle with pulsing alpha transparency
// - Logo with OutlineRotator effect and horizontal sine motion
// - Scrolling text with vertical sine wave and alpha pulsing
// - Flashing text with brightness animation
// - Smooth 60 FPS rendering with alpha blending
//
// Controls:
// - esc, q: quit
//
// Requirements:
// - Minimum terminal: 120x60
// - PNG assets in demos/assets/

const std = @import("std");
const movy = @import("movy");

// Calculate position on a circle given center, radius, and angle
// Returns integer x,y coordinates for sprite placement
fn calculateCirclePosition(
    center_x: i32,
    center_y: i32,
    radius: i32,
    angle_deg: f32,
) struct { x: i32, y: i32 } {
    const angle_rad = angle_deg * std.math.pi / 180.0;
    const x = center_x + @as(
        i32,
        @intFromFloat(@round(@as(f32, @floatFromInt(radius)) *
            @cos(angle_rad))),
    );
    const y = center_y + @as(
        i32,
        @intFromFloat(@round(@as(f32, @floatFromInt(radius)) *
            @sin(angle_rad))),
    );
    return .{ .x = x, .y = y };
}

// Calculate position on an ellipse with separate x/y radii
// Used for creating non-circular orbital motion
fn calculateEllipsePosition(
    center_x: i32,
    center_y: i32,
    radius_x: i32,
    radius_y: i32,
    angle_deg: f32,
) struct { x: i32, y: i32 } {
    const angle_rad = angle_deg * std.math.pi / 180.0;
    const x = center_x + @as(
        i32,
        @intFromFloat(@round(@as(f32, @floatFromInt(radius_x)) *
            @cos(angle_rad))),
    );
    const y = center_y + @as(
        i32,
        @intFromFloat(@round(@as(f32, @floatFromInt(radius_y)) *
            @sin(angle_rad))),
    );
    return .{ .x = x, .y = y };
}

// Calculate phase offset for alpha animation based on sprite index
// Distributes alpha pulsing across sprites so they don't all pulse in sync
fn calculateAlphaPhaseOffset(sprite_index: usize) usize {
    return sprite_index * 4;
}

pub fn main() !void {
    // -- Setup allocator and constants
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.getSize();
    const screen_width = terminal_size.width;
    const screen_height = terminal_size.height * 2; // Double height for half-block rendering

    // Validate minimum terminal size for all demo elements
    if (screen_width < 120 or screen_height < 60) {
        std.debug.print(
            "Terminal too small! Need at least 120x60, got {d}x{d}\n",
            .{ screen_width, screen_height },
        );
        std.debug.print("Please resize your terminal and try again.\n", .{});
        return;
    }

    // Setup terminal for raw input and alternate screen buffer
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(allocator, screen_width, screen_height);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // -- Setup logo with outline rotator effect
    var movy_logo = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/movy-logo2.png",
        "movy_logo",
    );
    defer movy_logo.deinit(allocator);

    // OutlineRotator effect cycles a colored outline around the logo
    var outline_rotator = movy.render.Effect.OutlineRotator{
        .start_x = 0,
        .start_y = 0,
        .direction = .left,
    };
    var rotator_effect = outline_rotator.asEffect();
    movy_logo.effect_ctx.input_surface = movy_logo.output_surface;

    // Sine wave for horizontal logo movement
    const movy_amplitude = @divTrunc(@as(i32, @intCast(screen_width)), 3);
    var movy_sine = movy.animation.TrigWave.init(240, movy_amplitude);

    // Position logo at lower center
    const movy_logo_width = @as(i32, @intCast(movy_logo.output_surface.w));
    const screen_center = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const movy_center_x = screen_center - @divTrunc(movy_logo_width, 2);
    const movy_y = @divTrunc(@as(i32, @intCast(screen_height * 3)), 4);

    // -- Setup scrolling alpha text
    var alpha_scroller = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/alpha_scroller.png",
        "alpha_scroller",
    );
    defer alpha_scroller.deinit(allocator);

    const scroller_surface = try alpha_scroller.getCurrentFrameSurface();
    const scroller_width = @as(i32, @intCast(scroller_surface.w));
    const scroller_height = @as(i32, @intCast(scroller_surface.h));

    // Start scroller off-screen to the right
    var scroller_x = @as(i32, @intCast(screen_width)) + 30;
    const scroller_y = @divTrunc(@as(i32, @intCast(screen_height)), 2) - 10;
    alpha_scroller.setXY(scroller_x, scroller_y);

    // Sine waves for scroller alpha pulsing and vertical bobbing
    var scroller_sine = movy.animation.TrigWave.init(150, 250);
    var scroller_vertical_sine = movy.animation.TrigWave.init(
        120,
        scroller_height + 10,
    );

    // -- Setup 8 wave-motion sprites with graduated alpha
    const alpha_values = [8]u8{ 50, 79, 109, 138, 168, 197, 227, 255 };
    var sprites: [8]*movy.graphic.Sprite = undefined;
    var sprite_sines: [8]movy.animation.TrigWave = undefined;
    var sprite_cosines: [8]movy.animation.TrigWave = undefined;

    const sprite_center_x = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const sprite_base_y = @divTrunc(@as(i32, @intCast(screen_height)), 3);

    const max_amplitude = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const min_amplitude = @divTrunc(@as(i32, @intCast(screen_width)), 8);

    const max_cosine_amplitude: i32 = 20;
    const min_cosine_amplitude: i32 = 5;

    // Create 8 sprites with increasing alpha and wave amplitude
    for (0..8) |i| {
        sprites[i] = try movy.graphic.Sprite.initFromPng(
            allocator,
            "demos/assets/sprite1.png",
            try std.fmt.allocPrint(allocator, "sprite{d}", .{i}),
        );

        // Apply graduated alpha transparency
        const current_frame = try sprites[i].getCurrentFrameSurface();
        for (current_frame.shadow_map) |*alpha| {
            if (alpha.* != 0) alpha.* = alpha_values[i];
        }

        // Setup frame animation
        try sprites[i].splitByWidth(allocator, 16);
        const frame_anim = movy.graphic.Sprite.FrameAnimation.init(
            1, // start frame
            16, // end frame
            .loopForward,
            4, // speed
        );
        try sprites[i].addAnimation(allocator, "default", frame_anim);
        try sprites[i].startAnimation("default");

        // Horizontal sine wave with increasing amplitude per sprite
        const amplitude = min_amplitude +
            @divTrunc((max_amplitude - min_amplitude) *
                @as(i32, @intCast(i)), 7);
        sprite_sines[i] = movy.animation.TrigWave.init(150, amplitude);

        // Phase offset so sprites start at different positions
        for (0..(i * 20)) |_| {
            _ = sprite_sines[i].tickSine();
        }

        // Vertical cosine wave with increasing amplitude per sprite
        const cosine_amplitude = min_cosine_amplitude +
            @divTrunc((max_cosine_amplitude - min_cosine_amplitude) *
                @as(i32, @intCast(i)), 7);
        sprite_cosines[i] = movy.animation.TrigWave.init(80, cosine_amplitude);

        // Phase offset for vertical motion
        for (0..(i * 10)) |_| {
            _ = sprite_cosines[i].tickCosine();
        }

        // Stack sprites vertically
        const sprite_y = sprite_base_y - @as(i32, @intCast(i * 2)) + 10;
        sprites[i].setXY(sprite_center_x, sprite_y);
    }

    defer {
        for (0..8) |i| {
            sprites[i].deinit(allocator);
        }
    }

    // -- Setup 16 circle sprites with rotation and pulsing alpha
    var circle_sprites: [16]*movy.graphic.Sprite = undefined;
    var circle_sines: [16]movy.animation.TrigWave = undefined;
    var circle_cosines: [16]movy.animation.TrigWave = undefined;
    var circle_alpha_sines: [16]movy.animation.TrigWave = undefined;
    var circle_radius_sines: [16]movy.animation.TrigWave = undefined;

    const circle_center_x = @divTrunc(@as(i32, @intCast(screen_width)), 2);
    const circle_center_y = @divTrunc(@as(i32, @intCast(screen_height)), 2) - 5;
    const circle_radius: i32 = 50;
    var circle_rotation_angle: f32 = 0.0;

    // Ellipse modulation: sine waves modify x/y radii for orbital breathing
    var circle_radius_x_sine = movy.animation.TrigWave.init(200, 15);
    var circle_radius_y_sine = movy.animation.TrigWave.init(150, 15);

    // Phase offsets for x/y radius modulation
    for (0..50) |_| {
        _ = circle_radius_x_sine.tickSine();
    }
    for (0..75) |_| {
        _ = circle_radius_y_sine.tickSine();
    }

    // Create 16 sprites arranged in circle
    for (0..16) |i| {
        circle_sprites[i] = try movy.graphic.Sprite.initFromPng(
            allocator,
            "demos/assets/sprite10x10-16.png",
            try std.fmt.allocPrint(allocator, "circle_sprite{d}", .{i}),
        );

        try circle_sprites[i].splitByWidth(allocator, 10);

        // Fast frame animation for visual interest
        const circle_anim = movy.graphic.Sprite.FrameAnimation.init(
            1, // start frame
            16, // end frame
            .loopForward,
            1, // speed
        );
        try circle_sprites[i].addAnimation(allocator, "default", circle_anim);
        try circle_sprites[i].startAnimation("default");

        // Individual 2D wave motion for each sprite
        circle_sines[i] = movy.animation.TrigWave.init(180, 10);
        circle_cosines[i] = movy.animation.TrigWave.init(120, 15);

        // Pulsing alpha transparency with distributed phase
        circle_alpha_sines[i] = movy.animation.TrigWave.init(120, 254);

        // Individual radius modulation for breathing effect
        circle_radius_sines[i] = movy.animation.TrigWave.init(100, 8);

        // Distribute alpha phases so sprites pulse in sequence
        const alpha_offset = calculateAlphaPhaseOffset(i);
        for (0..alpha_offset) |_| {
            _ = circle_alpha_sines[i].tickSine();
        }

        // Phase offset for radius variation
        for (0..(i * 5)) |_| {
            _ = circle_radius_sines[i].tickSine();
        }

        // Position sprites evenly around circle (360/16 = 22.5 degrees apart)
        const angle = @as(f32, @floatFromInt(i)) * 22.5;
        const pos = calculateCirclePosition(
            circle_center_x,
            circle_center_y,
            circle_radius,
            angle,
        );
        circle_sprites[i].setXY(pos.x, pos.y);
    }

    defer {
        for (0..16) |i| {
            circle_sprites[i].deinit(allocator);
        }
    }

    // -- Setup text surfaces
    // Flashing title text at bottom
    var text_surface = try movy.RenderSurface.init(
        allocator,
        screen_width,
        10, // 5 terminal lines tall
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 }, // Black background
    );
    defer text_surface.deinit(allocator);

    // Transparent background
    for (text_surface.shadow_map) |*alpha| {
        alpha.* = 0;
    }

    // Position at bottom, aligned to even row for half-block rendering
    var ty = screen_height - 5;
    if (ty % 2 == 1) ty -= 1;
    text_surface.y = @as(i32, @intCast(ty));
    text_surface.z = 40;

    // Sine wave for brightness pulsing effect
    var flash_sine = movy.animation.TrigWave.init(90, 150);

    // Help text at top
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
    help_surface.z = 200; // High z-index to appear on top

    // -- Main loop
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
                                key.sequence[0] == 'q') break;
                        },
                        else => {},
                    }
                },
                .mouse => {},
            }
        }

        // Update logo position and effect
        const movy_x = movy_center_x + movy_sine.tickSine();
        movy_logo.setXY(movy_x, movy_y);

        try rotator_effect.run(
            allocator,
            &movy_logo.effect_ctx,
            frame,
        );

        // Update wave-motion sprites
        for (0..8) |i| {
            const sprite_x = sprite_center_x + sprite_sines[i].tickSine();
            const sprite_y = sprite_base_y - @as(i32, @intCast(i * 4)) +
                sprite_cosines[i].tickCosine() + 4;
            sprites[i].stepActiveAnimation();
            sprites[i].setXY(sprite_x, sprite_y);
        }

        // Update rotating circle sprites
        circle_rotation_angle += 0.5;
        if (circle_rotation_angle >= 360.0) circle_rotation_angle -= 360.0;

        // Apply ellipse modulation to create breathing effect
        const radius_x_mod = circle_radius_x_sine.tickSine();
        const radius_y_mod = circle_radius_y_sine.tickSine();

        for (0..16) |i| {
            // Individual radius modulation per sprite
            const sprite_radius_mod = circle_radius_sines[i].tickSine();

            const final_radius_x =
                circle_radius + radius_x_mod + sprite_radius_mod;
            const final_radius_y =
                circle_radius + radius_y_mod + sprite_radius_mod;

            // Calculate ellipse position with rotation
            const base_angle = @as(f32, @floatFromInt(i)) * 22.5 +
                circle_rotation_angle;
            const base_pos = calculateEllipsePosition(
                circle_center_x,
                circle_center_y,
                final_radius_x,
                final_radius_y,
                base_angle,
            );

            // Add 2D wave motion on top of circular motion
            const wave_x = circle_sines[i].tickSine();
            const wave_y = circle_cosines[i].tickCosine();
            const final_x = base_pos.x + wave_x;
            const final_y = base_pos.y + wave_y;

            circle_sprites[i].stepActiveAnimation();
            circle_sprites[i].setXY(final_x, final_y);

            // Update pulsing alpha transparency
            const alpha_offset = circle_alpha_sines[i].tickSine();
            const circle_alpha = @as(u8, @intCast(128 + alpha_offset));

            const circle_frame = try circle_sprites[i].getCurrentFrameSurface();
            for (circle_frame.shadow_map) |*alpha| {
                if (alpha.* != 0) {
                    alpha.* = circle_alpha;
                }
            }
        }

        // Update scrolling text position
        if (frame % 2 == 0) {
            scroller_x -= 2;
            if (scroller_x <= -(scroller_width + 30)) {
                scroller_x = @as(i32, @intCast(screen_width)) + 30;
            }
        }

        // Apply vertical sine wave to scroller
        const scroller_y_offset = scroller_vertical_sine.tickSine();
        alpha_scroller.setXY(scroller_x, scroller_y + scroller_y_offset);

        // Update scroller alpha transparency
        const scroller_alpha_offset = scroller_sine.tickSine();
        const scroller_alpha = @as(u8, @intCast(128 + scroller_alpha_offset));

        for (alpha_scroller.output_surface.shadow_map, 0..) |*alpha, idx| {
            const original_alpha = scroller_surface.shadow_map[idx];
            if (original_alpha != 0) {
                alpha.* = scroller_alpha;
            }
        }

        // Update flashing title text
        const flash_value = flash_sine.tickSine();
        const darker_amount = @as(u8, @intCast(@abs(flash_value)));
        const flash_color = movy.color.darker(movy.color.WHITE, darker_amount);

        const text = "< MOVY 0.2.0 - ALPHA BLEND DEMO >";
        const text_x_pos = @divTrunc(@as(i32, @intCast(screen_width)), 2) -
            @as(i32, @intCast(text.len / 2));

        _ = text_surface.putStrXY(
            text,
            @intCast(text_x_pos),
            0,
            flash_color,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );

        // Render all elements with alpha blending
        try screen.renderInit();

        // Add all surfaces to screen (z-index determines layering)
        try screen.addRenderSurface(allocator, help_surface);
        try screen.addRenderSurface(allocator, text_surface);

        for (0..8) |i| {
            try screen.addRenderSurface(
                allocator,
                try sprites[i].getCurrentFrameSurface(),
            );
        }
        try screen.addRenderSurface(allocator, movy_logo.output_surface);
        try screen.addRenderSurface(allocator, alpha_scroller.output_surface);

        for (0..16) |i| {
            try screen.addRenderSurface(
                allocator,
                try circle_sprites[i].getCurrentFrameSurface(),
            );
        }

        // Composite all surfaces with alpha blending and output to terminal
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
}
