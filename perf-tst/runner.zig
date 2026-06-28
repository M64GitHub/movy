const std = @import("std");
const flagz = @import("flagz");
const json_writer = @import("json_writer");
// const html_generator = @import("html_generator"); // stubbed for 0.16 port

/// Minimal makePath using libc, for Zig 0.16 tools without Io context.
fn makePathLibc(path: []const u8) void {
    if (path.len == 0) return;
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    var i: usize = 0;
    if (path[0] == '/') {
        buf[0] = '/';
        i = 1;
    }
    var it = std.mem.tokenizeScalar(u8, path, '/');
    while (it.next()) |segment| {
        if (i > 0 and buf[i - 1] != '/') {
            buf[i] = '/';
            i += 1;
        }
        @memcpy(buf[i..][0..segment.len], segment);
        i += segment.len;
        buf[i] = 0;
        _ = std.c.mkdir(@ptrCast(&buf[0]), 0o755);
    }
}

/// Spawn child (inherit stdio), wait, return exit status byte. Uses libc for 0.16 compat.
fn spawnAndWaitLibc(argv: []const []const u8, allocator: std.mem.Allocator) !u8 {
    const c_argv = try allocator.alloc(?[*:0]const u8, argv.len + 1);
    defer allocator.free(c_argv);

    var owned = std.array_list.Managed([:0]const u8).init(allocator);
    defer {
        for (owned.items) |a| allocator.free(a);
        owned.deinit();
    }

    for (argv, 0..) |a, idx| {
        const z = try allocator.dupeZ(u8, a);
        try owned.append(z);
        c_argv[idx] = z.ptr;
    }
    c_argv[argv.len] = null;

    const pid = std.c.fork();
    if (pid == 0) {
        // Use execve (full path or $PATH name in argv[0]) with current env
        _ = std.c.execve(c_argv[0].?, @ptrCast(c_argv.ptr), std.c.environ);
        std.c._exit(127);
    }
    if (pid < 0) return error.ForkFailed;

    var status: c_int = 0;
    _ = std.c.waitpid(@intCast(pid), &status, 0);

    const s: u32 = @as(u32, @intCast(status));
    if (std.c.W.IFEXITED(s)) {
        return @intCast(std.c.W.EXITSTATUS(s));
    }
    return 1;
}

const RunnerArgs = struct {
    tests: ?[]const u8 = null, // Comma-separated test names
    output_dir: ?[]const u8 = null,
    suffix: ?[]const u8 = null, // Manual timestamp override
    iterations: ?usize = null, // Pass to tests
    help: bool = false, // Show usage information
};

const TestInfo = struct {
    name: []const u8,
    executable: []const u8,
};

