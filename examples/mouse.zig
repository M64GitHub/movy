const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

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
        std.time.sleep(10_000_000); // ~100 FPS
    }
}
