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

const RenderMethod = enum {
    render,
    renderOriginalClean,
    renderNoBranchClean,
    renderNoBranchBitwise,
    renderNoConditionalMove,
    renderPredictablePatternClean,
    renderWithAlphaClean,
    renderWithAlphaToBgClean,

    fn name(self: RenderMethod) []const u8 {
        return switch (self) {
            .render => "render()",
            .renderOriginalClean => "renderOriginalClean()",
            .renderNoBranchClean => "renderNoBranchClean()",
            .renderNoBranchBitwise => "renderNoBranchBitwise()",
            .renderNoConditionalMove => "renderConditionalMove()",
            .renderPredictablePatternClean => "renderPredictablePatternClean()",
            .renderWithAlphaClean => "renderWithAlphaClean()",
            .renderWithAlphaToBgClean => "renderWithAlphaToBgClean()",
        };
    }

    fn call(
        self: RenderMethod,
        surfaces: []const *movy.core.RenderSurface,
        output: *movy.core.RenderSurface,
    ) void {
        switch (self) {
            .render => movy.render.RenderEngine.render(surfaces, output),
            .renderOriginalClean => renderOriginalClean(surfaces, output),
            .renderNoBranchClean => renderNoBranchClean(surfaces, output),
            .renderNoBranchBitwise => renderNoBranchBitwise(surfaces, output),
            .renderNoConditionalMove => renderConditionalMove(surfaces, output),
            .renderPredictablePatternClean => renderPredictablePatternClean(
                surfaces,
                output,
            ),
            .renderWithAlphaClean => renderWithAlphaClean(surfaces, output),
            .renderWithAlphaToBgClean => renderWithAlphaToBgClean(
                surfaces,
                output,
            ),
        }
    }
};

const TestResult = struct {
    method: RenderMethod,
    surface_count: usize,
    surface_size: []const u8, // e.g., "10x10"
    output_w: usize,
    output_h: usize,
    elapsed_ns: u64,
    iterations: usize,

    fn timePerIter(self: TestResult) f64 {
        return @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(self.iterations)) / 1000.0;
    }

    fn iterPerSec(self: TestResult) f64 {
        const elapsed_s = @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(std.time.ns_per_s));
        return @as(f64, @floatFromInt(self.iterations)) / elapsed_s;
    }

    fn mpixelsPerSec(self: TestResult) f64 {
        const elapsed_s = @as(f64, @floatFromInt(self.elapsed_ns)) /
            @as(f64, @floatFromInt(std.time.ns_per_s));
        const pixels_per_iter = self.output_w * self.output_h;
        const total_pixels = pixels_per_iter * self.iterations;
        return @as(f64, @floatFromInt(total_pixels)) / elapsed_s / 1_000_000.0;
    }

    fn toMeasurementPoint(
        self: TestResult,
        allocator: std.mem.Allocator,
    ) !types.MeasurementPoint {
        const name = try std.fmt.allocPrint(
            allocator,
            "{s}_{s}_{d}surf",
            .{ self.method.name(), self.surface_size, self.surface_count },
        );
        return types.MeasurementPoint{
            .name = name,
            .width = self.output_w,
            .height = self.output_h,
            .pixels = self.output_w * self.output_h,
            .iterations = self.iterations,
            .elapsed_ns = self.elapsed_ns,
            .time_per_iter_us = self.timePerIter(),
            .iter_per_sec = self.iterPerSec(),
            .megapixels_per_sec = self.mpixelsPerSec(),
        };
    }
};

