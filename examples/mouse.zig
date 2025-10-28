const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();

    try stdout.print("Move mouse (Escape to quit):\n", .{});
    while (true) {
        if (try movy.input.get()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.type == .Escape) break;
                },
                .mouse => |mouse| {
                    try stdout.print(
                        "{s} at ({d}, {d})\n",
                        .{ @tagName(mouse.event), mouse.x, mouse.y },
                    );
                },
            }
        }
        std.Thread.sleep(10_000_000); // ~100 FPS
    }
}
