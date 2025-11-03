//! Easing functions for smooth animation transitions.
//!
//! Provides quadratic easing curves (ease-in, ease-out, ease-in-out)
//! and utility functions for applying easing to values over time.

/// Ease-in function (slow start, fast end) for a value over time
pub fn easeIn(t: f32) f32 {
    return t * t; // Quadratic ease-in
}

/// Ease-out function (fast start, slow end) for a value over time
pub fn easeOut(t: f32) f32 {
    return t * (2.0 - t); // Quadratic ease-out
}

/// Ease-in-out function (slow start, fast middle, slow end) for
/// a value over time
pub fn easeInOut(t: f32) f32 {
    if (t < 0.5) return 2.0 * t * t; // Quadratic ease-in
    return -2.0 * t * t + 4.0 * t - 1.0; // Quadratic ease-out
}

/// Applies easing to a value between start and end over duration
pub fn applyEaseFn(
    easing: *const fn (t: f32) f32,
    start: f32,
    end: f32,
    frame: usize,
    duration: usize,
) f32 {
    const t = if (frame >= duration) 1.0 else @as(
        f32,
        @floatFromInt(frame),
    ) / @as(f32, @floatFromInt(duration));
    const eased_t = easing(t);
    return start + (end - start) * eased_t;
}