fn testConfiguration(
    allocator: std.mem.Allocator,
    method: RenderMethod,
    surface_count: usize,
    surface_size_name: []const u8,
    asset_path: []const u8,
    output_w: usize,
    output_h: usize,
    iterations: usize,
) !TestResult {
    // Create output surface with alpha=128 (semi-transparent)
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

    // Set output alpha to 128
    output_surface.setAlpha(128);

    // Load surfaces with varied alpha values (64, 128, 192)
    var surfaces = std.ArrayList(*movy.core.RenderSurface){};
    defer surfaces.deinit(allocator);

    var sprites = std.ArrayList(*movy.Sprite){};
    defer {
        for (sprites.items) |sprite| {
            sprite.deinit(allocator);
        }
        sprites.deinit(allocator);
    }

    const alpha_values = [_]u8{ 64, 128, 192 };

    for (0..surface_count) |i| {
        const name_buf = try std.fmt.allocPrint(allocator, "surf_{d}", .{i});
        defer allocator.free(name_buf);

        // Create sprite and append to list
        var sprite =
            try movy.Sprite.initFromPng(allocator, asset_path, name_buf);
        try sprites.append(allocator, sprite);

        // Set alpha value on sprite (cycling through 64, 128, 192)
        const alpha_val = alpha_values[i % 3];
        try sprite.setAlphaCurrentFrameSurface(alpha_val);

        // Get surface from the sprite
        const surface = try sprite.getCurrentFrameSurface();

        // Position surfaces to overlap
        const offset = @as(i32, @intCast(i * 5)); // 5px offset per surface
        surface.x = 10 + offset;
        surface.y = 10 + offset;
        surface.z = @as(i32, @intCast(i)); // Higher index = rendered on top

        try surfaces.append(allocator, surface);
    }

    // Run timed test
    var timer = try common.PerfTimer.start();

    for (0..iterations) |_| {
        output_surface.clearTransparent();
        method.call(surfaces.items, output_surface);
    }

    const elapsed_ns = timer.elapsedNs();

    return TestResult{
        .method = method,
        .surface_count = surface_count,
        .surface_size = surface_size_name,
        .output_w = output_w,
        .output_h = output_h,
        .elapsed_ns = elapsed_ns,
        .iterations = iterations,
    };
}

