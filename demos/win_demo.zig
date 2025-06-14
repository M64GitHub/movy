const std = @import("std");
const movy = @import("movy");

const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get the terminal size
    const terminal_size = try movy.terminal.getSize();

    // Set raw mode, switch to alternate screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // -- Initialize screen (height in line numbers)
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height - 3,
    );

    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);

    // -- Sprites Setup: 2 logos loaded from PNG:
    // m64 logo
    var sprite_m64_logo = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/m64logo.png",
        "sprite 1",
    );
    // we dont defer .deinit() here, as sprite will be added to the manager,
    // which keeps track, and destroys it on its .deinit().

    // configure an outlineRotator effect
    var outline_rotator = movy.render.Effect.OutlineRotator{
        .start_x = 0,
        .start_y = 0,
        .direction = .left,
    };
    var rotator_effect = outline_rotator.asEffect();

    // movy logo
    var sprite_movy_logo = try movy.graphic.Sprite.initFromPng(
        allocator,
        "demos/assets/movy_100_transparent.png",
        "sprite 2",
    );

    // -- Create a UI manager - owns and tracks all UI elements, sprites
    var manager = movy.ui.Manager.init(allocator, &screen);
    defer manager.deinit();

    // -- Load default theme and style
    const theme = movy.ui.ColorTheme.initTokyoNightStorm();
    const style = movy.ui.Style.initNeoVim();
    // apply theme background to screen, but darker
    screen.bg_color = movy.color.darker(theme.getColor(.BackgroundColor), 50);

    // -- Position sprites (need manager to center)
    var spr_pos_m64 = manager.getCenterCoords(
        sprite_m64_logo.w,
        sprite_m64_logo.h,
    );
    spr_pos_m64.y += @divTrunc(spr_pos_m64.y, 2);

    // set up sine movement
    // 150 frames for a full cycle, amplitude little less than screen.w / 2
    var amplitude: i32 = @divTrunc(@as(i32, @intCast(screen.w)), 2);
    const amplitude_border: i32 = @divTrunc(@as(i32, @intCast(screen.w)), 8);
    amplitude = amplitude - amplitude_border;

    var sine_wave = movy.animation.TrigWave.init(150, amplitude);
    sprite_m64_logo.setXY(spr_pos_m64.x + sine_wave.tickSine(), spr_pos_m64.y);

    var spr_pos_movy = manager.getCenterCoords(
        sprite_movy_logo.w,
        sprite_movy_logo.h,
    );
    spr_pos_movy.y = @divTrunc(spr_pos_movy.y, 4);
    sprite_movy_logo.setXY(
        spr_pos_movy.x,
        spr_pos_movy.y + @rem(spr_pos_movy.y, 2),
    );

    // -- Add Textwindows
    // Calculate centered window position for a 40x60 window
    // This size will be used for all windows
    const window_w: usize = 50;
    const window_h: usize = 70;

    // Window 1
    // Center X
    // Center Y, slight top bias
    var window_x: i32 = manager.getCenterCoords(window_w, window_h).x;
    window_x = @divTrunc(window_x, 8);
    var window_y: i32 = manager.getCenterCoords(window_w, window_h).y;
    window_y -= 10;

    // Create a text-window, title " Text Window ", with text
    const text_window1 = try manager.createTextWindow(
        window_x,
        window_y,
        window_w,
        window_h,
        "Text Window 1",
        "Hello World!\n\nThis is a `TextWindow`!\n\nmovy your ui!!\n\n" ++
            "Start typing ...",
        &theme,
        &style,
    );

    // Window 2
    // Center X
    // Center Y, slight top bias
    window_x = manager.getCenterCoords(window_w, window_h).x;
    window_x = @divTrunc(window_x, 8);
    window_x *= 16;
    window_y = manager.getCenterCoords(window_w, window_h).y;
    window_y -= 10;

    // Create a text-window, title " Text Window ", with text
    // const text_window2 = try manager.createTextWindow(
    var text_window2 = try manager.createTextWindow(
        window_x,
        window_y,
        window_w,
        window_h,
        "Text Window 2",
        "no text",
        &theme,
        &style,
    );
    try text_window2.styled_text.fromFile(allocator, "demos/assets/test.md", 1024);
    text_window2.styleMarkDown();

    // add a status window
    const status_window = try manager.createTextWindow(
        0,
        @as(i32, @intCast(screen.h)) - 6,
        screen.w,
        6,
        "Status",
        "Status",
        &theme,
        &style,
    );

    try manager.addSprite(sprite_m64_logo);
    try manager.addSprite(sprite_movy_logo);

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
    var frame: usize = 0;

    // make textwindow active:
    manager.setActiveWidget(text_window1.getWidgetInfo());

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
                        .Char, .Other => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Key: {s}",
                                .{key.sequence},
                            );
                            message_len = message.len;
                        },
                        else => {
                            const message = try std.fmt.bufPrint(
                                &message_buffer,
                                "Key: {s}",
                                .{@tagName(key.type)},
                            );
                            message_len = message.len;
                        },
                    };
                    _ = manager.handleInputEvent(in); // event consumed?
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
                    _ = manager.handleInputEvent(in); // event consumed?
                },
            }
        }

        if (frame % 100 == 0) {
            // Update sprite, and alien cursor position
            sprite_m64_logo.setXY(
                spr_pos_m64.x + sine_wave.tickSine(),
                spr_pos_m64.y,
            );

            // Apply OutlineRotator effect
            try rotator_effect.runOnSurfaces(
                sprite_m64_logo.output_surface,
                sprite_m64_logo.output_surface,
                frame,
            );

            // Measure render time
            const start_time = std.time.nanoTimestamp();

            // Render
            try manager.render();
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
        } else std.time.sleep(50_000);
    }
}
