//! glyph-decrypt - text that lives inside a neon pixel scene.
//!
//! Shows movy's GlyphLayer on the Frame path: a slowly drifting color field
//! and a scanner beam are drawn as half-block pixels (with glow), and the text
//! is a GlyphLayer on top. Each character scrambles through random glyphs,
//! then locks in with a flash of light; `.pixels` glyph backgrounds let the
//! colors and the glow show through behind the text, and glyphGlow() gives the
//! text a bloom halo. The bottom bar uses `.solid` backgrounds for contrast.
//!
//!   zig build run-glyph-decrypt                      -> run it (ESC / q quits)
//!   zig build run-glyph-decrypt -- shot 0.5 out.ans  -> headless: simulate up
//!       to loop phase 0.5 and write that frame's ANSI (toAnsi) to out.ans
//!       (view it: tools/ansi2html.py out.ans out.html --png out.png)

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


const LINES = [_]struct { row: usize, text: []const u8, col: Rgb }{
    .{ .row = 7, .text = "G L Y P H   L A Y E R", .col = .{ .r = 255, .g = 120, .b = 220 } },
    .{ .row = 10, .text = "text that lives inside the scene", .col = .{ .r = 200, .g = 240, .b = 255 } },
    .{ .row = 12, .text = "half-block pixels below, glyphs on top", .col = .{ .r = 150, .g = 210, .b = 255 } },
    .{ .row = 14, .text = "the colors and the glow shine through", .col = .{ .r = 150, .g = 210, .b = 255 } },
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

/// Background: a slowly drifting color field (a few overlapping low-frequency
/// waves blended through a dark palette - no edges, so nothing to alias), and
/// a scanner beam that sweeps while the text decrypts.
fn drawScene(f: *movy.Frame, n: f32, t: f32) void {
    const uw: usize = @intCast(f.w);
    const uh: usize = @intCast(f.h);
    const inv_w = 1.0 / @as(f32, @floatFromInt(uw));
    const inv_h = 1.0 / @as(f32, @floatFromInt(uh));
    for (0..uh) |y| {
        const v = @as(f32, @floatFromInt(y)) * inv_h;
        const wy = @sin(v * 3.1 - t * 0.23);
        const row = y * uw;
        for (0..uw) |x| {
            const u = @as(f32, @floatFromInt(x)) * inv_w;
            // three drifting waves, one of them warped by another
            const p = @sin(u * 4.2 + t * 0.31 + wy) +
                @sin(v * 4.8 - t * 0.19 + @sin(u * 2.3 + t * 0.17) * 1.4) +
                @sin((u * 0.8 + v) * 3.4 + t * 0.27);
            const k = p * (1.0 / 6.0) + 0.5; // 0..1
            f.solid[row + x] = field(k, u, v);
        }
    }

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

const FIELD_DEEP = v3(0.02, 0.01, 0.07); // indigo
const FIELD_MID = v3(0.20, 0.03, 0.22); // magenta
const FIELD_HIGH = v3(0.02, 0.17, 0.24); // teal

/// The color field's palette: indigo -> magenta -> teal along k, darkened
/// toward the edges so the text block stays in front.
fn field(k: f32, u: f32, v: f32) V3 {
    const c = if (k < 0.5)
        FIELD_DEEP.lerp(FIELD_MID, smoothstep(0.1, 0.5, k))
    else
        FIELD_MID.lerp(FIELD_HIGH, smoothstep(0.5, 0.9, k));
    const du = u - 0.5;
    const dv = v - 0.5;
    return c.scale(1.0 - 1.2 * (du * du + dv * dv));
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
