const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Set raw mode, switch to alternate screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // Initialize screen (height in line numbers)
    var screen = try movy.Screen.init(allocator, 120, 40);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);

    // Load sprites
    // alien
    var sprite_alien = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/alien.png",
        "alien 1",
    );
    defer sprite_alien.deinit(allocator);

    // m64 logo
    var sprite_m64_logo = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/m64logo.png",
        "sprite 1",
    );
    defer sprite_m64_logo.deinit(allocator);

    // print some text onto our sprite
    var data_surface = try sprite_m64_logo.getCurrentFrameSurface();
    _ = data_surface.putStrXY(
        "UTF8!\nThis is TEXT on PNG data!",
        10,
        4,
        movy.color.WHITE,
        movy.color.DARK_GRAY,
    );

    _ = data_surface.putStrXY(
        "M64!",
        41,
        8,
        movy.color.BLACK_4,
        movy.color.DARK_GRAY,
    );

    // apply frame- to output-surface
    try sprite_m64_logo.applyCurrentFrame();

    // configure an outlineRotator effect
    var outline_rotator = movy.render.Effect.OutlineRotator{
        .start_x = 0,
        .start_y = 0,
        .direction = .left,
    };
    var rotator_effect = outline_rotator.asEffect();

    sprite_m64_logo.effect_ctx.input_surface = sprite_m64_logo.output_surface;

    // movy logo
    var sprite_movy_logo = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/movy_100_transparent.png",
        "sprite 2",
    );
    defer sprite_movy_logo.deinit(allocator);
    data_surface = try sprite_movy_logo.getCurrentFrameSurface();

    // set up sine movement
    // 150 frames for a full cycle, amplitude 50
    var sine_wave = movy.animation.TrigWave.init(150, 50);
    var sine_wave2 = movy.animation.TrigWave.init(200, 40);

    // position sprites
    sprite_m64_logo.setXY(34 + sine_wave.tickSine(), 54);
    sprite_movy_logo.setXY(10, 12);

    // add a textwindow
    // Create a manager—owns and tracks all UI elements.
    var manager = movy.ui.Manager.init(allocator, &screen);
    defer manager.deinit();

    // Load default theme and style
    const theme = movy.ui.ColorTheme.initCatppuccinMocha();
    // const theme = movy.ui.ColorTheme.initTokyoNightStorm();
    const style = movy.ui.Style.initNeoVim();

    screen.bg_color = movy.color.darker(theme.getColor(.BackgroundColor), 30);

    // Calculate centered position—60x40 window in 120x80 screen.
    const window_w: usize = 60;
    const window_h: usize = 40;

    // Center X
    const window_x: i32 =
        @divTrunc(@as(i32, @intCast(screen.width() - window_w)), 2);

    // Center Y, slight top bias
    var window_y: i32 =
        @divTrunc(@as(i32, @intCast(screen.height() - window_h)), 4);
    window_y = window_y + 10;

    // Create a text-window, title " Text Window ", with text
    const text_window = try manager.createTextWindow(
        window_x,
        window_y,
        window_w,
        window_h,
        " Text Window ",
        "Hello World!\n\nThis is a TextWindow!\n\nmovy your ui!!\n\n" ++
            "F1 to FREEZE!",
        &theme,
        &style,
    );

    // set active for typing
    text_window.setActive(true);

    // render and get output-surface pointer to add to screen later
    const window_surface = text_window.render();

    // add a status window
    const status_window = try manager.createTextWindow(
        0,
        @as(i32, @intCast(screen.h)) - 6,
        screen.w,
        6,
        " Status ",
        "Status",
        &theme,
        &style,
    );
    const status_surface = status_window.render();

    // add all we want to render to the screen - reverse z order: first is top
    try screen.addRenderSurface(allocator, sprite_alien.output_surface);
    try screen.addRenderSurface(allocator, window_surface);
    try screen.addRenderSurface(allocator, sprite_movy_logo.output_surface);
    try screen.addRenderSurface(allocator, sprite_m64_logo.output_surface);
    try screen.addRenderSurface(allocator, status_surface);

    // render the screen and blast it to the terminal before main loop starts
    screen.render();
    try screen.output();

    // Buffers for various outputs
    var message_buffer: [64]u8 = undefined;
    var render_time_buffer: [64]u8 = undefined;
    var output_time_buffer: [64]u8 = undefined;
    var loop_time_buffer: [64]u8 = undefined;
    var status_line_buffer: [1024]u8 = undefined;
    var message_len: usize = 0;
    var render_time_len: usize = 0;
    var output_time_len: usize = 0;
    var loop_time_len: usize = 0;

    // variables we use to control actions in the main loop
    var mouse_x: i32 = 0;
    var mouse_y: i32 = 0;

    var frame: usize = 0;
    var freeze: i32 = 0;
    var editing_started: bool = false;

    // Main loop
    while (true) {
        frame += 1;
        // Measure whole loop time
        const loop_start_time = std.time.nanoTimestamp();

        // Get input and format into buffer
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    _ = switch (key.type) {
                        .Enter => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Enter pressed",
                                .{},
                            );
                            message_len = message.len;
                            if (!editing_started) {
                                editing_started = true;
                                text_window.styled_text.clear();
                            }
                            text_window.handleInputEvent(in);
                        },
                        .Backspace => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Backspace pressed",
                                .{},
                            );
                            message_len = message.len;
                            if (!editing_started) {
                                editing_started = true;
                                text_window.styled_text.clear();
                            }
                            text_window.handleInputEvent(in);
                        },
                        .Escape => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Escape pressed, exitting ...",
                                .{},
                            );
                            message_len = message.len;
                            break;
                        },
                        .CtrlC => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Ctrl+C pressed, exitting ...",
                                .{},
                            );
                            message_len = message.len;
                            break;
                        },
                        .F1 => {
                            freeze = 1 - freeze;
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "F1 pressed, freeze: {d}",
                                .{freeze},
                            );
                            message_len = message.len;
                        },
                        // Control Keys passed to Window:
                        .Up,
                        .Down,
                        .Right,
                        .Left,
                        .CtrlRight,
                        .CtrlLeft,
                        .CtrlUp,
                        .CtrlDown,
                        .CtrlHome,
                        .CtrlEnd,
                        .ShiftRight,
                        .ShiftLeft,
                        .ShiftUp,
                        .ShiftDown,
                        .ShiftHome,
                        .ShiftEnd,
                        .Home,
                        .End,
                        .Tab,
                        .ShiftTab,
                        .Delete,
                        => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "{s} pressed",
                                .{@tagName(key.type)},
                            );
                            message_len = message.len;
                            text_window.handleInputEvent(in);
                        },
                        .F2,
                        .F3,
                        .F4,
                        .F5,
                        .F6,
                        .F7,
                        .F8,
                        .F9,
                        .F10,
                        .F11,
                        .F12,
                        .PageUp,
                        .PageDown,
                        .PrintScreen,
                        .Pause,
                        .ShiftPrintScreen,
                        .ShiftPause,
                        .CtrlPrintScreen,
                        .CtrlPause,
                        => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "{s} pressed",
                                .{@tagName(key.type)},
                            );
                            message_len = message.len;
                        },
                        .Char, .Other => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Key: {s}",
                                .{key.sequence},
                            );
                            message_len = message.len;

                            if (!editing_started) {
                                editing_started = true;
                                text_window.styled_text.clear();
                            }
                            text_window.handleInputEvent(in);
                        },
                    };
                    _ = text_window.render();
                },
                .mouse => |mouse| {
                    _ = switch (mouse.event) {
                        .Down => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Mouse Down: btn={} x={} y={}",
                                .{ mouse.button, mouse.x, mouse.y },
                            );
                            message_len = message.len;
                        },
                        .Up => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Mouse Up: btn={} x={} y={}",
                                .{ mouse.button, mouse.x, mouse.y },
                            );
                            message_len = message.len;
                        },
                        .WheelUp => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Wheel Up: x={} y={}",
                                .{ mouse.x, mouse.y },
                            );
                            message_len = message.len;
                        },
                        .WheelDown => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Wheel Down: x={} y={}",
                                .{ mouse.x, mouse.y },
                            );
                            message_len = message.len;
                        },
                        .Move => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Mouse Move: x={} y={}",
                                .{ mouse.x, mouse.y },
                            );
                            message_len = message.len;
                        },
                    };
                    mouse_x = mouse.x;
                    mouse_y = mouse.y;
                },
            }
        }
        if (frame % 100 == 0) {
            // Update sprite, and alien cursor position
            if (freeze == 0) {
                sprite_alien.setXY(mouse_x - 10, mouse_y * 2 - 8);
                sprite_m64_logo.setXY(34 + sine_wave.tickSine(), 54);
                text_window.setPosition(
                    window_x - sine_wave2.tickSine(),
                    window_y,
                );
            }

            // // Apply effect (same, but not using effect_ctx
            // // this works fine, when effects don't resize
            // try rotator_effect.runOnSurfaces(
            //     sprite_m64_logo.output_surface,
            //     sprite_m64_logo.output_surface,
            //     frame,
            // );

            // Apply effect
            try rotator_effect.run(
                allocator,
                &sprite_m64_logo.effect_ctx,
                frame,
            );

            // Measure render time
            const start_time = std.time.nanoTimestamp();

            // Render
            _ = status_window.render();
            screen.render();
            var end_time = std.time.nanoTimestamp();
            const render_time_ns = end_time - start_time;

            // Blast to terminal
            try screen.output();
            end_time = std.time.nanoTimestamp() - end_time;

            // Format render time (in microseconds)
            const render_time = try std.fmt.bufPrint(
                &render_time_buffer,
                "Render time: {d:>4} us",
                .{@divTrunc(render_time_ns, 1000)},
            );
            render_time_len = render_time.len;

            // Format output time (in microseconds)
            const output_time = try std.fmt.bufPrint(
                &output_time_buffer,
                "Output time: {d:>6} us",
                .{@divTrunc(end_time, 1000)},
            );
            output_time_len = output_time.len;

            // End loop timing
            const loop_end_time = std.time.nanoTimestamp();
            const loop_time_ns = loop_end_time - loop_start_time;

            // Format loop time (in microseconds)
            const loop_time = try std.fmt.bufPrint(
                &loop_time_buffer,
                "Loop time: {d:>6} us",
                .{@divTrunc(loop_time_ns, 1000) + 500},
            );
            loop_time_len = loop_time.len;

            // print status
            const status = try std.fmt.bufPrint(
                &status_line_buffer,
                " Message: {s:<30} {s:>28} | {s:>20} | {s:>20}",
                .{
                    message_buffer[0..message_len],
                    render_time_buffer[0..render_time_len],
                    output_time_buffer[0..output_time_len],
                    loop_time_buffer[0..loop_time_len],
                },
            );
            const status_len = status.len;
            try status_window.setText(status_line_buffer[0..status_len]);
        } else std.Thread.sleep(50_000);
    }
}
