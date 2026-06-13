//! Camera: eased lookahead follow + clamp to level bounds + trauma shake.
//! sx()/sy() convert world pixels -> screen pixels (and offset the play area
//! below the HUD strip).

const std = @import("std");
const cfg = @import("config.zig");

pub const Camera = struct {
    x: f32 = 0, // world px of the view's left edge
    y: f32 = 0,
    look: f32 = 0, // eased lookahead in the facing direction
    trauma: f32 = 0,
    shake_x: i32 = 0,
    shake_y: i32 = 0,
    prng: std.Random.DefaultPrng,

    pub fn init(seed: u64) Camera {
        return .{ .prng = std.Random.DefaultPrng.init(seed) };
    }

    /// Kick the screen-shake (0..1). amplitude scales with trauma^2.
    pub fn addTrauma(self: *Camera, amt: f32) void {
        self.trauma = @min(self.trauma + amt, 1.0);
    }

    /// Snap instantly to the target (spawn / respawn).
    pub fn snap(self: *Camera, px: f32, py: f32, lw: i32, lh: i32) void {
        self.x = px - @as(f32, @floatFromInt(cfg.view_w)) / 2.0;
        self.y = py - @as(f32, @floatFromInt(cfg.PLAY_H)) / 2.0;
        self.clamp(lw, lh);
    }

    pub fn update(self: *Camera, px: f32, py: f32, facing: i32, lw: i32, lh: i32) void {
        const look_target = @as(f32, @floatFromInt(facing)) * 16.0;
        self.look += (look_target - self.look) * 0.05;

        const tx = px + self.look - @as(f32, @floatFromInt(cfg.view_w)) / 2.0;
        self.x += (tx - self.x) * 0.10;

        const ty = py - @as(f32, @floatFromInt(cfg.PLAY_H)) * 0.55;
        const dy = ty - self.y;
        if (@abs(dy) > 4.0) self.y += dy * 0.08;

        self.clamp(lw, lh);

        self.trauma *= cfg.SHAKE_DECAY;
        if (self.trauma < 0.02) self.trauma = 0;
        const amp = self.trauma * self.trauma * 5.0;
        const rnd = self.prng.random();
        self.shake_x = @intFromFloat((rnd.float(f32) * 2.0 - 1.0) * amp);
        self.shake_y = @intFromFloat((rnd.float(f32) * 2.0 - 1.0) * amp * 0.6);
    }

    fn clamp(self: *Camera, lw: i32, lh: i32) void {
        const max_x = @as(f32, @floatFromInt(lw - cfg.view_w));
        const max_y = @as(f32, @floatFromInt(lh - cfg.PLAY_H));
        self.x = std.math.clamp(self.x, 0, @max(max_x, 0));
        self.y = std.math.clamp(self.y, 0, @max(max_y, 0));
    }

    /// world px -> screen px
    pub inline fn sx(self: *const Camera, wx: i32) i32 {
        return wx - @as(i32, @intFromFloat(@round(self.x))) + self.shake_x;
    }
    pub inline fn sy(self: *const Camera, wy: i32) i32 {
        return wy - @as(i32, @intFromFloat(@round(self.y))) + self.shake_y + cfg.HUD_H;
    }
};
