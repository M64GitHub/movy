const std = @import("std");
const movy = @import("movy");
const Ship = @import("Ship.zig").Ship;
const ShipController = @import("ShipController.zig").ShipController;
const WeaponManager = @import("WeaponManager.zig").WeaponManager;

const MovementSpeed: i32 = 2;
const AnimationSpeed = 1;

pub const PlayerShip = struct {
    ship: *Ship,
    controller: ShipController,
    weapon_manager: *WeaponManager,
    screen: *movy.Screen,
    msgbuf: [1024]u8,
    message: ?[]const u8 = null,

    //
    lives: usize = 5,

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !PlayerShip {
        // load sprites
        var ship_sprite = try movy.graphic.Sprite.initFromPng(
            allocator,
            "games/boom-zone/assets/playership.png",
            "player",
        );

        var thrust_sprite = try movy.graphic.Sprite.initFromPng(
            allocator,
            "games/boom-zone/assets/v-thrust.png",
            "thrust",
        );

        const weapon_sprite = try movy.graphic.Sprite.initFromPng(
            allocator,
            "games/boom-zone/assets/weapons.png",
            "weapons",
        );

        const shield_sprite = try movy.graphic.Sprite.initFromPng(
            allocator,
            "games/boom-zone/assets/shield_green.png",
            "shield",
        );

        // slice sprites
        try ship_sprite.splitByWidth(allocator, 24);
        try thrust_sprite.splitByWidth(allocator, 16);
        try weapon_sprite.splitByWidth(allocator, 48);
        try shield_sprite.splitByWidth(allocator, 16);

        // define animations

        const anims = [_]struct {
            name: []const u8,
            start: usize,
            end: usize,
            mode: movy.animation.IndexAnimator.LoopMode,
            speed: usize,
        }{
            .{
                .name = "idle",
                .start = 1,
                .end = 1,
                .mode = .loopForward,
                .speed = 4,
            },
            .{
                .name = "left",
                .start = 4,
                .end = 5,
                .mode = .once,
                .speed = 2,
            },
            .{
                .name = "right",
                .start = 2,
                .end = 3,
                .mode = .once,
                .speed = 2,
            },
            .{
                .name = "fire",
                .start = 0,
                .end = 0,
                .mode = .once,
                .speed = 1,
            },
        };

        // Add animations and reverse variants for the ship
        for (anims) |a| {
            try ship_sprite.addAnimation(
                allocator,
                a.name,
                movy.graphic.Sprite.FrameAnimation.init(
                    a.start,
                    a.end,
                    a.mode,
                    a.speed,
                ),
            );

            // reverse animations
            const rev_name = try std.fmt.allocPrint(
                allocator,
                "{s}_rev",
                .{a.name},
            );

            try ship_sprite.addAnimation(
                allocator,
                rev_name,
                movy.graphic.Sprite.FrameAnimation.init(
                    a.end,
                    a.start,
                    a.mode,
                    a.speed,
                ),
            );
        }

        try thrust_sprite.addAnimation(
            allocator,
            "idle",
            movy.graphic.Sprite.FrameAnimation.init(
                1,
                4,
                .loopBounce,
                4,
            ),
        );

        try ship_sprite.startAnimation("idle");
        try thrust_sprite.startAnimation("idle");
        try weapon_sprite.setFrameIndex(1);
        try shield_sprite.setFrameIndex(1);

        try screen.addSprite(ship_sprite);
        try screen.addSprite(thrust_sprite);

        const x =
            @divTrunc(@as(i32, @intCast(screen.width() - ship_sprite.w)), 2);

        const y =
            // @as(i32, @intCast(screen.h - ship_sprite.h - 16));
            @as(i32, @intCast(screen.h - ship_sprite.h - 10));

        const ship = try Ship.init(
            allocator,
            ship_sprite,
            thrust_sprite,
            weapon_sprite,
            shield_sprite,
            MovementSpeed,
            .Up,
        );

        const ps = PlayerShip{
            .ship = ship,
            .controller = ShipController.init(ship, screen),
            .weapon_manager = try WeaponManager.init(allocator, screen),
            .screen = screen,
            .msgbuf = [_]u8{0} ** 1024,
        };

        ship.stepAnimations();
        ship.setXY(x, y);

        return ps;
    }

    pub fn deinit(self: *PlayerShip, allocator: std.mem.Allocator) void {
        self.ship.sprite_ship.deinit(allocator);
        self.ship.sprite_thrust.deinit(allocator);
        self.ship.sprite_shield.deinit(allocator);
        self.ship.sprite_weapon.deinit(allocator);
        self.ship.deinit(allocator);
        self.weapon_manager.deinit(allocator);
        allocator.destroy(self.weapon_manager);
    }

    pub fn onKeyDown(self: *PlayerShip, key: movy.input.Key) void {
        self.controller.onKeyDown(key);
        if (key.type == .Char) {
            if (key.sequence[0] == ' ') {
                const fx = self.ship.x +
                    @divTrunc(
                        @as(i32, @intCast(self.ship.sprite_ship.w)),
                        2,
                    ) - 4;
                const fy = self.ship.y + 8;
                self.weapon_manager.tryFire(fx, fy);
            }
        }
    }

    pub fn onKeyUp(self: *PlayerShip, key: movy.input.Key) void {
        self.controller.onKeyUp(key);
    }

    pub fn update(self: *PlayerShip) !void {
        try self.controller.updateState();
        self.controller.handleState();
        self.ship.stepAnimations();
        if (self.ship.sprite_ship.active_animation) |ani_name| {
            try self.setMessage(ani_name);
        }
        try self.weapon_manager.update();
    }

    pub fn setMessage(
        self: *PlayerShip,
        msg: []const u8,
    ) !void {
        var ani_or_fired = msg;
        if (self.weapon_manager.just_fired) ani_or_fired = "FIRE!";
        self.message = try std.fmt.bufPrint(
            &self.msgbuf,
            "Player: {s} | Weapon: {s} | Ammo: {d} | Lives: {d}",
            .{
                ani_or_fired,
                self.weapon_manager.getWeaponName(),
                self.weapon_manager.getAmmo(),
                self.lives,
            },
        );
    }
};
