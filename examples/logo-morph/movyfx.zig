//! movyfx - the shared harness behind the logo-morph example.
//!
//! main.zig owns the *scene* (what one frame looks like); this file owns
//! everything around it: the canvas size, the small math helpers, the particle
//! system the scene draws from, the post-fx tuning, and the live terminal loop
//! (with the little shell-prompt overlay you see at the bottom of the banner).
//!
//! A scene function draws ONE frame:  fn(frame, ctx, n) void, where `n` is the
//! loop phase in [0,1) and `ctx` is optional per-demo state (here: the particle
//! list). The loop clears `solid`, runs the scene, composites, and pushes the
//! result to the terminal.

const std = @import("std");
const movy = @import("movy");
const pal = @import("pal.zig");
const logo = @import("logo.zig");

pub const V3 = movy.color.V3;

// -------------------------------------------------------------- canvas / look

pub const CANVAS_W: i32 = 120; // pixel columns  (= terminal columns) - wide banner
pub const CANVAS_H: i32 = 40; // pixel rows     (= 20 terminal lines, 2 px/cell)
pub const MIN_VIEW_W: i32 = 120; // 120x40 px -> a 3:1 banner, like movy-gfx.png
pub const FRAME_NS: i128 = 16_666_667; // ~60 fps live

pub const WALL_LEVEL: u8 = 178; // raw >= this is a bright wall (vs gray frame)

// the 61x18 logo centered in the canvas
pub const LOGO_W: i32 = @intCast(logo.W);
pub const LOGO_H: i32 = @intCast(logo.H);
pub const LOGO_OX: i32 = @divTrunc(CANVAS_W - LOGO_W, 2);
pub const LOGO_OY: i32 = @divTrunc(CANVAS_H - LOGO_H, 2);

/// A scene draws one frame given the loop phase `n` in [0,1). Driving the scene
/// by phase (not a frame counter) lets the live view run smooth at 60fps no
/// matter how long the loop is. `ctx` is optional per-demo state.
pub const SceneFn = *const fn (f: *movy.Frame, ctx: ?*const anyopaque, n: f32) void;

// -------------------------------------------------------------- small math

