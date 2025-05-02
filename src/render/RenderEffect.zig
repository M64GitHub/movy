const std = @import("std");
const movy = @import("../movy.zig");
const RenderSurface = movy.core.RenderSurface;

/// Common error set returned by effect parameter validation
pub const Error = error{
    InvalidDuration,
    InvalidAlphaRange,
    WrongEffectKind,
    SurfaceSizeMismatch,
    InvalidBlurRadius,
    InvalidPosition,
    InvalidValue,
};

pub const RenderEffectContext = struct {
    input_surface: *RenderSurface,
    output_surface: *RenderSurface,
    expansion_applied: ?movy.render.Effect.SurfaceExpand = null,
};

/// Direction enum used by certain effects such as `outlineRotator`.
pub const EffectDirection = enum {
    up,
    right,
    down,
    left,
};

/// A hint to describe how much extra surface space is needed
/// for rendering this effect without clipping (i.e. glow, shake, etc.)
pub const SurfaceExpand = struct {
    /// Units to expand horizontally (adds border_x * 2 to width)
    border_x: usize = 0,
    /// Units to expand vertically (adds border_y * 2 to height)
    border_y: usize = 0,
};

// Unified runtime object for a render effect.
/// Wraps a user-defined effect instance and runs it.
pub const RenderEffect = struct {
    /// Pointer to the effect instance (e.g., FadeEffect, BlurEffect, etc.)
    instance: *anyopaque,

    /// Function to run the effect logic.
    runFn: *const fn (
        instance: *anyopaque,
        in_surface: *const RenderSurface,
        out_surface: *RenderSurface,
        frame: usize,
    ) void,

    /// Validation function, mandatory
    validateFn: *const fn (instance: *anyopaque) Error!void,
    /// Optional surface expansion hint.
    surface_expand: ?SurfaceExpand = null,

    /// Creates a RenderEffect from a concrete effect instance.
    ///
    /// This function automatically wraps the given `run_fn` and `validate_fn`
    /// so they can be called through `*anyopaque` pointers, as expected by
    /// the RenderEffect system.
    ///
    /// This removes the need for users to manually write type-erased wrapper
    /// functions.
    ///
    /// ## Parameters:
    /// - `T`: The concrete type of the effect (e.g., `Fade`, `Blur`, etc.).
    /// - `instance`: A pointer to the effect instance.
    /// - `run_fn`: The effect's `run` function (must accept `*T`).
    /// - `validate_fn`: The effect's `validate` function (must accept `*T`).
    ///
    /// ## Returns:
    /// A fully constructed `RenderEffect` that can be used in chains,
    /// pipelines, or manual execution.
    ///
    /// ## Example usage:
    /// ```
    /// var fade = Fade{ .alpha_start = 0.0, .alpha_end = 1.0, .duration = 60 };
    /// var effect = RenderEffect.init(Fade, &fade, Fade.run, Fade.validate);
    /// ```
    pub fn init(
        comptime T: type,
        instance: *T,
        run_fn: fn (*T, *const RenderSurface, *RenderSurface, usize) void,
        validate_fn: fn (*T) Error!void,
    ) RenderEffect {
        return RenderEffect{
            .instance = instance,
            .runFn = struct {
                pub fn wrapped(
                    i: *anyopaque,
                    in_surface: *const RenderSurface,
                    out_surface: *RenderSurface,
                    frame: usize,
                ) void {
                    const real = castInstance(T, i);
                    run_fn(real, in_surface, out_surface, frame);
                }
            }.wrapped,
            .validateFn = struct {
                pub fn wrapped(i: *anyopaque) Error!void {
                    const real = castInstance(T, i);
                    return validate_fn(real);
                }
            }.wrapped,
            .surface_expand = instance.surface_expand,
        };
    }

    /// Runs the effect safely on surfaces.
    /// Ensures the output surface is large enough.
    pub fn runOnSurfaces(
        self: *const RenderEffect,
        in_surface: *const RenderSurface,
        out_surface: *RenderSurface,
        frame: usize,
    ) !void {
        if (out_surface.w < in_surface.w or out_surface.h < in_surface.h) {
            return Error.SurfaceSizeMismatch;
        }
        try self.validateFn(self.instance);
        self.runFn(self.instance, in_surface, out_surface, frame);
    }

    /// Runs the effect using expansion-aware context.
    /// Automatically resizes output surface if expansion is required.
    pub fn run(
        self: *const RenderEffect,
        allocator: std.mem.Allocator,
        ctx: *RenderEffectContext,
        frame: usize,
    ) !void {
        if (self.surface_expand) |expand| {
            const required_w = ctx.input_surface.w + expand.border_x * 2;
            const required_h = ctx.input_surface.h + expand.border_y * 2;

            if (ctx.output_surface.w < required_w or
                ctx.output_surface.h < required_h)
            {
                try ctx.output_surface.resize(
                    allocator,
                    required_w,
                    required_h,
                );
                ctx.expansion_applied = expand;
            }
        }
        return self.runOnSurfaces(ctx.input_surface, ctx.output_surface, frame);
    }

    inline fn castInstance(comptime T: type, i: *anyopaque) *T {
        return @as(*T, @alignCast(@ptrCast(i)));
    }
};
