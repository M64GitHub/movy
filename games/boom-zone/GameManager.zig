const std = @import("std");
const movy = @import("movy");
const PlayerShip = @import("PlayerShip.zig").PlayerShip;
const GameStateManager = @import("GameStateManager.zig").GameStateManager;
const StatusWindow = @import("StatusWindow.zig").StatusWindow;
const VisualsManager = @import("VisualsManager.zig").VisualsManager;
const ExplosionManager = @import("ExplosionManager.zig").ExplosionManager;
const ExplosionType = @import("ExplosionManager.zig").ExplosionType;
const ObstacleManager = @import("ObstacleManager.zig").ObstacleManager;
const Sprite = movy.graphic.Sprite;

pub const GameManager = struct {
    player: PlayerShip,
    gamestate: GameStateManager,
    statuswin: StatusWindow,
    visuals: VisualsManager,
    exploder: *ExplosionManager,
    obstacles: *ObstacleManager,
    screen: *movy.Screen,
    frame_counter: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !GameManager {
        return GameManager{
            .player = try PlayerShip.init(allocator, screen),
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
            .screen = screen,
        };
    }

    pub fn deinit(self: *GameManager, allocator: std.mem.Allocator) void {
        self.player.deinit(allocator);
        self.exploder.deinit(allocator);
        self.obstacles.deinit(allocator);
    }

    pub fn onKeyDown(self: *GameManager, key: movy.input.Key) void {
        self.player.onKeyDown(key);
        // switch weapon key
        if (key.type == .Char and key.sequence[0] == 'w') {
            self.switchWeapon();
        }
    }

    pub fn onKeyUp(self: *GameManager, key: movy.input.Key) void {
        self.player.onKeyUp(key);
    }

    pub fn update(self: *GameManager) !void {
        self.frame_counter += 1;

        // Update state transitions or timers
        self.gamestate.update(self.frame_counter);

        // Handle game logic depending on state
        switch (self.gamestate.state) {
            .FadeIn => {
                // maybe animate screen brightness here
            },
            .StartingInvincible, .AlmostVulnerable, .Playing => {
                try self.player.update();
                try self.exploder.update();
                try self.obstacles.update();
                self.doProjectileCollisions();
            },
            .Dying => {
                // maybe play an explosion, freeze player
            },
            .GameOver => {
                // freeze everything
            },
            .Paused => {
                // don't update anything except maybe animations for screen dimming
            },
            else => {},
        }
        self.visuals.update(self.frame_counter);
    }

    // -- render
    pub fn renderFrame(self: *GameManager) !void {
        try self.screen.renderInit();
        try self.exploder.addRenderSurfaces();
        try self.player.weapon_manager.addRendersurfaces();
        try self.obstacles.addRenderSurfaces();
        // renders surface incl player sprite
        try self.screen.renderWithSprites();

        try self.visuals.render();
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

    pub fn doProjectileCollisions(self: *GameManager) void {
        // default weapon projectiles
        self.doDefaultWeaponCollisions();
        self.doSpreadWeaponCollisions();
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
