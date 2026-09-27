//! VideoExport - a movy program records itself, frame by frame, as PNGs.
//!
//! Rasterizes what the terminal would show - half-block pixels, text and
//! GlyphLayer glyphs - into an RGB image, one terminal cell = cell_w x cell_h
//! image pixels, and writes numbered PNGs (frame_000000.png, ...). Drive your
//! program on a fixed clock (frame N = t = N / fps) and the result is
//! smoother than any screen capture: no dropped frames, no terminal.
//! tools/makevideo.sh then turns the frames (plus an optional wav) into an mp4.
//!
//! The cell rules mirror DiffOutput: a char_map char (fg = its upper pixel
//! color, bg = the lower one) > a GlyphLayer glyph (fg_out, bg from its
//! mode) > two stacked half-block pixels. Transparent pixels show
//! `background` (the terminal's default background).
//!
//! Text is drawn from fonts baked into cell-sized alpha bitmaps by
//! tools/bakefont.py (src/export/fonts/). Block elements (U+2580..259F) and
//! braille (U+2800..28FF) are drawn procedurally so they fill the cell like a
//! terminal draws them. A codepoint the font lacks renders its background only.
//!
//! Geometry: the default 19x38 cell makes half-block pixels exactly 19x19
//! squares; a 100x28 cell screen becomes 1900x1064, which pads to 1920x1080
//! with no rescaling (makevideo.sh does that).
//!
//! Requires the consumer to `exe.linkLibC()` (movy bundles lodepng).

const std = @import("std");
const movy = @import("../movy.zig");
const Rgb = movy.core.types.Rgb;
const RenderSurface = movy.RenderSurface;

const lp = @cImport({
    @cInclude("lodepng.h");
});

/// A baked font: `codepoints` sorted, one cell_w * cell_h alpha bitmap each.
pub const Atlas = struct {
    label: []const u8,
    cell_w: usize,
    cell_h: usize,
    codepoints: []const u21,
    alpha: []const u8,

    fn of(comptime M: type) Atlas {
        return .{
            .label = M.label,
            .cell_w = M.cell_w,
            .cell_h = M.cell_h,
            .codepoints = &M.codepoints,
            .alpha = M.alpha,
        };
    }

    /// The glyph's alpha bitmap, or null if the font does not have it.
    pub fn glyph(self: *const Atlas, cp: u21) ?[]const u8 {
        var lo: usize = 0;
        var hi: usize = self.codepoints.len;
        while (lo < hi) {
            const mid = (lo + hi) / 2;
            const c = self.codepoints[mid];
            if (c == cp) {
                const n = self.cell_w * self.cell_h;
                return self.alpha[mid * n ..][0..n];
            }
            if (c < cp) lo = mid + 1 else hi = mid;
        }
        return null;
    }
};

pub const Font = enum {
    /// SIL OFL 1.1 - see src/export/fonts/OFL-JetBrainsMono.txt
    jetbrains_mono,
    /// the closest match to macOS Menlo (Menlo derives from it)
    dejavu_sans_mono,
};

pub const CellSize = enum {
    /// 1080p: 100x28 cells -> 1900x1064, square 19x19 half-block pixels
    @"19x38",
    /// small: GIFs, banners, previews
    @"10x20",
};

/// The font used when Options.font is not set.
pub const default_font: Font = .jetbrains_mono;

pub fn atlas(font: Font, cell: CellSize) Atlas {
    return switch (font) {
        .jetbrains_mono => switch (cell) {
            .@"19x38" => Atlas.of(@import("fonts/jetbrains_mono_19x38.zig")),
            .@"10x20" => Atlas.of(@import("fonts/jetbrains_mono_10x20.zig")),
        },
        .dejavu_sans_mono => switch (cell) {
            .@"19x38" => Atlas.of(@import("fonts/dejavu_sans_mono_19x38.zig")),
            .@"10x20" => Atlas.of(@import("fonts/dejavu_sans_mono_10x20.zig")),
        },
    };
}

pub const Options = struct {
    font: Font = default_font,
    cell: CellSize = .@"19x38",
    /// frames go here as frame_000000.png, ...; created if missing
    out_dir: []const u8 = "export",
    /// what transparent pixels show (the terminal's default background)
    background: Rgb = .{ .r = 0, .g = 0, .b = 0 },
    fps: f32 = 60.0,
};

