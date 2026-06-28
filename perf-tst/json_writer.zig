const std = @import("std");
const types = @import("types");

/// Write test results to JSON file with proper formatting (libc for 0.16 compat)
pub fn writeTestResult(
    result: types.TestResult,
    filepath: []const u8,
) !void {
    // Best effort dir creation via libc
    if (std.fs.path.dirname(filepath)) |dir_path| {
        makePathLibc(dir_path);
    }

    const cpath = std.mem.concat(std.heap.page_allocator, u8, &.{ filepath, "\x00" }) catch return error.OutOfMemory;
    defer std.heap.page_allocator.free(cpath);

    const f = std.c.fopen(cpath.ptr, "wb") orelse return error.Unexpected;
    defer _ = std.c.fclose(f);

    // Serialize directly (simplified, no huge buffer needed for perf results)
    var buf: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try std.json.Stringify.value(result, .{ .whitespace = .indent_2 }, fbs.writer());

    const data = fbs.getWritten();
    _ = std.c.fwrite(data.ptr, 1, data.len, f);
}

/// Minimal makePath using libc (duplicated for module independence)
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
        if (i > 0 and buf[i-1] != '/') {
            buf[i] = '/';
            i += 1;
        }
        @memcpy(buf[i..][0..segment.len], segment);
        i += segment.len;
        buf[i] = 0;
        _ = std.c.mkdir(@ptrCast(&buf[0]), 0o755);
    }
}

/// Generate ISO 8601 timestamp for filenames (no colons)
/// Format: YYYY-MM-DDTHH-MM-SS
pub fn generateTimestamp(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp_ms: u64 = blk: {
        var ts: std.c.timespec = undefined;
        _ = std.c.clock_gettime(std.posix.CLOCK.MONOTONIC, &ts);
        break :blk @as(u64, @intCast(@as(i128, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000)));
    };
    const epoch_seconds: i64 = @intCast(@divTrunc(timestamp_ms, 1000));

    // Use Zig's proper epoch time conversion
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(epoch_seconds) };
    const day_seconds = epoch.getDaySeconds();
    const year_day = epoch.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    return try std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}-{d:0>2}-{d:0>2}",
        .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_seconds.getHoursIntoDay(),
            day_seconds.getMinutesIntoHour(),
            day_seconds.getSecondsIntoMinute(),
        },
    );
}

/// Generate date string for directory: YYYY-MM-DD
pub fn generateDateString(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp_ms: u64 = blk: {
        var ts: std.c.timespec = undefined;
        _ = std.c.clock_gettime(std.posix.CLOCK.MONOTONIC, &ts);
        break :blk @as(u64, @intCast(@as(i128, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000)));
    };
    const epoch_seconds: i64 = @intCast(@divTrunc(timestamp_ms, 1000));

    // Use Zig's proper epoch time conversion
    const epoch = std.time.epoch.EpochSeconds{ .secs = @intCast(epoch_seconds) };
    const year_day = epoch.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    return try std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2}",
        .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
        },
    );
}
