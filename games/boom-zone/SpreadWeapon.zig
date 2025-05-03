const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;

pub const SpreadWeapon = struct {
    screen: *movy.Screen,
    projectile_sprites: movy.graphic.SpritePool,
    projectiles: [MaxProjectiles]Projectile,
    cooldown: usize = 6,
    cooldown_ctr: usize = 0,
    ammo: usize = 15,
    num_side_projectiles: usize = 2,

    const MaxProjectiles = 64;
    pub const DefaultAmmo: usize = 50;

    const Projectile = struct {
        sprite: *Sprite = undefined,
        sprite_pool: *movy.graphic.SpritePool = undefined,
        screen: *movy.Screen = undefined,
        x: f32 = 0,
        y: f32 = 0,
        dx: f32 = 0,
        dy: f32 = 0,
        active: bool = false,

        pub fn update(self: *Projectile) void {
            self.x += self.dx;
            self.y += self.dy;
            self.sprite.stepActiveAnimation();

            self.sprite.setXY(
                @intFromFloat(self.x),
                @intFromFloat(self.y),
            );

            if (self.y < -@as(f32, @floatFromInt(self.sprite.h)) or
                self.y > @as(f32, @floatFromInt(self.screen.h)) or
                self.x < -@as(f32, @floatFromInt(self.sprite.w)) or
                self.x > @as(f32, @floatFromInt(self.screen.w)))
            {
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
    ) !*SpreadWeapon {
        const self = try allocator.create(SpreadWeapon);
        self.* = SpreadWeapon{
            .screen = screen,
            .projectiles = [_]Projectile{Projectile{}} ** MaxProjectiles,
            .projectile_sprites = movy.graphic.SpritePool.init(allocator),
        };

        try self.initSprites(allocator);
        return self;
    }

    fn initSprites(self: *SpreadWeapon, allocator: std.mem.Allocator) !void {
        const split: usize = 8;
        for (0..MaxProjectiles) |_| {
            const sprite = try movy.graphic.Sprite.initFromPng(
                allocator,
                "games/boom-zone/assets/projectiles_purple.png",
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

    pub fn update(self: *SpreadWeapon) !void {
        if (self.cooldown_ctr > 0)
            self.cooldown_ctr -= 1;

        for (&self.projectiles) |*proj| {
            if (proj.active) {
                proj.update();
                if (!proj.active) {
                    // release sprite
                    self.projectile_sprites.release(proj.sprite);
                }
            }
        }
    }

    pub fn addRenderSurfaces(self: *SpreadWeapon) !void {
        for (&self.projectiles) |*proj| {
            if (proj.active) {
                try self.screen.addRenderSurface(
                    try proj.sprite.getCurrentFrameSurface(),
                );
            }
        }
    }

    pub fn tryFire(self: *SpreadWeapon, x: i32, y: i32) bool {
        if (self.cooldown_ctr > 0 or self.ammo == 0)
            return false;

        var fired = false;

        const num = @as(i32, @intCast(self.num_side_projectiles));
        const step_angle = 90.0 /
            @as(f32, @floatFromInt(self.num_side_projectiles + 1));
        const speed: f32 = 4.0;

        var i: i32 = -num;
        while (i <= num) : (i += 1) {
            const angle_deg = step_angle * @as(f32, @floatFromInt(i));
            const angle_rad = std.math.degreesToRadians(angle_deg);

            const dx = std.math.sin(angle_rad) * speed;
            const dy = -std.math.cos(angle_rad) * speed;

            fired = spawnProjectile(self, x, y - 9, dx, dy);
        }

        self.cooldown_ctr = self.cooldown;
        self.ammo -= 1;

        return fired;
    }

    fn spawnProjectile(
        self: *SpreadWeapon,
        x: i32,
        y: i32,
        dx: f32,
        dy: f32,
    ) bool {
        for (&self.projectiles) |*proj| {
            if (!proj.active) {
                if (self.projectile_sprites.get()) |sprite| {
                    proj.* = Projectile{
                        .sprite = sprite,
                        .sprite_pool = &self.projectile_sprites,
                        .screen = self.screen,
                        .x = @floatFromInt(x),
                        .y = @floatFromInt(y),
                        .dx = dx,
                        .dy = dy,
                        .active = true,
                    };
                    return true;
                }
            }
        }
        return false;
    }

    pub fn deinit(self: *SpreadWeapon, allocator: std.mem.Allocator) void {
        self.projectile_sprites.deinit(allocator);
    }
};
