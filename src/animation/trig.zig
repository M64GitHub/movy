const std = @import("std");

/// Computes a sine movement value for a given frame, duration, and amplitude
pub fn sine(frame: usize, duration: usize, amplitude: i32) i32 {
    const dur = if (duration == 0) 1 else duration; // Prevent division by 0
    const t = @as(f32, @floatFromInt(frame % dur)) / @as(f32, @floatFromInt(dur));
    const angle = t * 2.0 * std.math.pi; // Map to 0 to 2π
    const value = std.math.sin(angle) * @as(f32, @floatFromInt(amplitude)) / 2.0;
    return @as(i32, @intFromFloat(@round(value))); // Round using @round
}

/// Computes a cosine movement value for a given frame, duration, and amplitude
pub fn cosine(frame: usize, duration: usize, amplitude: i32) i32 {
    const dur = if (duration == 0) 1 else duration; // Prevent division by 0
    const t = @as(f32, @floatFromInt(frame % dur)) / @as(f32, @floatFromInt(dur));
    const angle = t * 2.0 * std.math.pi; // Map to 0 to 2π
    const value = std.math.cos(angle) * @as(f32, @floatFromInt(amplitude)) / 2.0;
    return @as(i32, @intFromFloat(@round(value))); // Round using @round
}
