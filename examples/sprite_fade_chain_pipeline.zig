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

    // Initialize screen
    var screen = try movy.Screen.init(allocator, stdout, 120, 40);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);

    // Load sprite
    var sprite = try movy.graphic.Sprite.initFromPng(
        allocator,
        "examples/assets/m64logo.png",
        "fade_demo",
    );
    defer sprite.deinit(allocator);

    // Get input surface
    const input_surface = try sprite.getCurrentFrameSurface();

    // Create and initialize a fade effect with your params
    // you can change these parameters during runtime using this variable
    var fade = movy.render.Effect.Fade{
        .alpha_start = 0.0,
        .alpha_end = 1.0,
        .duration = 60,
    };

    // get a RenderEffect object able to be passed into chains and pipelines
    const fade_effect = fade.asEffect();

    // Create and initialize a blur effect with your params
    // you can change these parameters during runtime using this variable
    var blur = movy.render.Effect.Blur{
        .radius = 10,
    };
    // get a RenderEffect object able to be passed into chains and pipelines
    const blur_effect = blur.asEffect();

    // Create chain and add effects
    var chain = try movy.render.RenderEffectChain.init(allocator);
    try chain.chainEffect(fade_effect);
    try chain.chainEffect(blur_effect);
    defer chain.deinit(allocator);

    // Create pipeline
    var pipeline = try movy.render.RenderPipeline.init(
        allocator,
        screen.output_surface,
    );
    defer pipeline.deinit(allocator);

    const render_object = try movy.render.RenderObject.init(
        allocator,
        input_surface,
        &chain,
    );

    // Add render object
    try pipeline.addObject(render_object);

    // // Add render object
    // try pipeline.addSurface(allocator, input_surface, &chain);

    // Run pipeline at frame 30 (half fade)
    try pipeline.run(allocator, 30);

    // Output to screen
    try screen.output();

    movy.terminal.setColor(stdout, movy.color.LIGHT_BLUE);
    try stdout.print(
        "Sprite faded at frame 30! Press Enter to quit...\n",
        .{},
    );
    while (true) {
        if (try movy.input.get()) |event| {
            switch (event) {
                .key => |key| {
                    if (key.type == .Escape) break;
                },
                else => {},
            }
        }
        std.Thread.sleep(10_000_000); // ~100 FPS
    }
}