pub const VideoExport = struct {
    allocator: std.mem.Allocator,
    font: Atlas,
    background: Rgb,
    fps: f32,
    out_dir: []u8,
    cols: usize,
    rows: usize,
    img_w: usize,
    img_h: usize,
    rgb: []u8,
    /// the next frame's number (= frames written so far)
    frame_n: u32 = 0,

    /// An exporter for a screen of `cols` x `rows` terminal cells. Creates
    /// out_dir and removes old frame_NNNNNN.png files from it - a shorter
    /// export must not leave stale frames behind for ffmpeg to pick up.
    pub fn init(allocator: std.mem.Allocator, cols: usize, rows: usize, opts: Options) !*VideoExport {
        const self = try allocator.create(VideoExport);
        errdefer allocator.destroy(self);
        const font = atlas(opts.font, opts.cell);
        const img_w = cols * font.cell_w;
        const img_h = rows * font.cell_h;
        const rgb = try allocator.alloc(u8, img_w * img_h * 3);
        errdefer allocator.free(rgb);
        const out_dir = try allocator.dupe(u8, opts.out_dir);
        errdefer allocator.free(out_dir);

        try std.fs.cwd().makePath(out_dir);
        try removeStaleFrames(out_dir);

        self.* = .{
            .allocator = allocator,
            .font = font,
            .background = opts.background,
            .fps = opts.fps,
            .out_dir = out_dir,
            .cols = cols,
            .rows = rows,
            .img_w = img_w,
            .img_h = img_h,
            .rgb = rgb,
        };
        return self;
    }

    pub fn deinit(self: *VideoExport) void {
        self.allocator.free(self.rgb);
        self.allocator.free(self.out_dir);
        self.allocator.destroy(self);
    }

    /// The fixed-clock time of the next frame: frame_n / fps. Drive your
    /// animation with this instead of the wall clock.
    pub fn time(self: *const VideoExport) f32 {
        return @as(f32, @floatFromInt(self.frame_n)) / self.fps;
    }

    /// Rasterize `surf` (and its GlyphLayer, if attached) and write it as the
    /// next numbered frame.
    pub fn writeFrame(self: *VideoExport, surf: *const RenderSurface) !void {
        self.rasterize(surf);
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = try std.fmt.bufPrintZ(&buf, "{s}/frame_{d:0>6}.png", .{ self.out_dir, self.frame_n });
        try self.savePng(path);
        self.frame_n += 1;
    }

    /// Write the last rasterized image to `path`. Always a truecolor RGB PNG:
    /// lodepng would otherwise pick a palette / gray type for frames with few
    /// colors (a black first frame), and a color type that changes mid-sequence
    /// makes ffmpeg reconfigure its filters (it breaks GIF palette passes).
    pub fn savePng(self: *const VideoExport, path: [:0]const u8) !void {
        var state: lp.LodePNGState = undefined;
        lp.lodepng_state_init(&state);
        defer lp.lodepng_state_cleanup(&state);
        state.info_raw.colortype = lp.LCT_RGB;
        state.info_raw.bitdepth = 8;
        state.info_png.color.colortype = lp.LCT_RGB;
        state.info_png.color.bitdepth = 8;
        state.encoder.auto_convert = 0;

        var png: [*c]u8 = null;
        var png_size: usize = 0;
        const err = lp.lodepng_encode(&png, &png_size, self.rgb.ptr, @intCast(self.img_w), @intCast(self.img_h), &state);
        defer std.c.free(png);
        if (err != 0) return error.PngEncodeFailed;
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = png[0..png_size] });
    }

    /// Paint `surf` into the RGB image - the DiffOutput cell rules.
    pub fn rasterize(self: *VideoExport, surf: *const RenderSurface) void {
        std.debug.assert(surf.w == self.cols and surf.h / 2 == self.rows);
        const w = surf.w;
        const gl = surf.glyphs;
        const cw = self.font.cell_w;
        const ch = self.font.cell_h;
        for (0..self.rows) |row| {
            const up = row * 2 * w;
            const lo = up + w;
            for (0..w) |x| {
                const px = x * cw;
                const py = row * ch;
                const c_up = surf.char_map[up + x];
                const c_lo = surf.char_map[lo + x];
                if (c_up != 0) {
                    self.drawChar(px, py, c_up, surf.color_map[up + x], surf.color_map[lo + x]);
                } else if (c_lo != 0) {
                    self.drawChar(px, py, c_lo, surf.color_map[lo + x], surf.color_map[up + x]);
                } else if (gl != null and gl.?.char_map[row * w + x] != 0) {
                    const g = gl.?;
                    const ci = row * w + x;
                    const bg = g.resolveBg(ci, surf.color_map, surf.shadow_map, up + x, lo + x) orelse self.background;
                    self.drawChar(px, py, g.char_map[ci], g.fg_out[ci], bg);
                } else {
                    const top = if (surf.shadow_map[up + x] == 0) self.background else surf.color_map[up + x];
                    const bot = if (surf.shadow_map[lo + x] == 0) self.background else surf.color_map[lo + x];
                    self.fillRect(px, py, cw, ch / 2, top);
                    self.fillRect(px, py + ch / 2, cw, ch - ch / 2, bot);
                }
            }
        }
    }

    // ------------------------------------------------------------ drawing

    fn fillRect(self: *VideoExport, x0: usize, y0: usize, w: usize, h: usize, c: Rgb) void {
        for (y0..y0 + h) |y| {
            var o = (y * self.img_w + x0) * 3;
            for (0..w) |_| {
                self.rgb[o] = c.r;
                self.rgb[o + 1] = c.g;
                self.rgb[o + 2] = c.b;
                o += 3;
            }
        }
    }

    fn blendRect(self: *VideoExport, x0: usize, y0: usize, w: usize, h: usize, c: Rgb, a: u16) void {
        for (y0..y0 + h) |y| {
            var o = (y * self.img_w + x0) * 3;
            for (0..w) |_| {
                self.rgb[o] = blend(self.rgb[o], c.r, a);
                self.rgb[o + 1] = blend(self.rgb[o + 1], c.g, a);
                self.rgb[o + 2] = blend(self.rgb[o + 2], c.b, a);
                o += 3;
            }
        }
    }

    fn drawChar(self: *VideoExport, x0: usize, y0: usize, cp: u21, fg: Rgb, bg: Rgb) void {
        const cw = self.font.cell_w;
        const ch = self.font.cell_h;
        self.fillRect(x0, y0, cw, ch, bg);
        if (cp == ' ') return;
        if (cp >= 0x2580 and cp <= 0x259F) return self.drawBlock(x0, y0, cp, fg);
        if (cp >= 0x2800 and cp <= 0x28FF) return self.drawBraille(x0, y0, cp, fg);
        const a = self.font.glyph(cp) orelse return;
        for (0..ch) |cy| {
            var o = ((y0 + cy) * self.img_w + x0) * 3;
            for (0..cw) |cx| {
                const av = a[cy * cw + cx];
                if (av != 0) {
                    self.rgb[o] = blend(self.rgb[o], fg.r, av);
                    self.rgb[o + 1] = blend(self.rgb[o + 1], fg.g, av);
                    self.rgb[o + 2] = blend(self.rgb[o + 2], fg.b, av);
                }
                o += 3;
            }
        }
    }

    /// Block elements, cell-filling like a terminal draws them.
    fn drawBlock(self: *VideoExport, x0: usize, y0: usize, cp: u21, fg: Rgb) void {
        const cw = self.font.cell_w;
        const ch = self.font.cell_h;
        switch (cp) {
            0x2580 => self.fillRect(x0, y0, cw, ch / 2, fg), // upper half
            0x2581...0x2588 => { // lower 1/8 .. full
                const h = (ch * (cp - 0x2580) + 4) / 8;
                self.fillRect(x0, y0 + ch - h, cw, h, fg);
            },
            0x2589...0x258F => { // left 7/8 .. 1/8
                const wl = (cw * (0x2590 - cp) + 4) / 8;
                self.fillRect(x0, y0, wl, ch, fg);
            },
            0x2590 => self.fillRect(x0 + cw / 2, y0, cw - cw / 2, ch, fg), // right half
            0x2591...0x2593 => self.blendRect(x0, y0, cw, ch, fg, @intCast(64 * (cp - 0x2590))), // shades
            0x2594 => self.fillRect(x0, y0, cw, (ch + 4) / 8, fg), // upper 1/8
            0x2595 => { // right 1/8
                const wr = (cw + 4) / 8;
                self.fillRect(x0 + cw - wr, y0, wr, ch, fg);
            },
            0x2596...0x259F => { // quadrants: bits = UL, UR, LL, LR
                const quads = [_]u4{ 0b0010, 0b0001, 0b1000, 0b1011, 0b1001, 0b1110, 0b1101, 0b0100, 0b0110, 0b0111 };
                const q = quads[cp - 0x2596];
                const hw = cw / 2;
                const hh = ch / 2;
                if (q & 0b1000 != 0) self.fillRect(x0, y0, hw, hh, fg);
                if (q & 0b0100 != 0) self.fillRect(x0 + hw, y0, cw - hw, hh, fg);
                if (q & 0b0010 != 0) self.fillRect(x0, y0 + hh, hw, ch - hh, fg);
                if (q & 0b0001 != 0) self.fillRect(x0 + hw, y0 + hh, cw - hw, ch - hh, fg);
            },
            else => {},
        }
    }

    /// Braille from the dot bits (dots 1-3 left column, 4-6 right, 7/8 row 4).
    fn drawBraille(self: *VideoExport, x0: usize, y0: usize, cp: u21, fg: Rgb) void {
        const cw = self.font.cell_w;
        const ch = self.font.cell_h;
        const bits: u8 = @intCast(cp - 0x2800);
        const dot = @max(cw / 4, 2);
        const colx = [2]usize{ cw / 4, (cw * 3) / 4 };
        for (0..8) |d| {
            if (bits & (@as(u8, 1) << @intCast(d)) == 0) continue;
            const col: usize = if (d < 3) 0 else if (d < 6) 1 else d - 6;
            const r: usize = if (d < 6) d % 3 else 3;
            const cx = colx[col];
            const cy = (ch * (2 * r + 1)) / 8;
            self.fillRect(x0 + cx -| dot / 2, y0 + cy -| dot / 2, dot, dot, fg);
        }
    }
};

