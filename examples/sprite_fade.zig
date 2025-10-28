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
        "fade_demo",
    );
    defer sprite.deinit(allocator);
    try screen.addSprite(sprite);

    // Create and initialize a fade effect with your params
    // you can change these parameters during runtime using this variable
    var fade = movy.render.Effect.Fade{
        .alpha_start = 0.0,
        .alpha_end = 1.0,
        .duration = 60,
    };
    // get a RenderEffect object able to be passed into chains and pipelines
    var fade_effect = fade.asEffect();

    var frame: usize = 0;

    try stdout.print("Press keys (f to fade, Escape to quit):\n", .{});
    while (true) {
        if (try movy.input.get()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.type == .Escape) break;
                    if (key.type == .Char and key.sequence[0] == 'f') {
                        movy.terminal.setColor(stdout, movy.color.LIGHT_BLUE);
                        try stdout.print("\nrunning Fade: {d}\n", .{frame});
                        const in_surface = try sprite.getCurrentFrameSurface();
                        try fade_effect.runOnSurfaces(
                            in_surface,
                            sprite.output_surface,
                            frame,
                        );
                        try stdout.print("Fade: {d}\n", .{frame});
                        frame = (frame + 1) % 60; // Cycle 0-59
                    }
                },
                else => {},
            }
        }
        try screen.renderWithSprites();

        try screen.output();

        std.Thread.sleep(16_000_000); // ~60 FPS
    }
}
