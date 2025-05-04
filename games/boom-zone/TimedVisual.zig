const std = @import("std");
const movy = @import("movy");

pub const VisualType = enum {
    Auto,
    StartStop,
};

pub const TimedVisual = struct {
    surface_in: *movy.RenderSurface,
    surface_out: *movy.RenderSurface,
    visual_type: VisualType,
    fade_in: usize,
    hold: usize,
    fade_out: usize,
    frame_counter: usize = 0,
    fade_in_effect: movy.render.RenderEffect,
    fade_out_effect: movy.render.RenderEffect,
    active: bool,

    pub fn init(
        allocator: std.mem.Allocator,
        surface_in: *movy.RenderSurface,
        surface_out: *movy.RenderSurface,
        t_in: usize,
        t_hold: usize,
        t_out: usize,
        v_type: VisualType,
    ) !*TimedVisual {
        const visual = try allocator.create(TimedVisual);

        const fade_in = movy.render.Effect.Fade{
            .alpha_start = 0.0,
            .alpha_end = 1.0,
            .duration = t_in,
        };
        const fade_in_effect = fade_in.asEffect();

        const fade_out = movy.render.Effect.Fade{
            .alpha_start = 1.0,
            .alpha_end = 0.0,
            .duration = t_out,
        };
        const fade_out_effect = fade_out.asEffect();

        visual.* = .{
            .surface_in = surface_in,
            .surface_out = surface_out,
            .fade_in = t_in,
            .fade_out = t_out,
            .hold = t_hold,
            .fade_in_effect = fade_in_effect,
            .fade_out_effect = fade_out_effect,
            .frame_counter = 0,
            .visual_type = v_type,
            .active = false,
        };

        return visual;
    }

    pub fn deinit(self: *TimedVisual, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn totalDuration(self: *TimedVisual) usize {
        return self.fade_in + self.hold + self.fade_out;
    }

    pub fn update(self: *TimedVisual) !void {
        const frame = self.frame_counter;

        if (frame < self.fade_in) {
            // fade in
            try self.fade_in_effect.runOnSurfaces(
                self.surface_in,
                self.surface_out,
                frame,
            );
        } else if (frame < self.fade_in + self.hold) {
            // hold
        } else if (frame < self.totalDuration()) {
            // fade out
            try self.fade_out_effect.runOnSurfaces(
                self.surface_in,
                self.surface_out,
                frame - self.fade_in - self.hold,
            );
        } else {
            // wait for removal
            return;
        }
    }

    pub fn stop(
        visual: *TimedVisual,
    ) void {
        // prepare frame counter for fade out sequence
        visual.frame_counter = visual.fade_in + visual.hold + 1 + 1;
        visual.active = true; // Auto start
    }
};