fn blend(bg: u8, fg: u8, a: u16) u8 {
    const b: i32 = bg;
    const f: i32 = fg;
    return @intCast(b + @divTrunc((f - b) * @as(i32, a) + 127, 255));
}

/// Delete frame_NNNNNN.png files (exactly that pattern) in `dir`.
fn removeStaleFrames(dir_path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();
    var it = dir.iterate();
    while (try it.next()) |e| {
        if (e.kind != .file or !isFrameName(e.name)) continue;
        try dir.deleteFile(e.name);
    }
}

fn isFrameName(name: []const u8) bool {
    if (name.len != "frame_000000.png".len) return false;
    if (!std.mem.startsWith(u8, name, "frame_") or !std.mem.endsWith(u8, name, ".png")) return false;
    for (name[6..12]) |c| if (!std.ascii.isDigit(c)) return false;
    return true;
}

// ------------------------------------------------------------------- tests

const testing = std.testing;

test "atlas lookup finds ASCII and extras, misses the rest" {
    const a = atlas(.jetbrains_mono, .@"10x20");
    try testing.expect(a.glyph('A') != null);
    try testing.expect(a.glyph(0x00B7) != null); // middle dot
    try testing.expect(a.glyph(0x4E00) == null);
    try testing.expectEqual(@as(usize, 200), a.glyph('~').?.len);
}

