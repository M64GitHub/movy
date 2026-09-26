//! DiffOutput - high-throughput terminal output for Screen.
//!
//! Screen.output() re-encodes and writes the ENTIRE output surface every
//! frame (hundreds of KB at 60 fps). Terminal emulators and especially
//! multiplexers (tmux!) must parse all of it; when their event loop is
//! busy (e.g. handling keystrokes) the pty stops draining and the
//! blocking write() stalls the application.
//!
//! DiffOutput fixes both ends:
//!
//!   * Dirty rows  - each terminal row is compared against the previous
//!     frame (colors, shadow, chars); unchanged rows cost 0 bytes.
//!     Changed rows are emitted with absolute cursor addressing, and
//!     fg/bg codes that are already active are never re-sent.
//!
//!   * .threaded mode - a writer thread owns the blocking write() with a
//!     latest-wins mailbox: the render loop never blocks on the
//!     terminal; if the terminal stalls, frames are dropped instead.
//!
//! Usage (replaces `try screen.output()`):
//!
//!     var dout = try movy.DiffOutput.init(allocator, &screen, .threaded);
//!     defer dout.deinit();
//!     // in the render loop, after screen.render() and text overlays:
//!     try dout.output(&screen);
//!
//! Notes:
//!   * The output surface must keep its dimensions (no resize support).
//!   * Set `force_full = true` to repaint everything (e.g. after the
//!     terminal was cleared by something else).

const std = @import("std");
const movy = @import("../movy.zig");

const Rgb = movy.core.types.Rgb;

pub const Mode = enum {
    sync, // write() on the calling thread
    threaded, // writer thread + latest-wins mailbox (never blocks)
};

inline fn rgbEq(a: Rgb, b: Rgb) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b;
}

fn rgbRowEq(a: []const Rgb, b: []const Rgb) bool {
    for (a, b) |x, y| {
        if (!rgbEq(x, y)) return false;
    }
    return true;
}

/// Glyph cell row `gr..gr+w` unchanged since the last emitted frame?
/// (bg_out only matters for .solid cells, but a flat compare is cheaper
/// than asking per cell.)
fn glyphRowEq(gl: *const movy.GlyphLayer, self: *const DiffOutput, gr: usize, w: usize) bool {
    return std.mem.eql(u21, gl.char_map[gr..][0..w], self.prev_gchars[gr..][0..w]) and
        rgbRowEq(gl.fg_out[gr..][0..w], self.prev_gfg[gr..][0..w]) and
        rgbRowEq(gl.bg_out[gr..][0..w], self.prev_gbg[gr..][0..w]) and
        std.mem.eql(movy.core.GlyphBgMode, gl.bg_mode[gr..][0..w], self.prev_gmode[gr..][0..w]);
}

/// Append a decimal (0..999) to buf at i.
inline fn putNum(buf: []u8, i: *usize, n: u32) void {
    if (n >= 100) {
        buf[i.*] = '0' + @as(u8, @intCast(n / 100));
        i.* += 1;
        buf[i.*] = '0' + @as(u8, @intCast((n / 10) % 10));
        i.* += 1;
        buf[i.*] = '0' + @as(u8, @intCast(n % 10));
        i.* += 1;
    } else if (n >= 10) {
        buf[i.*] = '0' + @as(u8, @intCast(n / 10));
        i.* += 1;
        buf[i.*] = '0' + @as(u8, @intCast(n % 10));
        i.* += 1;
    } else {
        buf[i.*] = '0' + @as(u8, @intCast(n));
        i.* += 1;
    }
}

inline fn putStr(buf: []u8, i: *usize, s: []const u8) void {
    @memcpy(buf[i.*..][0..s.len], s);
    i.* += s.len;
}

