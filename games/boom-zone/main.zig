const std = @import("std");
const movy = @import("movy");
const GameManager = @import("GameManager.zig").GameManager;

const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // -- Init terminal and screen
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
        terminal_size.height,
    );

    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // -- Game Setup

    var game = try GameManager.init(
        allocator,
        &screen,
    );

    // -- Main loop

    // Buffers for various outputs
    var render_time_buffer: [64]u8 = undefined;
    var output_time_buffer: [64]u8 = undefined;
    var loop_time_buffer: [64]u8 = undefined;
    var status_line_buffer: [1024]u8 = undefined;
    var render_time_len: usize = 0;
    var output_time_len: usize = 0;
    var loop_time_len: usize = 0;

    // THE frame counter
    var inner_loop: usize = 0;
    var frame: usize = 0;

    // Keyboard control
    const keydown_time: usize = 500;
    var keydown_cooldown: usize = 0;
    var last_key: ?movy.input.Key = null;
    var freeze: i32 = 0;

    while (true) {
        inner_loop += 1;

        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    _ = switch (key.type) {
                        .Escape => {
                            break;
                        },
                        .Down => {
                            freeze = 1 - freeze;
                        },
                        else => {
                            last_key = key;
                            keydown_cooldown = keydown_time;
                            game.onKeyDown(last_key.?);
                        },
                    };
                },
                else => {},
            }
        } else {
            if (keydown_cooldown > 0) {
                keydown_cooldown -= 1;
                if (keydown_cooldown == 0) {
                    game.onKeyUp(last_key.?);
                    last_key = null;
                }
            }
        }
        // Measure whole loop time
        const loop_start_time = std.time.nanoTimestamp();

        if (inner_loop % 100 == 0) {
            frame += 1;

            if (freeze == 1) continue;

            // Update sprite, and alien cursor position
            // Measure render time
            const start_time = std.time.nanoTimestamp();

            // Run Game logic
            try game.update(allocator);
            try game.renderFrame();

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

            const msg =
                game.player.message orelse "";

            const status = try std.fmt.bufPrint(
                &status_line_buffer,
                "{s:>20} {s:>28} | {s:>20} | {s:>20}",
                .{
                    msg,
                    render_time_buffer[0..render_time_len],
                    output_time_buffer[0..output_time_len],
                    loop_time_buffer[0..loop_time_len],
                },
            );
            const status_len = status.len;
            game.statuswin.update(status_line_buffer[0..status_len]);
        } else std.time.sleep(50_000);
    }
}