test "rasterize follows the DiffOutput cell rules" {
    const allocator = testing.allocator;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);

    const surf = try RenderSurface.init(allocator, 3, 2, .{ .r = 0, .g = 0, .b = 0 });
    defer surf.deinit(allocator);
    // cell 0: pixels (red over transparent), cell 1: glyph .solid, cell 2: glyph .pixels
    surf.color_map[0] = .{ .r = 255, .g = 0, .b = 0 };
    surf.shadow_map[0] = 255;
    surf.shadow_map[3] = 0;
    for ([_]usize{ 2, 5 }) |i| {
        surf.color_map[i] = .{ .r = 0, .g = 0, .b = 200 };
        surf.shadow_map[i] = 255;
    }
    const gl = try movy.GlyphLayer.init(allocator, 3, 1);
    defer gl.deinit();
    gl.putSolid(1, 0, ' ', .{}, .{ .r = 0, .g = 255, .b = 0 });
    gl.put(2, 0, ' ', .{ .r = 255, .g = 255, .b = 255 });
    surf.setGlyphs(gl);

    const ve = try VideoExport.init(allocator, 3, 1, .{ .cell = .@"10x20", .out_dir = dir_path });
    defer ve.deinit();
    ve.rasterize(surf);
    const at = struct {
        fn f(v: *const VideoExport, x: usize, y: usize) Rgb {
            const o = (y * v.img_w + x) * 3;
            return .{ .r = v.rgb[o], .g = v.rgb[o + 1], .b = v.rgb[o + 2] };
        }
    }.f;
    try testing.expectEqual(Rgb{ .r = 255, .g = 0, .b = 0 }, at(ve, 5, 5)); // upper pixel
    try testing.expectEqual(Rgb{ .r = 0, .g = 0, .b = 0 }, at(ve, 5, 15)); // transparent -> background
    try testing.expectEqual(Rgb{ .r = 0, .g = 255, .b = 0 }, at(ve, 15, 10)); // .solid bg
    try testing.expectEqual(Rgb{ .r = 0, .g = 0, .b = 200 }, at(ve, 25, 10)); // .pixels bg = pixel average
}

test "isFrameName matches only the exporter's own files" {
    try testing.expect(isFrameName("frame_000042.png"));
    try testing.expect(!isFrameName("frame_42.png"));
    try testing.expect(!isFrameName("frame_00004a.png"));
    try testing.expect(!isFrameName("cover.png"));
}
