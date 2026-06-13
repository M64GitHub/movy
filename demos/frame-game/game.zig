//! Game orchestrator: owns the level, player, camera and enemies; steps the
//! world each frame and composites the scene. The app-level state machine
//! (title / playing / paused) lives in main.zig; this is the world itself.

const std = @import("std");
const cfg = @import("config.zig");
const pal = @import("pal.zig");
const movy = @import("movy");
const camera = @import("camera.zig");
const level = @import("level.zig");
const player = @import("player.zig");
const input = @import("input.zig");

// The level as ASCII art. '#'=solid '='=platform '@'=spawn 'o'=enemy, else air.
// Edit freely - initFromAscii takes the width from the first row.
const LEVEL_DATA = [_][]const u8{
    "............................................",
    "............................................",
    "............................................",
    "................======......................",
    "............................................",
    "........=====...............................",
    "............................................",
    "............................................",
    ".............................======.........",
    "..@.........................................",
    "....................................####....",
    ".................o......o...........####....",
    "###########################..###############",
};

/// A simple ground patroller: walks until it hits a wall or a ledge, then
/// turns around. Stomp it from above; it hurts you from the side.
const Enemy = struct {
    active: bool = false,
    x: i32 = 0, // sub-px top-left
    y: i32 = 0,
    dir: i32 = -1,

    const W: i32 = 5;
    const H: i32 = 5;

    inline fn pxX(self: *const Enemy) i32 {
        return @divFloor(self.x, cfg.SUB);
    }
    inline fn pxY(self: *const Enemy) i32 {
        return @divFloor(self.y, cfg.SUB);
    }

    fn update(self: *Enemy, lvl: *const level.Level) void {
        const speed: i32 = 110;
        const old = self.pxX();
        self.x += self.dir * speed;
        const new = self.pxX();
        if (new == old) return;
        // wall ahead?
        if (lvl.rectHitsBody(new, self.pxY(), W, H)) {
            self.x = old * cfg.SUB;
            self.dir = -self.dir;
            return;
        }
        // ledge ahead? (front foot loses solid ground)
        const front = if (self.dir > 0) new + W - 1 else new;
        if (lvl.tileAtPx(front, self.pxY() + H) != .solid) {
            self.x = old * cfg.SUB;
            self.dir = -self.dir;
        }
    }

    fn draw(self: *const Enemy, f: *movy.Frame, cam: *const camera.Camera, t: f32) void {
        const sx = cam.sx(self.pxX());
        const sy = cam.sy(self.pxY());
        const pulse = 0.6 + 0.4 * @sin(t * 4.0);
        f.grect(sx - 1, sy - 1, W + 2, H + 2, pal.ENEMY_GLOW.scale(0.55 * pulse));
        f.rect(sx, sy, W, H, pal.ENEMY_BODY);
        f.hline(sx, sy, W, pal.ENEMY_CORE.scale(0.6)); // bright top
        f.px(sx + (if (self.dir > 0) W - 1 else 0), sy + 2, pal.ENEMY_CORE); // facing eye
    }
};

pub const Game = struct {
    allocator: std.mem.Allocator,
    lvl: level.Level,
    plr: player.Player = .{},
    cam: camera.Camera,
    enemies: [16]Enemy = [_]Enemy{.{}} ** 16,
    enemy_count: usize = 0,
    score: u32 = 0,
    anim_t: f32 = 0,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        const self = try allocator.create(Game);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .lvl = try level.Level.initFromAscii(allocator, &LEVEL_DATA),
            .cam = camera.Camera.init(0x5eed),
        };
        self.plr.spawnAt(self.lvl.spawn_x, self.lvl.spawn_y);

        // place enemies wherever the level art has an 'o'
        for (LEVEL_DATA, 0..) |row, ty| {
            for (row, 0..) |c, tx| {
                if (c == 'o' and self.enemy_count < self.enemies.len) {
                    const e = &self.enemies[self.enemy_count];
                    self.enemy_count += 1;
                    e.* = .{
                        .active = true,
                        .x = @as(i32, @intCast(tx)) * cfg.TILE * cfg.SUB,
                        .y = @as(i32, @intCast(ty)) * cfg.TILE * cfg.SUB,
                        .dir = -1,
                    };
                }
            }
        }

        self.snapCam();
        return self;
    }

    pub fn deinit(self: *Game) void {
        self.lvl.deinit();
        self.allocator.destroy(self);
    }

    fn snapCam(self: *Game) void {
        self.cam.snap(
            @floatFromInt(self.plr.centerX()),
            @floatFromInt(self.plr.centerY()),
            self.lvl.pxW(),
            self.lvl.pxH(),
        );
    }

    fn respawn(self: *Game) void {
        self.plr.spawnAt(self.lvl.spawn_x, self.lvl.spawn_y);
        self.plr.invuln = cfg.INVULN_FRAMES;
        self.snapCam();
        self.cam.addTrauma(0.6);
    }

    fn overlap(p: *const player.Player, e: *const Enemy) bool {
        return p.pxX() < e.pxX() + Enemy.W and p.pxX() + cfg.P_W > e.pxX() and
            p.pxY() < e.pxY() + Enemy.H and p.pxY() + cfg.P_H > e.pxY();
    }

    pub fn update(self: *Game, in: *input.Input) void {
        self.anim_t += 1.0 / 60.0;

        const ev = self.plr.update(in, &self.lvl);
        if (ev.jumped) self.cam.addTrauma(0.06);
        if (ev.landed > 2.0) self.cam.addTrauma(@min(ev.landed * 0.04, 0.30));
        if (ev.died) self.respawn();

        var i: usize = 0;
        while (i < self.enemy_count) : (i += 1) {
            const e = &self.enemies[i];
            if (!e.active) continue;
            e.update(&self.lvl);
            if (!overlap(&self.plr, e)) continue;

            // stomp if descending onto the enemy's head, else take a hit
            if (self.plr.vy > 0 and self.plr.feetY() <= e.pxY() + 2) {
                e.active = false;
                self.plr.vy = cfg.STOMP_BOUNCE_V;
                self.score += 100;
                self.cam.addTrauma(0.25);
            } else if (self.plr.invuln == 0) {
                self.plr.vx = -self.plr.facing * 320;
                self.plr.vy = -300;
                self.plr.invuln = cfg.INVULN_FRAMES;
                self.cam.addTrauma(0.40);
            }
        }

        self.cam.update(
            @floatFromInt(self.plr.centerX()),
            @floatFromInt(self.plr.centerY()),
            self.plr.facing,
            self.lvl.pxW(),
            self.lvl.pxH(),
        );
    }

    pub fn render(self: *Game, f: *movy.Frame) void {
        // background gradient - fills the whole frame, which also clears
        // last frame's `solid` pixels (the glow buffer is managed separately)
        var y: i32 = 0;
        while (y < f.h) : (y += 1) {
            const ny = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(f.h - 1));
            f.hline(0, y, f.w, pal.BG_TOP.lerp(pal.BG_BOT, ny));
        }

        self.lvl.render(f, &self.cam);

        var i: usize = 0;
        while (i < self.enemy_count) : (i += 1) {
            if (self.enemies[i].active) self.enemies[i].draw(f, &self.cam, self.anim_t);
        }

        self.plr.render(f, &self.cam);
    }
};
