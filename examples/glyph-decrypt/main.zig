//! glyph-decrypt - text that lives inside a neon pixel scene.
//!
//! Shows movy's GlyphLayer on the Frame path: a synthwave grid and a scanner
//! beam are drawn as half-block pixels (with glow), and the text is a
//! GlyphLayer on top. Each character scrambles through random glyphs, then
//! locks in with a flash of light; `.pixels` glyph backgrounds let the grid
//! and the glow show through behind the text, and glyphGlow() gives the text a
//! bloom halo. The bottom bar uses `.solid` backgrounds for contrast.
//!
//!   zig build run-glyph-decrypt                      -> run it (ESC / q quits)
//!   zig build run-glyph-decrypt -- shot 0.5 out.ans  -> headless: simulate up
//!       to loop phase 0.5 and write that frame's ANSI (toAnsi) to out.ans
//!       (view it: tools/ansi2html.py out.ans out.html --png out.png)
//!
//! The ground grid is evaluated per pixel like a fragment shader (drawGrid):
//! antialiased lines that scroll smoothly between pixel rows and fade into a
//! haze where they get denser than the pixels can show.

const std = @import("std");
const movy = @import("movy");

const V3 = movy.color.V3;
const Rgb = movy.core.types.Rgb;
const v3 = movy.color.v3;

const CANVAS_W: i32 = 100; // columns
const CANVAS_H: i32 = 52; // pixels = 26 text rows
const ROWS: usize = @intCast(@divTrunc(CANVAS_H, 2));
const LOOP_SECONDS: f32 = 9.0;
const FPS: f32 = 60.0;
const FRAME_NS: i128 = 16_666_667;

const HORIZON: i32 = 30; // pixel row of the grid's horizon

const LINES = [_]struct { row: usize, text: []const u8, col: Rgb }{
    .{ .row = 2, .text = "G L Y P H   L A Y E R", .col = .{ .r = 255, .g = 120, .b = 220 } },
    .{ .row = 5, .text = "text that lives inside the scene", .col = .{ .r = 200, .g = 240, .b = 255 } },
    .{ .row = 7, .text = "half-block pixels below, glyphs on top", .col = .{ .r = 150, .g = 210, .b = 255 } },
    .{ .row = 9, .text = "the grid and the glow shine through", .col = .{ .r = 150, .g = 210, .b = 255 } },
};
const SCRAMBLE = "01<>/\\|[]{}#%&*+=?!ABCDEFXYZ$@~^";

// loop phases
const REVEAL_END: f32 = 0.45; // last char locked by here
const HOLD_END: f32 = 0.80; // then characters dissolve
const DISSOLVE_END: f32 = 0.95;
const SCRAMBLE_LEN: f32 = 0.10; // phase a char spends scrambling
const FLASH_LEN: f32 = 0.035; // phase of the lock-in flash

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
fn toRgb(c: V3) Rgb {
    return c.toRgb();
}

/// Background: gradient sky, sun bands, a scrolling perspective grid, and a
/// scanner beam that sweeps while the text decrypts.
fn drawScene(f: *movy.Frame, n: f32, t: f32) void {
    const uw: usize = @intCast(f.w);
    // sky gradient (solid)
    var y: i32 = 0;
    while (y < CANVAS_H) : (y += 1) {
        const k = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(CANVAS_H));
        const sky = if (y < HORIZON)
            v3(0.03, 0.0, 0.08).lerp(v3(0.20, 0.02, 0.22), k * k * 1.6)
        else
            v3(0.02, 0.0, 0.05);
        const row = @as(usize, @intCast(y)) * uw;
        @memset(f.solid[row..][0..uw], sky);
    }

    // sun: a banded disc sitting on the horizon
    const cx: f32 = @as(f32, @floatFromInt(CANVAS_W)) * 0.5;
    const sun_r: f32 = 8.0;
    y = HORIZON - 9;
    while (y < HORIZON) : (y += 1) {
        const dy = (@as(f32, @floatFromInt(y)) - @as(f32, @floatFromInt(HORIZON))) * 1.9;
        if (@abs(dy) > sun_r * 1.9) continue;
        const band = @mod(@as(f32, @floatFromInt(y)) + t * 3.0, 3.0) < 1.0 and y > HORIZON - 5;
        if (band) continue;
        const half = @sqrt(@max(0.0, sun_r * sun_r * 3.6 - dy * dy)) * 1.1;
        var x: i32 = @intFromFloat(cx - half);
        while (@as(f32, @floatFromInt(x)) < cx + half) : (x += 1) {
            const kk = @as(f32, @floatFromInt(HORIZON - y)) / 9.0;
            f.px(x, y, v3(1.0, 0.35, 0.25).lerp(v3(1.0, 0.85, 0.3), kk));
        }
    }

    drawGrid(f, t);

    // scanner beam during the reveal
    if (n < REVEAL_END + 0.05) {
        const bx = (n / (REVEAL_END + 0.05)) * @as(f32, @floatFromInt(CANVAS_W + 20)) - 10.0;
        var dx: i32 = -2;
        while (dx <= 2) : (dx += 1) {
            const fall = @exp(-@as(f32, @floatFromInt(dx * dx)) / 2.5);
            f.gvline(@as(i32, @intFromFloat(bx)) + dx, 0, CANVAS_H, v3(0.2, 0.8, 1.0).scale(0.12 * fall));
        }
    }
}