fn runSizeTests(
    allocator: std.mem.Allocator,
    method: RenderMethod,
    surface_count: usize,
    iterations: usize,
    results: *std.ArrayList(TestResult),
) !void {
    const configs = [_]struct {
        name: []const u8,
        path: []const u8,
        output_size: usize,
    }{
        .{
            .name = "10x10",
            .path = "perf-tst/assets/10x10.png",
            .output_size = 64,
        },
        .{
            .name = "20x20",
            .path = "perf-tst/assets/20x20.png",
            .output_size = 80,
        },
        .{
            .name = "40x40",
            .path = "perf-tst/assets/40x40.png",
            .output_size = 100,
        },
        .{
            .name = "64x64",
            .path = "perf-tst/assets/movycat.png",
            .output_size = 128,
        },
        .{
            .name = "80x80",
            .path = "perf-tst/assets/80x80.png",
            .output_size = 160,
        },
        .{
            .name = "100x100",
            .path = "perf-tst/assets/100x100.png",
            .output_size = 192,
        },
    };

    for (configs) |config| {
        const result = try testConfiguration(
            allocator,
            method,
            surface_count,
            config.name,
            config.path,
            config.output_size,
            config.output_size,
            iterations,
        );
        try results.append(allocator, result);

        std.debug.print("  {s:<15} {d} surfaces: {d:>6.2}µs/iter, {d:>7.2} MP/s\n", .{
            config.name,
            surface_count,
            result.timePerIter(),
            result.mpixelsPerSec(),
        });
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse command-line arguments
    const args = try flagz.parse(TestArgs, allocator);
    defer flagz.deinit(args, allocator);

    const write_json = args.suffix != null;
    const iterations = args.iterations orelse 10_000;

    std.debug.print(
        "=== RenderEngine Branch Prediction Comparison ===\n",
        .{},
    );
    std.debug.print(
        "Testing: specialized render functions ()\n",
        .{},
    );
    std.debug.print(
        "Surface counts: 3, 5, 10 overlapping surfaces\n",
        .{},
    );
    std.debug.print(
        "Surface sizes: 10x10, 20x20, 40x40, 64x64, 80x80, 100x100\n",
        .{},
    );
    std.debug.print(
        "Alpha config: Input surfaces = 1 for branch elimination, Output surface = 128\n",
        .{},
    );
    std.debug.print("{d} iterations per test\n\n", .{iterations});

    if (write_json) {
        std.debug.print(
            "JSON output: {s}/{s}_RenderEngine.branch_cache.json\n\n",
            .{ args.output_dir, args.suffix.? },
        );
    }

    var all_results = std.ArrayList(TestResult){};
    defer all_results.deinit(allocator);

    const methods = [_]RenderMethod{
        .render,
        .renderOriginalClean,
        .renderNoBranchClean,
        .renderNoBranchBitwise,
        .renderNoConditionalMove,
        .renderPredictablePatternClean,
        .renderWithAlphaClean,
        .renderWithAlphaToBgClean,
    };
    const surface_counts = [_]usize{ 3, 5, 10 };

    // Run all combinations
    for (methods) |method| {
        std.debug.print("\n--- Testing {s} ---\n", .{method.name()});

        for (surface_counts) |count| {
            std.debug.print("  {d} Surfaces:\n", .{count});
            try runSizeTests(allocator, method, count, iterations, &all_results);
        }
    }

    // Print comparison table
    std.debug.print("\n=== Performance Comparison Summary ===\n", .{});
    std.debug.print(
        "{s:<25} | {s:>6} | {s:>10} | {s:>10} | {s:>9}\n",
        .{ "Config", "Surf", "Time/iter", "Iter/sec", "MP/sec" },
    );
    std.debug.print(
        "{s:-<25}-+-{s:->6}-+-{s:->10}-+-{s:->10}-+-{s:->9}\n",
        .{ "", "", "", "", "" },
    );

    for (all_results.items) |result| {
        const config_name = try std.fmt.allocPrint(
            allocator,
            "{s} {s}",
            .{ result.method.name(), result.surface_size },
        );
        defer allocator.free(config_name);

        std.debug.print(
            "{s:<25} | {d:>6} | {d:>8.2}µs | {d:>10.0} | {d:>9.2}\n",
            .{
                config_name,
                result.surface_count,
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
        defer {
            for (measurements.items) |m| {
                allocator.free(m.name);
            }
            measurements.deinit(allocator);
        }

        for (all_results.items) |result| {
            const mp = try result.toMeasurementPoint(allocator);
            try measurements.append(allocator, mp);
        }

        const sys_info = try system_info.collect(allocator);
        defer allocator.free(sys_info.cpu_model);

        const test_result = types.TestResult{
            .test_name = "RenderEngine.alpha_comparison",
            .timestamp = args.suffix.?,
            .system_info = sys_info,
            .results = measurements.items,
        };

        const filename = try std.fmt.allocPrint(
            allocator,
            "{s}/RenderEngine.alpha_comparison_{s}.json",
            .{ args.output_dir, args.suffix.? },
        );
        defer allocator.free(filename);

        try json_writer.writeTestResult(test_result, filename);
        std.debug.print("\nJSON written to: {s}\n", .{filename});
    }
}

// -- modified render functions for branch prediction and cache effects

/// Identical to render() but removes all bounds checking since test sprites
/// are guaranteed to be within canvas bounds. Isolates the occupancy branch
/// performance without bounds checking interference.
pub fn renderOriginalClean(
    surfaces_in: []const *movy.core.RenderSurface,
    out_surface: *movy.core.RenderSurface,
) void {
    // Z-sort surfaces (front-to-back, highest Z first)
    var indices: [2048]usize = undefined;
    movy.render.RenderEngine.zSort(surfaces_in, &indices);
    const surface_count = @min(surfaces_in.len, 2048);

    for (indices[0..surface_count]) |i| {
        const surface_in = surfaces_in[i];
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // Calculate clipping bounds once
        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;

                // Use pre-computed row offset
                const idx_out =
                    out_row_offset + @as(usize, @intCast(out_x));

                // Only write if destination is not already occupied
                if (out_surface.shadow_map[idx_out] != 1) {
                    out_surface.color_map[idx_out] =
                        surface_in.color_map[idx_in];
                    out_surface.shadow_map[idx_out] = 1;
                    out_surface.char_map[idx_out] =
                        surface_in.char_map[idx_in];
                }
            }
        }
    }
}

/// Eliminates the occupancy branch entirely by always computing and writing
/// pixels using arithmetic selection (multiply by 0 or 1) instead of conditional
/// execution. Tests whether branch misprediction is the performance bottleneck.
pub fn renderNoBranchClean(
    surfaces_in: []const *movy.core.RenderSurface,
    out_surface: *movy.core.RenderSurface,
) void {
    // Z-sort surfaces (front-to-back, highest Z first)
    var indices: [2048]usize = undefined;
    movy.render.RenderEngine.zSort(surfaces_in, &indices);
    const surface_count = @min(surfaces_in.len, 2048);

    for (indices[0..surface_count]) |i| {
        const surface_in = surfaces_in[i];
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // Calculate clipping bounds once
        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;

                const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                // TRULY BRANCHLESS
                const occupied = out_surface.shadow_map[idx_out]; // 0 or 1
                const empty = 1 - occupied; // 1 or 0

                // Update colors: keep old if occupied, write new if empty
                const old_color = out_surface.color_map[idx_out];
                const new_color = surface_in.color_map[idx_in];

                out_surface.color_map[idx_out] = .{
                    .r = old_color.r * occupied + new_color.r * empty,
                    .g = old_color.g * occupied + new_color.g * empty,
                    .b = old_color.b * occupied + new_color.b * empty,
                };

                // Same for chars
                const old_char = out_surface.char_map[idx_out];
                const new_char = surface_in.char_map[idx_in];
                out_surface.char_map[idx_out] = old_char * occupied + new_char * empty;

                // Mark as occupied if we wrote
                out_surface.shadow_map[idx_out] |= empty;
            }
        }
    }
}

