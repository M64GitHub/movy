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

    msgbuf: [1024]u8 = [_]u8{0} ** 1024,
    message: []const u8 = undefined,

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
        if (!self.player.ship.visible) return;

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
                self.player.ship.visible = false;
                try self.obstacles.update();
                try self.exploder.update();
                // maybe animate screen brightness here
            },
            .StartingInvincible, .AlmostVulnerable, .Playing => {
                self.player.ship.visible = true;
                try self.player.update();
                try self.exploder.update();
                try self.obstacles.update();
                self.doProjectileCollisions();
                if (self.gamestate.state == .Playing)
                    self.doShipCollision();
            },
            .Dying,
            => {
                self.player.ship.visible = false;
                try self.player.weapon_manager.update(); // for weapons / projectiles
                try self.exploder.update();
                try self.obstacles.update();
                self.doProjectileCollisions();
            },
            .Respawning,
            => {
                self.player.ship.visible = false;
                try self.player.weapon_manager.update(); // for weapons / projectiles
                try self.exploder.update();
                try self.obstacles.update();
                self.doProjectileCollisions();
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
        try self.player.ship.addRenderSurfaces();
        self.screen.render();

        try self.visuals.render();

        self.message = try std.fmt.bufPrint(
            &self.msgbuf,
            "GameState: {s}",
            .{
                @tagName(self.gamestate.state),
            },
        );
        _ = self.screen.output_surface.putStrXY(
            self.message,
            0,
            0,
            movy.color.LIGHT_BLUE,
            movy.color.BLACK,
        );

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

    // check collision of a with individual inset bounds for a and b
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
        // default weapon projectiles
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
