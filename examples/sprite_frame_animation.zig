const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen(stdout);
    defer movy.terminal.endAlternateScreen(stdout);

    var screen = try movy.Screen.init(allocator, stdout, 120, 40);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);

    var sprite = try movy.graphic.Sprite.initFromPng(
        allocator,
        "examples/assets/m64logo.png",
        "my logo",
    );
    defer sprite.deinit(allocator);
    try screen.addSprite(sprite);

    var anim = movy.graphic.Sprite.FrameAnimation.init(
        0,
        5,
        .loopBounce,
        1,
    );
    while (true) {
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    if (key.type == .Escape) break;
                    anim.step(sprite);
                    screen.render();
                    try screen.output();
                },
                else => {},
            }
        }
        std.Thread.sleep(16_000_000); // ~60 FPS
    }
}
