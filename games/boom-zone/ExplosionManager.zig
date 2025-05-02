const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;

pub const ExplosionType = enum {
    Small,
    SmallPurple,
    Big,
    BigBlu,
    Huge,
    HugeBlu,
};

pub const Explosion = struct {
    sprite: *Sprite = undefined,
    x: i32 = 0,
    y: i32 = 0,
    active: bool = false,
    explosion_type: ExplosionType = .Big,
    delay: usize = 0,
    alive: usize = 0,

    pub fn update(self: *Explosion) void {
        self.sprite.stepActiveAnimation();
        self.sprite.setXY(self.x, self.y);

        if (self.sprite.finishedActiveAnimation()) {
            self.active = false;
        }
    }

    pub fn getCenterOffset(self: *Explosion) struct { x: i32, y: i32 } {
        const s_w: i32 = @as(i32, @intCast(self.sprite.w));
        const s_h: i32 = @as(i32, @intCast(self.sprite.h));

        const x = @divTrunc(s_w, 2);
        const y = @divTrunc(s_h, 2);

        return .{ .x = x, .y = y };
    }
};

pub const ExplosionManager = struct {
    screen: *movy.Screen,
    small_pool: movy.graphic.SpritePool,
    small_purple_pool: movy.graphic.SpritePool,
    big_pool: movy.graphic.SpritePool,
    big_blu_pool: movy.graphic.SpritePool,
    huge_pool: movy.graphic.SpritePool,
    huge_blu_pool: movy.graphic.SpritePool,
    active_explosions: [MaxExplosions]Explosion,

    pub const MaxExplosions = 32;

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*ExplosionManager {
        const self = try allocator.create(ExplosionManager);
        self.* = ExplosionManager{
            .screen = screen,
            .small_pool = movy.graphic.SpritePool.init(allocator),
            .small_purple_pool = movy.graphic.SpritePool.init(allocator),
            .big_pool = movy.graphic.SpritePool.init(allocator),
            .big_blu_pool = movy.graphic.SpritePool.init(allocator),
            .huge_pool = movy.graphic.SpritePool.init(allocator),
            .huge_blu_pool = movy.graphic.SpritePool.init(allocator),
            .active_explosions = [_]Explosion{.{ .active = false }} **
                MaxExplosions,
        };

        try self.initSprites(allocator);
        return self;
    }

    fn initSprites(
        self: *ExplosionManager,
        allocator: std.mem.Allocator,
    ) !void {
        const small_path = "games/boom-zone/assets/explosion_small.png";
        const small_purple_path = "games/boom-zone/assets/explosion_small_purple.png";
        const big_path = "games/boom-zone/assets/explosion_big.png";
        const big_blu_path = "games/boom-zone/assets/explosion_big_ship.png";
        const huge_path = "games/boom-zone/assets/explosion_huge.png";
        const huge_blu_path = "games/boom-zone/assets/explosion_huge_blu.png";
        const small_frames = 15;
        const big_frames = 15;
        const huge_frames = 15;

        for (0..MaxExplosions) |_| {
            // small
            var s = try Sprite.initFromPng(
                allocator,
                small_path,
                "small_explosion",
            );
            try s.splitByWidth(allocator, 16);
            try s.addAnimation(
                allocator,
                "explode",
                Sprite.FrameAnimation.init(1, small_frames, .once, 1),
            );
            try self.small_pool.addSprite(s);

            // small
            s = try Sprite.initFromPng(
                allocator,
                small_purple_path,
                "small_explosion_purple",
            );
            try s.splitByWidth(allocator, 16);
            try s.addAnimation(
                allocator,
                "explode",
                Sprite.FrameAnimation.init(1, small_frames, .once, 1),
            );
            try self.small_purple_pool.addSprite(s);

            // big
            var b = try Sprite.initFromPng(
                allocator,
                big_path,
                "big_explosion",
            );
            try b.splitByWidth(allocator, 32);
            try b.addAnimation(
                allocator,
                "explode",
                Sprite.FrameAnimation.init(1, big_frames, .once, 1),
            );
            try self.big_pool.addSprite(b);

            // big, blu
            b = try Sprite.initFromPng(
                allocator,
                big_blu_path,
                "big_ship_explosion",
            );
            try b.splitByWidth(allocator, 32);
            try b.addAnimation(
                allocator,
                "explode",
                Sprite.FrameAnimation.init(1, big_frames, .once, 1),
            );
            try self.big_blu_pool.addSprite(b);

            // huge
            var h = try Sprite.initFromPng(
                allocator,
                huge_path,
                "huge_explosion",
            );
            try h.splitByWidth(allocator, 50);
            try h.addAnimation(
                allocator,
                "explode",
                Sprite.FrameAnimation.init(1, huge_frames, .once, 1),
            );
            try self.huge_pool.addSprite(h);

            // huge, blu
            h = try Sprite.initFromPng(
                allocator,
                huge_blu_path,
                "huge_blu_explosion",
            );
            try h.splitByWidth(allocator, 50);
            try h.addAnimation(
                allocator,
                "explode",
                Sprite.FrameAnimation.init(1, huge_frames, .once, 1),
            );
            try self.huge_blu_pool.addSprite(h);
        }
    }

    pub fn tryExplodeDelayed(
        self: *ExplosionManager,
        x: i32,
        y: i32,
        kind: ExplosionType,
        delay: usize,
    ) !void {
        const sprite = switch (kind) {
            .Small => self.small_pool.get(),
            .SmallPurple => self.small_purple_pool.get(),
            .Big => self.big_pool.get(),
            .BigBlu => self.big_blu_pool.get(),
            .Huge => self.huge_pool.get(),
            .HugeBlu => self.huge_blu_pool.get(),
        } orelse return;

        try sprite.startAnimation("explode");
        sprite.setXY(x, y);

        for (&self.active_explosions) |*exp| {
            if (!exp.active) {
                exp.* = Explosion{
                    .sprite = sprite,
                    .x = x,
                    .y = y,
                    .active = true,
                    .explosion_type = kind,
                    .alive = 0,
                    .delay = delay,
                };

                var pos = exp.getCenterOffset();
                pos.x = x - pos.x;
                pos.y = y - pos.y;

                exp.x = pos.x;
                exp.y = pos.y;
                sprite.setXY(pos.x, pos.y);

                break;
            }
        }
    }

    pub fn tryExplode(
        self: *ExplosionManager,
        x: i32,
        y: i32,
        kind: ExplosionType,
    ) !void {
        try self.tryExplodeDelayed(x, y, kind, 0);
    }

    pub fn update(self: *ExplosionManager) !void {
        for (&self.active_explosions) |*exp| {
            if (exp.active) {
                // delay first
                if (exp.alive < exp.delay) {
                    exp.alive += 1;
                    continue;
                }
                exp.update();
                if (!exp.active) {
                    // release back to correct pool
                    switch (exp.explosion_type) {
                        .Small => self.small_pool.release(exp.sprite),
                        .SmallPurple => self.small_purple_pool.release(exp.sprite),
                        .Big => self.big_pool.release(exp.sprite),
                        .BigBlu => self.big_blu_pool.release(exp.sprite),
                        .Huge => self.huge_pool.release(exp.sprite),
                        .HugeBlu => self.huge_blu_pool.release(exp.sprite),
                    }
                }
            }
        }
    }

    pub fn addRenderSurfaces(self: *ExplosionManager) !void {
        for (&self.active_explosions) |*exp| {
            if (exp.active) {
                if (exp.active) {
                    if (exp.alive < exp.delay) {
                        continue;
                    }
                    try self.screen.addRenderSurface(
                        try exp.sprite.getCurrentFrameSurface(),
                    );
                }
            }
        }
    }

    pub fn deinit(self: *ExplosionManager, allocator: std.mem.Allocator) void {
        self.small_pool.deinit(allocator);
        self.small_purple_pool.deinit(allocator);
        self.big_pool.deinit(allocator);
        self.big_blu_pool.deinit(allocator);
        self.huge_pool.deinit(allocator);
        self.huge_blu_pool.deinit(allocator);
        allocator.destroy(self);
    }
};