pub fn hashU32(x: u32) u32 {
    var h = x;
    h ^= h >> 16;
    h *%= 0x7feb352d;
    h ^= h >> 15;
    h *%= 0x846ca68b;
    h ^= h >> 16;
    return h;
}
/// deterministic 0..1 from a seed (frame-reproducible, no RNG state)
pub fn hash01(seed: u32) f32 {
    return @as(f32, @floatFromInt(hashU32(seed) & 0xffffff)) / @as(f32, 0xffffff);
}
pub fn smoothstep(e0: f32, e1: f32, x: f32) f32 {
    const t = std.math.clamp((x - e0) / (e1 - e0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}
pub inline fn iround(x: f32) i32 {
    return @intFromFloat(@round(x));
}

// -------------------------------------------------------------- particles

/// One particle per non-black logo pixel. The scene reads `tx/ty` (where the
/// pixel belongs), `v` (its grayscale brightness) and `wall` (is it a bright
/// wall vs. the gray frame) to rebuild the logo every frame and to scatter the
/// pixels the sweeping beam touches. (`sx/sy`, `delay` and `col` are kept here
/// for the fly-in variants in the movy-fx family this example comes from.)
pub const Particles = struct {
    allocator: std.mem.Allocator,
    n: usize,
    tx: []f32, // target x (canvas px)
    ty: []f32, // target y
    sx: []f32, // off-canvas start x
    sy: []f32,
    v: []f32, // target brightness 0..1
    delay: []f32, // stagger 0..1
    col: []V3, // neon color
    wall: []bool, // bright wall (vs gray frame)

    pub fn init(allocator: std.mem.Allocator, ox: i32, oy: i32) !Particles {
        var cnt: usize = 0;
        for (logo.data) |d| {
            if (d != 0) cnt += 1;
        }
        var p: Particles = .{
            .allocator = allocator,
            .n = cnt,
            .tx = try allocator.alloc(f32, cnt),
            .ty = try allocator.alloc(f32, cnt),
            .sx = try allocator.alloc(f32, cnt),
            .sy = try allocator.alloc(f32, cnt),
            .v = try allocator.alloc(f32, cnt),
            .delay = try allocator.alloc(f32, cnt),
            .col = try allocator.alloc(V3, cnt),
            .wall = try allocator.alloc(bool, cnt),
        };

        const neon = [_]V3{ pal.P_CYAN, pal.P_BLUE, pal.P_AZURE, pal.P_VIOLET };
        const cxf: f32 = @floatFromInt(LOGO_OX + @divTrunc(@as(i32, @intCast(logo.W)), 2));
        const cyf: f32 = @floatFromInt(LOGO_OY + @divTrunc(@as(i32, @intCast(logo.H)), 2));

        var k: usize = 0;
        var j: usize = 0;
        while (j < logo.H) : (j += 1) {
            var i: usize = 0;
            while (i < logo.W) : (i += 1) {
                const raw = logo.data[j * logo.W + i];
                if (raw == 0) continue;
                const tx: f32 = @floatFromInt(ox + @as(i32, @intCast(i)));
                const ty: f32 = @floatFromInt(oy + @as(i32, @intCast(j)));
                p.tx[k] = tx;
                p.ty[k] = ty;
                p.v[k] = @as(f32, @floatFromInt(raw)) / 255.0;
                p.wall[k] = raw >= WALL_LEVEL;

                // fly in from far outside on a ray through the logo center
                const seed: u32 = @intCast(k);
                const dirx = tx - cxf;
                const diry = (ty - cyf) * 1.6; // canvas wider than tall
                var len = @sqrt(dirx * dirx + diry * diry);
                if (len < 0.001) len = 1.0;
                const jitter = (hash01(seed * 7 + 3) - 0.5) * 0.6;
                const ux = dirx / len + jitter;
                const uy = diry / len + jitter;
                const dist = 95.0 + hash01(seed * 7 + 5) * 70.0;
                p.sx[k] = cxf + ux * dist;
                p.sy[k] = cyf + uy * dist * 0.6;

                p.delay[k] = hash01(seed * 7 + 11);
                p.col[k] = neon[hashU32(seed * 7 + 17) % neon.len];
                k += 1;
            }
        }
        return p;
    }

    pub fn deinit(self: *Particles) void {
        const a = self.allocator;
        a.free(self.tx);
        a.free(self.ty);
        a.free(self.sx);
        a.free(self.sy);
        a.free(self.v);
        a.free(self.delay);
        a.free(self.col);
        a.free(self.wall);
    }
};

// -------------------------------------------------------------- post-fx tuning

/// Clean look: no vignette / scanline (the original is flat black). Color comes
/// from the cool GLOW tint and the neon particles.
pub fn tuneFrame(f: *movy.Frame) void {
    f.setVignette(0.0);
    f.scanline_mul = 1.0;
}

// -------------------------------------------------------------- prompt overlay

/// Draw a UTF-8 segment one codepoint per cell, returning the next column.
///
/// We can't use RenderSurface.putStrXY here: it iterates the string BYTE by byte
/// (so multi-byte glyphs like ↓ / › / █ turn into mojibake) and it returns a flat
/// buffer index, not a column. putUtf8XY places one decoded codepoint per cell,
/// and we advance the column ourselves.
fn putSeg(
    surface: *movy.RenderSurface,
    x: usize,
    row: usize,
    s: []const u8,
    fg: pal.Rgb,
    bg: pal.Rgb,
) usize {
    var col = x;
    var iter = (std.unicode.Utf8View.init(s) catch return col).iterator();
    while (iter.nextCodepoint()) |cp| {
        surface.putUtf8XY(cp, col, row, fg, bg);
        col += 1;
    }
    return col;
}

/// Draw the '~/get/movy  master ↓1 ›' prompt line as real terminal text on the
/// composited surface - a little "movy in your shell" caption under the banner.
pub fn drawPrompt(surface: *movy.RenderSurface, row: usize, blink_on: bool) void {
    const bg: pal.Rgb = .{ .r = 0, .g = 0, .b = 0 };
    const blue: pal.Rgb = .{ .r = 0x3c, .g = 0x9a, .b = 0xe0 };
    const green: pal.Rgb = .{ .r = 0x4c, .g = 0xc8, .b = 0x4c };
    var x: usize = 6;
    x = putSeg(surface, x, row, "~/get/movy", blue, bg);
    x = putSeg(surface, x, row, "  master ", green, bg);
    x = putSeg(surface, x, row, "↓1 ", green, bg); // git ahead/behind - green
    x = putSeg(surface, x, row, "› ", green, bg);
    _ = putSeg(surface, x, row, if (blink_on) "█" else " ", green, bg);
}

// -------------------------------------------------------------- live terminal

/// Open the alternate screen in raw mode and run `scene` in a 60fps loop until
/// ESC / q. The animation is driven by elapsed wall-clock time mapped onto a
/// `loop_seconds`-long phase, so it plays at the right speed (and stays smooth)
/// even if the output thread drops a frame.
pub fn runLive(
    allocator: std.mem.Allocator,
    loop_seconds: f32,
    scene: SceneFn,
    ctx: ?*const anyopaque,
) !void {
    const term = try movy.terminal.getSize();
    const need_rows: usize = @intCast(@divTrunc(CANVAS_H, 2));
    if (term.width < @as(usize, @intCast(MIN_VIEW_W)) or term.height < need_rows) {
        std.debug.print(
            "needs a terminal of at least {d}x{d} cells (yours is {d}x{d}).\n",
            .{ MIN_VIEW_W, need_rows, term.width, term.height },
        );
        return;
    }

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[?1003l\x1b[?1006l\x1b[?1000l") catch 0;

    const kitty = movy.input.detectKittyKeyboard(200);
    if (kitty) movy.input.enableKittyKeyboard();
    defer if (kitty) movy.input.disableKittyKeyboard();

    const view_rows: usize = @intCast(@divTrunc(CANVAS_H, 2));
    var screen = try movy.Screen.init(allocator, @intCast(CANVAS_W), view_rows);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = .{ .r = 0, .g = 0, .b = 0 };

    const off_cols = @as(i32, @intCast(term.width)) - CANVAS_W;
    const off_rows = @as(i32, @intCast(term.height)) - @as(i32, @intCast(view_rows));
    screen.setXY(@divTrunc(off_cols, 2), @divTrunc(off_rows, 2) * 2);

    // movy.Screen.init() paints a rect in its default gray bg (0x20) at the
    // terminal's top-left (cursorHome) before we switch bg to black, and the
    // centered canvas never covers it. Wipe the whole alt-screen to black once
    // up front (DiffOutput expects a pre-cleared terminal anyway).
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[48;2;0;0;0m\x1b[2J\x1b[0m") catch 0;

    const frame = try movy.Frame.init(allocator, CANVAS_W, CANVAS_H);
    defer frame.deinit();
    tuneFrame(frame);

    var dout = try movy.DiffOutput.init(allocator, &screen, .threaded);
    defer dout.deinit();

    const prompt_row: usize = view_rows - 3;
    const loop_ns: f32 = @max(loop_seconds, 0.1) * 1.0e9;

    // Animation is driven by elapsed wall-clock time -> correct speed and full
    // 60fps smoothness even if some frames are dropped by the writer thread.
    const start: i128 = std.time.nanoTimestamp();
    var next_deadline: i128 = start;
    while (true) {
        next_deadline += FRAME_NS;

        var quit = false;
        while (try movy.input.get()) |ev| {
            switch (ev) {
                .key => |k| switch (k.type) {
                    .Escape, .CtrlC => quit = true,
                    .Char => if (k.sequence.len > 0 and
                        (k.sequence[0] == 'q' or k.sequence[0] == 'Q'))
                    {
                        quit = true;
                    },
                    else => {},
                },
                .mouse => {},
            }
        }
        if (quit) break;

        const elapsed_ns: i128 = std.time.nanoTimestamp() - start;
        const elapsed_f: f32 = @floatFromInt(elapsed_ns);
        const n = @mod(elapsed_f / loop_ns, 1.0); // loop phase 0..1
        const blink_on = @mod(@divFloor(elapsed_ns, 500_000_000), 2) == 0; // ~2Hz

        frame.beginFrame();
        @memset(frame.solid, pal.BLACK);
        scene(frame, ctx, n);
        frame.composite();

        try screen.renderInit();
        try screen.addRenderSurface(allocator, frame.surface);
        screen.render();
        drawPrompt(screen.output_surface, prompt_row, blink_on);

        try dout.output(&screen);

        const now = std.time.nanoTimestamp();
        if (now < next_deadline) {
            std.Thread.sleep(@intCast(next_deadline - now));
        } else {
            next_deadline = now;
        }
    }
}
