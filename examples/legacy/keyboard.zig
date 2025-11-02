const std = @import("std");
const movy = @import("movy");

pub fn main() !void {



    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();

    std.debug.print("Press keys (Escape to quit):\n", .{});
    while (true) {
        if (try movy.input.get()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.type == .Escape) break;
                    if (key.type == .Char) {
                        std.debug.print("Key: {c}\n", .{key.sequence[0]});
                    } else std.debug.print(
                        "Key: {s}\n",
                        .{@tagName(key.type)},
                    );
                },
                else => {},
            }
        }
        std.Thread.sleep(10_000_000); // ~100 FPS
    }
}
