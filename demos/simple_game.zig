// Simple Game Starter
//
// - Fullscreen movy init
// - Sprite sheet + animation handling
// - Subpixel obstacle movement
// - Shooting & collision detection
// - Overlay text rendering
// - Smooth 60 FPS (adjustable)

const std = @import("std");
const movy = @import("movy");

const PLAYER_SPEED: i32 = 3;
const PLAYER_START_X: i32 = 68;
const PLAYER_START_Y: i32 = 60;

const PROJECTILE_SPEED: i32 = 4;
const MAX_PROJECTILES: usize = 10;

const OBSTACLE_SPEED: i32 = 60; // of 100

const POINTS_PER_HIT: usize = 100;

const Player = struct {
    sprite: *movy.graphic.Sprite,
    x: i32,
    y: i32,
    moving_left: bool = false,
    moving_right: bool = false,
    moving_up: bool = false,
    moving_down: bool = false,
    current_anim: []const u8 = "idle",
    screen: *movy.Screen, // for dimensions

    pub fn init(allocator: std.mem.Allocator, screen: *movy.Screen) !Player {
        var sprite = try movy.graphic.Sprite.initFromPng(
            allocator,
            "demos/assets/playership.png",
            "player",
        );
        try sprite.splitByWidth(allocator, 24); // 24px wide frames

        // Set up animations
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
            .{ .name = "left", .start = 4, .end = 5, .mode = .once, .speed = 2 },
            .{ .name = "left-hold", .start = 5, .end = 5, .mode = .loopForward, .speed = 2 },
            .{ .name = "left-return", .start = 4, .end = 4, .mode = .once, .speed = 2 },
            .{ .name = "right", .start = 2, .end = 3, .mode = .once, .speed = 2 },
            .{ .name = "right-hold", .start = 3, .end = 3, .mode = .loopForward, .speed = 2 },
            .{ .name = "right-return", .start = 2, .end = 2, .mode = .once, .speed = 2 },
        };

        for (anims) |anim_def| {
            const frame_anim = movy.graphic.Sprite.FrameAnimation.init(
                anim_def.start,
                anim_def.end,
                anim_def.mode,
                anim_def.speed,
            );
            try sprite.addAnimation(
                allocator,
                anim_def.name,
                frame_anim,
            );
        }

        try sprite.startAnimation("idle");

        return Player{
            .sprite = sprite,
            .x = PLAYER_START_X,
            .y = PLAYER_START_Y,
            .screen = screen,
        };
    }

    pub fn update(self: *Player) void {
        // Update animation based on movement state
        const new_anim: []const u8 =
            if (self.moving_left and self.moving_right) blk: {
                break :blk "idle";
            } else if (self.moving_left) blk: {
                break :blk "left-hold";
            } else if (self.moving_right) blk: {
                break :blk "right-hold";
            } else blk: {
                // Returning to idle
                if (std.mem.eql(u8, self.current_anim, "left-hold")) {
                    break :blk "left-return";
                } else if (std.mem.eql(u8, self.current_anim, "right-hold")) {
                    break :blk "right-return";
                } else {
                    break :blk "idle";
                }
            };

        if (!std.mem.eql(u8, self.current_anim, new_anim)) {
            self.sprite.startAnimation(new_anim) catch {};
            self.current_anim = new_anim;
        }

        self.sprite.stepActiveAnimation();

        // Apply movement
        if (self.moving_left and !self.moving_right) {
            self.x -= PLAYER_SPEED;
        }
        if (self.moving_right and !self.moving_left) {
            self.x += PLAYER_SPEED;
        }
        if (self.moving_up and !self.moving_down) {
            self.y -= PLAYER_SPEED;
        }
        if (self.moving_down and !self.moving_up) {
            self.y += PLAYER_SPEED;
        }

        // (avoid) casting hell ;)
        const screen_width: i32 = @intCast(self.screen.w);
        const screen_height: i32 = @intCast(self.screen.h);

        // Keep player on screen
        if (self.x < 0) self.x = 0;
        if (self.x > screen_width - 24) self.x = screen_width - 24;
        if (self.y < 0) self.y = 0;
        if (self.y > screen_height - 24) self.y = screen_height - 24;

        // set position always after getCurrentFrameSurface
        self.sprite.setXY(self.x, self.y);
    }

    pub fn getCenterX(self: *const Player) i32 {
        return self.x + 12; // half of 24px width
    }

    pub fn getCenterY(self: *const Player) i32 {
        return self.y + 12; // half of 24px height
    }

    pub fn deinit(self: *Player, allocator: std.mem.Allocator) void {
        self.sprite.deinit(allocator);
    }
};