fn printUsage() void {
    const usage =
        \\Performance Test Suite Runner
        \\
        \\USAGE:
        \\  perf-runner [OPTIONS]
        \\
        \\OPTIONS:
        \\  -tests <names>       Comma-separated test names to run (default: all)
        \\                       Available: alpha_comparison, render_stable, toAnsi, render_stable_with_toAnsi
        \\  -output_dir <path>   Base output directory (default: perf-results)
        \\  -suffix <timestamp>  Manual timestamp override (default: auto-generated)
        \\  -iterations <count>  Override iteration count for all tests (default: 100000)
        \\  -help                Show this help message
        \\
        \\EXAMPLES:
        \\  perf-runner
        \\  perf-runner -tests "render_stable,toAnsi"
        \\  perf-runner -iterations 50000
        \\  perf-runner -output_dir my-results -iterations 10000
        \\
        \\OUTPUT:
        \\  Results are saved to: {output_dir}/{timestamp}/{test_name}_{timestamp}.json
        \\  Each run creates a new directory named with the full timestamp.
        \\
    ;
    std.debug.print("{s}\n", .{usage});
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const args = try flagz.parse(RunnerArgs, allocator);
    defer flagz.deinit(args, allocator);

    // Show help if requested
    if (args.help) {
        printUsage();
        std.process.exit(0);
    }

    // Generate timestamp (will be used as directory name)
    const timestamp =
        if (args.suffix) |s|
            try allocator.dupe(u8, s)
        else
            try json_writer.generateTimestamp(allocator);

    defer allocator.free(timestamp);

    // Use default output directory if not specified
    const base_output_dir = args.output_dir orelse "perf-results";

    // Create output directory path using full timestamp
    const output_dir = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ base_output_dir, timestamp },
    );
    defer allocator.free(output_dir);

    // Create output directory using libc (Zig 0.16 port, no Io needed)
    makePathLibc(output_dir);

    std.debug.print("=== Performance Test Suite Runner ===\n", .{});
    std.debug.print("Timestamp: {s}\n", .{timestamp});
    std.debug.print("Output directory: {s}\n", .{output_dir});
    if (args.iterations) |iter| {
        std.debug.print("Iterations override: {d}\n", .{iter});
    }
    std.debug.print("\n", .{});

    // Define all available tests
    const all_tests = [_]TestInfo{
        .{
            .name = "RenderEngine.alpha_comparison",
            .executable = "perf-RenderEngine.alpha_comparison",
        },
        .{
            .name = "RenderEngine.branch_cache",
            .executable = "perf-RenderEngine.branch_cache",
        },
        .{
            .name = "RenderSurface.toAnsi",
            .executable = "perf-RenderSurface.toAnsi",
        },
        .{
            .name = "RenderEngine.render_stable",
            .executable = "perf-RenderEngine.render_stable",
        },
        .{
            .name = "RenderEngine.render_stable_with_toAnsi",
            .executable = "perf-RenderEngine.render_stable_with_toAnsi",
        },
    };

    // Determine which tests to run
    var tests_to_run: std.ArrayList(TestInfo) = .empty;
    defer tests_to_run.deinit(allocator);

    if (args.tests) |test_filter| {
        // Parse comma-separated test names
        var iter = std.mem.splitScalar(u8, test_filter, ',');
        while (iter.next()) |test_name| {
            const trimmed = std.mem.trim(u8, test_name, " \t");
            var found = false;
            for (all_tests) |test_info| {
                if (std.mem.indexOf(u8, test_info.name, trimmed) != null) {
                    try tests_to_run.append(allocator, test_info);
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print(
                    "Warning: Unknown test '{s}', skipping\n",
                    .{trimmed},
                );
            }
        }
    } else {
        // Run all tests
        for (all_tests) |test_info| {
            try tests_to_run.append(allocator, test_info);
        }
    }

    if (tests_to_run.items.len == 0) {
        std.debug.print("Error: No tests to run\n", .{});
        std.process.exit(1);
    }

    std.debug.print("Running {d} test(s):\n", .{tests_to_run.items.len});
    for (tests_to_run.items) |test_info| {
        std.debug.print("  - {s}\n", .{test_info.name});
    }
    std.debug.print("\n", .{});

    // Track test results
    var succeeded: usize = 0;
    var failed: usize = 0;
    var failed_tests: std.ArrayList([]const u8) = .empty;
    defer failed_tests.deinit(allocator);

    // Run each test
    for (tests_to_run.items) |test_info| {
        std.debug.print("--- Running: {s} ---\n", .{test_info.name});

        const exe_path = try std.fmt.allocPrint(
            allocator,
            "zig-out/bin/{s}",
            .{test_info.executable},
        );
        defer allocator.free(exe_path);

        // Build argument list
        var argv: std.ArrayList([]const u8) = .empty;
        defer {
            // Free any allocated strings in argv
            for (argv.items) |arg| {
                // Only free if it's one we allocated (not timestamp or output_dir)
                if (arg.ptr != timestamp.ptr and arg.ptr != output_dir.ptr and arg.ptr != exe_path.ptr) {
                    // Check if it's a constant string literal
                    if (!std.mem.eql(u8, arg, "-suffix") and
                        !std.mem.eql(u8, arg, "-output_dir") and
                        !std.mem.eql(u8, arg, "-iterations"))
                    {
                        allocator.free(arg);
                    }
                }
            }
            argv.deinit(allocator);
        }

        try argv.append(allocator, exe_path);
        try argv.append(allocator, "-suffix");
        try argv.append(allocator, timestamp);
        try argv.append(allocator, "-output_dir");
        try argv.append(allocator, output_dir);

        if (args.iterations) |iter| {
            try argv.append(allocator, "-iterations");
            const iter_str = try std.fmt.allocPrint(allocator, "{d}", .{iter});
            try argv.append(allocator, iter_str);
        }

        // Spawn using libc fork/execvp + waitpid (Zig 0.16 port, no Io Child)
        const exit_code = spawnAndWaitLibc(argv.items, allocator) catch |err| {
            std.debug.print("\nError spawning test: {}\n", .{err});
            failed += 1;
            try failed_tests.append(allocator, try allocator.dupe(u8, test_info.name));
            continue;
        };

        if (exit_code == 0) {
            succeeded += 1;
            std.debug.print(
                "\n✓ {s} completed successfully\n\n",
                .{test_info.name},
            );
        } else {
            failed += 1;
            try failed_tests.append(
                allocator,
                try allocator.dupe(u8, test_info.name),
            );
            std.debug.print(
                "\n✗ {s} failed with exit code {d}\n\n",
                .{ test_info.name, exit_code },
            );
        }
    }

    // Print summary
    std.debug.print("=== Test Suite Summary ===\n", .{});
    std.debug.print(
        "Total: {d} | Succeeded: {d} | Failed: {d}\n",
        .{ tests_to_run.items.len, succeeded, failed },
    );

    if (failed > 0) {
        std.debug.print("\nFailed tests:\n", .{});
        for (failed_tests.items) |test_name| {
            std.debug.print("  - {s}\n", .{test_name});
            allocator.free(test_name);
        }
        std.debug.print("\n", .{});
        std.process.exit(1);
    }

    std.debug.print("\nAll tests passed!\n", .{});
    std.debug.print("Results saved to: {s}/\n", .{output_dir});

    // Generate HTML visualization
    std.debug.print("\n", .{});
    // html_generator.generateHtmlReport(...) skipped (0.16 port)
}
