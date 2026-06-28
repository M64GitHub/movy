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
        const self = try allocator.create(DiffOutput);
        errdefer allocator.destroy(self);
        const n = surf.w * surf.h;
        self.* = .{
            .allocator = allocator,
            .w = surf.w,
            .h = surf.h,
            .prev_colors = try allocator.alloc(Rgb, n),
            .prev_shadow = try allocator.alloc(u8, n),
            .prev_chars = try allocator.alloc(u21, n),
            // worst case ~56B/cell + per-row addressing overhead
            .out = try allocator.alloc(
                u8,
                surf.w * (surf.h / 2) * 56 + surf.h * 24 + 64,
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

    /// Encode dirty rows of screen.output_surface and write them.
    pub fn output(self: *DiffOutput, screen: *movy.Screen) !void {
        const bytes = self.build(screen);
        if (bytes.len == 0) return;
        if (self.writer) |wr| {
            wr.send(bytes);
        } else {
            var off: usize = 0;
            while (off < bytes.len) {
                const chunk = bytes[off..];
                const n_ = std.posix.system.write(
                    std.posix.STDOUT_FILENO,
                    chunk.ptr,
                    chunk.len,
                );
                const n: usize = if (n_ < 0) break else @intCast(n_);
                if (n == 0) break;
                off += n;
            }
        }
    }

    fn build(self: *DiffOutput, screen: *movy.Screen) []u8 {
        const surf = screen.output_surface;
        const w = self.w;
        // 1-based terminal coords of the surface origin
        const origin_col: u32 = @intCast(screen.x + 1);
        const origin_row: u32 = @intCast(@divTrunc(screen.y, 2) + 1);

        var idx: usize = 0;
        self.rows_emitted = 0;

        var row: usize = 0;
        const text_rows = self.h / 2;
        while (row < text_rows) : (row += 1) {
            const up = (row * 2) * w;
            const lo = up + w;

            if (!self.force_full) {
                const same =
                    rgbRowEq(surf.color_map[up..][0..w], self.prev_colors[up..][0..w]) and
                    rgbRowEq(surf.color_map[lo..][0..w], self.prev_colors[lo..][0..w]) and
                    std.mem.eql(u8, surf.shadow_map[up..][0..w], self.prev_shadow[up..][0..w]) and
                    std.mem.eql(u8, surf.shadow_map[lo..][0..w], self.prev_shadow[lo..][0..w]) and
                    std.mem.eql(u21, surf.char_map[up..][0..w], self.prev_chars[up..][0..w]) and
                    std.mem.eql(u21, surf.char_map[lo..][0..w], self.prev_chars[lo..][0..w]);
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
        }

        self.force_full = false;
        return self.out[0..idx];
    }
};

/// Writer thread with a latest-wins mailbox: send() never blocks on the
/// terminal; an unsent frame is replaced (dropped) by a newer one.
const Writer = struct {
    allocator: std.mem.Allocator,
    // Use a simple atomic spin mutex to avoid Io.* dependencies for now.
    lock_state: std.atomic.Value(u8) = .init(0),
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

    fn lock(self: *Writer) void {
        while (self.lock_state.cmpxchgWeak(0, 1, .acquire, .monotonic) != null) {
            // spin
        }
    }
    fn unlock(self: *Writer) void {
        self.lock_state.store(0, .release);
    }

    fn deinit(self: *Writer) void {
        self.lock();
        self.stop = true;
        self.unlock();
        if (self.thread) |t| t.join();
        self.allocator.free(self.mailbox);
        self.allocator.free(self.standby);
        self.allocator.destroy(self);
    }

    fn send(self: *Writer, bytes: []const u8) void {
        if (bytes.len == 0) return;
        self.lock();
        if (self.pending) self.drops +%= 1;
        const n = @min(bytes.len, self.mailbox.len);
        @memcpy(self.mailbox[0..n], bytes[0..n]);
        self.mail_len = n;
        self.pending = true;
        self.unlock();
    }

    fn run(self: *Writer) void {
        while (true) {
            self.lock();
            while (!self.pending and !self.stop) {
                self.unlock();
                // tiny spin pause
                var spin: u32 = 0;
                while (spin < 10000) : (spin += 1) {}
                self.lock();
            }
            if (self.stop) {
                self.unlock();
                return;
            }
            // swap buffers so send() can refill while we write
            const buf = self.mailbox;
            const len = self.mail_len;
            self.mailbox = self.standby;
            self.standby = buf;
            self.pending = false;
            self.unlock();

            const t0_ms = blk: {
                var ts: std.c.timespec = undefined;
                _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts);
                break :blk @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
            };
            var off: usize = 0;
            while (off < len) {
                const chunk = buf[off..len];
                const n_ = std.posix.system.write(
                    std.posix.STDOUT_FILENO,
                    chunk.ptr,
                    chunk.len,
                );
                const n: usize = if (n_ < 0) break else @intCast(n_);
                if (n == 0) break;
                off += n;
            }
            const t1_ms = blk: {
                var ts: std.c.timespec = undefined;
                _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts);
                break :blk @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
            };
            self.last_write_ms = @as(f64, @floatFromInt(t1_ms - t0_ms));
        }
    }
};