/// Branchless variant using bitwise operations for selection instead of arithmetic.
/// Creates masks and uses AND/OR operations to select between old and new values
/// without branches. Tests if bitwise selection performs better than arithmetic.
pub fn renderNoBranchBitwise(
    surfaces_in: []const *movy.core.RenderSurface,
    out_surface: *movy.core.RenderSurface,
) void {
    // Z-sort surfaces (front-to-back, highest Z first)
    var indices: [2048]usize = undefined;
    movy.render.RenderEngine.zSort(surfaces_in, &indices);
    const surface_count = @min(surfaces_in.len, 2048);

    for (indices[0..surface_count]) |i| {
        const surface_in = surfaces_in[i];
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // Calculate clipping bounds once
        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;

                const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                const occupied = out_surface.shadow_map[idx_out];

                // Create a mask: all 1s if empty, all 0s if occupied
                const mask = ~(occupied *% ~@as(u8, 0)); // 0xFF if empty, 0x00 if occupied

                // Bitwise selection - same cost as the branch version's struct copy!
                const old_color = out_surface.color_map[idx_out];
                const new_color = surface_in.color_map[idx_in];

                out_surface.color_map[idx_out] = .{
                    .r = (old_color.r & ~mask) | (new_color.r & mask),
                    .g = (old_color.g & ~mask) | (new_color.g & mask),
                    .b = (old_color.b & ~mask) | (new_color.b & mask),
                };

                const old_char = out_surface.char_map[idx_out];
                const new_char = surface_in.char_map[idx_in];
                out_surface.char_map[idx_out] = (old_char & ~mask) |
                    (new_char & mask);

                out_surface.shadow_map[idx_out] |= (mask & 1);
            }
        }
    }
}

/// Uses conditional expressions that may compile to CMOV (conditional move)
/// instructions on modern CPUs. Technically branchless at the assembly level
/// but preserves the if/else structure in source code.
pub fn renderConditionalMove(
    surfaces_in: []const *movy.core.RenderSurface,
    out_surface: *movy.core.RenderSurface,
) void {
    // Z-sort surfaces (front-to-back, highest Z first)
    var indices: [2048]usize = undefined;
    movy.render.RenderEngine.zSort(surfaces_in, &indices);
    const surface_count = @min(surfaces_in.len, 2048);

    for (indices[0..surface_count]) |i| {
        const surface_in = surfaces_in[i];
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // Calculate clipping bounds once
        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;

                const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                // This might compile to a conditional move (CMOV) instruction
                // which is branchless at the CPU level
                const new_color = if (out_surface.shadow_map[idx_out] == 0)
                    surface_in.color_map[idx_in]
                else
                    out_surface.color_map[idx_out];

                out_surface.color_map[idx_out] = new_color;

                // Same for char
                const new_char = if (out_surface.shadow_map[idx_out] == 0)
                    surface_in.char_map[idx_in]
                else
                    out_surface.char_map[idx_out];

                out_surface.char_map[idx_out] = new_char;

                // Update shadow
                out_surface.shadow_map[idx_out] |=
                    (1 - out_surface.shadow_map[idx_out]);
            }
        }
    }
}

