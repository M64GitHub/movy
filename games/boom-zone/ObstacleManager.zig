const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;

pub const ObstacleType = enum {
    AsteroidSmall,
    AsteroidBig,
    AsteroidHuge,
};

pub const Obstacle = struct {
    sprite: *Sprite = undefined,
    sprite_pool: *movy.graphic.SpritePool = undefined,
    screen: *movy.Screen = undefined,
    damage: usize = 0,
    damage_threshold: usize = 5, // until destroyed
    x: i32 = 0,
    y: i32 = 0,
    kind: ObstacleType = .AsteroidSmall,
    active: bool = false,
    speed: usize = 0,
    speed_ctr: usize = 0,

    pub fn update(self: *Obstacle) void {
        if (self.speed_ctr > 0) {
            self.speed_ctr -= 1;
            return;
        }
        self.speed_ctr = self.speed;
        self.y += 1; // move downward
        self.sprite.stepActiveAnimation();
        self.sprite.setXY(self.x, self.y);

        if (self.y > @as(i32, @intCast(self.screen.h)) or
            self.y < -@as(i32, @intCast(self.sprite.h)) or
            self.x > @as(i32, @intCast(self.screen.w)) or
            self.x < -@as(i32, @intCast(self.sprite.w)))
        {
            self.active = false;
        }
    }

    pub fn getCenterCoords(self: *Obstacle) struct { x: i32, y: i32 } {
        const s_w: i32 = @as(i32, @intCast(self.sprite.w));
        const s_h: i32 = @as(i32, @intCast(self.sprite.h));

        const x = self.sprite.x + @divTrunc(s_w, 2);
        const y = self.sprite.y + @divTrunc(s_h, 2);

        return .{ .x = x, .y = y };
    }

    pub fn tryDestroy(self: *Obstacle) bool {
        if (self.damage < self.damage_threshold) {
            self.damage += 1;
            return false;
        }
        self.active = false;
        self.sprite_pool.release(self.sprite);
        return true;
    }
};

