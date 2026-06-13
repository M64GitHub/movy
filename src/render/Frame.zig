//! Frame - a float framebuffer + post-processing stack that gives terminal
//! apps a neon "glow" look for free. Build it on top of a RenderSurface.
//!
//! Two float (V3) layers:
//!   solid - opaque colors (background, bodies, tiles). You rewrite it each
//!           frame (fill the whole frame, or @memset it, before drawing).
//!   glow  - additive light, PERSISTENT across frames: each beginFrame() it is
//!           blurred and decayed, then this frame's emissions are added on top.
//!           That persistence + blur is what produces neon trails and bloom
//!           with no per-object trail bookkeeping.
//!
//! composite() = clamp(solid+glow) -> vignette -> scanline -> warmth -> flash
//! -> tint, written into the owned RenderSurface (u8) that Screen / DiffOutput
//! consume.
//!
//! Pixel model: 1 unit = 1 pixel; the terminal shows 2 pixels per text cell
//! (upper/lower half-block), so a frame `h` pixels tall is `h/2` text rows.
//!
//! Typical loop:
//!     frame.beginFrame();              // decay/blur the glow buffer
//!     // ... draw into solid (px/rect/...) and glow (gpx/grect/...) ...
//!     frame.composite();               // mix -> frame.surface
//!     try screen.renderInit();
//!     try screen.addRenderSurface(allocator, frame.surface);
//!     screen.render();
//!     try dout.output(&screen);        // movy.DiffOutput
//!
//! Tuning (glow_decay/glow_blur/scanline_mul + flash/flash_col/tint) are public
//! fields you may set any time. vignette_amt is baked into a lookup table at
//! init(); change it later with setVignette().

const std = @import("std");
const movy = @import("../movy.zig");

const V3 = movy.color.V3;
const Rgb = movy.core.types.Rgb;
const RenderSurface = movy.RenderSurface;

const BLACK = V3{ .r = 0, .g = 0, .b = 0 };
const WHITE = V3{ .r = 1, .g = 1, .b = 1 };

// lodepng_encode32_file is compiled into the movy module (movy bundles its own
// lodepng C). Resolves at link time when the consumer does `exe.linkLibC()`.
extern fn lodepng_encode32_file(
    filename: [*:0]const u8,
    image: [*]const u8,
    w: c_uint,
    h: c_uint,
) c_uint;

