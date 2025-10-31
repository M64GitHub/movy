const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== RenderEngine Stress Test ===\n", .{});
    std.debug.print("Setting up 200x100 output surface...\n", .{});

    // Create 200x100 output surface
    var output_surface = try movy.core.RenderSurface.init(
        allocator,
        200,
        100,
        .{ .r = 0, .g = 0, .b = 0 },
    );
    defer {
        output_surface.deinit(allocator);
        allocator.destroy(output_surface);
    }

    std.debug.print("Loading sprites...\n", .{});

    // Load alien.png
    var sprite_alien = try movy.Sprite.initFromPng(
        allocator,
        "demos/assets/alien.png",
        "alien",
    );
    defer sprite_alien.deinit(allocator);

    // Load m64logo.png
    var sprite_m64 = try movy.Sprite.initFromPng(
        allocator,
        "demos/assets/m64logo.png",
        "m64logo",
    );
    defer sprite_m64.deinit(allocator);

    // Get surfaces from sprites
    var surface_alien = try sprite_alien.getCurrentFrameSurface();
    var surface_m64 = try sprite_m64.getCurrentFrameSurface();

    // Set initial positions so they overlap
    // Alien at (50, 40), M64 at (80, 50) - they will overlap
    const alien_init_x: i32 = 50;
    const alien_init_y: i32 = 40;
    const m64_init_x: i32 = 80;
    const m64_init_y: i32 = 50;

    surface_alien.x = alien_init_x;
    surface_alien.y = alien_init_y;
    surface_m64.x = m64_init_x;
    surface_m64.y = m64_init_y;

    // Create input array (Unmanaged ArrayList like in Screen.zig)
    var input_surfaces = std.ArrayList(
        *movy.core.RenderSurface,
    ){};
    defer input_surfaces.deinit(allocator);

    try input_surfaces.append(allocator, surface_alien);
    try input_surfaces.append(allocator, surface_m64);

    std.debug.print("Starting stress test: 100,000 iterations...\n", .{});
    std.debug.print("Each iteration: clear + render + move sprites\n", .{});

    // Start timing
    var timer = try std.time.Timer.start();

    const iterations: usize = 100_000;
    for (0..iterations) |i| {
        // Clear output surface
        output_surface.clearTransparent();

        // Render both surfaces
        movy.render.RenderEngine.render(input_surfaces.items, output_surface);

        // Move alien: right by 1, down by 1
        surface_alien.x += 1;
        surface_alien.y += 1;

        // Move m64: left by 1, up by 1 (opposite direction)
        surface_m64.x -= 1;
        surface_m64.y -= 1;

        // Reset alien if goes off-screen (right or bottom)
        if (surface_alien.x > 200 or surface_alien.y > 100) {
            surface_alien.x = alien_init_x;
            surface_alien.y = alien_init_y;
        }

        // Reset m64 if goes off-screen (left or top)
        if (surface_m64.x < -@as(i32, @intCast(surface_m64.w)) or
            surface_m64.y < -@as(i32, @intCast(surface_m64.h)))
        {
            surface_m64.x = m64_init_x;
            surface_m64.y = m64_init_y;
        }

        // Print progress every 10,000 iterations
        if ((i + 1) % 10_000 == 0) {
            std.debug.print(
                "  Progress: {d}/100,000 ({d}%)\n",
                .{ i + 1, (i + 1) / 1000 },
            );
        }
    }

    // Stop timing
    const elapsed_ns = timer.read();
    const elapsed_ms = elapsed_ns / std.time.ns_per_ms;
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(
        f64,
        @floatFromInt(std.time.ns_per_s),
    );

    std.debug.print("\n=== Results ===\n", .{});
    std.debug.print("Total iterations: {d}\n", .{iterations});
    std.debug.print("Total time: {d}ms ({d:.3}s)\n", .{ elapsed_ms, elapsed_s });
    std.debug.print(
        "Time per iteration: {d:.2}µs\n",
        .{
            @as(f64, @floatFromInt(elapsed_ns)) /
                @as(f64, @floatFromInt(iterations)) / 1000.0,
        },
    );
    std.debug.print(
        "Iterations per second: {d:.0}\n",
        .{@as(f64, @floatFromInt(iterations)) / elapsed_s},
    );

    // Calculate pixels processed
    const pixels_per_iteration = output_surface.w * output_surface.h;
    const total_pixels = pixels_per_iteration * iterations;
    const mpixels_per_sec = @as(f64, @floatFromInt(total_pixels)) /
        elapsed_s / 1_000_000.0;

    std.debug.print(
        "\nPixels processed: {d} ({d:.1}M)\n",
        .{ total_pixels, @as(f64, @floatFromInt(total_pixels)) / 1_000_000.0 },
    );
    std.debug.print("Megapixels/sec: {d:.2}\n", .{mpixels_per_sec});

    std.debug.print("\n=== Test Complete ===\n", .{});
}
