const std = @import("std");
const movy = @import("../../movy.zig");
const Error = movy.render.RenderEffectError;
const RenderEffect = movy.render.RenderEffect;
const SurfaceExpand = movy.render.Effect.SurfaceExpand;

pub const Darker = struct {
    surface_expand: ?SurfaceExpand = null,
    amount: u8 = 0,
    start_frame: usize = 0,
    duration: usize = 60,

    pub fn validate(self: *Darker) !void {
        if (self.amount > 100) return Error.InvalidValue;
    }

    pub fn run(
        self: *Darker,
        in_surface: *const movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
        frame: usize,
    ) void {
        const t = @as(u8, @intFromFloat(@as(
            f32,
            @floatFromInt(frame - self.start_frame),
        ) / @as(f32, @floatFromInt(self.duration)) * 100.0));
        const amount_t = if ((frame - self.start_frame) >= self.duration)
            self.amount
        else
            self.amount * std.math.clamp(t, 0, 100);

        for (0..in_surface.color_map.len) |idx| {
            const new_color =
                movy.color.darker(in_surface.color_map[idx], amount_t);
            out_surface.color_map[idx] = new_color;

            out_surface.shadow_map[idx] = in_surface.shadow_map[idx];
            out_surface.char_map[idx] = in_surface.char_map[idx];
        }
    }

    /// Helper to wrap this effect into a RenderEffect.
    pub fn asEffect(self: *Darker) RenderEffect {
        return RenderEffect.init(
            Darker,
            self,
            Darker.run,
            Darker.validate,
        );
    }
};
