const std = @import("std");
const movy = @import("../../movy.zig");
const Error = movy.render.RenderEffectError;
const RenderEffect = movy.render.RenderEffect;
const SurfaceExpand = movy.render.Effect.SurfaceExpand;

pub const Blur = struct {
    surface_expand: ?SurfaceExpand = SurfaceExpand{
        .border_x = 0,
        .border_y = 0,
    },
    radius: usize,

    pub fn run(
        self: *Blur,
        in_surface: *const movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
        frame: usize,
    ) void {
        _ = frame; // Unused for now
        // Placeholder blur logic using p.radius
        for (0..in_surface.w * in_surface.h) |i| {
            if (in_surface.shadow_map[i] != 0) {
                out_surface.color_map[i].r =
                    in_surface.color_map[i].r +% @as(u8, @intCast(self.radius));
                out_surface.color_map[i].g =
                    in_surface.color_map[i].g +% @as(u8, @intCast(self.radius));
                out_surface.color_map[i].b =
                    in_surface.color_map[i].b +% @as(u8, @intCast(self.radius));
                out_surface.shadow_map[i] = 1;
            }
        }
    }

    pub fn validate(self: *Blur) !void {
        if (self.radius == 0) return Error.InvalidBlurRadius;
    }

    /// Helper to wrap this effect into a RenderEffect.
    pub fn asEffect(self: *Blur) RenderEffect {
        return RenderEffect.init(Blur, self, Blur.run, Blur.validate);
    }
};
