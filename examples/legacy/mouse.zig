const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();

    std.debug.print("Move mouse (Escape to quit):\n", .{});
    while (true) {
        if (try movy.input.get()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.type == .Escape) break;
                },
                .mouse => |mouse| {
                    std.debug.print(
                        "{s} at ({d}, {d})\n",
                        .{ @tagName(mouse.event), mouse.x, mouse.y },
                    );
                },
            }
        }
        std.Thread.sleep(10_000_000); // ~100 FPS
    }
}
