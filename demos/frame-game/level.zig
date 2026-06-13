//! A minimal tile world: a grid of {empty, solid, platform}, built from ASCII
//! rows. Exposes the collision contract the player physics needs
//! (tileAt / solidTile / rectHitsBody / tileAtPx) and renders tiles with a
//! neon top edge. Levels are small here, so render walks every tile; for big
//! worlds, restrict the loop to the camera's visible tile range.

const std = @import("std");
const cfg = @import("config.zig");
const pal = @import("pal.zig");
const movy = @import("movy");
const camera = @import("camera.zig");

pub const Tile = enum(u8) {
    empty,
    solid,
    platform, // thin: solid only from above (one-way)
};

pub const Level = struct {
    allocator: std.mem.Allocator,
    w: i32, // tiles
    h: i32,
    tiles: []Tile,
    spawn_x: i32 = 10, // px
    spawn_y: i32 = 10,

    /// Build from ASCII rows: '#'=solid, '='=platform, '@'=spawn, else empty.
    /// All rows must be the same length.
    pub fn initFromAscii(allocator: std.mem.Allocator, data: []const []const u8) !Level {
        const h: i32 = @intCast(data.len);
        const w: i32 = @intCast(data[0].len);
        const tiles = try allocator.alloc(Tile, @intCast(w * h));
        var self = Level{ .allocator = allocator, .w = w, .h = h, .tiles = tiles };
        var ty: i32 = 0;
        while (ty < h) : (ty += 1) {
            const row = data[@intCast(ty)];
            var tx: i32 = 0;
            while (tx < w) : (tx += 1) {
                const c = if (tx < row.len) row[@intCast(tx)] else ' ';
                self.tiles[self.tidx(tx, ty)] = switch (c) {
                    '#' => .solid,
                    '=' => .platform,
                    '@' => blk: {
                        self.spawn_x = tx * cfg.TILE;
                        self.spawn_y = ty * cfg.TILE;
                        break :blk .empty;
                    },
                    else => .empty,
                };
            }
        }
        return self;
    }

    pub fn deinit(self: *Level) void {
        self.allocator.free(self.tiles);
    }

    pub inline fn tidx(self: *const Level, tx: i32, ty: i32) usize {
        return @as(usize, @intCast(ty)) * @as(usize, @intCast(self.w)) +
            @as(usize, @intCast(tx));
    }

    pub fn tileAt(self: *const Level, tx: i32, ty: i32) Tile {
        if (tx < 0 or tx >= self.w) return .solid; // side walls
        if (ty < 0 or ty >= self.h) return .empty; // open sky / pit below
        return self.tiles[self.tidx(tx, ty)];
    }

    pub fn tileAtPx(self: *const Level, px: i32, py: i32) Tile {
        return self.tileAt(@divFloor(px, cfg.TILE), @divFloor(py, cfg.TILE));
    }

    pub inline fn solidTile(self: *const Level, tx: i32, ty: i32) bool {
        return self.tileAt(tx, ty) == .solid;
    }

    /// Does an axis-aligned px rect overlap any FULLY solid tile?
    pub fn rectHitsBody(self: *const Level, x: i32, y: i32, w: i32, h: i32) bool {
        const tx0 = @divFloor(x, cfg.TILE);
        const ty0 = @divFloor(y, cfg.TILE);
        const tx1 = @divFloor(x + w - 1, cfg.TILE);
        const ty1 = @divFloor(y + h - 1, cfg.TILE);
        var ty = ty0;
        while (ty <= ty1) : (ty += 1) {
            var tx = tx0;
            while (tx <= tx1) : (tx += 1) {
                if (self.solidTile(tx, ty)) return true;
            }
        }
        return false;
    }

    pub inline fn pxW(self: *const Level) i32 {
        return self.w * cfg.TILE;
    }
    pub inline fn pxH(self: *const Level) i32 {
        return self.h * cfg.TILE;
    }

    pub fn render(self: *const Level, f: *movy.Frame, cam: *const camera.Camera) void {
        var ty: i32 = 0;
        while (ty < self.h) : (ty += 1) {
            var tx: i32 = 0;
            while (tx < self.w) : (tx += 1) {
                const t = self.tiles[self.tidx(tx, ty)];
                if (t == .empty) continue;
                const sx = cam.sx(tx * cfg.TILE);
                const sy = cam.sy(ty * cfg.TILE);

                if (t == .solid) {
                    f.rect(sx, sy, cfg.TILE, cfg.TILE, pal.TILE_BODY);
                    f.hline(sx, sy + cfg.TILE - 1, cfg.TILE, pal.TILE_DARK);
                    // neon top edge where the surface is exposed (walkable)
                    if (self.tileAt(tx, ty - 1) != .solid) {
                        f.hline(sx, sy, cfg.TILE, pal.TILE_TOP);
                        f.ghline(sx, sy, cfg.TILE, pal.TILE_TOP_GLOW);
                    }
                } else { // platform: just a glowing top lip
                    f.hline(sx, sy, cfg.TILE, pal.TILE_TOP);
                    f.ghline(sx, sy, cfg.TILE, pal.TILE_TOP_GLOW);
                }
            }
        }
    }
};
