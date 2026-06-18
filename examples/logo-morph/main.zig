//! logo-morph — a looping neon logo reveal, drawn straight into a movy.Frame.
//!
//! The movy logo is rebuilt every frame from its own grayscale pixels (see
//! logo.zig). A flare beam sweeps across it; where the beam touches, pixels
//! energize and scatter, then re-form. The logo stays crisp and clean — its
//! true grays visible — until the beam reaches it. Glow appears only
//! transiently:
//!   * energize + warm scorch where/just-behind the beam, and
//!   * the purple ignite + afterglow swell after the beam exits,
//! and the afterglow then glows down to the clean base state, so the loop
//! closes on the same non-glowing logo (clean -> ... -> clean).
//!
//! This is the animation shown in the project README. It shows off the **Frame**
//! rendering path: a float framebuffer with a persistent, additive glow buffer
//! (bloom + neon trails for free) and a built-in CRT post-fx stack — no manual
//! per-object trail bookkeeping anywhere.
//!
//!   zig build run-logo-morph            -> run it (ESC / q quits)
//!   zig build run-logo-morph -- shake   -> add a screen shake on the ignite beat

const std = @import("std");
const movy = @import("movy");
const fx = @import("movyfx.zig");
const pal = @import("pal.zig");

/// Loop length in seconds. The arc is driven by a 0..1 loop phase, so the live
/// view runs smooth at 60fps regardless of this value (see movyfx.runLive).
const LOOP_SECONDS: f32 = 6.6;
const TAU = 2.0 * std.math.pi;

const SWEEP_FRAC: f32 = 0.50;
const SWEEP_START: f32 = -16.0;
const SWEEP_END: f32 = 150.0;
const RETURN_D: f32 = 26.0;
const ATTACK: f32 = 0.20;
const SCATTER: f32 = 26.0;
const BEAM_W: i32 = 2; //                 beam bloom half-width
const BEAM_SIGMA: f32 = 7.0; //           gaussian denom (smaller -> thinner)
const SCORCH_LEN: f32 = 30.0; //          px the scorch trails behind the beam

const IGNITE: f32 = 0.45; // purple beat
const BEAT2: f32 = 0.60; //  second, smaller cool beat

/// set from the CLI (`shake`); read by the scene.
var shake_enabled: bool = false;

fn bell(x: f32, c: f32, w: f32) f32 {
    const d = (x - c) / w;
    return @exp(-d * d);
}

fn disturb(d: f32) f32 {
    if (d <= 0.0 or d >= RETURN_D) return 0.0;
    const u = d / RETURN_D;
    if (u < ATTACK) return fx.smoothstep(0.0, ATTACK, u);
    return 1.0 - fx.smoothstep(ATTACK, 1.0, u);
}

fn ring(f: *movy.Frame, n: f32, t0: f32, dur: f32, cx: f32, cy: f32, maxr: f32, col: fx.V3, amp: f32) void {
    const rt = (n - t0) / dur;
    if (rt <= 0.0 or rt >= 1.0) return;
    const a = 1.0 - rt;
    f.gring(cx, cy, rt * maxr, col.scale(amp * a * a));
    f.gring(cx, cy, rt * maxr * 0.62, col.scale(amp * 0.6 * a * a));
}