const Projectile = struct {
    sprite: *movy.graphic.Sprite,
    x: i32,
    y: i32,
    active: bool = false,

    pub fn activate(self: *Projectile, x: i32, y: i32) void {
        self.active = true;
        self.x = x;
        self.y = y;
        self.sprite.setXY(self.x, self.y);
    }

    pub fn update(self: *Projectile) void {
        if (!self.active) return;

        self.y -= PROJECTILE_SPEED;
        self.sprite.stepActiveAnimation();
        self.sprite.setXY(self.x, self.y);

        // Deactivate if off screen
        if (self.y < -8) {
            self.active = false;
        }
    }

    pub fn getCenterX(self: *const Projectile) i32 {
        return self.x + 4; // half of 8px width
    }

    pub fn getCenterY(self: *const Projectile) i32 {
        return self.y + 4; // half of 8px height
    }
};

const Obstacle = struct {
    sprite: *movy.graphic.Sprite,
    x: i32,
    y: i32,
    speed_adder: usize,
    speed_value: usize,
    speed_threshold: usize,
    screen: *movy.Screen,

    pub fn update(self: *Obstacle, random: std.Random) void {
        // subpixel movement
        self.speed_value += self.speed_adder;
        while (self.speed_value >= self.speed_threshold) {
            self.speed_value -= self.speed_threshold;
            self.y += 1;
        }
        self.sprite.stepActiveAnimation();
        self.sprite.setXY(self.x, self.y);

        const screen_width: i32 = @intCast(self.screen.w);

        // Respawn at top if off screen
        if (self.y > self.screen.h) {
            self.x = random.intRangeAtMost(i32, 0, screen_width - 16);
            self.y = -16;
        }
    }

    pub fn getCenterX(self: *const Obstacle) i32 {
        return self.x + 8; // approximate center for small asteroid
    }

    pub fn getCenterY(self: *const Obstacle) i32 {
        return self.y + 8;
    }
};

