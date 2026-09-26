//! GlyphLayer - a cell-resolution text layer resolved over the pixels at
//! output time.
//!
//! RenderSurface text (char_map) lives *inside* the pixel buffer: a char takes
//! its fg from the upper pixel and its bg from the lower one, so text replaces
//! the pixels it sits on. A GlyphLayer keeps text separate. Each cell holds a
//! codepoint, an fg color and a background mode:
//!
//!   .pixels - bg is the average of the two pixels under the cell, so the
//!             text sits *in* the scene (glow, trails, gradients show through)
//!   .solid  - bg is the cell's own bg color
//!
//! Empty cells (char 0) show the half-block pixels as usual.
//!
//! Attach a layer to the surface that gets encoded - `screen.output_surface`
//! - and DiffOutput / toAnsi resolve it over the final composited pixels:
//!
//!     const glyphs = try movy.GlyphLayer.init(allocator, screen.w, screen.h / 2);
//!     defer glyphs.deinit();
//!     screen.output_surface.setGlyphs(glyphs);
//!
//! The layer is NOT composited by RenderEngine: glyph layers on other
//! surfaces are not merged into the output (debug builds panic in
//! Screen.render() to say so). Precedence at output: pixels < glyphs <
//! RenderSurface char_map text (UI / HUD text stays on top).
//!
//! The layer persists across frames - nothing clears it but you. Keep static
//! text in it once, or clear() and redraw per frame; the output cost is the
//! same (DiffOutput only re-emits rows whose pixels or glyphs changed).
//!
//! Output colors: the encoders read `fg_out` / `bg_out`. By default those
//! alias `fg_map` / `bg_map`. A Frame with the layer set (Frame.setGlyphs)
//! gives the layer separate out buffers and writes graded colors (vignette,
//! flash, tint, warmth) into them each composite(), so the authored colors
//! are never graded twice.

const std = @import("std");
const movy = @import("../movy.zig");

const Rgb = movy.core.types.Rgb;

pub const BgMode = enum(u8) {
    pixels = 0, // bg = average of the two pixels under the cell
    solid = 1, // bg = the cell's bg_map color
};

