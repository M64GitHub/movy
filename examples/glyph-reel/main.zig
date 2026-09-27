//! glyph-reel - a ~40s showcase for movy v0.4.0: the GlyphLayer and VideoExport.
//!
//! One scene, one timeline (seconds):
//!
//!    0.0  field fades in from black
//!    1.0  a scanner beam sweeps; the v0.4.0 news decrypts behind it
//!    8.6  the news scrambles off, char by char
//!   10.2  the movy logo rises from below the frame, transparent -> white
//!   12.4  a .solid bar fades in under it
//!   14.0  the storm: the waves go wild and throw off glyphs; flash + shake
//!         on the peak (15.6), then everything calms down (19.4)
//!   19.6  logo and bar drift up and out
//!   21.0  "REC" + timecode; a pink beam sweeps right -> left, VideoExport
//!         decrypts behind it (27.4 scrambles off)
//!   28.6  the v0.3.0 recap decrypts in place (no beam), holds, scrambles off
//!   35.0  closing card
//!   39.0  fade to black -> loop
//!
//! The background is half-block pixels on a movy.Frame (glow + post-fx); all
//! text is a GlyphLayer on top of it, so the colors and the glow show through
//! behind the characters.
//!
//!   zig build run-glyph-reel                    -> live, looping (ESC / q quits)
//!   zig build run-glyph-reel -- once            -> play once, hold the card
//!   zig build run-glyph-reel -- wide            -> 120x20 banner instead of 100x28 (16:9)
//!   zig build run-glyph-reel -- pal ember       -> palette: aurora (default), decrypt, ember
//!   zig build run-glyph-reel -- export [dir]    -> record with movy.VideoExport:
//!       60fps PNGs (1900x1064) into dir (default export/), then
//!       tools/makevideo.sh export glyph-reel.mp4 [--audio music.wav]
//!       export options: full (one loop instead of once + hold), small
//!       (10x20 px cells), font dejavu (instead of JetBrains Mono)
//!   zig build run-glyph-reel -- shot 16.0 out.ans
//!       headless: simulate up to 16.0s, write that frame's ANSI
//!       (view it: tools/ansi2html.py out.ans out.html --png out.png)

const std = @import("std");
const movy = @import("movy");
const logo = @import("logo.zig");

const V3 = movy.color.V3;
const Rgb = movy.core.types.Rgb;
const v3 = movy.color.v3;

const FPS: f32 = 60.0;
const FRAME_NS: i128 = 16_666_667;
const TAU = 2.0 * std.math.pi;

// ---------------------------------------------------------------- timeline

const T_FADE_IN: f32 = 1.2;
const T_BEAM0: f32 = 1.0;
const T_BEAM1: f32 = 6.0;
const T_NEWS_GONE0: f32 = 8.6;
const T_NEWS_GONE1: f32 = 11.0;
const T_LOGO_IN0: f32 = 10.2;
const T_LOGO_IN1: f32 = 12.8;
const T_BAR_IN0: f32 = 12.4;
const T_BAR_IN1: f32 = 13.4;
const T_STORM0: f32 = 14.0;
const T_PEAK: f32 = 15.6;
const T_CALM0: f32 = 16.8;
const T_CALM1: f32 = 19.4;
const T_BAR_OUT0: f32 = 19.4;
const T_BAR_OUT1: f32 = 20.2;
const T_LOGO_OUT0: f32 = 19.6;
const T_LOGO_OUT1: f32 = 21.6;
const T_REC0: f32 = 21.0;
const T_VX0: f32 = 21.4; // VideoExport: a pink beam sweeps right -> left
const T_VX1: f32 = 25.0;
const T_VX_GONE0: f32 = 27.4;
const T_VX_GONE1: f32 = 29.0;
const T_REC1: f32 = 29.2;
const T_RECAP0: f32 = 28.6;
const T_RECAP1: f32 = 30.4;
const T_RECAP_GONE0: f32 = 33.0;
const T_RECAP_GONE1: f32 = 34.6;
const T_CARD0: f32 = 35.0;
const T_CARD1: f32 = 36.0;
const T_CARD_HOLD: f32 = 37.5; // `once` freezes the story here
const T_CARD_GONE0: f32 = 38.0;
const T_CARD_GONE1: f32 = 39.0;
const T_FADE_OUT0: f32 = 39.0;
const T_TOTAL: f32 = 40.0;

// ------------------------------------------------------------------- text

const Line = struct {
    dy: i32, // row offset from the screen's center row
    text: []const u8,
    col: Rgb,
    bg: ?Rgb = null, // set: the line decrypts into a .solid bar
};

const PINK = Rgb{ .r = 255, .g = 120, .b = 220 };
const ICE = Rgb{ .r = 200, .g = 240, .b = 255 };
const SKY = Rgb{ .r = 150, .g = 210, .b = 255 };
const DIM = Rgb{ .r = 110, .g = 150, .b = 190 };
const INK = Rgb{ .r = 20, .g = 10, .b = 30 };