pub const ObstacleManager = struct {
    screen: *movy.Screen,
    asteroids_small_pool: movy.graphic.SpritePool,
    asteroids_big_pool: movy.graphic.SpritePool,
    asteroids_huge_pool: movy.graphic.SpritePool,
    active_obstacles: [MaxObstacles]Obstacle,

    // auto spawn
    target_count: usize = 8,
    spawn_cooldown: u8 = 0,
    spawn_interval: u8 = 50, // spawn every 16 frames
    rng: std.Random.DefaultPrng,

    pub const MaxObstacles = 64;

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*ObstacleManager {
        const self = try allocator.create(ObstacleManager);
        self.* = ObstacleManager{
            .screen = screen,
            .asteroids_small_pool = movy.graphic.SpritePool.init(allocator),
            .asteroids_big_pool = movy.graphic.SpritePool.init(allocator),
            .asteroids_huge_pool = movy.graphic.SpritePool.init(allocator),
            .active_obstacles = [_]Obstacle{.{ .active = false }} **
                MaxObstacles,
            .rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp())),
        };

        try self.initSprites(allocator);
        return self;
    }

    fn initSprites(self: *ObstacleManager, allocator: std.mem.Allocator) !void {
        const small_path = "games/boom-zone/assets/asteroid_small.png";
        const big_path = "games/boom-zone/assets/asteroid_big.png";
        const huge_path = "games/boom-zone/assets/asteroid_huge.png";

        for (0..MaxObstacles) |_| {
            // small
            const s = try Sprite.initFromPng(
                allocator,
                small_path,
                "small_obstacle",
            );
            try s.splitByWidth(allocator, 16);
            try s.addAnimation(
                allocator,
                "rotate",
                Sprite.FrameAnimation.init(1, 6, .loopBounce, 1),
            );
            try self.asteroids_small_pool.addSprite(s);

            // big
            const b = try Sprite.initFromPng(
                allocator,
                big_path,
                "big_obstacle",
            );
            try b.splitByWidth(allocator, 30);
            try b.addAnimation(
                allocator,
                "rotate",
                Sprite.FrameAnimation.init(1, 6, .loopBounce, 2),
            );
            try self.asteroids_big_pool.addSprite(b);

            // huge
            const h = try Sprite.initFromPng(
                allocator,
                huge_path,
                "huge_obstacle",
            );
            try h.splitByWidth(allocator, 48);
            try h.addAnimation(
                allocator,
                "rotate",
                Sprite.FrameAnimation.init(1, 6, .loopBounce, 0),
            );
            try self.asteroids_huge_pool.addSprite(h);
        }
    }

    pub fn trySpawn(
        self: *ObstacleManager,
        x: i32,
        y: i32,
        kind: ObstacleType,
    ) !void {
        const sprite = switch (kind) {
            .AsteroidSmall => self.asteroids_small_pool.get(),
            .AsteroidBig => self.asteroids_big_pool.get(),
            .AsteroidHuge => self.asteroids_huge_pool.get(),
        } orelse return;

        const speed: usize = switch (kind) {
            .AsteroidSmall => 0,
            .AsteroidBig => 1,
            .AsteroidHuge => 2,
        };

        const spritepool: *movy.graphic.SpritePool = switch (kind) {
            .AsteroidSmall => &self.asteroids_small_pool,
            .AsteroidBig => &self.asteroids_big_pool,
            .AsteroidHuge => &self.asteroids_huge_pool,
        };

        const damage_thr: usize = switch (kind) {
            .AsteroidSmall => 3,
            .AsteroidBig => 5,
            .AsteroidHuge => 10,
        };

        try sprite.startAnimation("rotate");
        sprite.setXY(x, y);

        for (&self.active_obstacles) |*obs| {
            if (!obs.active) {
                obs.* = Obstacle{
                    .sprite = sprite,
                    .sprite_pool = spritepool,
                    .screen = self.screen,
                    .x = x,
                    .y = y,
                    .active = true,
                    .kind = kind,
                    .speed = speed,
                    .speed_ctr = 0,
                    .damage = 0,
                    .damage_threshold = damage_thr,
                };
                break;
            }
        }
    }

    pub fn update(self: *ObstacleManager) !void {

        // Automatic asteroid random add
        var count: usize = 0;
        for (self.active_obstacles) |obs| {
            if (obs.active) count += 1;
        }

        if (count < self.target_count) {
            if (self.spawn_cooldown == 0) {
                const rand_x: i32 = self.rng.random().intRangeAtMost(
                    i32,
                    0,
                    @as(i32, @intCast(self.screen.w)),
                );

                const roll = self.rng.random().intRangeLessThan(u8, 0, 10);

                const kind: ObstacleType = switch (roll) {
                    0...5 => ObstacleType.AsteroidSmall, // 6 out of 10
                    6...8 => ObstacleType.AsteroidBig, // 3 out of 10
                    else => ObstacleType.AsteroidHuge, // 1 out of 10
                };

                const y: i32 = switch (kind) {
                    .AsteroidSmall => -16,
                    .AsteroidBig => -30,
                    .AsteroidHuge => -48,
                };

                const x: i32 = switch (kind) {
                    .AsteroidSmall => -8,
                    .AsteroidBig => -16,
                    .AsteroidHuge => -24,
                };

                try self.trySpawn(rand_x + x, y, kind);

                self.spawn_cooldown = self.spawn_interval;
            } else {
                self.spawn_cooldown -= 1;
            }
        }

        for (&self.active_obstacles) |*obs| {
            if (obs.active) {
                obs.update();
                if (!obs.active) {
                    // release sprites of inactive
                    switch (obs.kind) {
                        .AsteroidSmall => self.asteroids_small_pool.release(
                            obs.sprite,
                        ),
                        .AsteroidBig => self.asteroids_big_pool.release(
                            obs.sprite,
                        ),
                        .AsteroidHuge => self.asteroids_huge_pool.release(
                            obs.sprite,
                        ),
                    }
                }
            }
        }
    }

    pub fn addRenderSurfaces(self: *ObstacleManager) !void {
        // add small ones first (-> on top of big ones)
        for (&self.active_obstacles) |*obs| {
            if (obs.active) {
                switch (obs.kind) {
                    .AsteroidSmall => try self.screen.addRenderSurface(
                        try obs.sprite.getCurrentFrameSurface(),
                    ),
                    else => {},
                }
            }
        }

        // add big ones
        for (&self.active_obstacles) |*obs| {
            if (obs.active) {
                switch (obs.kind) {
                    .AsteroidBig => try self.screen.addRenderSurface(
                        try obs.sprite.getCurrentFrameSurface(),
                    ),
                    else => {},
                }
            }
        }

        // add huge ones
        for (&self.active_obstacles) |*obs| {
            if (obs.active) {
                switch (obs.kind) {
                    .AsteroidHuge => try self.screen.addRenderSurface(
                        try obs.sprite.getCurrentFrameSurface(),
                    ),
                    else => {},
                }
            }
        }
    }

    pub fn deinit(self: *ObstacleManager, allocator: std.mem.Allocator) void {
        self.asteroids_small_pool.deinit(allocator);
        self.asteroids_big_pool.deinit(allocator);
        self.asteroids_huge_pool.deinit(allocator);
        allocator.destroy(self);
    }
};
