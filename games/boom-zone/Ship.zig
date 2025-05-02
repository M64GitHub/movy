const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;

pub const Ship = struct {
    x: i32,
    y: i32,
    base_y: i32,
    orientation: Orientation = .Up,
    speed: i32,
    sprite_ship: *Sprite,
    sprite_thrust: *Sprite,
    screen: *movy.Screen,
    visible: bool = false,

    pub const Orientation = enum {
        Up,
        Down,
        Left,
        Right,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        ship: *Sprite,
        thrust: *Sprite,
        speed: i32,
        orientation: Orientation,
        screen: *movy.Screen,
    ) !*Ship {
        const s = try allocator.create(Ship);
        s.* = Ship{
            .x = 0,
            .y = 0,
            .base_y = 0,
            .sprite_ship = ship,
            .sprite_thrust = thrust,
            .speed = speed,
            .orientation = orientation,
            .screen = screen,
        };

        return s;
    }

    pub fn deinit(self: *Ship, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn setXY(self: *Ship, x: i32, y: i32) void {
        self.x = x;
        self.y = y;

        const new_y = y + self.base_y;

        self.sprite_ship.setXY(x, new_y);
        self.sprite_thrust.setXY(
            self.sprite_ship.x + 3,
            self.sprite_ship.y + 18,
        );
    }

    pub fn getCenterCoords(self: *Ship) struct { x: i32, y: i32 } {
        const s_w: i32 = @as(i32, @intCast(self.sprite_ship.w));
        const s_h: i32 = @as(i32, @intCast(self.sprite_ship.h));

        const x = self.sprite_ship.x + @divTrunc(s_w, 2);
        const y = self.sprite_ship.y + @divTrunc(s_h, 2);

        return .{ .x = x, .y = y };
    }

    pub fn stepAnimations(self: *Ship) void {
        self.sprite_ship.stepActiveAnimation();
        self.sprite_thrust.stepActiveAnimation();
        // make sure, current frame surface's x/y is updated
        self.setXY(self.x, self.y);
    }

    pub fn addRenderSurfaces(self: *Ship) !void {
        if (!self.visible) return;

        try self.screen.addRenderSurface(
            try self.sprite_ship.getCurrentFrameSurface(),
        );

        try self.screen.addRenderSurface(
            try self.sprite_thrust.getCurrentFrameSurface(),
        );
    }
};
