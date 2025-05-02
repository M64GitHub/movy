const std = @import("std");
const movy = @import("../../movy.zig");
const Error = movy.render.RenderEffectError;
const RenderEffect = movy.render.RenderEffect;
const SurfaceExpand = movy.render.Effect.SurfaceExpand;

/// A dummy effect example for new users.
/// Simply copies the input surface to the output surface without changes.
pub const DummyEffect = struct {
    /// the only mandatory field, used by the effect system
    surface_expand: ?SurfaceExpand = null,

    /// This function performs the effect, usually to modify the given
    /// output_surface, based on input_surface.
    /// The user can also write destructive effects, like OutlineRotator,
    /// by calling run(surface, surface) - same pointer for both.
    pub fn run(
        self: *DummyEffect,
        in_surface: *const movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
        frame: usize,
    ) void {
        _ = self; // Unused, but required
        _ = frame; // DummyEffect ignores the frame

        for (0..in_surface.w * in_surface.h) |i| {
            out_surface.char_map[i] = in_surface.char_map[i];
            out_surface.color_map[i] = in_surface.color_map[i];
            out_surface.shadow_map[i] = in_surface.shadow_map[i];
        }
    }

    /// Parameter validation function
    /// Our effect has no parameters (fields) to check, so nothing to do.
    pub fn validate(self: *DummyEffect) !void {
        _ = self; // nothing to validate for dummy
        return;
    }

    /// Helper to wrap this effect into a RenderEffect.
    pub fn asEffect(self: *DummyEffect) RenderEffect {
        return RenderEffect.init(
            DummyEffect,
            self,
            DummyEffect.run,
            DummyEffect.validate,
        );
    }
};