/// Replaces the occupancy check with a perfectly predictable checkerboard
/// pattern ((x + y) % 2). Used to measure the performance impact of perfect
/// branch prediction versus the irregular occupancy pattern.
pub fn renderPredictablePatternClean(
    surfaces_in: []const *movy.core.RenderSurface,
    out_surface: *movy.core.RenderSurface,
) void {
    // Z-sort surfaces (front-to-back, highest Z first)
    var indices: [2048]usize = undefined;
    movy.render.RenderEngine.zSort(surfaces_in, &indices);
    const surface_count = @min(surfaces_in.len, 2048);

    for (indices[0..surface_count]) |i| {
        const surface_in = surfaces_in[i];
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // Calculate clipping bounds once
        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;

                const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                // PREDICTABLE PATTERN: checkerboard based on coordinates
                if ((x + y) % 2 == 0) { // This is 100% predictable
                    out_surface.color_map[idx_out] = surface_in.color_map[idx_in];
                    out_surface.shadow_map[idx_out] = 1;
                    out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
                }
            }
        }
    }
}

/// Alpha blending variant without bounds checking. Always blends colors
/// instead of checking occupancy, but removes bounds checks to isolate
/// the blending arithmetic cost from branch interference effects.
pub fn renderWithAlphaClean(
    surfaces_in: []const *movy.core.RenderSurface,
    out_surface: *movy.core.RenderSurface,
) void {
    // Z-sort surfaces (front-to-back, highest Z first)
    var indices: [2048]usize = undefined;
    movy.render.RenderEngine.zSort(surfaces_in, &indices);
    const surface_count = @min(surfaces_in.len, 2048);

    for (indices[0..surface_count]) |i| {
        const surface_in = surfaces_in[i];
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // Calculate clipping bounds once
        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Get source alpha - early exit if fully transparent
                const alpha_fg = surface_in.shadow_map[idx_in];

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;

                // Use pre-computed row offset
                const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                // Get destination alpha and colors
                const alpha_bg = out_surface.shadow_map[idx_out];
                const fg_color = surface_in.color_map[idx_in];
                const bg_color = out_surface.color_map[idx_out];

                // Perform alpha blending
                out_surface.color_map[idx_out] =
                    movy.render.RenderEngine
                        .blendPixelGeneral(
                        fg_color,
                        alpha_fg,
                        bg_color,
                        alpha_bg,
                    );

                // Mark as rendered (opaque marker, not actual composited alpha)
                out_surface.shadow_map[idx_out] = 255;
                out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
            }
        }
    }
}

/// Optimized alpha blending for opaque backgrounds without bounds checking.
/// Uses simplified blend formula when background alpha is known to be 1.0,
/// with bounds checks removed to measure pure arithmetic performance.
pub fn renderWithAlphaToBgClean(
    surfaces_in: []const *movy.core.RenderSurface,
    out_surface: *movy.core.RenderSurface,
) void {
    // Z-sort surfaces (front-to-back, highest Z first)
    var indices: [2048]usize = undefined;
    movy.render.RenderEngine.zSort(surfaces_in, &indices);
    const surface_count = @min(surfaces_in.len, 2048);

    for (indices[0..surface_count]) |i| {
        const surface_in = surfaces_in[i];
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // Calculate clipping bounds once
        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Get source alpha - early exit if fully transparent
                const alpha_fg = surface_in.shadow_map[idx_in];

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;

                // Use pre-computed row offset
                const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                // Get colors (background assumed opaque)
                const fg_color = surface_in.color_map[idx_in];
                const bg_color = out_surface.color_map[idx_out];

                // Perform optimized alpha blending (assumes bg is opaque)
                out_surface.color_map[idx_out] =
                    movy.render.RenderEngine
                        .blendPixelToBg(
                        fg_color,
                        alpha_fg,
                        bg_color,
                    );

                // Output is always opaque
                out_surface.shadow_map[idx_out] = 255;
                out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
            }
        }
    }
}