inline fn putColor(
    buf: []u8,
    i: *usize,
    prefix: []const u8,
    c: Rgb,
) void {
    putStr(buf, i, prefix);
    putNum(buf, i, c.r);
    buf[i.*] = ';';
    i.* += 1;
    putNum(buf, i, c.g);
    buf[i.*] = ';';
    i.* += 1;
    putNum(buf, i, c.b);
    buf[i.*] = 'm';
    i.* += 1;
}

pub const DiffOutput = struct {
    allocator: std.mem.Allocator,
    w: usize, // surface width (terminal columns)
    h: usize, // surface height in pixel rows (2 per terminal row)
    prev_colors: []Rgb,
    prev_shadow: []u8,
    prev_chars: []u21,
    // previous GlyphLayer state (cells), allocated when a layer first shows up
    prev_gchars: []u21 = &.{},
    prev_gfg: []Rgb = &.{},
    prev_gbg: []Rgb = &.{},
    prev_gmode: []movy.core.GlyphBgMode = &.{},
    had_glyphs: bool = false,
    out: []u8,
    force_full: bool = true,
    mode: Mode,
    writer: ?*Writer = null,

    /// stats: terminal rows emitted by the last output() call
    rows_emitted: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
        mode: Mode,
    ) !*DiffOutput {
        const surf = screen.output_surface;
        return initSize(allocator, surf.w, surf.h, mode);
    }

    /// init() for a surface of w columns x h pixel rows, without a Screen.
    pub fn initSize(
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
        mode: Mode,
    ) !*DiffOutput {
        const self = try allocator.create(DiffOutput);
        errdefer allocator.destroy(self);
        const n = w * h;
        self.* = .{
            .allocator = allocator,
            .w = w,
            .h = h,
            .prev_colors = try allocator.alloc(Rgb, n),
            .prev_shadow = try allocator.alloc(u8, n),
            .prev_chars = try allocator.alloc(u21, n),
            // worst case ~56B/cell + per-row addressing overhead
            .out = try allocator.alloc(
                u8,
                w * (h / 2) * 56 + h * 24 + 64,
            ),
            .mode = mode,
        };
        @memset(self.prev_chars, 0);
        @memset(self.prev_shadow, 0);
        if (mode == .threaded) {
            self.writer = try Writer.init(allocator, self.out.len);
        }
        return self;
    }

    pub fn deinit(self: *DiffOutput) void {
        if (self.writer) |wr| wr.deinit();
        self.allocator.free(self.prev_colors);
        self.allocator.free(self.prev_shadow);
        self.allocator.free(self.prev_chars);
        self.freeGlyphState();
        self.allocator.free(self.out);
        self.allocator.destroy(self);
    }

    /// stats from the writer thread (threaded mode only)
    pub fn droppedFrames(self: *DiffOutput) u32 {
        return if (self.writer) |wr| wr.drops else 0;
    }

    pub fn lastWriteMs(self: *DiffOutput) f64 {
        return if (self.writer) |wr| wr.last_write_ms else 0;
    }

    fn freeGlyphState(self: *DiffOutput) void {
        if (self.prev_gchars.len == 0) return;
        self.allocator.free(self.prev_gchars);
        self.allocator.free(self.prev_gfg);
        self.allocator.free(self.prev_gbg);
        self.allocator.free(self.prev_gmode);
    }

    /// Track a glyph layer being attached / detached: allocate its previous-
    /// frame state once, and repaint everything when it comes or goes.
    fn syncGlyphState(self: *DiffOutput, surf: *movy.RenderSurface) !void {
        const has = surf.glyphs != null;
        if (has != self.had_glyphs) {
            self.force_full = true;
            self.had_glyphs = has;
        }
        if (!has or self.prev_gchars.len != 0) return;
        const cells = self.w * (self.h / 2);
        const a = self.allocator;
        const gchars = try a.alloc(u21, cells);
        errdefer a.free(gchars);
        const gfg = try a.alloc(Rgb, cells);
        errdefer a.free(gfg);
        const gbg = try a.alloc(Rgb, cells);
        errdefer a.free(gbg);
        const gmode = try a.alloc(movy.core.GlyphBgMode, cells);
        self.prev_gchars = gchars;
        self.prev_gfg = gfg;
        self.prev_gbg = gbg;
        self.prev_gmode = gmode;
        self.force_full = true;
    }

    /// Encode dirty rows of screen.output_surface and write them.
    pub fn output(self: *DiffOutput, screen: *movy.Screen) !void {
        const surf = screen.output_surface;
        try self.syncGlyphState(surf);
        const bytes = self.build(
            surf,
            @intCast(screen.x + 1),
            @intCast(@divTrunc(screen.y, 2) + 1),
        );
        if (bytes.len == 0) return;
        if (self.writer) |wr| {
            wr.send(bytes);
        } else {
            var off: usize = 0;
            while (off < bytes.len) {
                const n = try std.posix.write(
                    std.posix.STDOUT_FILENO,
                    bytes[off..],
                );
                if (n == 0) break;
                off += n;
            }
        }
    }

    /// origin_col / origin_row: 1-based terminal coords of the surface origin.
    fn build(self: *DiffOutput, surf: *movy.RenderSurface, origin_col: u32, origin_row: u32) []u8 {
        // Two instantiations: surfaces without a glyph layer run the plain
        // pixel loop, with no per-cell glyph test at all.
        return if (surf.glyphs != null)
            self.buildRows(true, surf, origin_col, origin_row)
        else
            self.buildRows(false, surf, origin_col, origin_row);
    }

    fn buildRows(
        self: *DiffOutput,
        comptime with_glyphs: bool,
        surf: *movy.RenderSurface,
        origin_col: u32,
        origin_row: u32,
    ) []u8 {
        const w = self.w;
        const gl: *movy.GlyphLayer = if (with_glyphs) surf.glyphs.? else undefined;
        if (with_glyphs) std.debug.assert(gl.w == w and gl.h == self.h / 2);

        var idx: usize = 0;
        self.rows_emitted = 0;

        var row: usize = 0;
        const text_rows = self.h / 2;
        while (row < text_rows) : (row += 1) {
            const up = (row * 2) * w;
            const lo = up + w;
            const gr = row * w; // glyph cell row start
            const g_chars: []const u21 = if (with_glyphs) gl.char_map[gr..][0..w] else &.{};

            if (!self.force_full) {
                const same =
                    rgbRowEq(surf.color_map[up..][0..w], self.prev_colors[up..][0..w]) and
                    rgbRowEq(surf.color_map[lo..][0..w], self.prev_colors[lo..][0..w]) and
                    std.mem.eql(u8, surf.shadow_map[up..][0..w], self.prev_shadow[up..][0..w]) and
                    std.mem.eql(u8, surf.shadow_map[lo..][0..w], self.prev_shadow[lo..][0..w]) and
                    std.mem.eql(u21, surf.char_map[up..][0..w], self.prev_chars[up..][0..w]) and
                    std.mem.eql(u21, surf.char_map[lo..][0..w], self.prev_chars[lo..][0..w]) and
                    (!with_glyphs or glyphRowEq(gl, self, gr, w));
                if (same) continue;
            }
            self.rows_emitted += 1;

            // absolute cursor position: ESC[row;colH
            putStr(self.out, &idx, "\x1b[");
            putNum(self.out, &idx, origin_row + @as(u32, @intCast(row)));
            self.out[idx] = ';';
            idx += 1;
            putNum(self.out, &idx, origin_col);
            self.out[idx] = 'H';
            idx += 1;

            // track active SGR colors; null = unknown/reset
            var cur_bg: ?Rgb = null;
            var cur_fg: ?Rgb = null;

            var x: usize = 0;
            while (x < w) : (x += 1) {
                const i_up = up + x;
                const i_lo = lo + x;
                const char = surf.char_map[i_up];
                const char_below = surf.char_map[i_lo];

                if (char != 0) {
                    // text cell: fg = upper color, bg = lower color
                    const fg = surf.color_map[i_up];
                    const bg = surf.color_map[i_lo];
                    if (cur_fg == null or !rgbEq(cur_fg.?, fg)) {
                        putColor(self.out, &idx, "\x1b[38;2;", fg);
                        cur_fg = fg;
                    }
                    if (cur_bg == null or !rgbEq(cur_bg.?, bg)) {
                        putColor(self.out, &idx, "\x1b[48;2;", bg);
                        cur_bg = bg;
                    }
                    const n = std.unicode.utf8Encode(
                        @intCast(char),
                        self.out[idx..][0..4],
                    ) catch blk: {
                        self.out[idx] = '?';
                        break :blk 1;
                    };
                    idx += n;
                } else if (char_below != 0) {
                    // char on the odd pixel row (toAnsi char_above case)
                    const bg = surf.color_map[i_up];
                    const fg = surf.color_map[i_lo];
                    if (cur_bg == null or !rgbEq(cur_bg.?, bg)) {
                        putColor(self.out, &idx, "\x1b[48;2;", bg);
                        cur_bg = bg;
                    }
                    if (cur_fg == null or !rgbEq(cur_fg.?, fg)) {
                        putColor(self.out, &idx, "\x1b[38;2;", fg);
                        cur_fg = fg;
                    }
                    const n = std.unicode.utf8Encode(
                        @intCast(char_below),
                        self.out[idx..][0..4],
                    ) catch blk: {
                        self.out[idx] = '?';
                        break :blk 1;
                    };
                    idx += n;
                } else if (with_glyphs and g_chars[x] != 0) {
                    // GlyphLayer cell: its fg; bg from its mode (pixels / solid)
                    const ci = gr + x;
                    const fg = gl.fg_out[ci];
                    if (cur_fg == null or !rgbEq(cur_fg.?, fg)) {
                        putColor(self.out, &idx, "\x1b[38;2;", fg);
                        cur_fg = fg;
                    }
                    if (gl.resolveBg(ci, surf.color_map, surf.shadow_map, i_up, i_lo)) |bg| {
                        if (cur_bg == null or !rgbEq(cur_bg.?, bg)) {
                            putColor(self.out, &idx, "\x1b[48;2;", bg);
                            cur_bg = bg;
                        }
                    } else {
                        putStr(self.out, &idx, "\x1b[49m");
                        cur_bg = null;
                    }
                    const n = std.unicode.utf8Encode(
                        g_chars[x],
                        self.out[idx..][0..4],
                    ) catch blk: {
                        self.out[idx] = '?';
                        break :blk 1;
                    };
                    idx += n;
                } else {
                    const upper = surf.color_map[i_up];
                    const lower = surf.color_map[i_lo];
                    const up_trans = surf.shadow_map[i_up] == 0;
                    const lo_trans = surf.shadow_map[i_lo] == 0;

                    if (up_trans and lo_trans) {
                        putStr(self.out, &idx, "\x1b[0m ");
                        cur_bg = null;
                        cur_fg = null;
                    } else if (up_trans) {
                        putStr(self.out, &idx, "\x1b[0m");
                        cur_bg = null;
                        putColor(self.out, &idx, "\x1b[38;2;", lower);
                        cur_fg = lower;
                        putStr(self.out, &idx, "\xE2\x96\x84"); // ▄
                    } else if (lo_trans) {
                        putStr(self.out, &idx, "\x1b[0m");
                        cur_bg = null;
                        putColor(self.out, &idx, "\x1b[38;2;", upper);
                        cur_fg = upper;
                        putStr(self.out, &idx, "\xE2\x96\x80"); // ▀
                    } else if (rgbEq(upper, lower)) {
                        // uniform cell: bg + space (fg untouched)
                        if (cur_bg == null or !rgbEq(cur_bg.?, upper)) {
                            putColor(self.out, &idx, "\x1b[48;2;", upper);
                            cur_bg = upper;
                        }
                        self.out[idx] = ' ';
                        idx += 1;
                    } else {
                        if (cur_bg == null or !rgbEq(cur_bg.?, upper)) {
                            putColor(self.out, &idx, "\x1b[48;2;", upper);
                            cur_bg = upper;
                        }
                        if (cur_fg == null or !rgbEq(cur_fg.?, lower)) {
                            putColor(self.out, &idx, "\x1b[38;2;", lower);
                            cur_fg = lower;
                        }
                        putStr(self.out, &idx, "\xE2\x96\x84"); // ▄
                    }
                }
            }
            putStr(self.out, &idx, "\x1b[0m");

            // remember this row pair
            @memcpy(self.prev_colors[up..][0..w], surf.color_map[up..][0..w]);
            @memcpy(self.prev_colors[lo..][0..w], surf.color_map[lo..][0..w]);
            @memcpy(self.prev_shadow[up..][0..w], surf.shadow_map[up..][0..w]);
            @memcpy(self.prev_shadow[lo..][0..w], surf.shadow_map[lo..][0..w]);
            @memcpy(self.prev_chars[up..][0..w], surf.char_map[up..][0..w]);
            @memcpy(self.prev_chars[lo..][0..w], surf.char_map[lo..][0..w]);
            if (with_glyphs) {
                @memcpy(self.prev_gchars[gr..][0..w], gl.char_map[gr..][0..w]);
                @memcpy(self.prev_gfg[gr..][0..w], gl.fg_out[gr..][0..w]);
                @memcpy(self.prev_gbg[gr..][0..w], gl.bg_out[gr..][0..w]);
                @memcpy(self.prev_gmode[gr..][0..w], gl.bg_mode[gr..][0..w]);
            }
        }

        self.force_full = false;
        return self.out[0..idx];
    }
};

