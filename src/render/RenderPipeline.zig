const std = @import("std");
const movy = @import("../movy.zig");

/// Errors that can occur when working with RenderPipeline.
pub const Error = error{
    /// Failed to allocate memory for render objects or intermediate surfaces.
    OutOfMemory,
    /// An error occurred while processing render objects or the effect chain.
    ProcessingError,
    /// No render objects were provided for processing.
    EmptyPipeline,
};

/// A pipeline that processes multiple render objects and applies a final effect
/// chain, merging inputs into a single output surface for rendering.
pub const RenderPipeline = struct {
    render_objects: std.ArrayList(movy.render.RenderObject),
    effect_chain: ?movy.render.RenderEffectChain,
    output_surface: *movy.core.RenderSurface,
    result_surface: *movy.core.RenderSurface,

    /// Initializes a RenderPipeline with an output surface and an allocator.
    pub fn init(
        allocator: std.mem.Allocator,
        output: *movy.core.RenderSurface,
    ) !RenderPipeline {
        return .{
            .render_objects = std.ArrayList(
                movy.render.RenderObject,
            ).init(allocator),
            .effect_chain = null,
            .output_surface = output,
            .result_surface = try movy.core.RenderSurface.init(
                allocator,
                output.w,
                output.h,
                movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
            ),
        };
    }

    /// Frees all resources owned by the pipeline, including render objects.
    /// Does not free the output surface, as it is owned by the caller.
    pub fn deinit(self: *RenderPipeline, allocator: std.mem.Allocator) void {
        for (self.render_objects.items) |*obj| {
            obj.deinit(allocator);
        }
        self.render_objects.deinit();
        if (self.effect_chain) |*chain| chain.deinit(allocator);
        self.result_surface.deinit(allocator);
    }

    /// Adds an existing RenderObject to the pipeline.
    pub fn addObject(
        self: *RenderPipeline,
        obj: movy.render.RenderObject,
    ) !void {
        try self.render_objects.append(obj);
    }

    /// Creates a new RenderObject from an input surface and effect chain, and
    /// adds it to the pipeline.
    pub fn addSurface(
        self: *RenderPipeline,
        allocator: std.mem.Allocator,
        input: *movy.core.RenderSurface,
        effect_chain: ?*movy.render.RenderEffectChain,
    ) !void {
        const obj = try movy.render.RenderObject.init(
            allocator,
            input,
            effect_chain,
        );
        try self.render_objects.append(obj);
    }

    /// Sets the final effect chain for post-processing the merged output.
    pub fn setEffectChain(
        self: *RenderPipeline,
        chain: movy.render.RenderEffectChain,
    ) void {
        self.effect_chain = chain;
    }

    /// Runs the pipeline, processing all render objects and merging their
    /// outputs, then applying the final effect chain (if present) to produce
    /// the output surface.
    pub fn run(
        self: *RenderPipeline,
        allocator: std.mem.Allocator,
        frame: usize,
    ) !void {
        if (self.render_objects.items.len == 0) return Error.EmptyPipeline;

        var temp_surfaces =
            std.ArrayList(*movy.core.RenderSurface).init(allocator);
        defer temp_surfaces.deinit();

        // Process each render object
        for (self.render_objects.items) |*obj| {
            try temp_surfaces.append(try obj.process(allocator, frame));
        }

        // Apply final effect chain if present
        if (self.effect_chain) |*chain| {
            // Render / merge down
            movy.render.RenderEngine.render(
                temp_surfaces.items,
                self.result_surface,
            );
            var fx_ctx = movy.render.Effect.RenderEffectContext{
                .input_surface = self.result_surface,
                .output_surface = self.output_surface,
            };
            try chain.run(allocator, &fx_ctx, frame);
        } else {
            // Render / merge down
            movy.render.RenderEngine.render(
                temp_surfaces.items,
                self.output_surface,
            );
        }
    }
};
