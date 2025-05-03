const std = @import("std");
const movy = @import("movy");
const PlayerShip = @import("PlayerShip.zig").PlayerShip;
const ShieldManager = @import("ShieldManager.zig").ShieldManager;
const GameStateManager = @import("GameStateManager.zig").GameStateManager;
const ExplosionManager = @import("ExplosionManager.zig").ExplosionManager;
const ExplosionType = @import("ExplosionManager.zig").ExplosionType;
const ObstacleManager = @import("ObstacleManager.zig").ObstacleManager;
const VisualsManager = @import("VisualsManager.zig").VisualsManager;
const StatusWindow = @import("StatusWindow.zig").StatusWindow;
const Sprite = movy.graphic.Sprite;

const Lives = 5;

pub const GameManager = struct {
    player: PlayerShip,
    gamestate: GameStateManager,
    shields: *ShieldManager,
    exploder: *ExplosionManager,
    obstacles: *ObstacleManager,
    visuals: VisualsManager,
    statuswin: StatusWindow,
    screen: *movy.Screen,
    frame_counter: usize = 0,

    msgbuf: [1024]u8 = [_]u8{0} ** 1024,
    message: []const u8 = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !GameManager {
        return GameManager{
            .player = try PlayerShip.init(allocator, screen, Lives),
            .gamestate = GameStateManager.init(),
            .statuswin = try StatusWindow.init(
                allocator,
                16,
                8,
                movy.color.DARK_BLUE,
                movy.color.GRAY,
            ),
            .visuals = VisualsManager.init(allocator, screen),
            .exploder = try ExplosionManager.init(allocator, screen),
            .obstacles = try ObstacleManager.init(allocator, screen),
            .shields = try ShieldManager.init(allocator, screen),
            .screen = screen,
        };
    }

    pub fn deinit(self: *GameManager, allocator: std.mem.Allocator) void {
        self.player.deinit(allocator);
        self.exploder.deinit(allocator);
        self.obstacles.deinit(allocator);
    }

    pub fn onKeyDown(self: *GameManager, key: movy.input.Key) void {
        if (!self.player.ship.visible) return;

        self.player.onKeyDown(key);
        // switch weapon key
        if (key.type == .Char and key.sequence[0] == 'w') {
            self.switchWeapon();
        }

        // shield key
        if (key.type == .Char and key.sequence[0] == 's') {
            self.shields.activate(.Default);
        }
    }

    pub fn onKeyUp(self: *GameManager, key: movy.input.Key) void {
        self.player.onKeyUp(key);
    }

    pub fn update(self: *GameManager) !void {

        // Handle game logic depending on state
        switch (self.gamestate.state) {
            .FadeIn => {
                self.player.ship.visible = false;
                try self.obstacles.update();
                try self.exploder.update();
                // maybe animate screen brightness here
            },
            .StartingInvincible, .AlmostVulnerable, .Playing => {
                if (self.gamestate.justTransitioned()) {
                    self.player.ship.visible = true;
                    if (self.gamestate.state == .Playing) {
                        self.shields.activate(.None);
                    }
                    if (self.gamestate.state == .StartingInvincible) {
                        self.shields.activate(.Default);
                        self.shields.default_shield.cooldown_ctr = 500;
                    }
                    if (self.gamestate.state == .AlmostVulnerable) {
                        // self.shields.activate(.Default);
                        // self.shields.default_shield.cooldown_ctr = 300;
                    }
                }
                try self.player.update();
                try self.shields.update(
                    self.player.ship.x,
                    self.player.ship.y,
                );
                try self.exploder.update();
                try self.obstacles.update();
                self.doProjectileCollisions();
                if (self.gamestate.state == .Playing) {
                    if (self.shields.active_shield == .None) {
                        self.doShipCollision();
                    }
                }
            },
            .Dying,
            => {
                if (self.gamestate.justTransitioned()) {
                    self.player.lives -= 1;
                    self.player.ship.visible = false;
                    self.player.controller.reset();
                    self.shields.reset();
                }
                try self.player.weapon_manager.update(); // for projectiles
                try self.exploder.update();
                try self.obstacles.update();
                self.doProjectileCollisions();
            },
            .Respawning,
            => {
                // transition start
                if (self.player.lives == 0) {
                    self.gamestate.transitionTo(.FadeToGameOver);
                }
                try self.player.weapon_manager.update(); // for projectiles
                try self.exploder.update();
                try self.obstacles.update();
                self.doProjectileCollisions();
            },
            .FadeToGameOver => {},
            .GameOver => {
                // freeze everything
                self.gamestate.transitionTo(.FadeIn);
                self.player.lives = Lives;
            },
            .Paused => {
                // don't update anything except screen dimming, pause visuals
            },
            else => {},
        }
        self.visuals.update(self.frame_counter);

        // Update state transitions or timers
        self.gamestate.update(self.frame_counter);

        self.frame_counter += 1;
    }

    // -- render
    pub fn renderFrame(self: *GameManager) !void {
        try self.screen.renderInit();
        try self.exploder.addRenderSurfaces();
        try self.player.weapon_manager.addRenderSurfaces();
        try self.shields.addRenderSurfaces();
        try self.obstacles.addRenderSurfaces();
        try self.player.ship.addRenderSurfaces();
        self.screen.render();

        try self.visuals.render();

        self.message = try std.fmt.bufPrint(
            &self.msgbuf,
            "GameState: {s:>20} || Shield: {s} | Shield Cooldown: {d} || Frame: {d}",
            .{
                @tagName(self.gamestate.state),
                @tagName(self.shields.active_shield),
                self.shields.getCooldown(),
                self.gamestate.frame_counter,
            },
        );
        _ = self.screen.output_surface.putStrXY(
            self.message,
            0,
            0,
            movy.color.LIGHT_BLUE,
            movy.color.BLACK,
        );

        try self.player.setMessage();
        if (self.player.message) |msg| {
            _ = self.screen.output_surface.putStrXY(
                msg,
                0,
                1,
                movy.color.LIGHT_BLUE,
                movy.color.BLACK,
            );
        }
    }

    // -- key commands
    pub fn switchWeapon(self: *GameManager) void {
        if (self.player.weapon_manager.active_weapon == .Default) {
            self.player.weapon_manager.active_weapon = .Spread;
            self.player.weapon_manager.spread_weapon.ammo = 50;
        } else {
            self.player.weapon_manager.active_weapon = .Default;
        }
    }

    // -- collision logic

    // check collision of a with inset bounds of b
    inline fn checkCollision(a: *Sprite, b: *Sprite, inset: i32) bool {
        const a_w: i32 = @as(i32, @intCast(a.w));
        const a_h: i32 = @as(i32, @intCast(a.h));
        const b_w: i32 = @as(i32, @intCast(b.w));
        const b_h: i32 = @as(i32, @intCast(b.h));

        return a.x < b.x + b_w - inset and
            a.x + a_w > b.x + inset and
            a.y < b.y + b_h - inset and
            a.y + a_h > b.y + inset;
    }

    // check collision of a with individual inset bounds for a(x/y) and b
    inline fn checkCollisionShip(
        a: *Sprite,
        b: *Sprite,
        inset_ship_x: i32,
        inset_ship_y: i32,
        inset: i32,
    ) bool {
        const a_w: i32 = @as(i32, @intCast(a.w));
        const a_h: i32 = @as(i32, @intCast(a.h));
        const b_w: i32 = @as(i32, @intCast(b.w));
        const b_h: i32 = @as(i32, @intCast(b.h));

        var rv = a.x + inset_ship_x < b.x + b_w - inset and
            a.x + a_w - inset_ship_x > b.x + inset and
            a.y + inset_ship_y < b.y + b_h - inset and
            a.y + a_h - inset_ship_y > b.y + inset;

        // extra check for tip
        if (!rv) {
            const tip_x: i32 = a.x + @divTrunc(a_w, 2);
            rv = tip_x < b.x + b_w - inset * 4 and
                tip_x > b.x + inset * 4 and
                a.y < b.y + b_h - inset and
                a.y + a_h > b.y + inset;
        }

        return rv;
    }

    pub fn doProjectileCollisions(self: *GameManager) void {
        self.doDefaultWeaponCollisions();
        self.doSpreadWeaponCollisions();
    }

    pub fn doShipCollision(self: *GameManager) void {
        // check ship collision with obstacles:
        for (&self.obstacles.active_obstacles) |*obstacle| {
            if (!obstacle.active) continue;

            const coll_inset: i32 = switch (obstacle.kind) {
                .AsteroidSmall => 1,
                .AsteroidBig => 1,
                .AsteroidBig2 => 1,
                .AsteroidHuge => 2,
            };

            // check collision
            if (checkCollisionShip(
                self.player.ship.sprite_ship,
                obstacle.sprite,
                1,
                11,
                coll_inset,
            )) {
                const pos_ship = self.player.ship.getCenterCoords();
                const pos_obs = obstacle.getCenterCoords();

                var sign: i32 = 1;

                if (pos_ship.x < pos_obs.x) {
                    sign = -1;
                }

                self.exploder.tryExplodeDelayed(
                    pos_ship.x - 5 * sign,
                    pos_ship.y - 5,
                    .Small,
                    0,
                ) catch {};

                self.exploder.tryExplodeDelayed(
                    pos_ship.x + 5 * sign,
                    pos_ship.y + 5,
                    .Small,
                    10,
                ) catch {};

                self.exploder.tryExplodeDelayed(
                    pos_ship.x + 5 * sign,
                    pos_ship.y - 5,
                    .Small,
                    20,
                ) catch {};
                self.exploder.tryExplodeDelayed(
                    pos_ship.x - 5 * sign,
                    pos_ship.y + 5,
                    .Small,
                    30,
                ) catch {};

                self.exploder.tryExplodeDelayed(
                    pos_ship.x,
                    pos_ship.y,
                    .Huge,
                    40,
                ) catch {};

                if (obstacle.tryDestroy()) {
                    const exp_type: ExplosionType = switch (obstacle.kind) {
                        .AsteroidSmall => .Big,
                        .AsteroidBig => .Big,
                        .AsteroidBig2 => .Big,
                        .AsteroidHuge => .Huge,
                    };

                    self.exploder.tryExplode(
                        pos_obs.x,
                        pos_obs.y,
                        exp_type,
                    ) catch {};
                }

                self.gamestate.transitionTo(.Dying);
            }
        }
    }

    pub fn doDefaultWeaponCollisions(self: *GameManager) void {
        // for all active projectiles: check collisions with: obstacles, enemies
        for (&self.player.weapon_manager.default_weapon.projectiles) |*proj| {
            if (!proj.active) continue;

            // check obstacle collisions
            for (&self.obstacles.active_obstacles) |*obstacle| {
                if (!obstacle.active) continue;

                const coll_inset: i32 = switch (obstacle.kind) {
                    .AsteroidSmall => 1,
                    .AsteroidBig => 3,
                    .AsteroidBig2 => 3,
                    .AsteroidHuge => 5,
                };

                // check collision
                if (checkCollision(proj.sprite, obstacle.sprite, coll_inset)) {
                    proj.release();
                    const pos_proj = proj.getCenterCoords();
                    self.exploder.tryExplode(
                        pos_proj.x,
                        pos_proj.y,
                        .Small,
                    ) catch {};

                    if (obstacle.tryDestroy()) {
                        const pos_obs = obstacle.getCenterCoords();

                        const exp_type: ExplosionType = switch (obstacle.kind) {
                            .AsteroidSmall => .Big,
                            .AsteroidBig => .Big,
                            .AsteroidBig2 => .Big,
                            .AsteroidHuge => .Huge,
                        };

                        self.exploder.tryExplode(
                            pos_obs.x,
                            pos_obs.y,
                            exp_type,
                        ) catch {};
                    }
                }
            }
        }
    }

    pub fn doSpreadWeaponCollisions(self: *GameManager) void {
        // for all active projectiles: check collisions with: obstacles, enemies
        for (&self.player.weapon_manager.spread_weapon.projectiles) |*proj| {
            if (!proj.active) continue;

            // check obstacle collisions
            for (&self.obstacles.active_obstacles) |*obstacle| {
                if (!obstacle.active) continue;

                const coll_inset: i32 = switch (obstacle.kind) {
                    .AsteroidSmall => 1,
                    .AsteroidBig => 3,
                    .AsteroidBig2 => 3,
                    .AsteroidHuge => 5,
                };

                // check collision
                if (checkCollision(proj.sprite, obstacle.sprite, coll_inset)) {
                    proj.release();
                    const pos_proj = proj.getCenterCoords();
                    self.exploder.tryExplode(
                        pos_proj.x,
                        pos_proj.y,
                        .SmallPurple,
                    ) catch {};

                    if (obstacle.tryDestroy()) {
                        const pos_obs = obstacle.getCenterCoords();

                        const exp_type: ExplosionType = switch (obstacle.kind) {
                            .AsteroidSmall => .Big,
                            .AsteroidBig => .Big,
                            .AsteroidBig2 => .Big,
                            .AsteroidHuge => .Huge,
                        };

                        self.exploder.tryExplode(
                            pos_obs.x,
                            pos_obs.y,
                            exp_type,
                        ) catch {};
                    }
                }
            }
        }
    }
};
