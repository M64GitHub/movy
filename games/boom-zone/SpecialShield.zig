const std = @import("std");
const movy = @import("movy");
const Sprite = movy.graphic.Sprite;

pub const SpecialShield = struct {
    screen: *movy.Screen,
    cooldown: usize = 6,
    cooldown_ctr: usize = 0,
    sprite: *movy.Sprite = undefined,
    x: i32 = 0,
    y: i32 = 0,
    active: bool = false,
    mode: Mode = .Normal,

    pub const Cooldown: usize = 1000;
    pub const Warn1: usize = 300;
    pub const Warn2: usize = 100;

    pub const Mode = enum {
        Normal,
        Warn1,
        Warn2,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*SpecialShield {
        const self = try allocator.create(SpecialShield);
        self.* = SpecialShield{
            .screen = screen,
            .cooldown_ctr = 0,
            .cooldown = Cooldown,
            .active = false,
        };

        const sprite = try movy.graphic.Sprite.initFromPng(
            allocator,
            "games/boom-zone/assets/shield_green_24.png",
            "special shield",
        );

        try sprite.splitByWidth(allocator, 24);

        try sprite.addAnimation(
            allocator,
            "idle",
            movy.graphic.Sprite.FrameAnimation.init(
                1,
                2,
                .loopForward,
                2,
            ),
        );
        try sprite.addAnimation(
            allocator,
            "warn1",
            movy.graphic.Sprite.FrameAnimation.init(
                3,
                4,
                .loopForward,
                4,
            ),
        );
        try sprite.addAnimation(
            allocator,
            "warn2",
            movy.graphic.Sprite.FrameAnimation.init(
                5,
                6,
                .loopForward,
                1,
            ),
        );

        try sprite.startAnimation("idle");
        self.sprite = sprite;

        return self;
    }

    pub fn reset(self: *SpecialShield) void {
        self.cooldown_ctr = Cooldown;
        self.active = false;
        self.sprite.startAnimation("idle") catch {};
        self.mode = .Normal;
    }

    pub fn update(self: *SpecialShield, x: i32, y: i32) void {
        if (!self.active) return;

        if (self.cooldown_ctr > 0) {
            self.cooldown_ctr -= 1;
            if (self.mode == .Normal and self.cooldown_ctr < Warn1) {
                self.mode = .Warn1;
                self.sprite.startAnimation("warn1") catch {};
            }
            if (self.mode == .Warn1 and self.cooldown_ctr < Warn2) {
                self.mode = .Warn2;
                self.sprite.startAnimation("warn2") catch {};
            }
        }

        self.sprite.stepActiveAnimation();
        self.sprite.setXY(x, y);

        if (self.cooldown_ctr == 0) {
            self.reset();
        }
    }

    pub fn addRenderSurfaces(self: *SpecialShield) !void {
        if (self.active)
            try self.screen.addRenderSurface(
                try self.sprite.getCurrentFrameSurface(),
            );
    }

    pub fn deinit(self: *SpecialShield, allocator: *std.mem.Allocator) void {
        self.sprite.deinit(allocator);
    }
};
