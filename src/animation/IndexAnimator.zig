/// A generic index-based animator that cycles through values between `start`
/// and `end` based on a looping mode. Commonly used for controlling animation
/// frame indices.
pub const IndexAnimator = struct {
    /// The start index of the animation range (inclusive).
    start: usize,
    /// The end index of the animation range (inclusive).
    end: usize,
    /// Defines how the index should advance through the range.
    mode: LoopMode,
    /// The current index value.
    current: usize,
    /// Direction of animation. Used only in `loopBounce` mode.
    /// `1` means forward, `-1` means backward.
    direction: i8,
    /// True if the animation has reached its end in `once` mode.
    once_finished: bool = false,

    /// Specifies the behavior of the animator once it reaches the end of
    /// its range.
    pub const LoopMode = enum {
        /// Advances from `start` to `end` once, then stops.
        once,
        /// Loops forward from `start` to `end`, then wraps back to `start`.
        loopForward,
        /// Loops backward from `end` to `start`, then wraps back to `end`.
        loopBackwards,
        /// Bounces between `start` and `end` back and forth.
        loopBounce,
    };

    /// Initializes a new IndexAnimator with a specified range and loop mode.
    ///
    /// The current index is initialized to `start`, and the bounce direction
    /// is set to forward.
    ///
    /// Parameters:
    /// - `start`: the starting index of the animation.
    /// - `end`: the final index of the animation.
    /// - `mode`: the looping behavior (see `LoopMode`).
    ///
    /// Returns: an initialized `IndexAnimator` struct.
    pub fn init(
        start: usize,
        end: usize,
        mode: LoopMode,
    ) IndexAnimator {
        return .{
            .start = start,
            .end = end,
            .mode = mode,
            .current = start,
            .direction = 1,
            .once_finished = false,
        };
    }

    /// Advances the animator by one step based on its current mode.
    ///
    /// In `once` mode, stops at the `end` index and sets `once_finished`
    /// to true.
    /// In `loopForward` and `loopBackwards`, wraps at the bounds.
    /// In `loopBounce`, reverses direction at each bound.
    ///
    /// Returns: the updated current index.
    pub fn step(self: *IndexAnimator) usize {
        const forward = self.end >= self.start;

        switch (self.mode) {
            .once => {
                if (self.current == self.end) {
                    self.once_finished = true;
                    return self.current;
                }

                self.current = if (forward)
                    @min(self.current + 1, self.end)
                else
                    @max(self.current - 1, self.end);

                // Check if we just reached the end
                if (self.current == self.end) {
                    self.once_finished = true;
                }
            },
            .loopForward => {
                if (forward) {
                    if (self.current >= self.end) self.current =
                        self.start else self.current += 1;
                } else {
                    if (self.current <= self.end) self.current =
                        self.start else self.current -= 1;
                }
            },
            .loopBackwards => {
                if (forward) {
                    if (self.current <= self.start) self.current =
                        self.end else self.current -= 1;
                } else {
                    if (self.current >= self.start) self.current =
                        self.end else self.current += 1;
                }
            },
            .loopBounce => {
                // For normal range (start < end): direction +1 means increment,
                //                                           -1 means decrement
                // For reverse range (start > end): direction +1 means decrement,
                //                                            -1 means increment
                if (forward) {
                    if (self.direction > 0) {
                        self.current += 1;
                    } else {
                        self.current -= 1;
                    }
                } else {
                    // Reverse range: flip direction meaning
                    if (self.direction > 0) {
                        self.current -= 1;
                    } else {
                        self.current += 1;
                    }
                }

                if (forward) {
                    if (self.current >= self.end) {
                        self.current = self.end;
                        self.direction = -1;
                    } else if (self.current <= self.start) {
                        self.current = self.start;
                        self.direction = 1;
                    }
                } else {
                    if (self.current <= self.end) {
                        self.current = self.end;
                        self.direction = -1;
                    } else if (self.current >= self.start) {
                        self.current = self.start;
                        self.direction = 1;
                    }
                }
            },
        }

        return self.current;
    }
};

// ============================================================================
// Tests
// ============================================================================

const std = @import("std");
const testing = std.testing;

test "IndexAnimator.once mode advances and stops" {
    var animator = IndexAnimator.init(0, 4, .once);

    // Initial state
    try testing.expectEqual(@as(usize, 0), animator.current);
    try testing.expectEqual(false, animator.once_finished);

    // Step through 0->1->2->3->4
    try testing.expectEqual(@as(usize, 1), animator.step());
    try testing.expectEqual(false, animator.once_finished);

    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 4), animator.step());
    try testing.expectEqual(true, animator.once_finished);

    // Should stay at 4
    try testing.expectEqual(@as(usize, 4), animator.step());
    try testing.expectEqual(true, animator.once_finished);
}

