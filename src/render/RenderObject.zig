const std = @import("std");
const movy = @import("../movy.zig");

/// A container for a single input surface and its associated effect chain,
/// processing the input into an output surface for rendering.
pub const RenderObject = struct {
    effect_ctx: movy.render.Effect.RenderEffectContext,
    effect_chain: ?*movy.render.RenderEffectChain,

    /// Initializes a RenderObject with an input surface and an optional
    /// effect chain. Creates an output surface based on input dimensions.
    pub fn init(
        allocator: std.mem.Allocator,
        input: *movy.core.RenderSurface,
        effect_chain: ?*movy.render.RenderEffectChain,
    ) !RenderObject {
        var output = try movy.core.RenderSurface.init(
            allocator,
            input.w,
            input.h,
            .{ .r = 0, .g = 0, .b = 0 },
        );
        output.x = input.x;
        output.y = input.y;
        output.z = input.z;

        const fx_ctx = movy.render.Effect.RenderEffectContext{
            .input_surface = input,
            .output_surface = output,
        };

        return .{
            .effect_ctx = fx_ctx,
            .effect_chain = effect_chain,
        };
    }

    /// Frees the output surface owned by the RenderObject.
    /// Does not free the input surface or effect chain, as they may be
    /// externally owned.
    pub fn deinit(self: *RenderObject, allocator: std.mem.Allocator) void {
        self.effect_ctx.output_surface.deinit(allocator);
        allocator.destroy(self.effect_ctx.output_surface);
    }

    /// Returns the output surface of the RenderObject (stored in effect_ctx).
    pub fn getOutputSurface(self: *RenderObject) *movy.core.RenderSurface {
        return self.effect_ctx.output_surface;
    }

    /// Returns the input surface of the RenderObject (stored in effect_ctx).
    pub fn getInputSurface(self: *RenderObject) *movy.core.RenderSurface {
        return self.effect_ctx.input_surface;
    }

    /// Processes the input surface through the effect chain (if present),
    /// producing the result in the output surface. If no effect chain is set,
    /// simply points the output surface to the input surface.
    /// During processing, the effect_ctx will be updated.
    pub fn process(
        self: *RenderObject,
        allocator: std.mem.Allocator,
        frame: usize,
    ) !*movy.core.RenderSurface {
        if (self.effect_chain) |chain| {
            try chain.run(allocator, &self.effect_ctx, frame);
        } else {
            try self.effect_ctx.output_surface.copy(
                self.effect_ctx.input_surface,
            );
        }
        return self.effect_ctx.output_surface;
    }
};