const NEWS = [_]Line{
    .{ .dy = -6, .text = "movy  v0.4.0", .col = DIM },
    .{ .dy = -4, .text = "G L Y P H   L A Y E R", .col = PINK },
    .{ .dy = -1, .text = "text that lives inside the scene", .col = ICE },
    .{ .dy = 1, .text = "glow, gradients and trails shine through", .col = SKY },
    .{ .dy = 3, .text = "Frame  ·  DiffOutput  ·  toAnsi()", .col = SKY },
    .{ .dy = 5, .text = "free when you don't use it", .col = DIM },
};

const VX = [_]Line{
    .{ .dy = -6, .text = "one more thing", .col = DIM },
    .{ .dy = -4, .text = "V I D E O   E X P O R T", .col = PINK },
    .{ .dy = -1, .text = "movy records itself", .col = ICE },
    .{ .dy = 1, .text = "60fps frames  ->  mp4, no screen capture", .col = SKY },
    .{ .dy = 3, .text = "pixels, text and glyphs, pixel-perfect", .col = SKY },
    .{ .dy = 5, .text = "this video was rendered by movy.VideoExport", .col = ICE },
};

const RECAP = [_]Line{
    .{ .dy = -6, .text = "built on  v0.3.0", .col = DIM },
    .{ .dy = -3, .text = "NEON RENDER LAYER  ·  movy.Frame", .col = PINK },
    .{ .dy = -1, .text = "glow, bloom and CRT post-fx for free", .col = ICE },
    .{ .dy = 1, .text = "60fps dirty-row output  ·  movy.DiffOutput", .col = SKY },
    .{ .dy = 3, .text = "kitty keyboard protocol", .col = SKY },
    .{ .dy = 5, .text = "linear float colors  ·  movy.color.V3", .col = SKY },
};

const CARD = [_]Line{
    .{ .dy = -2, .text = "  movy  v0.4.0  ", .col = INK, .bg = PINK },
    .{ .dy = 0, .text = "Glyph Layer  ·  VideoExport", .col = ICE },
    .{ .dy = 2, .text = "github.com/M64GitHub/movy", .col = SKY },
};

const BAR_TEXT = " movy v0.4.0  ·  the Glyph Layer ";
const SCRAMBLE = "01<>/\\|[]{}#%&*+=?!ABCDEFXYZ$@~^";

// --------------------------------------------------------------- palettes

const Palette = struct {
    name: []const u8,
    deep: V3,
    mid: V3,
    high: V3,
    hot_mid: V3, // mid / high at the storm's peak
    hot_high: V3,
};

const PALETTES = [_]Palette{
    .{ // deep blue -> violet -> sea green; the storm turns it hot pink/cyan
        .name = "aurora",
        .deep = v3(0.01, 0.015, 0.07),
        .mid = v3(0.13, 0.04, 0.26),
        .high = v3(0.00, 0.19, 0.20),
        .hot_mid = v3(0.34, 0.03, 0.30),
        .hot_high = v3(0.02, 0.30, 0.38),
    },
    .{ // glyph-decrypt's indigo -> magenta -> teal
        .name = "decrypt",
        .deep = v3(0.02, 0.01, 0.07),
        .mid = v3(0.20, 0.03, 0.22),
        .high = v3(0.02, 0.17, 0.24),
        .hot_mid = v3(0.36, 0.04, 0.34),
        .hot_high = v3(0.04, 0.30, 0.40),
    },
    .{ // plum -> ember -> gold
        .name = "ember",
        .deep = v3(0.04, 0.01, 0.04),
        .mid = v3(0.22, 0.03, 0.10),
        .high = v3(0.24, 0.10, 0.02),
        .hot_mid = v3(0.40, 0.04, 0.16),
        .hot_high = v3(0.40, 0.22, 0.03),
    },
};

// ------------------------------------------------------------------ state

const Opts = struct {
    wide: bool = false,
    once: bool = false,
    pal: *const Palette = &PALETTES[0],
    // export only
    font: movy.video_export.Font = movy.video_export.default_font,
    cell: movy.video_export.CellSize = .@"19x38",
};

/// How long `export` runs: the story once, then the card held for a moment.
/// (`export full` renders exactly one loop, T_TOTAL, instead.)
const EXPORT_TAIL: f32 = 2.0;

