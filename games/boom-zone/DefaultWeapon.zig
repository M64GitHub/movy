const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;

pub const DefaultWeapon = struct {
    screen: *movy.Screen,
    cooldown: usize = 6,
    cooldown_ctr: usize = 0,
    ammo: usize = 9999,
    projectiles: [MaxProjectiles]Projectile,
    projectile_sprites: movy.graphic.SpritePool,

    const MaxProjectiles = 16;

    const Projectile = struct {
        sprite: *Sprite = undefined,
        sprite_pool: *movy.graphic.SpritePool = undefined,
        x: i32 = 0,
        y: i32 = 0,
        active: bool = false,

        pub fn update(self: *Projectile) void {
            self.y -= 4;
            self.sprite.stepActiveAnimation();
            self.sprite.setXY(self.x, self.y);
            if (self.y < -@as(i32, @intCast(self.sprite.h))) {
                self.active = false;
            }
        }

        pub fn release(self: *Projectile) void {
            self.active = false;
            self.sprite_pool.release(self.sprite);
        }

        pub fn getCenterCoords(self: *Projectile) struct { x: i32, y: i32 } {
            const s_w: i32 = @as(i32, @intCast(self.sprite.w));
            const s_h: i32 = @as(i32, @intCast(self.sprite.h));

            const x = self.sprite.x + @divTrunc(s_w, 2);
            const y = self.sprite.y + @divTrunc(s_h, 2);

            return .{ .x = x, .y = y };
        }
    };

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*DefaultWeapon {
        const self = try allocator.create(DefaultWeapon);
        self.* = DefaultWeapon{
            .screen = screen,
            .cooldown_ctr = 0,
            .ammo = 9999,
            .projectiles = [_]Projectile{Projectile{ .active = false }} **
                MaxProjectiles,
            .projectile_sprites = movy.graphic.SpritePool.init(allocator),
        };

        try self.initSprites(allocator);
        return self;
    }

    pub fn initSprites(
        self: *DefaultWeapon,
        allocator: std.mem.Allocator,
    ) !void {
        // default sprites
        const split: usize = 8;
        for (0..MaxProjectiles) |_| {
            const sprite = try movy.graphic.Sprite.initFromPng(
                allocator,
                "games/boom-zone/assets/projectiles_orange.png",
                "projectile",
            );
            try sprite.splitByWidth(allocator, split);
            try sprite.addAnimation(
                allocator,
                "flying",
                movy.graphic.Sprite.FrameAnimation.init(
                    1,
                    6,
                    .loopForward,
                    1,
                ),
            );
            try sprite.startAnimation("flying");
            try self.projectile_sprites.addSprite(sprite);
        }
    }

    pub fn update(self: *DefaultWeapon) !void {
        if (self.cooldown_ctr > 0)
            self.cooldown_ctr -= 1;

        for (&self.projectiles) |*proj| {
            if (proj.active) {
                proj.update();
                // set inactive
                if (!proj.active) self.projectile_sprites.release(
                    proj.sprite,
                );
            }
        }
    }

    pub fn addRenderSurfaces(self: *DefaultWeapon) !void {
        for (&self.projectiles) |*proj| {
            if (proj.active) {
                try self.screen.addRenderSurface(
                    try proj.sprite.getCurrentFrameSurface(),
                );
            }
        }
    }

    pub fn tryFire(self: *DefaultWeapon, x: i32, y: i32) bool {
        if (self.cooldown_ctr > 0 or self.ammo == 0)
            return false;

        var fired = false;

        for (&self.projectiles) |*proj| {
            if (!proj.active) {
                if (self.projectile_sprites.get()) |sprite| {
                    // do the fire
                    proj.* = Projectile{
                        .sprite = sprite,
                        .x = x,
                        .y = y,
                        .active = true,
                        .sprite_pool = &self.projectile_sprites,
                    };
                    self.cooldown_ctr = self.cooldown;
                    self.ammo -= 1;
                    fired = true;
                }
                break;
            }
        }

        return fired;
    }

    pub fn deinit(self: *DefaultWeapon, allocator: *std.mem.Allocator) void {
        // deinitializes the pool and frees all sprites
        self.projectile_sprites.deinit(allocator);
    }
};