// Ground grid: world lines on a plane seen from above the horizon.
const GRID_CAM_H: f32 = 20.0; // depth scale: larger = lines farther apart near us
const GRID_U: f32 = 1.0; // sideways scale: larger = verticals closer together
const GRID_LINE_PX: f32 = 1.1; // line half-width in pixels
const GRID_COL = v3(0.9, 0.1, 0.8);
const FLOOR = v3(0.02, 0.0, 0.05);
const GRID_HAZE: f32 = 0.3; // brightness where lines blur together at the horizon

/// Antialiased coverage of a grid line: `d` is the world distance to the
/// nearest line, `deriv` how much world one pixel spans, `slant` the line's
/// horizontal pixels per pixel row (0 for horizontal/vertical lines; a slanted
/// line's perpendicular distance is shorter than the measured one). Where lines
/// get denser than ~2px they fade to their average coverage instead of aliasing.
fn lineCov(d: f32, deriv: f32, slant: f32) f32 {
    const px = (d / deriv) / @sqrt(1.0 + slant * slant);
    const cov = std.math.clamp(1.0 - px / GRID_LINE_PX, 0.0, 1.0);
    const avg = @min(GRID_LINE_PX * deriv, GRID_HAZE);
    return cov + (avg - cov) * smoothstep(0.25, 0.6, deriv);
}

/// A perspective grid evaluated per pixel (like a fragment shader): soft,
/// sub-pixel-smooth scrolling, fading into a glowing haze at the horizon.
fn drawGrid(f: *movy.Frame, t: f32) void {
    const uw: usize = @intCast(f.w);
    const cx: f32 = @as(f32, @floatFromInt(CANVAS_W)) * 0.5;
    const depth_rows: f32 = @floatFromInt(CANVAS_H - HORIZON);
    const scroll = t * 1.6;

    var y: i32 = HORIZON;
    while (y < CANVAS_H) : (y += 1) {
        const dy = @as(f32, @floatFromInt(y - HORIZON)) + 0.5; // pixel center
        const depth = GRID_CAM_H / dy;
        const dz = GRID_CAM_H / (dy * dy); // world depth per pixel row
        const wz = depth + scroll;
        const cov_z = lineCov(@abs(wz - @round(wz)), dz, 0.0);
        const dwx = GRID_U / dy; // world x per pixel
        const fog = 0.35 + 0.65 * smoothstep(0.0, depth_rows, dy);
        const row = @as(usize, @intCast(y)) * uw;
        for (0..uw) |x| {
            const wx = (@as(f32, @floatFromInt(x)) + 0.5 - cx) * dwx;
            // line j sits at x = cx + j * dy / GRID_U: it slants j / GRID_U px per row
            const cov_x = lineCov(@abs(wx - @round(wx)), dwx, @round(wx) / GRID_U);
            const c = GRID_COL.scale(@max(cov_x, cov_z) * fog);
            f.solid[row + x] = FLOOR.add(c);
            f.glow[row + x] = f.glow[row + x].add(c.scale(0.03));
        }
    }

    // horizon: a soft glow band instead of a hard line
    f.ghline(0, HORIZON, CANVAS_W, v3(1.0, 0.3, 0.9).scale(0.07));
    f.ghline(0, HORIZON - 1, CANVAS_W, v3(1.0, 0.3, 0.9).scale(0.03));
}

