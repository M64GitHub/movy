const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;
const RenderSurface = movy.core.RenderSurface;
const Effect = movy.render.Effect;

pub const VisualsManager = struct {
    screen: *movy.Screen,
    allocator: std.mem.Allocator,
    dim_level: f32 = 1.0,
    // fade_effect: ?Effect.Instance = null,
    visuals: std.ArrayList(TimedVisual),

    const TimedVisual = struct {
        sprite: *Sprite,
        fade_in: usize,
        hold: usize,
        fade_out: usize,
        frame_counter: usize = 0,

        pub fn totalDuration(self: TimedVisual) usize {
            return self.fade_in + self.hold + self.fade_out;
        }

        pub fn computeAlpha(self: TimedVisual) f32 {
            const frame = self.frame_counter;
            if (frame < self.fade_in) {
                return @as(f32, @floatFromInt(frame)) /
                    @as(f32, @floatFromInt(self.fade_in));
            } else if (frame < self.fade_in + self.hold) {
                return 1.0;
            } else if (frame < self.totalDuration()) {
                const fade_frame = frame - (self.fade_in + self.hold);
                return 1.0 - (@as(f32, @floatFromInt(fade_frame)) /
                    @as(f32, @floatFromInt(self.fade_out)));
            } else {
                return 0.0;
            }
        }
    };

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) VisualsManager {
        return VisualsManager{
            .screen = screen,
            .allocator = allocator,
            .visuals = std.ArrayList(TimedVisual).init(allocator),
        };
    }

    pub fn deinit(self: *VisualsManager) void {
        self.visuals.deinit();
    }

    pub fn setDimLevel(self: *VisualsManager, level: f32) void {
        self.dim_level = std.math.clamp(level, 0.0, 1.0);
    }

    pub fn showSprite(
        self: *VisualsManager,
        sprite: *Sprite,
        fade_in: usize,
        hold: usize,
        fade_out: usize,
    ) !void {
        try self.visuals.append(.{
            .sprite = sprite,
            .fade_in = fade_in,
            .hold = hold,
            .fade_out = fade_out,
        });
    }

    pub fn update(self: *VisualsManager, global_frame: usize) void {
        _ = global_frame;
        var i: usize = 0;
        while (i < self.visuals.items.len) {
            var vis = &self.visuals.items[i];
            vis.frame_counter += 1;
            if (vis.frame_counter >= vis.totalDuration()) {
                _ = self.visuals.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn render(self: *VisualsManager) !void {
        // if (self.dim_level < 1.0) {
        //     if (self.fade_effect == null) {
        //         self.fade_effect = try Effect.init(.fade, self.allocator);
        //     }
        //
        //     var inst = self.fade_effect.?;
        //     inst.params.fade.value = self.dim_level;
        //     try self.screen.renderEffect(inst);
        // }
        //
        // for (self.visuals.items) |*vis| {
        //     const alpha = vis.computeAlpha();
        //     try vis.sprite.setAlpha(alpha);
        //     try self.screen.addRenderSurface(
        //         try vis.sprite.getCurrentFrameSurface(),
        //     );
        // }

        _ = self;
    }

    pub fn clearAll(self: *VisualsManager) void {
        self.visuals.clearRetainingCapacity();
    }
};
