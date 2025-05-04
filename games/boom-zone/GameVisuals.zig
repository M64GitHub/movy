const std = @import("std");
const movy = @import("movy");

const TimedVisual = @import("TimedVisual.zig").TimedVisual;

pub const GameVisual = struct {
    sprite: *movy.Sprite,
    fade_in: usize,
    hold: usize,
    fade_out: usize,
    visual: ?*TimedVisual = null,

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
    screen: *movy.Screen,
    boom: GameVisual,
    zone: GameVisual,
    paused: GameVisual,
    game: GameVisual,
    over: GameVisual,

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !GameVisuals {
        const boom = try GameVisual.init(
            allocator,
            "games/boom-zone/assets/boom.png",
            "game",
            50,
            1,
            50,
        );
        var pos = screen.getCenterCoords(boom.sprite.w, boom.sprite.h);
        pos.y -= 30;
        boom.sprite.setXY(pos.x, pos.y);

        const zone = try GameVisual.init(
            allocator,
            "games/boom-zone/assets/zone.png",
            "game",
            50,
            1,
            50,
        );
        pos = screen.getCenterCoords(zone.sprite.w, zone.sprite.h);
        zone.sprite.setXY(pos.x, pos.y);

        const paused = try GameVisual.init(
            allocator,
            "games/boom-zone/assets/paused.png",
            "game",
            20,
            1,
            20,
        );
        pos = screen.getCenterCoords(paused.sprite.w, paused.sprite.h);
        paused.sprite.setXY(pos.x, pos.y);

        const game = try GameVisual.init(
            allocator,
            "games/boom-zone/assets/game.png",
            "game",
            50,
            1,
            50,
        );
        pos = screen.getCenterCoords(game.sprite.w, game.sprite.h);
        pos.y -= 20;
        game.sprite.setXY(pos.x, pos.y);

        const over = try GameVisual.init(
            allocator,
            "games/boom-zone/assets/over.png",
            "game",
            50,
            1,
            50,
        );
        pos = screen.getCenterCoords(over.sprite.w, over.sprite.h);
        pos.y += 20;
        over.sprite.setXY(pos.x, pos.y);

        return GameVisuals{
            .screen = screen,
            .boom = boom,
            .zone = zone,
            .game = game,
            .over = over,
            .paused = paused,
        };
    }

    pub fn deinit(self: *GameVisuals, allocator: std.mem.Allocator) void {
        self.boom.sprite.deinit(allocator);
        self.zone.sprite.deinit(allocator);
        self.game.sprite.deinit(allocator);
        self.over.sprite.deinit(allocator);
        self.paused.sprite.deinit(allocator);
    }
};
