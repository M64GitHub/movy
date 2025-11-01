const std = @import("std");

/// Wrapper around std.time.Timer for consistent performance measurement
pub const PerfTimer = struct {
    timer: std.time.Timer,
    start_ns: u64,

    pub fn start() !PerfTimer {
        var timer = try std.time.Timer.start();
        return PerfTimer{
            .timer = timer,
            .start_ns = timer.read(),
        };
    }

    pub fn read(self: *PerfTimer) u64 {
        return self.timer.read();
    }

    pub fn elapsedNs(self: *PerfTimer) u64 {
        return self.timer.read() - self.start_ns;
    }
};

/// Print progress update during test execution
pub fn printProgress(current: usize, total: usize) void {
    const percent = (current * 100) / total;
    std.debug.print(
        "  Progress: {d}/{d} ({d}%)\n",
        .{ current, total, percent },
    );
}

/// Format and print timing results
pub fn formatResults(
    test_name: []const u8,
    iterations: usize,
    elapsed_ns: u64,
) void {
    const elapsed_ms = elapsed_ns / std.time.ns_per_ms;
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(
        f64,
        @floatFromInt(std.time.ns_per_s),
    );

    std.debug.print("\n=== {s} Results ===\n", .{test_name});
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
}

/// Format and print pixel throughput metrics
pub fn formatPixelThroughput(
    pixels_per_iteration: usize,
    iterations: usize,
    elapsed_s: f64,
) void {
    const total_pixels = pixels_per_iteration * iterations;
    const mpixels_per_sec = @as(f64, @floatFromInt(total_pixels)) /
        elapsed_s / 1_000_000.0;

    std.debug.print(
        "\nPixels processed: {d} ({d:.1}M)\n",
        .{ total_pixels, @as(f64, @floatFromInt(total_pixels)) / 1_000_000.0 },
    );
    std.debug.print("Megapixels/sec: {d:.2}\n", .{mpixels_per_sec});
}