/// Text: every char scrambles, locks in with a flash, holds, then dissolves.
fn drawText(f: *movy.Frame, gl: *movy.GlyphLayer, n: f32, t: f32) void {
    gl.clear();
    const tick: u32 = @intFromFloat(t * 18.0); // scramble rate
    var seq: u32 = 0;
    for (LINES) |line| {
        const x0 = (@as(usize, @intCast(CANVAS_W)) - line.text.len) / 2;
        for (line.text, 0..) |ch, i| {
            seq += 1;
            if (ch == ' ') continue;
            const x = x0 + i;
            // lock time: left to right, with jitter; dissolve time: random
            const along = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(CANVAS_W));
            const lock = 0.06 + along * (REVEAL_END - 0.12) + hash01(seq) * 0.06;
            const start = lock - SCRAMBLE_LEN;
            const gone = HOLD_END + hash01(seq *% 31 + 7) * (DISSOLVE_END - HOLD_END);
            if (n < start or n >= gone) continue;

            if (n < lock) {
                const r = hashU32(seq *% 131 +% tick);
                const s = SCRAMBLE[r % SCRAMBLE.len];
                const heat = (n - start) / SCRAMBLE_LEN;
                gl.put(x, line.row, s, toRgb(v3(0.1, 0.5, 0.6).lerp(v3(0.4, 1.0, 1.0), heat)));
                continue;
            }
            const since = n - lock;
            const flash = 1.0 - smoothstep(0.0, FLASH_LEN, since);
            const final = V3.fromRgb(line.col);
            // fading out: dim toward the dissolve point
            const fade = 1.0 - smoothstep(gone - 0.04, gone, n);
            gl.put(x, line.row, ch, toRgb(final.lerp(v3(1, 1, 1), flash).scale(fade)));
            if (flash > 0.01) f.gcell(@intCast(x), @intCast(line.row), v3(0.5, 0.9, 1.0).scale(flash * 0.5));
        }
    }

    // status bar: .solid backgrounds (still graded with the scene)
    const bar = " movy GlyphLayer  |  .pixels bg over the scene  |  .solid bg here  |  q quits ";
    const bx = (@as(usize, @intCast(CANVAS_W)) - bar.len) / 2;
    _ = gl.putStrSolid(bx, ROWS - 1, bar, .{ .r = 20, .g = 10, .b = 30 }, .{ .r = 255, .g = 120, .b = 220 });
}

fn frameStep(f: *movy.Frame, gl: *movy.GlyphLayer, n: f32, t: f32) void {
    f.beginFrame();
    drawScene(f, n, t);
    drawText(f, gl, n, t);
    f.glyphGlow(0.025);
    f.composite();
}

fn setupFrame(allocator: std.mem.Allocator) !struct { f: *movy.Frame, gl: *movy.GlyphLayer } {
    const f = try movy.Frame.init(allocator, CANVAS_W, CANVAS_H);
    errdefer f.deinit();
    f.glow_decay = 0.80;
    f.setVignette(0.30);
    const gl = try movy.GlyphLayer.init(allocator, @intCast(CANVAS_W), ROWS);
    errdefer gl.deinit();
    try f.setGlyphs(gl);
    return .{ .f = f, .gl = gl };
}

/// Headless: simulate at 60fps up to phase `n_end`, write the frame's ANSI.
fn shot(allocator: std.mem.Allocator, n_end: f32, path: []const u8) !void {
    const s = try setupFrame(allocator);
    defer s.f.deinit();
    defer s.gl.deinit();
    s.f.surface.setGlyphs(s.gl); // no Screen here: encode the frame surface directly

    const frames: usize = @intFromFloat(n_end * LOOP_SECONDS * FPS);
    for (0..frames + 1) |i| {
        const t = @as(f32, @floatFromInt(i)) / FPS;
        frameStep(s.f, s.gl, @mod(t / LOOP_SECONDS, 1.0), t);
    }
    const ansi = try s.f.surface.toAnsi();
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = ansi });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len >= 2 and std.mem.eql(u8, args[1], "shot")) {
        const n = if (args.len >= 3) try std.fmt.parseFloat(f32, args[2]) else 0.5;
        const path = if (args.len >= 4) args[3] else "glyph-decrypt.ans";
        return shot(allocator, n, path);
    }

    const term = try movy.terminal.getSize();
    if (term.width < @as(usize, @intCast(CANVAS_W)) or term.height < ROWS) {
        std.debug.print("needs a terminal of at least {d}x{d} cells (yours is {d}x{d}).\n", .{ CANVAS_W, ROWS, term.width, term.height });
        return;
    }

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(allocator, @intCast(CANVAS_W), ROWS);
    defer screen.deinit(allocator);
    screen.setScreenMode(.bgcolor);
    screen.bg_color = .{};
    const off_cols = @as(i32, @intCast(term.width)) - CANVAS_W;
    const off_rows = @as(i32, @intCast(term.height)) - @as(i32, @intCast(ROWS));
    screen.setXY(@divTrunc(off_cols, 2), @divTrunc(off_rows, 2) * 2);
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[48;2;0;0;0m\x1b[2J\x1b[0m") catch 0;

    const s = try setupFrame(allocator);
    defer s.f.deinit();
    defer s.gl.deinit();
    // the layer is resolved on the surface that gets encoded
    screen.output_surface.setGlyphs(s.gl);

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
        frameStep(s.f, s.gl, @mod(t / LOOP_SECONDS, 1.0), t);

        try screen.renderInit();
        try screen.addRenderSurface(allocator, s.f.surface);
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