pub const GlyphLayer = struct {
    allocator: std.mem.Allocator,
    w: usize, // cells (terminal columns)
    h: usize, // cells (terminal rows) = surface height in pixels / 2

    char_map: []u21, // 0 = empty cell (pixels show)
    fg_map: []Rgb, // authored fg
    bg_map: []Rgb, // authored bg (.solid cells only)
    bg_mode: []BgMode,

    // What the encoders read. Alias fg_map / bg_map unless a Frame grades.
    fg_out: []Rgb,
    bg_out: []Rgb,
    owns_out: bool = false,

    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize) !*GlyphLayer {
        const self = try allocator.create(GlyphLayer);
        errdefer allocator.destroy(self);
        const n = w * h;
        const char_map = try allocator.alloc(u21, n);
        errdefer allocator.free(char_map);
        const fg_map = try allocator.alloc(Rgb, n);
        errdefer allocator.free(fg_map);
        const bg_map = try allocator.alloc(Rgb, n);
        errdefer allocator.free(bg_map);
        const bg_mode = try allocator.alloc(BgMode, n);
        self.* = .{
            .allocator = allocator,
            .w = w,
            .h = h,
            .char_map = char_map,
            .fg_map = fg_map,
            .bg_map = bg_map,
            .bg_mode = bg_mode,
            .fg_out = fg_map,
            .bg_out = bg_map,
        };
        self.clear();
        return self;
    }

    pub fn deinit(self: *GlyphLayer) void {
        const allocator = self.allocator;
        if (self.owns_out) {
            allocator.free(self.fg_out);
            allocator.free(self.bg_out);
        }
        allocator.free(self.char_map);
        allocator.free(self.fg_map);
        allocator.free(self.bg_map);
        allocator.free(self.bg_mode);
        allocator.destroy(self);
    }

    /// Give the layer its own fg_out / bg_out (for a grading Frame). Idempotent.
    pub fn ensureOutBuffers(self: *GlyphLayer) !void {
        if (self.owns_out) return;
        const fg_out = try self.allocator.alloc(Rgb, self.fg_map.len);
        errdefer self.allocator.free(fg_out);
        const bg_out = try self.allocator.alloc(Rgb, self.bg_map.len);
        @memcpy(fg_out, self.fg_map);
        @memcpy(bg_out, self.bg_map);
        self.fg_out = fg_out;
        self.bg_out = bg_out;
        self.owns_out = true;
    }

    /// Empty every cell (pixels show everywhere).
    pub fn clear(self: *GlyphLayer) void {
        @memset(self.char_map, 0);
        @memset(self.fg_map, Rgb{});
        @memset(self.bg_map, Rgb{});
        @memset(self.bg_mode, .pixels);
        if (self.owns_out) {
            @memset(self.fg_out, Rgb{});
            @memset(self.bg_out, Rgb{});
        }
    }

    pub inline fn idx(self: *const GlyphLayer, x: usize, y: usize) usize {
        return y * self.w + x;
    }

    /// A glyph over the pixels (.pixels background). Clips silently.
    pub inline fn put(self: *GlyphLayer, x: usize, y: usize, ch: u21, fg: Rgb) void {
        if (x >= self.w or y >= self.h) return;
        const i = self.idx(x, y);
        self.char_map[i] = narrow(ch);
        self.fg_map[i] = fg;
        self.bg_mode[i] = .pixels;
    }

    /// A glyph on its own solid background. Clips silently.
    pub inline fn putSolid(self: *GlyphLayer, x: usize, y: usize, ch: u21, fg: Rgb, bg: Rgb) void {
        if (x >= self.w or y >= self.h) return;
        const i = self.idx(x, y);
        self.char_map[i] = narrow(ch);
        self.fg_map[i] = fg;
        self.bg_map[i] = bg;
        self.bg_mode[i] = .solid;
    }

    /// Empty one cell.
    pub inline fn erase(self: *GlyphLayer, x: usize, y: usize) void {
        if (x >= self.w or y >= self.h) return;
        self.char_map[self.idx(x, y)] = 0;
    }

    /// Set only the fg of an occupied cell (color animation without re-putting).
    pub inline fn setFg(self: *GlyphLayer, x: usize, y: usize, fg: Rgb) void {
        if (x >= self.w or y >= self.h) return;
        self.fg_map[self.idx(x, y)] = fg;
    }

    /// The background an occupied cell `ci` shows, given the pixel pair under
    /// it (indices into a surface's color/shadow maps). null = the terminal's
    /// default background (both pixels transparent, .pixels mode).
    pub inline fn resolveBg(
        self: *const GlyphLayer,
        ci: usize,
        colors: []const Rgb,
        shadow: []const u8,
        i_up: usize,
        i_lo: usize,
    ) ?Rgb {
        if (self.bg_mode[ci] == .solid) return self.bg_out[ci];
        const up = shadow[i_up] != 0;
        const lo = shadow[i_lo] != 0;
        if (up and lo) {
            const a = colors[i_up];
            const b = colors[i_lo];
            return .{
                .r = @intCast((@as(u16, a.r) + b.r + 1) >> 1),
                .g = @intCast((@as(u16, a.g) + b.g + 1) >> 1),
                .b = @intCast((@as(u16, a.b) + b.b + 1) >> 1),
            };
        }
        if (up) return colors[i_up];
        if (lo) return colors[i_lo];
        return null;
    }

    /// UTF-8 text from (x, y), .pixels background. '\n' returns to x on the
    /// next row; clips at the edges. Invalid UTF-8 bytes render as '?'.
    /// Returns the number of cells written.
    pub fn putStr(self: *GlyphLayer, x: usize, y: usize, str: []const u8, fg: Rgb) usize {
        return self.writeStr(x, y, str, fg, null);
    }

    /// Like putStr, on a solid background.
    pub fn putStrSolid(self: *GlyphLayer, x: usize, y: usize, str: []const u8, fg: Rgb, bg: Rgb) usize {
        return self.writeStr(x, y, str, fg, bg);
    }

    fn writeStr(self: *GlyphLayer, x0: usize, y0: usize, str: []const u8, fg: Rgb, bg: ?Rgb) usize {
        var x = x0;
        var y = y0;
        var n: usize = 0;
        var i: usize = 0;
        while (i < str.len) {
            const len = std.unicode.utf8ByteSequenceLength(str[i]) catch 1;
            const cp: u21 = if (i + len <= str.len)
                std.unicode.utf8Decode(str[i..][0..len]) catch '?'
            else
                '?';
            i += @min(len, str.len - i);
            if (cp == '\n') {
                x = x0;
                y += 1;
                continue;
            }
            if (x < self.w and y < self.h) {
                if (bg) |b| self.putSolid(x, y, cp, fg, b) else self.put(x, y, cp, fg);
                n += 1;
            }
            x += 1;
        }
        return n;
    }

    /// A cell is one terminal column: double-width codepoints would shift the
    /// rest of the row, so they become U+25C9 (the same rule as putUtf8XY).
    inline fn narrow(ch: u21) u21 {
        return if (ch >= 0x1100 and movy.RenderSurface.isDoubleWidth(ch)) 0x25C9 else ch;
    }
};

