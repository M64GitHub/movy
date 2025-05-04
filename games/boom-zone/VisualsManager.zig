const std = @import("std");
const movy = @import("movy");
const TimedVisual = @import("TimedVisual.zig").TimedVisual;

pub const VisualsManager = struct {
    screen: *movy.Screen,
    visuals: std.ArrayList(*TimedVisual),

    // --

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) VisualsManager {
        return VisualsManager{
            .screen = screen,
            .visuals = std.ArrayList(*TimedVisual).init(allocator),
        };
    }

    pub fn deinit(self: *VisualsManager) void {
        self.visuals.deinit();
    }

    pub fn showSprite(
        self: *VisualsManager,
        allocator: std.mem.Allocator,
        sprite: *movy.Sprite,
        fade_in: usize,
        hold: usize,
        fade_out: usize,
    ) !void {
        const visual = try TimedVisual.init(
            allocator,
            try sprite.getCurrentFrameSurface(),
            sprite.output_surface,
            fade_in,
            hold,
            fade_out,
            .Auto,
        );

        visual.active = true; // Auto start
        visual.state = .Starting;
        try self.visuals.append(visual);
    }

    pub fn startSprite(
        self: *VisualsManager,
        allocator: std.mem.Allocator,
        sprite: *movy.Sprite,
        fade_in: usize,
        fade_out: usize,
    ) !*TimedVisual {
        var visual = try TimedVisual.init(
            allocator,
            try sprite.getCurrentFrameSurface(),
            sprite.output_surface,
            fade_in,
            1, // dummy val for update logic, will be skipped by stopVisual
            fade_out,
            .StartStop,
        );
        visual.active = true; // Auto start
        visual.state = .Starting;
        try self.visuals.append(visual);
        return visual;
    }

    pub fn showSurface(
        self: *VisualsManager,
        allocator: std.mem.Allocator,
        surface_in: *movy.RenderSurface,
        surface_out: *movy.RenderSurface,
        fade_in: usize,
        hold: usize,
        fade_out: usize,
    ) !void {
        const visual = try TimedVisual.init(
            allocator,
            surface_in,
            surface_out,
            fade_in,
            hold,
            fade_out,
            .Auto,
        );

        visual.active = true; // Auto start
        visual.state = .Starting;
        try self.visuals.append(visual);
    }

    pub fn startSurface(
        self: *VisualsManager,
        allocator: std.mem.Allocator,
        surface_in: *movy.RenderSurface,
        surface_out: *movy.RenderSurface,
        fade_in: usize,
        fade_out: usize,
    ) !*TimedVisual {
        const visual = try TimedVisual.init(
            allocator,
            surface_in,
            surface_out,
            fade_in,
            1, // dummy val for update logic, will be skipped by stopVisual
            fade_out,
            .StartStop,
        );
        visual.active = true; // Auto start
        visual.state = .Starting;
        try self.visuals.append(visual);
        return visual;
    }

    pub fn update(
        self: *VisualsManager,
        allocator: std.mem.Allocator,
        global_frame: usize,
    ) !void {
        _ = global_frame;

        var i: usize = 0;
        while (i < self.visuals.items.len) {
            var vis = self.visuals.items[i];

            // update auto visuals
            if (vis.visual_type == .Auto) {
                // try vis.update();
                vis.frame_counter += 1;
            }

            // update manual visuals
            if (vis.visual_type == .StartStop) {
                if (vis.active) {
                    switch (vis.state) {
                        .Starting => {
                            vis.frame_counter += 1;
                            try vis.update();
                            if (vis.frame_counter >= vis.fade_in)
                                vis.state = .Holding;
                        },
                        .Holding => {
                            // hold, and wait until state is set to .Stopping
                        },
                        .Stopping => {
                            vis.frame_counter += 1;
                            try vis.update();
                        },
                        else => {},
                    }
                }
            }

            if (vis.frame_counter >= vis.totalDuration()) {
                // visual finished: remove and destroy
                _ = self.visuals.orderedRemove(i);
                vis.deinit(allocator);
            } else {
                i += 1;
            }
        }
    }

    pub fn addRenderSurfaces(self: *VisualsManager) !void {
        for (self.visuals.items) |vis| {
            if (vis.active)
                try self.screen.addRenderSurface(vis.surface_out);
        }
    }

    pub fn clearAll(self: *VisualsManager, allocator: std.mem.Allocator) void {
        for (self.visuals.items) |vis| {
            vis.deinit(allocator);
        }
        self.visuals.clearRetainingCapacity();
    }
};
