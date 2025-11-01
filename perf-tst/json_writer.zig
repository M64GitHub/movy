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
    const epoch_seconds: u64 = @intCast(@divTrunc(timestamp_ms, 1000));

    // Use epoch seconds to calculate date/time (very simplified)
    const seconds_per_minute: u64 = 60;
    const seconds_per_hour: u64 = 3600;
    const seconds_per_day: u64 = 86400;

    const days_since_epoch = epoch_seconds / seconds_per_day;
    const seconds_today = epoch_seconds % seconds_per_day;

    // Approximate year/month/day (simplified - good enough for filenames)
    const days_per_year: u64 = 365;
    const year = 1970 + (days_since_epoch / days_per_year);
    const day_of_year = days_since_epoch % days_per_year;
    const month = 1 + (day_of_year / 30);
    const day = 1 + (day_of_year % 30);

    // Calculate time
    const hours = seconds_today / seconds_per_hour;
    const minutes = (seconds_today % seconds_per_hour) / seconds_per_minute;
    const seconds = seconds_today % seconds_per_minute;

    return try std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}-{d:0>2}-{d:0>2}",
        .{ year, month, day, hours, minutes, seconds },
    );
}

/// Generate date string for directory: YYYY-MM-DD
pub fn generateDateString(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp_ms = std.time.milliTimestamp();
    const epoch_seconds: u64 = @intCast(@divTrunc(timestamp_ms, 1000));

    const seconds_per_day: u64 = 86400;
    const days_since_epoch = epoch_seconds / seconds_per_day;

    const days_per_year: u64 = 365;
    const year = 1970 + (days_since_epoch / days_per_year);
    const day_of_year = days_since_epoch % days_per_year;
    const month = 1 + (day_of_year / 30);
    const day = 1 + (day_of_year % 30);

    return try std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day });
}