pub const Frame = struct {
    allocator: std.mem.Allocator,
    w: i32,
    h: i32,
    n: usize,
    solid: []V3,
    glow: []V3,
    tmp: []V3,
    vig_x: []f32,
    vig_y: []f32,
    surface: *RenderSurface,

    // --- grading state (public; set per frame as you like) ---
    warmth: f32 = 0, // 0 = unchanged; 1 = full R<->B swap (warm/cool flip)
    flash: f32 = 0, // 0..1 full-screen flash toward flash_col
    flash_col: V3 = WHITE,
    tint: V3 = WHITE, // multiplicative tint (e.g. dim on pause)

    // --- tuning (public) ---
    glow_decay: f32 = 0.72, // glow persistence per frame (0..1)
    glow_blur: bool = true, // separable 1-2-1 blur of the glow buffer
    scanline_mul: f32 = 0.87, // odd pixel rows darkened (CRT look)
    vignette_amt: f32 = 0.22, // edge darkening; baked at init / setVignette()

    pub fn init(allocator: std.mem.Allocator, w: i32, h: i32) !*Frame {
        const self = try allocator.create(Frame);
        errdefer allocator.destroy(self);

        const uw: usize = @intCast(w);
        const uh: usize = @intCast(h);
        const n = uw * uh;

        self.* = .{
            .allocator = allocator,
            .w = w,
            .h = h,
            .n = n,
            .solid = try allocator.alloc(V3, n),
            .glow = try allocator.alloc(V3, n),
            .tmp = try allocator.alloc(V3, n),
            .vig_x = try allocator.alloc(f32, uw),
            .vig_y = try allocator.alloc(f32, uh),
            .surface = try RenderSurface.init(allocator, uw, uh, .{ .r = 0, .g = 0, .b = 0 }),
        };

        @memset(self.solid, BLACK);
        @memset(self.glow, BLACK);
        @memset(self.tmp, BLACK);
        self.rebuildVignette();
        return self;
    }

    pub fn deinit(self: *Frame) void {
        const allocator = self.allocator;
        allocator.free(self.solid);
        allocator.free(self.glow);
        allocator.free(self.tmp);
        allocator.free(self.vig_x);
        allocator.free(self.vig_y);
        self.surface.deinit(allocator);
        allocator.destroy(self);
    }

    /// Recompute the vignette tables from `vignette_amt` (x^4 falloff).
    pub fn setVignette(self: *Frame, amt: f32) void {
        self.vignette_amt = amt;
        self.rebuildVignette();
    }

    fn rebuildVignette(self: *Frame) void {
        const uw: usize = @intCast(self.w);
        const uh: usize = @intCast(self.h);
        for (0..uw) |x| {
            const nx = (@as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(uw - 1))) * 2.0 - 1.0;
            self.vig_x[x] = 1.0 - self.vignette_amt * nx * nx * nx * nx;
        }
        for (0..uh) |y| {
            const ny = (@as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(uh - 1))) * 2.0 - 1.0;
            self.vig_y[y] = 1.0 - self.vignette_amt * ny * ny * ny * ny;
        }
    }

    pub inline fn idx(self: *const Frame, x: i32, y: i32) usize {
        return @as(usize, @intCast(y)) * @as(usize, @intCast(self.w)) + @as(usize, @intCast(x));
    }

    pub inline fn inBounds(self: *const Frame, x: i32, y: i32) bool {
        return x >= 0 and x < self.w and y >= 0 and y < self.h;
    }

    // ---------------------------------------------------------- frame ops

    /// Decay + blur the persistent glow buffer. Call ONCE at frame start,
    /// BEFORE drawing this frame's emissions.
    pub fn beginFrame(self: *Frame) void {
        const uw: usize = @intCast(self.w);
        const uh: usize = @intCast(self.h);

        if (self.glow_blur) {
            // horizontal 1-2-1 pass: glow -> tmp
            for (0..uh) |y| {
                const row = y * uw;
                for (0..uw) |x| {
                    const i = row + x;
                    const l = if (x > 0) self.glow[i - 1] else BLACK;
                    const r = if (x + 1 < uw) self.glow[i + 1] else BLACK;
                    self.tmp[i] = .{
                        .r = l.r * 0.25 + self.glow[i].r * 0.5 + r.r * 0.25,
                        .g = l.g * 0.25 + self.glow[i].g * 0.5 + r.g * 0.25,
                        .b = l.b * 0.25 + self.glow[i].b * 0.5 + r.b * 0.25,
                    };
                }
            }
            // vertical 1-2-1 pass with decay: tmp -> glow
            const d = self.glow_decay;
            for (0..uh) |y| {
                const row = y * uw;
                for (0..uw) |x| {
                    const i = row + x;
                    const u = if (y > 0) self.tmp[i - uw] else BLACK;
                    const dn = if (y + 1 < uh) self.tmp[i + uw] else BLACK;
                    self.glow[i] = .{
                        .r = (u.r * 0.25 + self.tmp[i].r * 0.5 + dn.r * 0.25) * d,
                        .g = (u.g * 0.25 + self.tmp[i].g * 0.5 + dn.g * 0.25) * d,
                        .b = (u.b * 0.25 + self.tmp[i].b * 0.5 + dn.b * 0.25) * d,
                    };
                }
            }
        } else {
            const d = self.glow_decay;
            for (self.glow) |*g| {
                g.r *= d;
                g.g *= d;
                g.b *= d;
            }
        }
    }

    /// Final mix into the owned RenderSurface. Call AFTER all drawing.
    pub fn composite(self: *Frame) void {
        const uw: usize = @intCast(self.w);
        const uh: usize = @intCast(self.h);
        for (0..uh) |y| {
            const row = y * uw;
            const scan: f32 = if (y & 1 == 1) self.scanline_mul else 1.0;
            const vy = self.vig_y[y] * scan;
            for (0..uw) |x| {
                const i = row + x;
                const s = self.solid[i];
                const g = self.glow[i];
                const v = self.vig_x[x] * vy;

                var r = std.math.clamp(s.r + g.r, 0.0, 1.0) * v;
                var gg = std.math.clamp(s.g + g.g, 0.0, 1.0) * v;
                var b = std.math.clamp(s.b + g.b, 0.0, 1.0) * v;

                // warmth: a symmetric R<->B channel mix (an involution at w=1),
                // graded BEFORE the flash so a white flash stays white. Use it
                // for warm/cool mood shifts or a polarity/phase palette swap.
                if (self.warmth > 0.001) {
                    const w = self.warmth;
                    const wr = r + (b - r) * w;
                    const wb = b + (r - b) * w;
                    r = wr;
                    b = wb;
                }

                if (self.flash > 0.005) {
                    r += (self.flash_col.r - r) * self.flash;
                    gg += (self.flash_col.g - gg) * self.flash;
                    b += (self.flash_col.b - b) * self.flash;
                }

                r *= self.tint.r;
                gg *= self.tint.g;
                b *= self.tint.b;

                self.surface.color_map[i] = .{
                    .r = @intFromFloat(std.math.clamp(r, 0.0, 1.0) * 255.0),
                    .g = @intFromFloat(std.math.clamp(gg, 0.0, 1.0) * 255.0),
                    .b = @intFromFloat(std.math.clamp(b, 0.0, 1.0) * 255.0),
                };
                self.surface.shadow_map[i] = 255; // opaque
            }
        }
    }

    // ------------------------------------------------------- solid drawing

    pub inline fn px(self: *Frame, x: i32, y: i32, c: V3) void {
        if (!self.inBounds(x, y)) return;
        self.solid[self.idx(x, y)] = c;
    }

    pub fn rect(self: *Frame, x: i32, y: i32, w: i32, h: i32, c: V3) void {
        const x0 = @max(x, 0);
        const y0 = @max(y, 0);
        const x1 = @min(x + w, self.w);
        const y1 = @min(y + h, self.h);
        if (x0 >= x1 or y0 >= y1) return;
        var yy = y0;
        while (yy < y1) : (yy += 1) {
            var xx = x0;
            while (xx < x1) : (xx += 1) {
                self.solid[self.idx(xx, yy)] = c;
            }
        }
    }

    pub fn rectOutline(self: *Frame, x: i32, y: i32, w: i32, h: i32, c: V3) void {
        self.hline(x, y, w, c);
        self.hline(x, y + h - 1, w, c);
        self.vline(x, y, h, c);
        self.vline(x + w - 1, y, h, c);
    }

    pub fn hline(self: *Frame, x: i32, y: i32, w: i32, c: V3) void {
        if (y < 0 or y >= self.h) return;
        const x0 = @max(x, 0);
        const x1 = @min(x + w, self.w);
        var xx = x0;
        while (xx < x1) : (xx += 1) {
            self.solid[self.idx(xx, y)] = c;
        }
    }

    pub fn vline(self: *Frame, x: i32, y: i32, h: i32, c: V3) void {
        if (x < 0 or x >= self.w) return;
        const y0 = @max(y, 0);
        const y1 = @min(y + h, self.h);
        var yy = y0;
        while (yy < y1) : (yy += 1) {
            self.solid[self.idx(x, yy)] = c;
        }
    }

    /// Multiply a solid region's brightness (cheap texture/shadow).
    pub fn shadeRect(self: *Frame, x: i32, y: i32, w: i32, h: i32, m: f32) void {
        const x0 = @max(x, 0);
        const y0 = @max(y, 0);
        const x1 = @min(x + w, self.w);
        const y1 = @min(y + h, self.h);
        if (x0 >= x1 or y0 >= y1) return;
        var yy = y0;
        while (yy < y1) : (yy += 1) {
            var xx = x0;
            while (xx < x1) : (xx += 1) {
                const i = self.idx(xx, yy);
                self.solid[i] = self.solid[i].scale(m);
            }
        }
    }

    // -------------------------------------------------------- glow drawing
    // Everything here ADDS into the persistent glow buffer. Same color at a
    // still position each frame -> stable bloom; if it moves -> a trail.

    pub inline fn gpx(self: *Frame, x: i32, y: i32, c: V3) void {
        if (!self.inBounds(x, y)) return;
        const i = self.idx(x, y);
        self.glow[i] = self.glow[i].add(c);
    }

    pub fn grect(self: *Frame, x: i32, y: i32, w: i32, h: i32, c: V3) void {
        const x0 = @max(x, 0);
        const y0 = @max(y, 0);
        const x1 = @min(x + w, self.w);
        const y1 = @min(y + h, self.h);
        if (x0 >= x1 or y0 >= y1) return;
        var yy = y0;
        while (yy < y1) : (yy += 1) {
            var xx = x0;
            while (xx < x1) : (xx += 1) {
                const i = self.idx(xx, yy);
                self.glow[i] = self.glow[i].add(c);
            }
        }
    }

    pub fn ghline(self: *Frame, x: i32, y: i32, w: i32, c: V3) void {
        if (y < 0 or y >= self.h) return;
        const x0 = @max(x, 0);
        const x1 = @min(x + w, self.w);
        var xx = x0;
        while (xx < x1) : (xx += 1) {
            const i = self.idx(xx, y);
            self.glow[i] = self.glow[i].add(c);
        }
    }

    pub fn gvline(self: *Frame, x: i32, y: i32, h: i32, c: V3) void {
        if (x < 0 or x >= self.w) return;
        const y0 = @max(y, 0);
        const y1 = @min(y + h, self.h);
        var yy = y0;
        while (yy < y1) : (yy += 1) {
            const i = self.idx(x, yy);
            self.glow[i] = self.glow[i].add(c);
        }
    }

    /// Additive soft ring of radius r (1.5px band) - explosion ripples, etc.
    pub fn gring(self: *Frame, cx: f32, cy: f32, r: f32, c: V3) void {
        if (r <= 0) return;
        const band: f32 = 1.5;
        const x0: i32 = @intFromFloat(@floor(cx - r - band));
        const x1: i32 = @intFromFloat(@ceil(cx + r + band));
        const y0: i32 = @intFromFloat(@floor(cy - r - band));
        const y1: i32 = @intFromFloat(@ceil(cy + r + band));
        var yy = @max(y0, 0);
        const ymax = @min(y1, self.h - 1);
        while (yy <= ymax) : (yy += 1) {
            var xx = @max(x0, 0);
            const xmax = @min(x1, self.w - 1);
            while (xx <= xmax) : (xx += 1) {
                const dx = @as(f32, @floatFromInt(xx)) - cx;
                const dy = @as(f32, @floatFromInt(yy)) - cy;
                const d = @sqrt(dx * dx + dy * dy);
                const a = 1.0 - @abs(d - r) / band;
                if (a > 0) {
                    const i = self.idx(xx, yy);
                    self.glow[i] = self.glow[i].add(c.scale(a));
                }
            }
        }
    }

    // ----------------------------------------------------------- dev tools

    /// Save the composited surface as a nearest-upscaled PNG. The headless dev
    /// loop: render N frames, savePng, then open/Read the image to verify
    /// visuals without a real terminal. `scale` = pixel magnification.
    /// Requires the consumer to `exe.linkLibC()` (movy bundles lodepng).
    pub fn savePng(self: *Frame, allocator: std.mem.Allocator, path: [*:0]const u8, scale: usize) !void {
        const uw: usize = @intCast(self.w);
        const uh: usize = @intCast(self.h);
        const ow = uw * scale;
        const oh = uh * scale;
        const buf = try allocator.alloc(u8, ow * oh * 4);
        defer allocator.free(buf);

        for (0..oh) |oy| {
            const sy = oy / scale;
            for (0..ow) |ox| {
                const sx = ox / scale;
                const c = self.surface.color_map[sy * uw + sx];
                const o = (oy * ow + ox) * 4;
                buf[o] = c.r;
                buf[o + 1] = c.g;
                buf[o + 2] = c.b;
                buf[o + 3] = 255;
            }
        }

        const err = lodepng_encode32_file(path, buf.ptr, @intCast(ow), @intCast(oh));
        if (err != 0) return error.PngEncodeFailed;
    }
};
