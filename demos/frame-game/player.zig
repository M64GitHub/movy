//! Player: sub-pixel platforming physics tuned for feel - accel/friction
//! running, fixed snappy jump arc, coyote time, jump buffering, and
//! pixel-stepped collision against the tile world (so you never tunnel
//! through a wall at speed). Position is in sub-px (cfg.SUB per pixel).

const std = @import("std");
const cfg = @import("config.zig");
const pal = @import("pal.zig");
const movy = @import("movy");
const camera = @import("camera.zig");
const level = @import("level.zig");
const input = @import("input.zig");

pub const Events = struct {
    landed: f32 = 0, // impact speed px/frame; 0 = no landing this frame
    jumped: bool = false,
    died: bool = false, // fell out of the world
};

pub const Player = struct {
    x: i32 = 0, // sub-px, hitbox top-left
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    on_ground: bool = false,
    coyote: u8 = 0,
    facing: i32 = 1,
    run_anim: f32 = 0,
    invuln: u32 = 0,

    pub fn spawnAt(self: *Player, px_x: i32, px_y: i32) void {
        self.* = .{ .x = px_x * cfg.SUB, .y = px_y * cfg.SUB };
    }

    pub inline fn pxX(self: *const Player) i32 {
        return @divFloor(self.x, cfg.SUB);
    }
    pub inline fn pxY(self: *const Player) i32 {
        return @divFloor(self.y, cfg.SUB);
    }
    pub inline fn centerX(self: *const Player) i32 {
        return self.pxX() + @divTrunc(cfg.P_W, 2);
    }
    pub inline fn centerY(self: *const Player) i32 {
        return self.pxY() + @divTrunc(cfg.P_H, 2);
    }
    pub inline fn feetY(self: *const Player) i32 {
        return self.pxY() + cfg.P_H - 1;
    }

    pub fn update(self: *Player, in: *input.Input, lvl: *const level.Level) Events {
        var ev = Events{};

        // ---- horizontal control
        const accel: i32 = if (self.on_ground) cfg.P_ACCEL else cfg.P_AIR_ACCEL;
        const l = in.leftHeld();
        const r = in.rightHeld();
        if (l and !r) {
            self.vx -= accel;
            self.facing = -1;
        } else if (r and !l) {
            self.vx += accel;
            self.facing = 1;
        } else if (self.on_ground) {
            self.vx = @divTrunc(self.vx * cfg.P_FRICTION_NUM, 256);
            if (@abs(self.vx) < 10) self.vx = 0;
        } else {
            self.vx = @divTrunc(self.vx * cfg.P_AIR_DRAG_NUM, 256);
        }
        self.vx = std.math.clamp(self.vx, -cfg.P_MAX_RUN, cfg.P_MAX_RUN);

        // ---- gravity
        self.vy += if (self.vy < 0) cfg.P_GRAV_UP else cfg.P_GRAV_DOWN;
        self.vy = @min(self.vy, cfg.P_MAX_FALL);

        // ---- coyote + jump (buffered press fires if grounded or within coyote)
        if (self.on_ground) {
            self.coyote = cfg.COYOTE_FRAMES;
        } else {
            self.coyote -|= 1;
        }
        if (in.jump_buf > 0 and (self.on_ground or self.coyote > 0)) {
            self.vy = cfg.P_JUMP_V;
            self.on_ground = false;
            self.coyote = 0;
            in.jump_buf = 0;
            ev.jumped = true;
        }

        // ---- move X, pixel-stepped (advance one px at a time, stop at a wall)
        {
            const old_px = self.pxX();
            self.x += self.vx;
            const new_px = self.pxX();
            if (new_px != old_px) {
                const dir: i32 = if (new_px > old_px) 1 else -1;
                var cur = old_px;
                var blocked = false;
                while (cur != new_px) {
                    const nxt = cur + dir;
                    if (lvl.rectHitsBody(nxt, self.pxY(), cfg.P_W, cfg.P_H)) {
                        blocked = true;
                        break;
                    }
                    cur = nxt;
                }
                if (blocked) {
                    self.x = if (dir > 0)
                        cur * cfg.SUB + (cfg.SUB - 1)
                    else
                        cur * cfg.SUB;
                    self.vx = 0;
                }
            }
        }

        // ---- move Y, pixel-stepped (platforms catch the feet from above only)
        {
            const old_py = self.pxY();
            self.y += self.vy;
            const new_py = self.pxY();
            if (new_py != old_py) {
                const dir: i32 = if (new_py > old_py) 1 else -1;
                var cur = old_py;
                var blocked = false;
                while (cur != new_py) {
                    const nxt = cur + dir;
                    if (lvl.rectHitsBody(self.pxX(), nxt, cfg.P_W, cfg.P_H)) {
                        blocked = true;
                        break;
                    }
                    if (dir > 0) {
                        const feet = nxt + cfg.P_H - 1;
                        if (@mod(feet, cfg.TILE) == 0 and self.platformUnderFeet(lvl, feet)) {
                            blocked = true;
                            break;
                        }
                    }
                    cur = nxt;
                }
                if (blocked) {
                    if (dir > 0) {
                        if (!self.on_ground) {
                            ev.landed = @as(f32, @floatFromInt(self.vy)) /
                                @as(f32, @floatFromInt(cfg.SUB));
                        }
                        self.on_ground = true;
                    }
                    self.vy = 0;
                    self.y = cur * cfg.SUB;
                }
            }
        }

        // ---- still supported?
        if (self.on_ground and !self.supported(lvl)) self.on_ground = false;

        // ---- fell out of the world
        if (self.pxY() > lvl.pxH() + 12) ev.died = true;

        // ---- anim bookkeeping
        if (self.on_ground) {
            self.run_anim += @abs(@as(f32, @floatFromInt(self.vx))) /
                @as(f32, @floatFromInt(cfg.SUB)) * 0.55;
        }
        self.invuln -|= 1;

        return ev;
    }

    fn platformUnderFeet(self: *const Player, lvl: *const level.Level, feet_row: i32) bool {
        const ty = @divFloor(feet_row, cfg.TILE);
        var tx = @divFloor(self.pxX(), cfg.TILE);
        const tx1 = @divFloor(self.pxX() + cfg.P_W - 1, cfg.TILE);
        while (tx <= tx1) : (tx += 1) {
            if (lvl.tileAt(tx, ty) == .platform) return true;
        }
        return false;
    }

    fn supported(self: *const Player, lvl: *const level.Level) bool {
        const below = self.pxY() + cfg.P_H; // pixel row just below the feet
        const ty = @divFloor(below, cfg.TILE);
        const top_aligned = @mod(below, cfg.TILE) == 0;
        var tx = @divFloor(self.pxX(), cfg.TILE);
        const tx1 = @divFloor(self.pxX() + cfg.P_W - 1, cfg.TILE);
        while (tx <= tx1) : (tx += 1) {
            if (lvl.solidTile(tx, ty)) return true;
            if (lvl.tileAt(tx, ty) == .platform and top_aligned) return true;
        }
        return false;
    }

    pub fn render(self: *const Player, f: *movy.Frame, cam: *const camera.Camera) void {
        const sx = cam.sx(self.pxX());
        const sy = cam.sy(self.pxY());

        // i-frame blink (still faintly visible)
        const blink = self.invuln > 0 and (self.invuln / 4) % 2 == 1;
        const dim: f32 = if (blink) 0.35 else 1.0;
        const spd = @abs(@as(f32, @floatFromInt(self.vx))) / @as(f32, @floatFromInt(cfg.SUB));
        const right = self.facing > 0;

        const body = pal.PLAYER_BODY.scale(dim);
        const dark = pal.PLAYER_DARK.scale(dim);
        const core = pal.PLAYER_CORE.scale(dim);

        // soft glow halo (the neon bloom - see the movy-render skill)
        f.grect(sx - 1, sy - 1, cfg.P_W + 2, cfg.P_H + 2, pal.PLAYER_GLOW.scale((0.40 + spd * 0.12) * dim));

        // head (2px) + facing eye
        f.rect(sx + 1, sy, 2, 2, body);
        f.px(sx + (if (right) @as(i32, 2) else 1), sy + 1, core);

        // torso with a bright vertical core line + dark waist
        f.rect(sx, sy + 2, cfg.P_W, 4, body);
        f.vline(sx + (if (right) @as(i32, 2) else 1), sy + 2, 3, core.scale(0.85));
        f.hline(sx, sy + 5, cfg.P_W, dark);

        // legs: tuck/spread airborne, 2-frame run on the ground, stand idle
        if (!self.on_ground) {
            const inner: i32 = if (self.vy < 0) 1 else 0; // tucked rising, spread falling
            f.vline(sx + inner, sy + 6, 2, body);
            f.vline(sx + cfg.P_W - 1 - inner, sy + 6, 2, body);
        } else if (spd > 0.15) {
            if (@mod(@as(i32, @intFromFloat(self.run_anim)), 2) == 0) {
                f.vline(sx, sy + 6, 2, body);
                f.vline(sx + cfg.P_W - 1, sy + 6, 2, body);
            } else {
                f.vline(sx + 1, sy + 6, 2, body);
                f.vline(sx + 2, sy + 6, 2, body);
            }
        } else {
            f.vline(sx + 1, sy + 6, 2, body);
            f.vline(sx + 2, sy + 6, 2, body);
        }
    }
};
