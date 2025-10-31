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
                if (self.direction > 0) {
                    self.current += 1;
                } else {
                    self.current -= 1;
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