const Game = struct {
    allocator: std.mem.Allocator,
    player: Player,
    projectiles: [MAX_PROJECTILES]Projectile,
    obstacle: Obstacle,
    score: usize = 0,
    game_over: bool = false,
    random: std.Random,
    screen: *movy.Screen,

    pub fn init(allocator: std.mem.Allocator, screen: *movy.Screen) !Game {
        const player = try Player.init(allocator, screen);

        // Initialize projectiles
        var projectiles: [MAX_PROJECTILES]Projectile = undefined;
        for (&projectiles) |*proj| {
            const proj_sprite = try movy.graphic.Sprite.initFromPng(
                allocator,
                "demos/assets/projectiles_orange.png",
                "projectile",
            );
            try proj_sprite.splitByWidth(allocator, 8); // 8px wide frames
            const proj_anim =
                movy.graphic.Sprite.FrameAnimation.init(1, 6, .loopForward, 1);
            try proj_sprite.addAnimation(allocator, "fly", proj_anim);
            try proj_sprite.startAnimation("fly");

            proj.* = Projectile{
                .sprite = proj_sprite,
                .x = 0,
                .y = 0,
                .active = false,
            };
        }

        // Initialize obstacle
        const obs_sprite = try movy.graphic.Sprite.initFromPng(
            allocator,
            "demos/assets/asteroid_small.png",
            "asteroid",
        );
        try obs_sprite.splitByWidth(allocator, 16); // 16px wide frames
        const obs_anim = movy.graphic.Sprite.FrameAnimation.init(1, 6, .loopForward, 2);
        try obs_sprite.addAnimation(allocator, "spin", obs_anim);
        try obs_sprite.startAnimation("spin");

        // Initialize random number generator
        var prng =
            std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const random = prng.random();

        const screen_width: i32 = @intCast(screen.w);

        const obstacle = Obstacle{
            .sprite = obs_sprite,
            .x = random.intRangeAtMost(i32, 0, screen_width - 16),
            .y = -16,
            .speed_adder = OBSTACLE_SPEED,
            .speed_value = 0,
            .speed_threshold = 100,
            .screen = screen,
        };

        return Game{
            .allocator = allocator,
            .player = player,
            .projectiles = projectiles,
            .obstacle = obstacle,
            .random = random,
            .screen = screen,
        };
    }

    pub fn update(self: *Game) void {
        if (self.game_over) return;

        // Update player
        self.player.update();

        // Update projectiles
        for (&self.projectiles) |*proj| {
            proj.update();
        }

        // Update obstacle
        self.obstacle.update(self.random);

        // Check collisions
        self.checkCollisions();
    }

    pub fn fireProjectile(self: *Game) void {
        // Find inactive projectile
        for (&self.projectiles) |*proj| {
            if (!proj.active) {
                const x = self.player.getCenterX() - 4; // center on player
                const y = self.player.y;
                proj.activate(x, y);
                return;
            }
        }
    }

    fn checkCollisions(self: *Game) void {
        // Check projectile-obstacle collisions
        for (&self.projectiles) |*proj| {
            if (!proj.active) continue;

            const dx = proj.getCenterX() - self.obstacle.getCenterX();
            const dy = proj.getCenterY() - self.obstacle.getCenterY();
            const dist_sq = dx * dx + dy * dy;

            const screen_width: i32 = @intCast(self.screen.w);

            // Collision if distance < 12 pixels (combined radii)
            if (dist_sq < 144) {
                proj.active = false;
                // Respawn obstacle at top
                self.obstacle.x =
                    self.random.intRangeAtMost(i32, 0, screen_width - 16);
                self.obstacle.y = -16;
                self.score += POINTS_PER_HIT;
                break;
            }
        }

        // Check player-obstacle collision
        const dx = self.player.getCenterX() - self.obstacle.getCenterX();
        const dy = self.player.getCenterY() - self.obstacle.getCenterY();
        const dist_sq = dx * dx + dy * dy;

        // Collision if distance < 16 pixels
        if (dist_sq < 256) {
            self.game_over = true;
        }
    }

    pub fn render(self: *Game) !void {
        // Clear screen's surfaces
        try self.screen.renderInit();

        // Add player sprite
        try self.screen.addRenderSurface(
            try self.player.sprite.getCurrentFrameSurface(),
        );

        // Add active projectiles
        for (&self.projectiles) |*proj| {
            if (proj.active) {
                try self.screen.addRenderSurface(
                    try proj.sprite.getCurrentFrameSurface(),
                );
            }
        }

        // Add obstacle
        try self.screen.addRenderSurface(
            try self.obstacle.sprite.getCurrentFrameSurface(),
        );

        // render the graphics
        self.screen.render();

        // Add score text
        const score_buf = try std.fmt.allocPrint(
            self.allocator,
            "SCORE: {d}",
            .{self.score},
        );
        defer self.allocator.free(score_buf);

        // now add text onto the rendered image
        _ = self.screen.output_surface.putStrXY(
            score_buf,
            2,
            2,
            movy.color.WHITE,
            movy.color.BLACK,
        );

        // Add game over text if needed
        if (self.game_over) {
            const game_over_text = "GAME OVER - Press ESC to exit";

            const text_x = @divTrunc(self.screen.w, 2) -
                @as(i32, @intCast(game_over_text.len / 2));
            // Middle of visible area (h/2 rows, so h/4 is center)
            const text_y = @divTrunc(self.screen.h, 4);

            _ = self.screen.output_surface.putStrXY(
                game_over_text,
                @intCast(text_x),
                @intCast(text_y),
                movy.color.RED,
                movy.color.BLACK,
            );

            const final_score = try std.fmt.allocPrint(
                self.allocator,
                "Final Score: {d}",
                .{self.score},
            );
            defer self.allocator.free(final_score);

            const screen_width: i32 = @intCast(self.screen.w);

            const score_x = @divTrunc(screen_width, 2) -
                @as(i32, @intCast(final_score.len / 2));

            _ = self.screen.output_surface.putStrXY(
                final_score,
                @intCast(score_x),
                @intCast(text_y + 2),
                movy.color.WHITE,
                movy.color.BLACK,
            );
        }
    }

    pub fn deinit(self: *Game) void {
        self.player.deinit(self.allocator);
        for (&self.projectiles) |*proj| {
            proj.sprite.deinit(self.allocator);
        }
        self.obstacle.sprite.deinit(self.allocator);
    }
};

// -- MAIN

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // -- Init terminal and screen
    // Get the terminal size
    const terminal_size = try movy.terminal.getSize();

    // Set raw mode, switch to alternate screen
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // -- Initialize screen (height in line numbers)
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );

    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // -- Initialize game
    var game = try Game.init(allocator, &screen);
    defer game.deinit();

    // -- Game loop
    var frame_counter: usize = 0;
    const frame_delay_ns = 17 * std.time.ns_per_ms; // ~60 FPS

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Handle input
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    switch (key.type) {
                        .Escape => break,
                        .Left => game.player.moving_left = true,
                        .Right => game.player.moving_right = true,
                        .Up => game.player.moving_up = true,
                        .Down => game.player.moving_down = true,
                        .Char => {
                            if (key.sequence.len > 0 and key.sequence[0] == ' ') {
                                if (!game.game_over) {
                                    game.fireProjectile();
                                }
                            }
                        },
                        else => {},
                    }
                },
                .mouse => {}, // Ignore mouse input
            }
        } else {
            // No input - reset movement flags
            game.player.moving_left = false;
            game.player.moving_right = false;
            game.player.moving_up = false;
            game.player.moving_down = false;
        }

        // Update game state
        game.update();

        // Render frame
        try game.render();
        try screen.output();

        frame_counter += 1;

        // Frame timing
        const frame_end = std.time.nanoTimestamp();
        const frame_time = frame_end - frame_start;
        if (frame_time < frame_delay_ns) {
            std.time.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
