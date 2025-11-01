const std = @import("std");
const movy = @import("movy");
const common = @import("common");

const OutputSizeResult = struct {
    width: usize,
    height: usize,
    elapsed_ns: u64,
    iterations: usize,

    fn timePerIter(self: OutputSizeResult) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(self.iterations)) / 1000.0;
    }

    fn iterPerSec(self: OutputSizeResult) f64 {
        const elapsed_s = @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(std.time.ns_per_s));
        return @as(f64, @floatFromInt(self.iterations)) / elapsed_s;
    }

    fn mpixelsPerSec(self: OutputSizeResult) f64 {
        const elapsed_s = @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(std.time.ns_per_s));
        const pixels_per_iter = self.width * self.height;
        const total_pixels = pixels_per_iter * self.iterations;
        return @as(f64, @floatFromInt(total_pixels)) / elapsed_s / 1_000_000.0;
    }
};

fn testOutputSize(
    allocator: std.mem.Allocator,
    output_w: usize,
    output_h: usize,
    iterations: usize,
) !OutputSizeResult {
    std.debug.print("\n--- Testing {d}x{d} output surface ---\n", .{ output_w, output_h });

    // Create output surface
    var output_surface = try movy.core.RenderSurface.init(
        allocator,
        output_w,
        output_h,
        .{ .r = 0, .g = 0, .b = 0 },
    );
    defer {
        output_surface.deinit(allocator);
        allocator.destroy(output_surface);
    }

    // Load sprites
    var sprite_10a = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/10x10.png", "10a");
    defer sprite_10a.deinit(allocator);
    var sprite_10b = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/10x10.png", "10b");
    defer sprite_10b.deinit(allocator);
    var sprite_20a = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/20x20.png", "20a");
    defer sprite_20a.deinit(allocator);
    var sprite_20b = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/20x20.png", "20b");
    defer sprite_20b.deinit(allocator);
    var sprite_movycat = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/movycat.png", "movycat");
    defer sprite_movycat.deinit(allocator);

    var surface_10a = try sprite_10a.getCurrentFrameSurface();
    var surface_10b = try sprite_10b.getCurrentFrameSurface();
    var surface_20a = try sprite_20a.getCurrentFrameSurface();
    var surface_20b = try sprite_20b.getCurrentFrameSurface();
    var surface_movycat = try sprite_movycat.getCurrentFrameSurface();

    // Initial positions (non-overlapping, 2px from borders)
    const w_i32 = @as(i32, @intCast(output_w));
    const h_i32 = @as(i32, @intCast(output_h));

    surface_10a.x = 2; // Top-left
    surface_10a.y = 2;
    surface_10b.x = w_i32 - 12; // Top-right
    surface_10b.y = 2;
    surface_20a.x = 2; // Bottom-left
    surface_20a.y = h_i32 - 22;
    surface_20b.x = w_i32 - 22; // Bottom-right
    surface_20b.y = h_i32 - 22;
    surface_movycat.x = @divTrunc(w_i32, 2) - 32; // Center
    surface_movycat.y = @divTrunc(h_i32, 2) - 32;

    // Movement deltas
    const dx_10a: i32 = 1;
    const dy_10a: i32 = 1;
    const dx_10b: i32 = -1;
    const dy_10b: i32 = -1;
    const dx_20a: i32 = 1;
    const dy_20a: i32 = -1;
    const dx_20b: i32 = -1;
    const dy_20b: i32 = 1;

    // Create input array (movycat added last = background)
    var input_surfaces = std.ArrayList(*movy.core.RenderSurface){};
    defer input_surfaces.deinit(allocator);

    try input_surfaces.append(allocator, surface_10a);
    try input_surfaces.append(allocator, surface_10b);
    try input_surfaces.append(allocator, surface_20a);
    try input_surfaces.append(allocator, surface_20b);
    try input_surfaces.append(allocator, surface_movycat);

    std.debug.print("Running {d} iterations...\n", .{iterations});

    var timer = try common.PerfTimer.start();

    for (0..iterations) |i| {
        output_surface.clearTransparent();
        movy.render.RenderEngine.render(input_surfaces.items, output_surface);

        // Convert to ANSI (full pipeline test)
        _ = try output_surface.toAnsi();

        // Move sprites with wrapping
        surface_10a.x += dx_10a;
        surface_10a.y += dy_10a;
        if (surface_10a.x < 0) surface_10a.x = w_i32 - 10;
        if (surface_10a.x >= w_i32) surface_10a.x = 0;
        if (surface_10a.y < 0) surface_10a.y = h_i32 - 10;
        if (surface_10a.y >= h_i32) surface_10a.y = 0;

        surface_10b.x += dx_10b;
        surface_10b.y += dy_10b;
        if (surface_10b.x < 0) surface_10b.x = w_i32 - 10;
        if (surface_10b.x >= w_i32) surface_10b.x = 0;
        if (surface_10b.y < 0) surface_10b.y = h_i32 - 10;
        if (surface_10b.y >= h_i32) surface_10b.y = 0;

        surface_20a.x += dx_20a;
        surface_20a.y += dy_20a;
        if (surface_20a.x < 0) surface_20a.x = w_i32 - 20;
        if (surface_20a.x >= w_i32) surface_20a.x = 0;
        if (surface_20a.y < 0) surface_20a.y = h_i32 - 20;
        if (surface_20a.y >= h_i32) surface_20a.y = 0;

        surface_20b.x += dx_20b;
        surface_20b.y += dy_20b;
        if (surface_20b.x < 0) surface_20b.x = w_i32 - 20;
        if (surface_20b.x >= w_i32) surface_20b.x = 0;
        if (surface_20b.y < 0) surface_20b.y = h_i32 - 20;
        if (surface_20b.y >= h_i32) surface_20b.y = 0;

        if ((i + 1) % 10_000 == 0) {
            common.printProgress(i + 1, iterations);
        }
    }

    const elapsed_ns = timer.elapsedNs();

    return OutputSizeResult{
        .width = output_w,
        .height = output_h,
        .elapsed_ns = elapsed_ns,
        .iterations = iterations,
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("=== RenderEngine.render() + toAnsi() Performance Test ===\n", .{});
    std.debug.print("Testing full pipeline performance across 3 output surface sizes\n", .{});
    std.debug.print("5 input sprites per test: 2x10x10, 2x20x20, 1x64x64 (movycat in background)\n", .{});
    std.debug.print("100,000 iterations per size\n", .{});

    const iterations: usize = 100_000;

    const result_100x60 = try testOutputSize(allocator, 100, 60, iterations);
    const result_150x100 = try testOutputSize(allocator, 150, 100, iterations);
    const result_200x100 = try testOutputSize(allocator, 200, 100, iterations);

    // Print comparison table
    std.debug.print("\n=== Output Surface Size Comparison ===\n", .{});
    std.debug.print(
        "{s:<12} | {s:>10} | {s:>11} | {s:>11} | {s:>9}\n",
        .{ "Size", "Pixels", "Time/iter", "Iter/sec", "MP/sec" },
    );
    std.debug.print("{s:-<12}-+-{s:->10}-+-{s:->11}-+-{s:->11}-+-{s:->9}\n", .{ "", "", "", "", "" });

    const results = [_]OutputSizeResult{ result_100x60, result_150x100, result_200x100 };
    for (results) |result| {
        std.debug.print(
            "{d:>4}x{d:<7} | {d:>10} | {d:>9.2}µs | {d:>11.0} | {d:>9.2}\n",
            .{
                result.width,
                result.height,
                result.width * result.height,
                result.timePerIter(),
                result.iterPerSec(),
                result.mpixelsPerSec(),
            },
        );
    }

    std.debug.print("\n=== Test Complete ===\n", .{});
}
