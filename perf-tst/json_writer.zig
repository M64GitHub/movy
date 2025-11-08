const std = @import("std");
const types = @import("types");

/// Write test results to JSON file with proper formatting
pub fn writeTestResult(
    result: types.TestResult,
    filepath: []const u8,
) !void {
    // Create directory if it doesn't exist
    if (std.fs.path.dirname(filepath)) |dir_path| {
        std.fs.cwd().makePath(dir_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    // Open file for writing
    const file = try std.fs.cwd().createFile(filepath, .{});
    defer file.close();

    // Serialize to JSON with buffered writing
    var buffer: [65536]u8 = undefined;
    var file_writer = file.writer(&buffer);
    const writer = &file_writer.interface;

    try std.json.Stringify.value(result, .{
        .whitespace = .indent_2,
    }, writer);

    // Flush the buffer to ensure all data is written
    try writer.flush();
}

/// Generate ISO 8601 timestamp for filenames (no colons)
/// Format: YYYY-MM-DDTHH-MM-SS
pub fn generateTimestamp(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp_ms = std.time.milliTimestamp();
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
    const timestamp_ms = std.time.milliTimestamp();
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