/// Writer thread with a latest-wins mailbox: send() never blocks on the
/// terminal; an unsent frame is replaced (dropped) by a newer one.
const Writer = struct {
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    mailbox: []u8,
    standby: []u8,
    mail_len: usize = 0,
    pending: bool = false,
    stop: bool = false,
    thread: ?std.Thread = null,

    drops: u32 = 0,
    last_write_ms: f64 = 0,

    fn init(allocator: std.mem.Allocator, cap: usize) !*Writer {
        const self = try allocator.create(Writer);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .mailbox = try allocator.alloc(u8, cap),
            .standby = try allocator.alloc(u8, cap),
        };
        self.thread = try std.Thread.spawn(.{}, run, .{self});
        return self;
    }

    fn deinit(self: *Writer) void {
        self.mutex.lock();
        self.stop = true;
        self.cond.signal();
        self.mutex.unlock();
        if (self.thread) |t| t.join();
        self.allocator.free(self.mailbox);
        self.allocator.free(self.standby);
        self.allocator.destroy(self);
    }

    fn send(self: *Writer, bytes: []const u8) void {
        if (bytes.len == 0) return;
        self.mutex.lock();
        if (self.pending) self.drops +%= 1;
        const n = @min(bytes.len, self.mailbox.len);
        @memcpy(self.mailbox[0..n], bytes[0..n]);
        self.mail_len = n;
        self.pending = true;
        self.cond.signal();
        self.mutex.unlock();
    }

    fn run(self: *Writer) void {
        while (true) {
            self.mutex.lock();
            while (!self.pending and !self.stop) {
                self.cond.wait(&self.mutex);
            }
            if (self.stop) {
                self.mutex.unlock();
                return;
            }
            // swap buffers so send() can refill while we write
            const buf = self.mailbox;
            const len = self.mail_len;
            self.mailbox = self.standby;
            self.standby = buf;
            self.pending = false;
            self.mutex.unlock();

            var timer = std.time.Timer.start() catch null;
            var off: usize = 0;
            while (off < len) {
                const n = std.posix.write(
                    std.posix.STDOUT_FILENO,
                    buf[off..len],
                ) catch break;
                if (n == 0) break;
                off += n;
            }
            if (timer) |*t| {
                self.last_write_ms =
                    @as(f64, @floatFromInt(t.read())) / 1_000_000.0;
            }
        }
    }
};