const Reel = struct {
    f: *movy.Frame,
    gl: *movy.GlyphLayer,
    pal: *const Palette,
    w: i32,
    h: i32, // pixels
    rows: usize,
    tw: f32 = 0, // the field's own clock - runs faster during the storm
    last_t: f32 = 0,

    fn cx(self: *const Reel) i32 {
        return @divTrunc(self.w, 2);
    }
    fn centerRow(self: *const Reel) i32 {
        return @intCast(self.rows / 2);
    }
    /// logo resting position (pixels), leaves one text row below it for the bar
    fn logoX(self: *const Reel) i32 {
        return @divTrunc(self.w - @as(i32, logo.W), 2);
    }
    fn logoY(self: *const Reel) i32 {
        const y = @divTrunc(self.h - @as(i32, logo.H), 2) - 3;
        return y & ~@as(i32, 1); // even: logo rows align to cells
    }
    fn barRow(self: *const Reel) usize {
        return @intCast(@divTrunc(self.logoY() + @as(i32, logo.H), 2) + 1);
    }
};

// ---------------------------------------------------------------- helpers

fn hashU32(x_in: u32) u32 {
    var x = x_in;
    x ^= x >> 16;
    x *%= 0x7feb352d;
    x ^= x >> 15;
    x *%= 0x846ca68b;
    x ^= x >> 16;
    return x;
}
fn hash01(seed: u32) f32 {
    return @as(f32, @floatFromInt(hashU32(seed) & 0xffffff)) / @as(f32, 0xffffff);
}
fn smoothstep(e0: f32, e1: f32, x: f32) f32 {
    const t = std.math.clamp((x - e0) / (e1 - e0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
fn lin(e0: f32, e1: f32, x: f32) f32 {
    return std.math.clamp((x - e0) / (e1 - e0), 0.0, 1.0);
}
fn easeOutCubic(x: f32) f32 {
    const u = 1.0 - x;
    return 1.0 - u * u * u;
}
fn easeInCubic(x: f32) f32 {
    return x * x * x;
}
fn toRgb(c: V3) Rgb {
    return c.toRgb();
}
fn cellWidth(text: []const u8) usize {
    return std.unicode.utf8CountCodepoints(text) catch text.len;
}

/// Storm intensity 0..1.
fn storm(t: f32) f32 {
    return smoothstep(T_STORM0, T_PEAK, t) * (1.0 - smoothstep(T_CALM0, T_CALM1, t));
}

/// Screen shake (pixels) on the storm's peak.
fn shake(t: f32) struct { x: i32, y: i32 } {
    const td = t - T_PEAK;
    if (td < 0.0 or td > 0.8) return .{ .x = 0, .y = 0 };
    const env = 1.0 - td / 0.8;
    const e2 = env * env;
    return .{
        .x = @intFromFloat(@round(e2 * 3.0 * @sin(t * 53.0))),
        .y = @intFromFloat(@round(e2 * 2.0 * @sin(t * 41.0 + 1.3))),
    };
}

// ------------------------------------------------------------ background

/// The field value 0..1 at (u, v). `s` is the storm: faster, denser, more
/// warped waves plus a ripple running out from the logo.
fn fieldK(u: f32, v: f32, tw: f32, s: f32, aspect: f32) f32 {
    const fm = 1.0 + 0.9 * s;
    const warp = 1.4 + 2.6 * s;
    const wy = @sin(v * 3.1 * fm - tw * 0.23);
    var p = @sin(u * 4.2 * fm + tw * 0.31 + wy * (1.0 + s)) +
        @sin(v * 4.8 * fm - tw * 0.19 + @sin(u * 2.3 * fm + tw * 0.17) * warp) +
        @sin((u * 0.8 + v) * 3.4 * fm + tw * 0.27);
    if (s > 0.001) {
        const du = (u - 0.5) * aspect;
        const dv = v - 0.42;
        p += s * 1.3 * @sin(@sqrt(du * du + dv * dv) * 24.0 - tw * 2.4);
    }
    return std.math.clamp(p * (1.0 / 6.0) * (1.0 + 0.7 * s) + 0.5, 0.0, 1.0);
}

fn fieldColor(pal: *const Palette, k: f32, s: f32) V3 {
    const mid = pal.mid.lerp(pal.hot_mid, s);
    const high = pal.high.lerp(pal.hot_high, s);
    return if (k < 0.5)
        pal.deep.lerp(mid, smoothstep(0.1, 0.5, k))
    else
        mid.lerp(high, smoothstep(0.5, 0.9, k));
}

fn drawField(r: *Reel, t: f32, s: f32, fade: f32) void {
    const f = r.f;
    const uw: usize = @intCast(f.w);
    const uh: usize = @intCast(f.h);
    const inv_w = 1.0 / @as(f32, @floatFromInt(uw));
    const inv_h = 1.0 / @as(f32, @floatFromInt(uh));
    const aspect = @as(f32, @floatFromInt(uw)) * inv_h;
    const sh = shake(t);
    const bright = (1.0 + 0.6 * s) * fade;
    for (0..uh) |y| {
        const v = (@as(f32, @floatFromInt(y)) + @as(f32, @floatFromInt(sh.y))) * inv_h;
        const row = y * uw;
        for (0..uw) |x| {
            const u = (@as(f32, @floatFromInt(x)) + @as(f32, @floatFromInt(sh.x))) * inv_w;
            const k = fieldK(u, v, r.tw, s, aspect);
            const du = u - 0.5;
            const dv = v - 0.5;
            f.solid[row + x] = fieldColor(r.pal, k, s).scale(bright * (1.0 - 1.2 * (du * du + dv * dv)));
        }
    }

    // scanner beams
    for ([_]Beam{ NEWS_BEAM, VX_BEAM }) |b| {
        if (t <= b.t0 or t >= b.t1 + 0.3) continue;
        const bx = beamX(r, b, t);
        var dx: i32 = -2;
        while (dx <= 2) : (dx += 1) {
            const fall = @exp(-@as(f32, @floatFromInt(dx * dx)) / 2.5);
            f.gvline(@as(i32, @intFromFloat(bx)) + dx, 0, f.h, b.col.scale(0.13 * fall));
        }
    }

    // storm peak: shockwave rings from the logo + a cool flash
    const lcx = @as(f32, @floatFromInt(r.cx()));
    const lcy = @as(f32, @floatFromInt(r.logoY())) + @as(f32, @floatFromInt(logo.H)) * 0.5;
    const rings = [_]f32{ T_PEAK, T_PEAK + 0.35, T_PEAK + 0.7 };
    for (rings, 0..) |t0, i| {
        const rt = (t - t0) / 1.4;
        if (rt <= 0.0 or rt >= 1.0) continue;
        const a = 1.0 - rt;
        const col = if (i == 1) v3(1.0, 0.4, 0.9) else v3(0.3, 0.9, 1.0);
        f.gring(lcx, lcy, rt * @as(f32, @floatFromInt(f.w)) * 0.7, col.scale(0.5 * a * a));
    }
    const ft = t - T_PEAK;
    f.flash = if (ft >= 0.0 and ft < 0.6) 0.45 * (1.0 - ft / 0.6) * (1.0 - ft / 0.6) else 0.0;
    f.flash_col = v3(0.75, 0.95, 1.0);
}

const Beam = struct { t0: f32, t1: f32, reverse: bool, col: V3 };
const NEWS_BEAM = Beam{ .t0 = T_BEAM0, .t1 = T_BEAM1, .reverse = false, .col = v3(0.2, 0.8, 1.0) };
const VX_BEAM = Beam{ .t0 = T_VX0, .t1 = T_VX1, .reverse = true, .col = v3(1.0, 0.3, 0.8) };

/// Beam position 0..1 across the screen (with 10 columns of run-up per side).
fn beamPos(b: Beam, p_time: f32) f32 {
    return if (b.reverse) 1.0 - p_time else p_time;
}
fn beamX(r: *const Reel, b: Beam, t: f32) f32 {
    const w: f32 = @floatFromInt(r.w);
    return beamPos(b, lin(b.t0, b.t1, t)) * (w + 20.0) - 10.0;
}
/// When the beam passes column x.
fn beamTime(r: *const Reel, b: Beam, x: usize) f32 {
    const w: f32 = @floatFromInt(r.w);
    const p = beamPos(b, (@as(f32, @floatFromInt(x)) + 10.0) / (w + 20.0));
    return b.t0 + p * (b.t1 - b.t0);
}

// ------------------------------------------------------------------ logo

fn logoPose(r: *const Reel, t: f32) struct { y: i32, a: f32 } {
    const rest: f32 = @floatFromInt(r.logoY());
    const below = @as(f32, @floatFromInt(r.h)) + 2.0;
    const above = -@as(f32, @floatFromInt(logo.H)) - 4.0;
    var y = rest;
    var a: f32 = 0;
    if (t < T_LOGO_IN0 or t >= T_LOGO_OUT1) return .{ .y = 0, .a = 0 };
    if (t < T_LOGO_IN1) {
        y = below + (rest - below) * easeOutCubic(lin(T_LOGO_IN0, T_LOGO_IN1, t));
        a = smoothstep(T_LOGO_IN0, T_LOGO_IN1 - 0.6, t);
    } else if (t < T_LOGO_OUT0) {
        a = 1.0;
    } else {
        y = rest + (above - rest) * easeInCubic(lin(T_LOGO_OUT0, T_LOGO_OUT1, t));
        a = 1.0 - smoothstep(T_LOGO_OUT0 + 0.2, T_LOGO_OUT1 - 0.2, t);
    }
    return .{ .y = @intFromFloat(@round(y)), .a = a };
}

fn drawLogo(r: *Reel, t: f32, s: f32) void {
    const pose = logoPose(r, t);
    if (pose.a <= 0.001) return;
    const f = r.f;
    const sh = shake(t);
    const ox = r.logoX() - sh.x;
    const oy = pose.y - sh.y;
    // the logo breathes light into the glow buffer during the storm
    const pulse = 0.03 + s * (0.10 + 0.06 * @sin(t * 9.0));
    for (0..logo.H) |ly| {
        for (0..logo.W) |lx| {
            const raw = logo.data[ly * logo.W + lx];
            const x = ox + @as(i32, @intCast(lx));
            const y = oy + @as(i32, @intCast(ly));
            if (!f.inBounds(x, y)) continue;
            if (raw == 0) { // interior: the field shows through, dimmed in the storm
                const i = f.idx(x, y);
                f.solid[i] = f.solid[i].scale(1.0 - 0.7 * s * pose.a);
                continue;
            }
            const g = @as(f32, @floatFromInt(raw)) / 255.0;
            const col = v3(g, g, g);
            const i = f.idx(x, y);
            f.solid[i] = f.solid[i].lerp(col, pose.a);
            if (raw >= 178) f.gpx(x, y, v3(0.7, 0.85, 1.0).scale(pulse * pose.a));
        }
    }
}

// ------------------------------------------------------------------ text

const Reveal = union(enum) {
    beam: Beam, // lock where the scanner beam passes
    random: struct { t0: f32, t1: f32 }, // lock in random order in [t0, t1]
};

/// Average pixel color under text cell (x, row), before post-fx.
fn cellUnder(f: *const movy.Frame, x: usize, row: usize) V3 {
    const uw: usize = @intCast(f.w);
    const a = f.solid[row * 2 * uw + x].add(f.glow[row * 2 * uw + x]);
    const b = f.solid[(row * 2 + 1) * uw + x].add(f.glow[(row * 2 + 1) * uw + x]);
    return a.add(b).scale(0.5);
}

/// A block of lines: every char scrambles, locks in with a flash, holds,
/// then scrambles off and vanishes at a random time in [gone0, gone1].
fn drawBlock(r: *Reel, lines: []const Line, id: u32, t: f32, reveal: Reveal, gone0: f32, gone1: f32) void {
    const f = r.f;
    const gl = r.gl;
    const scr_in: f32 = if (reveal == .beam) 0.55 else 0.45;
    const scr_out: f32 = 0.30;
    const flash_len: f32 = 0.22;
    const tick: u32 = @intFromFloat(t * 18.0);

    for (lines, 0..) |line, li| {
        const row_i = r.centerRow() + line.dy;
        if (row_i < 0 or row_i >= @as(i32, @intCast(r.rows))) continue;
        const row: usize = @intCast(row_i);
        const len = cellWidth(line.text);
        const x0 = (@as(usize, @intCast(r.w)) -| len) / 2;
        var it = (std.unicode.Utf8View.init(line.text) catch unreachable).iterator();
        var i: usize = 0;
        while (it.nextCodepoint()) |ch| : (i += 1) {
            const x = x0 + i;
            const seq = id * 4096 + @as(u32, @intCast(li)) * 128 + @as(u32, @intCast(i));
            if (ch == ' ' and line.bg == null) continue;

            const lock = switch (reveal) {
                .beam => |b| beamTime(r, b, x) + 0.05 + hash01(seq) * 0.25,
                .random => |rv| rv.t0 + hash01(seq) * (rv.t1 - rv.t0),
            };
            const gone = gone0 + hash01(seq *% 31 + 7) * (gone1 - gone0);
            if (t < lock - scr_in or t >= gone) continue;

            const final = V3.fromRgb(line.col);
            const scram = SCRAMBLE[hashU32(seq *% 131 +% tick) % SCRAMBLE.len];
            if (t < lock) { // scrambling in: cyan heating up
                const heat = (t - (lock - scr_in)) / scr_in;
                gl.put(x, row, scram, toRgb(v3(0.1, 0.5, 0.6).lerp(v3(0.4, 1.0, 1.0), heat)));
                continue;
            }
            if (t >= gone - scr_out) { // scrambling off: fading into the field
                const k = (t - (gone - scr_out)) / scr_out;
                gl.put(x, row, scram, toRgb(v3(0.4, 1.0, 1.0).lerp(v3(0.05, 0.25, 0.35), k)));
                continue;
            }
            const flash = 1.0 - smoothstep(0.0, flash_len, t - lock);
            if (line.bg) |bg| {
                const bgv = V3.fromRgb(bg).lerp(v3(1, 1, 1), flash);
                gl.putSolid(x, row, ch, toRgb(final), toRgb(bgv));
            } else {
                gl.put(x, row, ch, toRgb(final.lerp(v3(1, 1, 1), flash)));
            }
            if (flash > 0.01) f.gcell(@intCast(x), @intCast(row), v3(0.5, 0.9, 1.0).scale(flash * 0.5));
        }
    }
}

/// The .solid bar under the logo: its background cross-fades from the
/// pixels underneath to the bar color.
fn drawBar(r: *Reel, t: f32) void {
    const a = smoothstep(T_BAR_IN0, T_BAR_IN1, t) * (1.0 - smoothstep(T_BAR_OUT0, T_BAR_OUT1, t));
    if (a <= 0.001) return;
    const row = r.barRow();
    const x0 = (@as(usize, @intCast(r.w)) -| cellWidth(BAR_TEXT)) / 2;
    var it = (std.unicode.Utf8View.init(BAR_TEXT) catch unreachable).iterator();
    var i: usize = 0;
    while (it.nextCodepoint()) |ch| : (i += 1) {
        const under = cellUnder(r.f, x0 + i, row);
        const bg = under.lerp(V3.fromRgb(PINK), a);
        const fg = under.lerp(V3.fromRgb(INK), a);
        r.gl.putSolid(x0 + i, row, ch, toRgb(fg), toRgb(bg));
    }
}

/// A camcorder-style "REC" with the video's timecode while VideoExport is on.
fn drawRec(r: *Reel, t: f32) void {
    const a = smoothstep(T_REC0, T_REC0 + 0.4, t) * (1.0 - smoothstep(T_REC1 - 0.4, T_REC1, t));
    if (a <= 0.001) return;
    const blink: f32 = if (@mod(t, 1.0) < 0.6) 1.0 else 0.25;
    r.gl.put(3, 1, 0x25CF, toRgb(v3(1.0, 0.15, 0.25).scale(a * blink))); // ●
    const secs: u32 = @intFromFloat(t);
    const frame: u32 = @intFromFloat(@mod(t, 1.0) * FPS);
    var buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "REC  00:{d:0>2}:{d:0>2}", .{ secs, frame }) catch return;
    _ = r.gl.putStr(5, 1, s, toRgb(V3.fromRgb(ICE).scale(a)));
    if (blink > 0.5) r.f.gcell(3, 1, v3(1.0, 0.1, 0.2).scale(0.15 * a));
}

/// The storm's glyphs: wherever the waves crest, cells fill with scramble
/// characters in the field's own (brightened) colors.
fn drawStormGlyphs(r: *Reel, t: f32, s: f32) void {
    if (s < 0.12) return;
    const uw: usize = @intCast(r.w);
    const inv_w = 1.0 / @as(f32, @floatFromInt(r.w));
    const inv_h = 1.0 / @as(f32, @floatFromInt(r.h));
    const aspect = @as(f32, @floatFromInt(r.w)) * inv_h;
    const thresh = 1.0 - 0.34 * s;
    const tick: u32 = @intFromFloat(r.tw * 10.0);
    // keep the logo and the bar clean
    const pose = logoPose(r, t);
    const l_row0: i32 = @divFloor(pose.y, 2) - 1;
    const l_row1: i32 = @divFloor(pose.y + @as(i32, logo.H), 2) + 1;
    const lx0: usize = @intCast(r.logoX() - 2);
    const lx1: usize = @intCast(r.logoX() + @as(i32, logo.W) + 2);
    const bar_row = r.barRow();

    for (0..r.rows) |row| {
        const v = (@as(f32, @floatFromInt(row)) * 2.0 + 1.0) * inv_h;
        const ri: i32 = @intCast(row);
        for (0..uw) |x| {
            if (pose.a > 0.0 and ri >= l_row0 and ri <= l_row1 and x >= lx0 and x < lx1) continue;
            if (row == bar_row) continue;
            const u = (@as(f32, @floatFromInt(x)) + 0.5) * inv_w;
            const k = fieldK(u, v, r.tw, s, aspect);
            if (k < thresh) continue;
            const seq: u32 = @intCast(row * uw + x);
            if (hash01(seq *% 17 +% tick / 3) > 0.25 + 0.25 * s) continue; // sparkle, not a wall
            const heat = (k - thresh) / (1.0 - thresh + 0.001);
            const col = fieldColor(r.pal, k, s).scale(3.2).lerp(v3(0.8, 1.0, 1.0), heat * 0.6 * s);
            r.gl.put(x, row, SCRAMBLE[hashU32(seq *% 97 +% tick) % SCRAMBLE.len], toRgb(col));
        }
    }
}

// ----------------------------------------------------------------- frame

fn frameStep(r: *Reel, t_story: f32, t_anim: f32) void {
    const dt = @max(t_anim - r.last_t, 0.0);
    r.last_t = t_anim;
    const s = storm(t_story);
    r.tw += dt * (1.0 + 5.0 * s);

    const fade_in = smoothstep(0.0, T_FADE_IN, t_story);
    const fade_out = 1.0 - smoothstep(T_FADE_OUT0, T_TOTAL, t_story);

    const f = r.f;
    f.beginFrame();
    r.gl.clear();
    drawField(r, t_story, s, fade_in);
    drawLogo(r, t_story, s);
    drawStormGlyphs(r, t_story, s);
    drawBlock(r, &NEWS, 1, t_story, .{ .beam = NEWS_BEAM }, T_NEWS_GONE0, T_NEWS_GONE1);
    drawBlock(r, &VX, 4, t_story, .{ .beam = VX_BEAM }, T_VX_GONE0, T_VX_GONE1);
    drawRec(r, t_story);
    drawBar(r, t_story);
    drawBlock(r, &RECAP, 2, t_story, .{ .random = .{ .t0 = T_RECAP0, .t1 = T_RECAP1 } }, T_RECAP_GONE0, T_RECAP_GONE1);
    drawBlock(r, &CARD, 3, t_story, .{ .random = .{ .t0 = T_CARD0, .t1 = T_CARD1 } }, T_CARD_GONE0, T_CARD_GONE1);
    f.glyphGlow(0.025);
    f.tint = v3(1, 1, 1).scale(fade_out);
    f.composite();
}

/// An export dir argument (not one of the keywords).
fn isPath(a: []const u8) bool {
    const words = [_][]const u8{ "wide", "once", "pal", "full", "small", "font", "shot" };
    for (words) |w| if (std.mem.eql(u8, a, w)) return false;
    return true;
}

fn storyTime(t: f32, opts: Opts) f32 {
    return if (opts.once) @min(t, T_CARD_HOLD) else @mod(t, T_TOTAL);
}

fn setup(allocator: std.mem.Allocator, opts: Opts) !Reel {
    const w: i32 = if (opts.wide) 120 else 100;
    const h: i32 = if (opts.wide) 40 else 56; // 100x28 cells ~ 16:9
    const f = try movy.Frame.init(allocator, w, h);
    errdefer f.deinit();
    f.glow_decay = 0.80;
    f.setVignette(0.30);
    const rows: usize = @intCast(@divTrunc(h, 2));
    const gl = try movy.GlyphLayer.init(allocator, @intCast(w), rows);
    errdefer gl.deinit();
    try f.setGlyphs(gl);
    return .{ .f = f, .gl = gl, .pal = opts.pal, .w = w, .h = h, .rows = rows };
}

/// Headless: simulate at 60fps up to `t_end` seconds, write the frame's ANSI.
fn shot(allocator: std.mem.Allocator, opts: Opts, t_end: f32, path: []const u8) !void {
    var r = try setup(allocator, opts);
    defer r.f.deinit();
    defer r.gl.deinit();
    r.f.surface.setGlyphs(r.gl); // no Screen here: encode the frame surface directly

    const frames: usize = @intFromFloat(t_end * FPS);
    for (0..frames + 1) |i| {
        const t = @as(f32, @floatFromInt(i)) / FPS;
        frameStep(&r, storyTime(t, opts), t);
    }
    const ansi = try r.f.surface.toAnsi();
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = ansi });
}

