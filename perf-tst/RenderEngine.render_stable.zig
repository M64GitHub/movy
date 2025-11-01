const std = @import("std");
const movy = @import("movy");
const common = @import("common");
const flagz = @import("flagz");
const types = @import("types");
const system_info = @import("system_info");
const json_writer = @import("json_writer");

const TestArgs = struct {
    suffix: ?[]const u8 = null,
    output_dir: []const u8 = "perf-results",
    iterations: ?usize = null,
};

const OutputSizeResult = struct {
    name: []const u8,
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

    fn toMeasurementPoint(self: OutputSizeResult) types.MeasurementPoint {
        return types.MeasurementPoint{
            .name = self.name,
            .width = self.width,
            .height = self.height,
            .pixels = self.width * self.height,
            .iterations = self.iterations,
            .elapsed_ns = self.elapsed_ns,
            .time_per_iter_us = self.timePerIter(),
            .iter_per_sec = self.iterPerSec(),
            .megapixels_per_sec = self.mpixelsPerSec(),
        };
    }
};

fn testOutputSize(
    allocator: std.mem.Allocator,
    name: []const u8,
    output_w: usize,
    output_h: usize,
    iterations: usize,
) !OutputSizeResult {
    std.debug.print("  {s:<12} ", .{name});

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
    var sprite_10c = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/10x10.png", "10c");
    defer sprite_10c.deinit(allocator);
    var sprite_10d = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/10x10.png", "10d");
    defer sprite_10d.deinit(allocator);
    var sprite_40 = try movy.Sprite.initFromPng(allocator, "perf-tst/assets/40x40.png", "40");
    defer sprite_40.deinit(allocator);

    var surface_10a = try sprite_10a.getCurrentFrameSurface();
    var surface_10b = try sprite_10b.getCurrentFrameSurface();
    var surface_10c = try sprite_10c.getCurrentFrameSurface();
    var surface_10d = try sprite_10d.getCurrentFrameSurface();
    var surface_40 = try sprite_40.getCurrentFrameSurface();

    // Static positions (no movement)
    const w_i32 = @as(i32, @intCast(output_w));
    const h_i32 = @as(i32, @intCast(output_h));

    surface_10a.x = 4; // Top-left corner, 4px inset
    surface_10a.y = 4;
    surface_10b.x = w_i32 - 14; // Top-right corner, 4px inset
    surface_10b.y = 4;
    surface_10c.x = 4; // Bottom-left corner, 4px inset
    surface_10c.y = h_i32 - 14;
    surface_10d.x = w_i32 - 14; // Bottom-right corner, 4px inset
    surface_10d.y = h_i32 - 14;
    surface_40.x = @divTrunc(w_i32, 2) - 20; // Center
    surface_40.y = @divTrunc(h_i32, 2) - 20;

    // Create input array
    var input_surfaces = std.ArrayList(*movy.core.RenderSurface){};
    defer input_surfaces.deinit(allocator);

    try input_surfaces.append(allocator, surface_10a);
    try input_surfaces.append(allocator, surface_10b);
    try input_surfaces.append(allocator, surface_10c);
    try input_surfaces.append(allocator, surface_10d);
    try input_surfaces.append(allocator, surface_40);

    var timer = try common.PerfTimer.start();

    // NO MOVEMENT - static sprites for fair comparison
    for (0..iterations) |_| {
        output_surface.clearTransparent();
        movy.render.RenderEngine.render(input_surfaces.items, output_surface);
    }

    const elapsed_ns = timer.elapsedNs();

    std.debug.print("{d:>6.2}µs\n", .{
        @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations)) / 1000.0,
    });

    return OutputSizeResult{
        .name = name,
        .width = output_w,
        .height = output_h,
        .elapsed_ns = elapsed_ns,
        .iterations = iterations,
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command-line arguments
    const args = try flagz.parse(TestArgs, allocator);
    defer flagz.deinit(args, allocator);

    const write_json = args.suffix != null;
    const iterations = args.iterations orelse 100_000;

    std.debug.print("=== RenderEngine.render() Stable Performance Test ===\n", .{});
    std.debug.print("Static sprites (no movement) for fair comparison across surface sizes\n", .{});
    std.debug.print("5 sprites per test: 4x10x10 (corners, 4px inset), 1x40x40 (center)\n", .{});
    std.debug.print("{d} iterations per size\n\n", .{iterations});
    if (write_json) {
        std.debug.print("JSON output: {s}/{s}_RenderEngine.render_stable.json\n\n", .{ args.output_dir, args.suffix.? });
    }

    var results = std.ArrayList(OutputSizeResult){};
    defer results.deinit(allocator);

    // Square sizes
    std.debug.print("--- Square Sizes ---\n", .{});
    try results.append(allocator, try testOutputSize(allocator, "64x64", 64, 64, iterations));
    try results.append(allocator, try testOutputSize(allocator, "96x96", 96, 96, iterations));
    try results.append(allocator, try testOutputSize(allocator, "128x128", 128, 128, iterations));
    try results.append(allocator, try testOutputSize(allocator, "160x160", 160, 160, iterations));
    try results.append(allocator, try testOutputSize(allocator, "192x192", 192, 192, iterations));
    try results.append(allocator, try testOutputSize(allocator, "256x256", 256, 256, iterations));

    // Horizontal 16:9 aspect
    std.debug.print("\n--- Horizontal 16:9 Aspect ---\n", .{});
    try results.append(allocator, try testOutputSize(allocator, "64x36", 64, @divTrunc(64 * 9, 16), iterations));
    try results.append(allocator, try testOutputSize(allocator, "96x54", 96, @divTrunc(96 * 9, 16), iterations));
    try results.append(allocator, try testOutputSize(allocator, "128x72", 128, @divTrunc(128 * 9, 16), iterations));
    try results.append(allocator, try testOutputSize(allocator, "160x90", 160, @divTrunc(160 * 9, 16), iterations));
    try results.append(allocator, try testOutputSize(allocator, "192x108", 192, @divTrunc(192 * 9, 16), iterations));
    try results.append(allocator, try testOutputSize(allocator, "256x144", 256, @divTrunc(256 * 9, 16), iterations));

    // Vertical 9:16 aspect
    std.debug.print("\n--- Vertical 9:16 Aspect ---\n", .{});
    try results.append(allocator, try testOutputSize(allocator, "36x64", @divTrunc(64 * 9, 16), 64, iterations));
    try results.append(allocator, try testOutputSize(allocator, "54x96", @divTrunc(96 * 9, 16), 96, iterations));
    try results.append(allocator, try testOutputSize(allocator, "72x128", @divTrunc(128 * 9, 16), 128, iterations));
    try results.append(allocator, try testOutputSize(allocator, "90x160", @divTrunc(160 * 9, 16), 160, iterations));
    try results.append(allocator, try testOutputSize(allocator, "108x192", @divTrunc(192 * 9, 16), 192, iterations));
    try results.append(allocator, try testOutputSize(allocator, "144x256", @divTrunc(256 * 9, 16), 256, iterations));

    // Print comprehensive comparison table
    std.debug.print("\n=== Comprehensive Size Comparison ===\n", .{});
    std.debug.print(
        "{s:<12} | {s:>10} | {s:>11} | {s:>11} | {s:>9}\n",
        .{ "Size", "Pixels", "Time/iter", "Iter/sec", "MP/sec" },
    );
    std.debug.print("{s:-<12}-+-{s:->10}-+-{s:->11}-+-{s:->11}-+-{s:->9}\n", .{ "", "", "", "", "" });

    for (results.items) |result| {
        std.debug.print(
            "{s:<12} | {d:>10} | {d:>9.2}µs | {d:>11.0} | {d:>9.2}\n",
            .{
                result.name,
                result.width * result.height,
                result.timePerIter(),
                result.iterPerSec(),
                result.mpixelsPerSec(),
            },
        );
    }

    std.debug.print("\n=== Test Complete ===\n", .{});

    // Write JSON output if suffix provided
    if (write_json) {
        var measurements = std.ArrayList(types.MeasurementPoint){};
        defer measurements.deinit(allocator);

        for (results.items) |result| {
            try measurements.append(allocator, result.toMeasurementPoint());
        }

        const sys_info = try system_info.collect(allocator);
        defer allocator.free(sys_info.cpu_model);

        const test_result = types.TestResult{
            .test_name = "RenderEngine.render_stable",
            .timestamp = args.suffix.?,
            .system_info = sys_info,
            .results = measurements.items,
        };

        const filename = try std.fmt.allocPrint(
            allocator,
            "{s}/RenderEngine.render_stable_{s}.json",
            .{ args.output_dir, args.suffix.? },
        );
        defer allocator.free(filename);

        try json_writer.writeTestResult(test_result, filename);
        std.debug.print("\nJSON written to: {s}\n", .{filename});
    }
}