// ------------------------------------------------------------------- tests

const testing = std.testing;

fn testFrame(dout: *DiffOutput, surf: *movy.RenderSurface) ![]u8 {
    try dout.syncGlyphState(surf);
    return dout.build(surf, 1, 1);
}

test "DiffOutput: glyphs over pixels, solid, precedence, dirty rows" {
    const a = testing.allocator;
    const surf = try movy.RenderSurface.init(a, 3, 4, .{}); // 3 cols x 2 rows
    defer surf.deinit(a);
    const gl = try movy.GlyphLayer.init(a, 3, 2);
    defer gl.deinit();
    const dout = try DiffOutput.initSize(a, 3, 4, .sync);
    defer dout.deinit();

    // pixel pair under cell (1,0): red over blue -> averaged bg
    surf.color_map[1] = .{ .r = 100 };
    surf.color_map[3 + 1] = .{ .b = 201 };
    surf.setGlyphs(gl);
    gl.put(1, 0, 'A', .{ .r = 255, .g = 255, .b = 255 });
    gl.putSolid(2, 1, 'Z', .{ .g = 9 }, .{ .r = 7, .g = 8, .b = 9 });

    var out = try testFrame(dout, surf);
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[38;2;255;255;255m\x1b[48;2;50;0;101mA") != null);
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[38;2;0;9;0m\x1b[48;2;7;8;9mZ") != null);
    try testing.expectEqual(@as(usize, 2), dout.rows_emitted);

    // nothing changed -> nothing emitted
    out = try testFrame(dout, surf);
    try testing.expectEqual(@as(usize, 0), out.len);

    // pixels behind static text change -> only that row, glyph re-resolved
    surf.color_map[1] = .{ .r = 200 };
    out = try testFrame(dout, surf);
    try testing.expectEqual(@as(usize, 1), dout.rows_emitted);
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[48;2;100;0;101mA") != null);

    // glyph-only change -> its row
    gl.setFg(2, 1, .{ .g = 10 });
    out = try testFrame(dout, surf);
    try testing.expectEqual(@as(usize, 1), dout.rows_emitted);
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[38;2;0;10;0m") != null);

    // RenderSurface char_map text wins over the glyph in the same cell
    surf.putUtf8XY('H', 1, 0, .{ .r = 1, .g = 2, .b = 3 }, .{ .r = 4, .g = 5, .b = 6 });
    out = try testFrame(dout, surf);
    try testing.expect(std.mem.indexOf(u8, out, "H") != null);
    try testing.expect(std.mem.indexOf(u8, out, "A") == null);

    // detaching the layer repaints everything, as plain pixels
    surf.setGlyphs(null);
    out = try testFrame(dout, surf);
    try testing.expectEqual(@as(usize, 2), dout.rows_emitted);
    try testing.expect(std.mem.indexOf(u8, out, "Z") == null);
}

test "DiffOutput: glyph over transparent pixels uses the default bg" {
    const a = testing.allocator;
    const surf = try movy.RenderSurface.init(a, 2, 2, .{});
    defer surf.deinit(a);
    surf.clearTransparent();
    const gl = try movy.GlyphLayer.init(a, 2, 1);
    defer gl.deinit();
    const dout = try DiffOutput.initSize(a, 2, 2, .sync);
    defer dout.deinit();
    surf.setGlyphs(gl);
    gl.put(0, 0, 'q', .{ .r = 1 });
    const out = try testFrame(dout, surf);
    try testing.expect(std.mem.indexOf(u8, out, "\x1b[38;2;1;0;0m\x1b[49mq") != null);
}
