//! Animation utilities for terminal graphics and sprites.
//!
//! This module provides easing functions, trigonometric waves,
//! stateful wave generators (TrigWave), and index-based animation
//! control (IndexAnimator) for frame sequences and cycling effects.

pub const ease = @import("ease.zig");
pub const trig = @import("trig.zig");
pub const TrigWave = @import("TrigWave.zig").TrigWave;
pub const IndexAnimator = @import("IndexAnimator.zig").IndexAnimator;
pub const IndexAnimatorError = @import("IndexAnimator.zig").Error;
