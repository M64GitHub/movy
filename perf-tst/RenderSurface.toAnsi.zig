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

const SpriteTestResult = struct {
    name: []const u8,
    width: usize,
    height: usize,
    pixels: usize,
    elapsed_ns: u64,
    iterations: usize,

    fn timePerIter(self: SpriteTestResult) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(self.iterations)) / 1000.0;
    }

    fn iterPerSec(self: SpriteTestResult) f64 {
        const elapsed_s = @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(std.time.ns_per_s));
        return @as(f64, @floatFromInt(self.iterations)) / elapsed_s;
    }

    fn mpixelsPerSec(self: SpriteTestResult) f64 {
        const elapsed_s = @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(std.time.ns_per_s));
        const total_pixels = self.pixels * self.iterations;
        return @as(f64, @floatFromInt(total_pixels)) / elapsed_s / 1_000_000.0;
    }

    fn toMeasurementPoint(self: SpriteTestResult) types.MeasurementPoint {
        return types.MeasurementPoint{
            .name = self.name,
            .width = self.width,
            .height = self.height,
            .pixels = self.pixels,
            .iterations = self.iterations,
            .elapsed_ns = self.elapsed_ns,
            .time_per_iter_us = self.timePerIter(),
            .iter_per_sec = self.iterPerSec(),
            .megapixels_per_sec = self.mpixelsPerSec(),
        };
    }
};

fn testSprite(
    allocator: std.mem.Allocator,
    sprite_path: []const u8,
    sprite_name: []const u8,
    iterations: usize,
) !SpriteTestResult {
    std.debug.print("\n--- Testing {s} ---\n", .{sprite_name});

    var sprite = try movy.Sprite.initFromPng(
        allocator,
        sprite_path,
        sprite_name,
    );
    defer sprite.deinit(allocator);

    var surface = try sprite.getCurrentFrameSurface();

    std.debug.print(
        "Dimensions: {d}x{d} ({d} pixels)\n",
        .{ surface.w, surface.h, surface.w * surface.h },
    );

    var timer = try common.PerfTimer.start();

    for (0..iterations) |i| {
        _ = try surface.toAnsi();

        if ((i + 1) % 10_000 == 0) {
            common.printProgress(i + 1, iterations);
        }
    }

    const elapsed_ns = timer.elapsedNs();

    return SpriteTestResult{
        .name = sprite_name,
        .width = surface.w,
        .height = surface.h,
        .pixels = surface.w * surface.h,
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

    std.debug.print("=== RenderSurface.toAnsi() Performance Test ===\n", .{});
    std.debug.print("Testing ANSI conversion across 7 standardized sprite sizes\n", .{});
    std.debug.print("{d} iterations per sprite\n", .{iterations});
    if (write_json) {
        std.debug.print("JSON output: {s}/{s}_RenderSurface.toAnsi.json\n", .{ args.output_dir, args.suffix.? });
    }

    // Test all 7 sprite sizes
    const result_10 = try testSprite(
        allocator,
        "perf-tst/assets/10x10.png",
        "10x10",
        iterations,
    );

    const result_20 = try testSprite(
        allocator,
        "perf-tst/assets/20x20.png",
        "20x20",
        iterations,
    );

    const result_40 = try testSprite(
        allocator,
        "perf-tst/assets/40x40.png",
        "40x40",
        iterations,
    );

    const result_64 = try testSprite(
        allocator,
        "perf-tst/assets/movycat.png",
        "64x64",
        iterations,
    );

    const result_80 = try testSprite(
        allocator,
        "perf-tst/assets/80x80.png",
        "80x80",
        iterations,
    );

    const result_100 = try testSprite(
        allocator,
        "perf-tst/assets/100x100.png",
        "100x100",
        iterations,
    );

    const result_200 = try testSprite(
        allocator,
        "perf-tst/assets/200x200.png",
        "200x200",
        iterations,
    );

    // Print comparison table
    std.debug.print("\n=== Sprite Size vs Performance Comparison ===\n", .{});
    std.debug.print(
        "{s:<10} | {s:>10} | {s:>8} | {s:>11} | {s:>11} | {s:>9}\n",
        .{ "Size", "Dimensions", "Pixels", "Time/iter", "Iter/sec", "MP/sec" },
    );
    std.debug.print("{s:-<10}-+-{s:->10}-+-{s:->8}-+-{s:->11}-+-{s:->11}-+-{s:->9}\n", .{ "", "", "", "", "", "" });

    const results = [_]SpriteTestResult{
        result_10,
        result_20,
        result_40,
        result_64,
        result_80,
        result_100,
        result_200,
    };

    for (results) |result| {
        std.debug.print(
            "{s:<10} | {d:>4}x{d:<5} | {d:>8} | {d:>9.2}µs | {d:>11.0} | {d:>9.2}\n",
            .{
                result.name,
                result.width,
                result.height,
                result.pixels,
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

        for (results) |result| {
            try measurements.append(allocator, result.toMeasurementPoint());
        }

        const sys_info = try system_info.collect(allocator);
        defer allocator.free(sys_info.cpu_model);

        const test_result = types.TestResult{
            .test_name = "RenderSurface.toAnsi",
            .timestamp = args.suffix.?,
            .system_info = sys_info,
            .results = measurements.items,
        };

        const filename = try std.fmt.allocPrint(
            allocator,
            "{s}/RenderSurface.toAnsi_{s}.json",
            .{ args.output_dir, args.suffix.? },
        );
        defer allocator.free(filename);

        try json_writer.writeTestResult(test_result, filename);
        std.debug.print("\nJSON written to: {s}\n", .{filename});
    }
}