/// Record the reel with movy.VideoExport: a fixed 60fps clock (frame N is
/// t = N / 60 exactly), every frame written as a PNG into `dir`. Then:
///   tools/makevideo.sh <dir> glyph-reel.mp4 [--audio music.wav]
fn exportFrames(allocator: std.mem.Allocator, opts_in: Opts, dir: []const u8, full: bool) !void {
    var opts = opts_in;
    opts.once = !full;
    var r = try setup(allocator, opts);
    defer r.f.deinit();
    defer r.gl.deinit();
    r.f.surface.setGlyphs(r.gl); // no Screen: rasterize the frame surface directly

    const ve = try movy.VideoExport.init(allocator, @intCast(r.w), r.rows, .{
        .font = opts.font,
        .cell = opts.cell,
        .out_dir = dir,
        .fps = FPS,
    });
    defer ve.deinit();

    const duration = if (full) T_TOTAL else T_CARD_HOLD + EXPORT_TAIL;
    const total: u32 = @intFromFloat(@round(duration * FPS));
    std.debug.print("export: {d}x{d} px ({d}x{d} cells, {s}) -> {s}/  {d} frames = {d:.1}s of video @ {d}fps\n", .{
        ve.img_w, ve.img_h, r.w, r.rows, ve.font.label, dir, total, duration, @as(u32, @intFromFloat(FPS)),
    });
    if (@import("builtin").mode == .Debug) {
        std.debug.print("  note: Debug build - about 10x slower; build with -Doptimize=ReleaseFast\n", .{});
    }
    const t0 = std.time.nanoTimestamp();
    while (ve.frame_n < total) {
        const t = ve.time();
        frameStep(&r, storyTime(t, opts), t);
        try ve.writeFrame(r.f.surface);
        if (ve.frame_n % 300 == 0) {
            const el = @as(f32, @floatFromInt(std.time.nanoTimestamp() - t0)) / 1.0e9;
            // export speed, not the video's frame rate (that is always FPS)
            const rate = @as(f32, @floatFromInt(ve.frame_n)) / el;
            const eta: u32 = @intFromFloat(@as(f32, @floatFromInt(total - ve.frame_n)) / rate);
            std.debug.print("  frame {d}/{d}  rendering {d:.1} frames/s  eta {d}s\n", .{ ve.frame_n, total, rate, eta });
        }
    }
    const el = @as(f32, @floatFromInt(std.time.nanoTimestamp() - t0)) / 1.0e9;
    std.debug.print("export done: {d} frames in {d:.1}s\n  next: tools/makevideo.sh {s} glyph-reel.mp4\n", .{ total, el, dir });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var opts = Opts{};
    var shot_t: ?f32 = null;
    var shot_path: []const u8 = "glyph-reel.ans";
    var export_dir: ?[]const u8 = null;
    var export_full = false;
    var ai: usize = 1;
    while (ai < args.len) : (ai += 1) {
        const a = args[ai];
        if (std.mem.eql(u8, a, "wide")) {
            opts.wide = true;
        } else if (std.mem.eql(u8, a, "once")) {
            opts.once = true;
        } else if (std.mem.eql(u8, a, "pal") and ai + 1 < args.len) {
            ai += 1;
            for (&PALETTES) |*p| {
                if (std.mem.eql(u8, p.name, args[ai])) opts.pal = p;
            }
        } else if (std.mem.eql(u8, a, "export")) {
            export_dir = "export";
            if (ai + 1 < args.len and isPath(args[ai + 1])) {
                ai += 1;
                export_dir = args[ai];
            }
        } else if (std.mem.eql(u8, a, "full")) {
            export_full = true;
        } else if (std.mem.eql(u8, a, "small")) {
            opts.cell = .@"10x20";
        } else if (std.mem.eql(u8, a, "font") and ai + 1 < args.len) {
            ai += 1;
            if (std.mem.startsWith(u8, args[ai], "dejavu")) opts.font = .dejavu_sans_mono;
            if (std.mem.startsWith(u8, args[ai], "jetbrains")) opts.font = .jetbrains_mono;
        } else if (std.mem.eql(u8, a, "shot")) {
            shot_t = 16.0;
            if (ai + 1 < args.len) {
                if (std.fmt.parseFloat(f32, args[ai + 1])) |v| {
                    shot_t = v;
                    ai += 1;
                    if (ai + 1 < args.len and std.mem.endsWith(u8, args[ai + 1], ".ans")) {
                        ai += 1;
                        shot_path = args[ai];
                    }
                } else |_| {}
            }
        }
    }
    if (shot_t) |t| return shot(allocator, opts, t, shot_path);
    if (export_dir) |dir| return exportFrames(allocator, opts, dir, export_full);

    var r = try setup(allocator, opts);
    defer r.f.deinit();
    defer r.gl.deinit();

    const term = try movy.terminal.getSize();
    if (term.width < @as(usize, @intCast(r.w)) or term.height < r.rows) {
        std.debug.print("needs a terminal of at least {d}x{d} cells (yours is {d}x{d}).\n", .{ r.w, r.rows, term.width, term.height });
        return;
    }

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(allocator, @intCast(r.w), r.rows);
    defer screen.deinit(allocator);
    screen.setScreenMode(.bgcolor);
    screen.bg_color = .{};
    const off_cols = @as(i32, @intCast(term.width)) - r.w;
    const off_rows = @as(i32, @intCast(term.height)) - @as(i32, @intCast(r.rows));
    screen.setXY(@divTrunc(off_cols, 2), @divTrunc(off_rows, 2) * 2);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[48;2;0;0;0m\x1b[2J\x1b[0m") catch 0;

    // the layer is resolved on the surface that gets encoded
    screen.output_surface.setGlyphs(r.gl);

    var dout = try movy.DiffOutput.init(allocator, &screen, .threaded);
    defer dout.deinit();

    const start: i128 = std.time.nanoTimestamp();
    var next_deadline: i128 = start;
    while (true) {
        next_deadline += FRAME_NS;
        var quit = false;
        while (try movy.input.get()) |ev| switch (ev) {
            .key => |k| switch (k.type) {
                .Escape, .CtrlC => quit = true,
                .Char => if (k.sequence.len > 0 and (k.sequence[0] == 'q' or k.sequence[0] == 'Q')) {
                    quit = true;
                },
                else => {},
            },
            .mouse => {},
        };
        if (quit) break;

        const t: f32 = @as(f32, @floatFromInt(std.time.nanoTimestamp() - start)) / 1.0e9;
        frameStep(&r, storyTime(t, opts), t);

        try screen.renderInit();
        try screen.addRenderSurface(allocator, r.f.surface);
        screen.render();
        try dout.output(&screen);

        const now = std.time.nanoTimestamp();
        if (next_deadline > now) {
            std.Thread.sleep(@intCast(next_deadline - now));
        } else {
            next_deadline = now;
        }
    }
}
