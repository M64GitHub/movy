const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();

    try stdout.print("Press keys (Escape to quit):\n", .{});
    while (true) {
        if (try movy.input.get()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.type == .Escape) break;
                    if (key.type == .Char) {
                        try stdout.print("Key: {c}\n", .{key.sequence[0]});
                    } else try stdout.print(
                        "Key: {s}\n",
                        .{@tagName(key.type)},
                    );
                },
                else => {},
            }
        }
        std.time.sleep(10_000_000); // ~100 FPS
    }
}