fn scene(f: *movy.Frame, ctx: ?*const anyopaque, n: f32) void {
    const p = @as(*const fx.Particles, @ptrCast(@alignCast(ctx.?)));

    f.glow_decay = 0.86;
    f.flash = 0;

    // screen shake: a short decaying jitter on the ignite (whole scene offset)
    var shx: i32 = 0;
    var shy: i32 = 0;
    if (shake_enabled) {
        const td = n - IGNITE;
        if (td >= 0.0 and td < 0.13) {
            const env = 1.0 - td / 0.13;
            const e2 = env * env;
            shx = fx.iround(e2 * 3.0 * @sin(n * 230.0));
            shy = fx.iround(e2 * 2.2 * @sin(n * 190.0 + 1.3));
        }
    }
    const fshx: f32 = @floatFromInt(shx);
    const fshy: f32 = @floatFromInt(shy);

    const sweep_n = @min(n / SWEEP_FRAC, 1.0);
    const bar_x = fx.lerp(SWEEP_START, SWEEP_END, sweep_n);
    const bxi = fx.iround(bar_x) + shx;

    // afterglow swell (rise as the bar leaves, slow settle back to the clean base)
    var swell: f32 = 0;
    if (n >= 0.42) {
        swell = @min(fx.smoothstep(0.42, 0.55, n), 1.0 - fx.smoothstep(0.55, 0.84, n));
    }
    const settle_t = fx.smoothstep(0.55, 0.84, n);
    const aglow_col = pal.P_MAGENTA.lerp(pal.FLARE_BEAM, settle_t);

    const cxf = @as(f32, @floatFromInt(fx.LOGO_OX)) + @as(f32, @floatFromInt(fx.LOGO_W)) * 0.5 + fshx;
    const cyf = @as(f32, @floatFromInt(fx.LOGO_OY)) + @as(f32, @floatFromInt(fx.LOGO_H)) * 0.5 + fshy;
    const cyi = fx.iround(cyf);

    // ---- the logo, rebuilt from its own (grayscale) pixels ----
    var i: usize = 0;
    while (i < p.n) : (i += 1) {
        const d = bar_x - p.tx[i];
        const sc = disturb(d);
        const v = p.v[i];

        var x = p.tx[i];
        var y = p.ty[i];
        if (sc > 0.001) {
            const ang = fx.hash01(@as(u32, @intCast(i)) * 7 + 1) * TAU;
            const dist = SCATTER * sc;
            x = p.tx[i] + @cos(ang) * dist;
            y = p.ty[i] + @sin(ang) * dist * 0.55;
        }
        const xi = fx.iround(x) + shx;
        const yi = fx.iround(y) + shy;

        // crisp grayscale pixel; brightened only while energized / in the swell
        f.px(xi, yi, pal.INK.scale(v * (1.0 + 0.5 * sc + 0.6 * swell)));

        // glow ONLY transiently: where the beam is energizing (sc) and during
        // the afterglow swell. No constant baseline glow -> clean logo at rest.
        if (sc > 0.01 or swell > 0.01) {
            const gcol = pal.GLOW.lerp(pal.FLARE_BEAM, sc).lerp(aglow_col, swell * 0.85);
            const energ = sc * 0.55;
            const after = (if (p.wall[i]) v else v * 0.5) * swell * 0.65;
            f.gpx(xi, yi, gcol.scale(energ + after));
        }

        // warm scorch: each wall glows hot for a moment AFTER the beam re-forms
        // it, then fades back to clean (transient).
        if (p.wall[i]) {
            const passed = d - RETURN_D;
            if (passed > 0.0 and passed < SCORCH_LEN) {
                const s = 1.0 - passed / SCORCH_LEN;
                f.gpx(xi, yi, pal.SCORCH.scale(v * s * s * 0.9));
            }
        }
    }

    // ---- the sweeping flare beam ----
    const I = fx.smoothstep(-16.0, 2.0, bar_x) * (1.0 - fx.smoothstep(104.0, 124.0, bar_x));
    if (I > 0.01) {
        f.vline(bxi, fx.LOGO_OY - 3 + shy, fx.LOGO_H + 6, pal.INK.scale(0.95 * I));
        var dx: i32 = -BEAM_W;
        while (dx <= BEAM_W) : (dx += 1) {
            const fall = @exp(-@as(f32, @floatFromInt(dx * dx)) / BEAM_SIGMA);
            f.gvline(bxi + dx, fx.LOGO_OY - 7 + shy, fx.LOGO_H + 14, pal.FLARE_BEAM.scale(0.5 * I * fall));
        }
        f.ghline(0, cyi, fx.CANVAS_W, pal.FLARE_STREAK.scale(0.24 * I));
        f.ghline(0, cyi - 1, fx.CANVAS_W, pal.FLARE_STREAK.scale(0.13 * I));
        f.ghline(0, cyi + 1, fx.CANVAS_W, pal.FLARE_STREAK.scale(0.13 * I));
        f.ghline(0, cyi - 2, fx.CANVAS_W, pal.FLARE_STREAK.scale(0.05 * I));
        f.ghline(0, cyi + 2, fx.CANVAS_W, pal.FLARE_STREAK.scale(0.05 * I));
        f.gpx(bxi, cyi, pal.INK.scale(1.5 * I));
    }

    // ---- beats: purple ignite, then a smaller cool echo ----
    const b1 = bell(n, IGNITE, 0.035);
    if (b1 > 0.01) {
        f.flash = 0.55 * b1;
        f.flash_col = pal.P_MAGENTA;
        f.ghline(0, cyi, fx.CANVAS_W, pal.P_MAGENTA.scale(0.30 * b1));
    }
    ring(f, n, IGNITE, 0.22, cxf, cyf, 84.0, pal.P_MAGENTA, 0.60);
    ring(f, n, IGNITE + 0.05, 0.18, cxf, cyf, 58.0, pal.FLARE_RING, 0.42);

    const b2 = bell(n, BEAT2, 0.030);
    if (b2 > 0.01) {
        f.flash = @max(f.flash, 0.26 * b2);
        f.flash_col = pal.FLARE_BEAM;
    }
    ring(f, n, BEAT2, 0.14, cxf, cyf, 48.0, pal.FLARE_RING, 0.32);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "shake") or std.mem.eql(u8, a, "--shake")) {
            shake_enabled = true;
        }
    }

    var parts = try fx.Particles.init(allocator, fx.LOGO_OX, fx.LOGO_OY);
    defer parts.deinit();

    try fx.runLive(allocator, LOOP_SECONDS, scene, &parts);
}
