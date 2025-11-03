const std = @import("std");
const movy = @import("../../movy.zig");
const Error = movy.render.RenderEffectError;
const RenderEffect = movy.render.RenderEffect;
const SurfaceExpand = movy.render.Effect.SurfaceExpand;

/// Fades a surface from one alpha level to another over a duration.
/// Alpha values range from 0.0 (transparent) to 1.0 (opaque).
pub const Fade = struct {
    surface_expand: ?SurfaceExpand = null,
    alpha_start: f32 = 1.0,
    alpha_end: f32 = 0.0,
    duration: usize = 60,

    /// Validates duration and alpha range (0.0-1.0).
    pub fn validate(self: *Fade) !void {
        if (self.duration == 0) return Error.InvalidDuration;
        if (self.alpha_start < 0.0 or self.alpha_start > 1.0 or
            self.alpha_end < 0.0 or self.alpha_end > 1.0)
        {
            return Error.InvalidAlphaRange;
        }
    }

    /// Applies fade effect by interpolating alpha over duration.
    pub fn run(
        self: *Fade,
        in_surface: *const movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
        frame: usize,
    ) void {
        const t =
            @as(f32, @floatFromInt(frame)) /
            @as(f32, @floatFromInt(self.duration));
        const alpha = if (frame >= self.duration)
            self.alpha_end
        else
            self.alpha_start +
                (self.alpha_end - self.alpha_start) *
                    std.math.clamp(t, 0.0, 1.0);

        var rgb = movy.core.types.Rgb{ .r = 0x00, .g = 0x00, .b = 0x00 };

        for (0..in_surface.w * in_surface.h) |i| {
            if (in_surface.shadow_map[i] != 0) {
                out_surface.shadow_map[i] = in_surface.shadow_map[i];
                out_surface.char_map[i] = in_surface.char_map[i];
                rgb = in_surface.color_map[i];

                rgb.r = @as(
                    u8,
                    @intFromFloat(
                        @as(f32, @floatFromInt(rgb.r)) * alpha,
                    ),
                );
                rgb.g = @as(
                    u8,
                    @intFromFloat(
                        @as(f32, @floatFromInt(rgb.g)) * alpha,
                    ),
                );
                rgb.b = @as(
                    u8,
                    @intFromFloat(
                        @as(f32, @floatFromInt(rgb.b)) * alpha,
                    ),
                );

                out_surface.color_map[i] = rgb;
            }
        }
    }

    /// Wraps this effect for use in rendering pipelines.
    pub fn asEffect(self: *Fade) RenderEffect {
        return RenderEffect.init(
            Fade,
            self,
            Fade.run,
            Fade.validate,
        );
    }
};
