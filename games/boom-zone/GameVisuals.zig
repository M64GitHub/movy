const std = @import("std");
const movy = @import("movy");

pub const GameVisual = struct {
    sprite: *movy.Sprite,
    fade_in: usize,
    hold: usize,
    fade_out: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        file_name: []const u8,
        name: []const u8,
        fade_in: usize,
        hold: usize,
        fade_out: usize,
    ) !GameVisual {
        const sprite = try movy.Sprite.initFromPng(allocator, file_name, name);

        return GameVisual{
            .sprite = sprite,
            .fade_in = fade_in,
            .hold = hold,
            .fade_out = fade_out,
        };
    }
};

pub const GameVisuals = struct {
    boom: GameVisual,
    zone: GameVisual,
    paused: GameVisual,
    game: GameVisual,
    over: GameVisual,

    pub fn init(allocator: std.mem.Allocator) !GameVisuals {
        const boom = GameVisual.init(
            allocator,
            "games/boom-zone/assets/boom.png",
            "game",
            50,
            1,
            50,
        );

        const zone = GameVisual.init(
            allocator,
            "games/boom-zone/assets/zone.png",
            "game",
            50,
            1,
            50,
        );

        const game = GameVisual.init(
            allocator,
            "games/boom-zone/assets/game.png",
            "game",
            50,
            1,
            50,
        );

        const over = GameVisual.init(
            allocator,
            "games/boom-zone/assets/over.png",
            "game",
            50,
            1,
            50,
        );
    }

    pub fn deinit(self: *GameVisuals, allocator: std.mem.Allocator) void {}
};
