const std = @import("std");
const movy = @import("../movy.zig");

/// Errors that can occur when working with RenderEffectChain.
pub const Error = error{
    /// The chain has no effects to run.
    EmptyChain,
    /// An intermediate or final output surface is null during execution.
    NullSurface,
    /// Failed to allocate memory for intermediate surfaces or effect links.
    OutOfMemory,
};

/// A chain of RenderEffects that processes an input surface through multiple
/// effects, producing a final output surface.
/// Supports dynamic resizing and flexible initialization.
pub const RenderEffectChain = struct {
    effect_links: std.array_list.Managed(EffectLink),
    total_border_expand: movy.render.Effect.SurfaceExpand = .{
        .border_x = 0,
        .border_y = 0,
    },

    /// A link in the chain, pairing a RenderEffect with its output surface.
    const EffectLink = struct {
        effect: movy.render.RenderEffect,
        out_surface: ?*movy.core.RenderSurface,
    };

    /// Initializes an empty RenderEffectChain.
    /// Effects must be added manually via `chainEffect()`.
    /// No surfaces are allocated until `run()` is called.
    pub fn init(allocator: std.mem.Allocator) !RenderEffectChain {
        const effect_links =
            // "smart" default
            try std.array_list.Managed(EffectLink).initCapacity(allocator, 3);
        return RenderEffectChain{
            .effect_links = effect_links,
        };
    }

    /// Frees all resources owned by the chain, including intermediate surfaces.
    /// Does not free the final output_surface, as it is owned by the caller.
    pub fn deinit(self: *RenderEffectChain, allocator: std.mem.Allocator) void {
        // Free intermediate surfaces (skip last, it’s null or user-owned)
        for (self.effect_links.items[0 .. self.effect_links.items.len - 1]) |link| {
            if (link.out_surface) |surface| {
                surface.deinit(allocator);
                allocator.destroy(surface);
            }
        }
        self.effect_links.deinit();
    }

    /// Adds a new effect to the chain and updates expansion requirements
    pub fn chainEffect(
        self: *RenderEffectChain,
        new_effect: movy.render.RenderEffect,
    ) !void {
        try self.effect_links.append(.{
            .effect = new_effect,
            .out_surface = null,
        });

        // Accumulate surface expansion requirements
        if (new_effect.surface_expand) |expand| {
            self.total_border_expand.border_x += expand.border_x;
            self.total_border_expand.border_y += expand.border_y;
        }
    }

    /// Ensures all intermediate and final output surfaces are properly sized
    /// for all effects in the chain. Allocates or resizes intermediate surfaces
    /// except for the last effect, which uses `ctx.output_surface`.
    pub fn dryResize(
        self: *RenderEffectChain,
        allocator: std.mem.Allocator,
        ctx: *movy.render.Effect.RenderEffectContext,
    ) !void {
        const input = ctx.input_surface;
        const expand = self.total_border_expand;
        const target_w = input.w + expand.border_x * 2;
        const target_h = input.h + expand.border_y * 2;

        // Case 1: Only one effect — no intermediates needed
        if (self.effect_links.items.len == 1) {
            if (ctx.output_surface.w != target_w or
                ctx.output_surface.h != target_h)
            {
                try ctx.output_surface.resize(allocator, target_w, target_h);
            }
            ctx.expansion_applied = expand;
            return;
        }

        // Case 2: Multiple effects — allocate intermediates
        for (self.effect_links.items[0 .. self.effect_links.items.len - 1]) |*link| {
            if (link.out_surface) |surface| {
                if (surface.w != target_w or surface.h != target_h) {
                    try surface.resize(allocator, target_w, target_h);
                }
            } else {
                const surface = try movy.core.RenderSurface.init(
                    allocator,
                    target_w,
                    target_h,
                    .{ .r = 0, .g = 0, .b = 0 },
                );
                link.out_surface = surface;
            }
        }

        // Resize final output
        if (ctx.output_surface.w != target_w or ctx.output_surface.h != target_h) {
            try ctx.output_surface.resize(allocator, target_w, target_h);
        }

        ctx.expansion_applied = expand;
    }

    /// Runs the full RenderEffectChain on the given RenderEffectContext.
    /// Ensures intermediate and final surfaces are correctly sized
    /// (via dryResize).
    /// Each effect is applied in sequence, passing output to the next.
    /// The last effect writes into ctx.output_surface.
    pub fn run(
        self: *RenderEffectChain,
        allocator: std.mem.Allocator,
        ctx: *movy.render.Effect.RenderEffectContext,
        frame: usize,
    ) !void {
        if (self.effect_links.items.len == 0) return Error.EmptyChain;

        // Step 1: Ensure all intermediate/output surfaces are ready
        try self.dryResize(allocator, ctx);

        // Step 2: Handle single-effect case (no intermediates needed)
        if (self.effect_links.items.len == 1) {
            return self.effect_links.items[0].effect.runOnSurfaces(
                ctx.input_surface,
                ctx.output_surface,
                frame,
            );
        }

        // Step 3: Handle multi-effect case
        var current_input = ctx.input_surface;

        for (self.effect_links.items[0 .. self.effect_links.items.len - 1]) |link| {
            const output = link.out_surface orelse return Error.NullSurface;
            try link.effect.runOnSurfaces(current_input, output, frame);
            current_input = output;
        }

        // Step 4: Run the final effect into the user's output surface
        const last_link = self.effect_links.items[self.effect_links.items.len - 1];
        try last_link.effect.runOnSurfaces(current_input, ctx.output_surface, frame);
    }
};
