const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var input_surface = try movy.core.RenderSurface.init(
        allocator,
        10,
        10,
        .{ .r = 128, .g = 128, .b = 128 },
    );
    defer input_surface.deinit(allocator);
    input_surface.x = 1;
    input_surface.y = 2;
    input_surface.z = 3;
    for (input_surface.shadow_map) |*s| s.* = 1;

    var output_surface = try movy.core.RenderSurface.init(
        allocator,
        10,
        10,
        .{ .r = 0, .g = 0, .b = 0 },
    );
    defer output_surface.deinit(allocator);

    // Create and initialize a fade effect with your params
    // you can change these parameters during runtime using this variable
    var fade = movy.render.Effect.Fade{
        .alpha_start = 0.0,
        .alpha_end = 1.0,
        .duration = 60,
    };
    // get a RenderEffect object able to be passed into chains and pipelines
    const fade_effect = fade.asEffect();

    // Create and initialize a fade effect with your params
    // you can change these parameters during runtime using this variable
    var blur = movy.render.Effect.Blur{
        .radius = 10,
    };
    // get a RenderEffect object able to be passed into chains and pipelines
    const blur_effect = blur.asEffect();

    // Initialize chain
    var chain = try movy.render.RenderEffectChain.init(allocator);
    defer chain.deinit(allocator);
    // chain the effects
    try chain.chainEffect(blur_effect);
    try chain.chainEffect(fade_effect);

    // Create an Effect Context
    var fx_ctx = movy.render.Effect.RenderEffectContext{
        .input_surface = input_surface,
        .output_surface = output_surface,
    };

    // Run the chain
    try stdout.print("Running chain...\n", .{});
    try chain.run(allocator, &fx_ctx, 30);
    try stdout.print("Output[0]: r={d}, g={d}, b={d}\n", .{
        output_surface.color_map[0].r,
        output_surface.color_map[0].g,
        output_surface.color_map[0].b,
    });

    try stdout.print("Expecting: r=g=b=69 (128/2) + 10/2\n", .{});
}
