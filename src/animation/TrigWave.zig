const std = @import("std");
const trig = @import("trig.zig");

/// TrigWave struct to manage stateful sine/cosine movement
pub const TrigWave = struct {
    tick: usize = 0,
    duration: usize,
    amplitude: i32,

    /// Initializes a TrigWave with duration (frames for a full cycle)
    /// and amplitude
    pub fn init(duration: usize, amplitude: i32) TrigWave {
        return .{
            // Prevent division by 0
            .duration = if (duration == 0) 1 else duration,
            .amplitude = amplitude,
        };
    }

    /// Computes the sine value for the current tick, increments tick
    pub fn tickSine(self: *TrigWave) i32 {
        const result = trig.sine(self.tick, self.duration, self.amplitude);
        self.tick = (self.tick + 1) % self.duration; // Cycle 0 to duration-1
        return result;
    }

    /// Computes the cosine value for the current tick, increments tick
    pub fn tickCosine(self: *TrigWave) i32 {
        const result = trig.cosine(self.tick, self.duration, self.amplitude);
        self.tick = (self.tick + 1) % self.duration; // Cycle 0 to duration-1
        return result;
    }
};