// ------------------------------------------------------------------- tests

const testing = std.testing;

test "GlyphLayer put / putStr / clear" {
    const gl = try GlyphLayer.init(testing.allocator, 6, 2);
    defer gl.deinit();

    const red = Rgb{ .r = 255 };
    try testing.expectEqual(@as(usize, 4), gl.putStr(1, 0, "hé\nxy", red));
    try testing.expectEqual(@as(u21, 'h'), gl.char_map[1]);
    try testing.expectEqual(@as(u21, 'é'), gl.char_map[2]);
    try testing.expectEqual(@as(u21, 'x'), gl.char_map[gl.idx(1, 1)]);
    try testing.expectEqual(BgMode.pixels, gl.bg_mode[1]);

    // clipping: only the cells inside are written
    try testing.expectEqual(@as(usize, 2), gl.putStrSolid(4, 1, "abcd", red, .{ .b = 9 }));
    try testing.expectEqual(BgMode.solid, gl.bg_mode[gl.idx(5, 1)]);
    try testing.expectEqual(@as(u8, 9), gl.bg_out[gl.idx(5, 1)].b); // aliases bg_map

    // wide codepoints are narrowed to one cell
    gl.put(0, 0, 0x4E00, red);
    try testing.expectEqual(@as(u21, 0x25C9), gl.char_map[0]);

    gl.clear();
    for (gl.char_map) |c| try testing.expectEqual(@as(u21, 0), c);
}

test "GlyphLayer out buffers" {
    const gl = try GlyphLayer.init(testing.allocator, 2, 1);
    defer gl.deinit();
    gl.put(0, 0, 'a', .{ .g = 7 });
    try testing.expect(gl.fg_out.ptr == gl.fg_map.ptr);
    try gl.ensureOutBuffers();
    try gl.ensureOutBuffers();
    try testing.expect(gl.fg_out.ptr != gl.fg_map.ptr);
    try testing.expectEqual(@as(u8, 7), gl.fg_out[0].g);
}

test "RenderSurface.toAnsi resolves glyphs" {
    const a = testing.allocator;
    const surf = try movy.RenderSurface.init(a, 2, 2, .{ .r = 10, .g = 20, .b = 30 });
    defer surf.deinit(a);
    const gl = try GlyphLayer.init(a, 2, 1);
    defer gl.deinit();
    surf.setGlyphs(gl);
    gl.put(1, 0, 'x', .{ .r = 250 });
    const out = try surf.toAnsi();
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[38;2;250;0;0m\x1b[48;2;10;20;30mx") != null);
}