test "IndexAnimator.once mode reverse range" {
    var animator = IndexAnimator.init(5, 2, .once);

    try testing.expectEqual(@as(usize, 5), animator.current);

    // Step through 5->4->3->2
    try testing.expectEqual(@as(usize, 4), animator.step());
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(true, animator.once_finished);

    // Should stay at 2
    try testing.expectEqual(@as(usize, 2), animator.step());
}

test "IndexAnimator.once mode single frame" {
    var animator = IndexAnimator.init(3, 3, .once);

    try testing.expectEqual(@as(usize, 3), animator.current);

    // Already at end, should finish immediately
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(true, animator.once_finished);
}

test "IndexAnimator.loopForward cycles correctly" {
    var animator = IndexAnimator.init(0, 3, .loopForward);

    // First cycle: 0->1->2->3->0
    try testing.expectEqual(@as(usize, 1), animator.step());
    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 0), animator.step()); // Wrap

    // Second cycle
    try testing.expectEqual(@as(usize, 1), animator.step());
    try testing.expectEqual(@as(usize, 2), animator.step());
}

test "IndexAnimator.loopForward reverse range" {
    var animator = IndexAnimator.init(5, 2, .loopForward);

    // 5->4->3->2->5
    try testing.expectEqual(@as(usize, 4), animator.step());
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(@as(usize, 5), animator.step()); // Wrap
}

test "IndexAnimator.loopBackwards cycles correctly" {
    var animator = IndexAnimator.init(0, 3, .loopBackwards);

    // Starts at 0, goes backwards to 3, wraps
    try testing.expectEqual(@as(usize, 3), animator.step()); // Jump to end
    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(@as(usize, 1), animator.step());
    try testing.expectEqual(@as(usize, 0), animator.step()); // Wrap to start
    try testing.expectEqual(@as(usize, 3), animator.step());
}

test "IndexAnimator.loopBackwards reverse range" {
    var animator = IndexAnimator.init(5, 2, .loopBackwards);

    // Starts at 5, goes forward toward 2 (since end < start)
    try testing.expectEqual(@as(usize, 2), animator.step()); // Jump to end
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 4), animator.step());
    try testing.expectEqual(@as(usize, 5), animator.step()); // Wrap
}

test "IndexAnimator.loopBounce bounces correctly" {
    var animator = IndexAnimator.init(0, 3, .loopBounce);

    // Forward: 0->1->2->3
    try testing.expectEqual(@as(usize, 1), animator.step());
    try testing.expectEqual(@as(i8, 1), animator.direction);

    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(i8, -1), animator.direction); // Should reverse

    // Backward: 3->2->1->0
    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(@as(i8, -1), animator.direction);

    try testing.expectEqual(@as(usize, 1), animator.step());
    try testing.expectEqual(@as(usize, 0), animator.step());
    try testing.expectEqual(@as(i8, 1), animator.direction); // Should reverse

    // Forward again
    try testing.expectEqual(@as(usize, 1), animator.step());
}

test "IndexAnimator.loopBounce reverse range" {
    var animator = IndexAnimator.init(5, 2, .loopBounce);

    // Start at 5, bounce toward 2
    try testing.expectEqual(@as(usize, 4), animator.step());
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 2), animator.step());
    try testing.expectEqual(@as(i8, -1), animator.direction); // Hit end, reverse

    // Bounce back
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 4), animator.step());
    try testing.expectEqual(@as(usize, 5), animator.step());
    try testing.expectEqual(@as(i8, 1), animator.direction); // Hit start, reverse
}

test "IndexAnimator.loopBounce single frame" {
    var animator = IndexAnimator.init(3, 3, .loopBounce);

    // With only one frame, should just bounce in place
    try testing.expectEqual(@as(usize, 3), animator.current);
    try testing.expectEqual(@as(usize, 3), animator.step());
    try testing.expectEqual(@as(usize, 3), animator.step());
}

test "IndexAnimator multiple complete cycles" {
    var animator = IndexAnimator.init(1, 3, .loopForward);

    // Run 10 complete cycles
    for (0..10) |_| {
        try testing.expectEqual(@as(usize, 2), animator.step());
        try testing.expectEqual(@as(usize, 3), animator.step());
        try testing.expectEqual(@as(usize, 1), animator.step()); // Wrap
    }
}
