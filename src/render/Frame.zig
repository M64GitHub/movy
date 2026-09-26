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
//! scanline_mask - a per-pixel CRT-stripe exemption (HUD-class text over a
//! strong scanline): pixels marked via slpx()/slrect() keep full brightness on
//! odd rows; every other grade (vignette/warmth/flash/tint) still applies. The
//! mask is a PER-FRAME transient - beginFrame() clears it, so drawing code
//! re-marks while stamping each frame.
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
//! Glyphs: setGlyphs(layer) makes composite() grade the layer's colors like
//! the pixels (vignette, warmth, flash, tint - no scanline: a glyph is a whole
//! cell) into its fg_out / bg_out, leaving the authored colors untouched.
//! glyphGlow() / gcell() emit glyph light into the glow buffer, so text blooms
//! and leaves trails like everything else. The layer itself is attached to
//! screen.output_surface (it is resolved at output, not composited):
//!     frame.setGlyphs(glyphs);                  // once
//!     screen.output_surface.setGlyphs(glyphs);  // once
//!
//! Tuning (glow_decay/glow_blur/scanline_mul + flash/flash_col/tint) are public
//! fields you may set any time. vignette_amt is baked into a lookup table at
//! init(); change it later with setVignette().

const std = @import("std");
const movy = @import("../movy.zig");

const V3 = movy.color.V3;
const Rgb = movy.core.types.Rgb;
const RenderSurface = movy.RenderSurface;
const GlyphLayer = movy.GlyphLayer;

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
    scanline_mask: []u8, // 1 = skip the scanline stripe here (see header)
    vig_x: []f32,
    vig_y: []f32,
    surface: *RenderSurface,
    /// Optional glyph layer graded with the pixels (see setGlyphs).
    glyphs: ?*GlyphLayer = null,

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
            .scanline_mask = try allocator.alloc(u8, n),
            .vig_x = try allocator.alloc(f32, uw),
            .vig_y = try allocator.alloc(f32, uh),
            .surface = try RenderSurface.init(allocator, uw, uh, .{ .r = 0, .g = 0, .b = 0 }),
        };

        @memset(self.solid, BLACK);
        @memset(self.glow, BLACK);
        @memset(self.tmp, BLACK);
        @memset(self.scanline_mask, 0);
        self.rebuildVignette();
        return self;
    }

    pub fn deinit(self: *Frame) void {
        const allocator = self.allocator;
        allocator.free(self.solid);
        allocator.free(self.glow);
        allocator.free(self.tmp);
        allocator.free(self.scanline_mask);
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

    /// Decay + blur the persistent glow buffer (and clear the per-frame
    /// scanline mask). Call ONCE at frame start, BEFORE drawing this frame's
    /// emissions.
    pub fn beginFrame(self: *Frame) void {
        @memset(self.scanline_mask, 0);
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
            const odd = (y & 1) == 1;
            const scan: f32 = if (odd) self.scanline_mul else 1.0;
            const vy = self.vig_y[y] * scan;
            const vy_free = self.vig_y[y]; // scanline_mask pixels keep this
            for (0..uw) |x| {
                const i = row + x;
                const s = self.solid[i];
                const g = self.glow[i];
                const v = self.vig_x[x] * (if (odd and self.scanline_mask[i] != 0) vy_free else vy);

                self.surface.color_map[i] = self.grade(
                    std.math.clamp(s.r + g.r, 0.0, 1.0) * v,
                    std.math.clamp(s.g + g.g, 0.0, 1.0) * v,
                    std.math.clamp(s.b + g.b, 0.0, 1.0) * v,
                );
                self.surface.shadow_map[i] = 255; // opaque
            }
        }
        if (self.glyphs) |gl| self.gradeGlyphs(gl);
    }

    /// warmth -> flash -> tint -> quantize, for an already vignetted color.
    inline fn grade(self: *const Frame, r_in: f32, g_in: f32, b_in: f32) Rgb {
        var r = r_in;
        var gg = g_in;
        var b = b_in;

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

        return .{
            .r = @intFromFloat(std.math.clamp(r, 0.0, 1.0) * 255.0),
            .g = @intFromFloat(std.math.clamp(gg, 0.0, 1.0) * 255.0),
            .b = @intFromFloat(std.math.clamp(b, 0.0, 1.0) * 255.0),
        };
    }

    inline fn gradeRgb(self: *const Frame, c: Rgb, v: f32) Rgb {
        const k = v / 255.0;
        return self.grade(
            @as(f32, @floatFromInt(c.r)) * k,
            @as(f32, @floatFromInt(c.g)) * k,
            @as(f32, @floatFromInt(c.b)) * k,
        );
    }

    /// Grade occupied glyph cells into fg_out / bg_out. The vignette is
    /// sampled at the cell's upper pixel; no scanline (a glyph is a cell).
    fn gradeGlyphs(self: *Frame, gl: *GlyphLayer) void {
        for (0..gl.h) |cy| {
            const vy = self.vig_y[cy * 2];
            const row = cy * gl.w;
            for (gl.char_map[row..][0..gl.w], 0..) |ch, cx| {
                if (ch == 0) continue;
                const i = row + cx;
                const v = self.vig_x[cx] * vy;
                gl.fg_out[i] = self.gradeRgb(gl.fg_map[i], v);
                if (gl.bg_mode[i] == .solid) gl.bg_out[i] = self.gradeRgb(gl.bg_map[i], v);
            }
        }
    }

    /// Grade this Frame's glyph layer in composite() (null detaches). The
    /// layer must be w cells wide and h/2 tall. Gives it its own out buffers.
    pub fn setGlyphs(self: *Frame, glyphs: ?*GlyphLayer) !void {
        if (glyphs) |gl| {
            std.debug.assert(gl.w == @as(usize, @intCast(self.w)) and
                gl.h == @as(usize, @intCast(self.h)) / 2);
            try gl.ensureOutBuffers();
        }
        self.glyphs = glyphs;
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

    // ------------------------------------------------- scanline-mask marking
    // Mark pixels scanline-free for THIS frame (composite skips the CRT stripe
    // there; every other grade still applies). Cleared each beginFrame().

    pub inline fn slpx(self: *Frame, x: i32, y: i32) void {
        if (!self.inBounds(x, y)) return;
        self.scanline_mask[self.idx(x, y)] = 1;
    }

    pub fn slrect(self: *Frame, x: i32, y: i32, w: i32, h: i32) void {
        const x0 = @max(x, 0);
        const y0 = @max(y, 0);
        const x1 = @min(x + w, self.w);
        const y1 = @min(y + h, self.h);
        if (x0 >= x1 or y0 >= y1) return;
        var yy = y0;
        while (yy < y1) : (yy += 1) {
            var xx = x0;
            while (xx < x1) : (xx += 1) {
                self.scanline_mask[self.idx(xx, yy)] = 1;
            }
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

    /// Add glow to both pixels of text cell (cx, cy) - e.g. a single glyph
    /// flaring up.
    pub inline fn gcell(self: *Frame, cx: i32, cy: i32, c: V3) void {
        self.gpx(cx, cy * 2, c);
        self.gpx(cx, cy * 2 + 1, c);
    }

    /// Every occupied glyph cell of the layer set with setGlyphs() emits its
    /// authored fg * strength into the glow buffer (spaces don't). Call
    /// between beginFrame() and composite(); with the glow's blur + decay
    /// that gives text a bloom halo, and moving text a light trail.
    pub fn glyphGlow(self: *Frame, strength: f32) void {
        const gl = self.glyphs orelse return;
        const uw: usize = @intCast(self.w);
        for (0..gl.h) |cy| {
            const row = cy * gl.w;
            const up = cy * 2 * uw;
            for (gl.char_map[row..][0..gl.w], 0..) |ch, cx| {
                if (ch == 0 or ch == ' ') continue;
                const c = V3.fromRgb(gl.fg_map[row + cx]).scale(strength);
                self.glow[up + cx] = self.glow[up + cx].add(c);
                self.glow[up + uw + cx] = self.glow[up + uw + cx].add(c);
            }
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

test "Frame grades glyphs into fg_out, never the authored colors" {
    const a = std.testing.allocator;
    const f = try Frame.init(a, 4, 4);
    defer f.deinit();
    const gl = try GlyphLayer.init(a, 4, 2);
    defer gl.deinit();
    try f.setGlyphs(gl);
    f.setVignette(0);
    gl.put(1, 0, 'a', .{ .r = 200, .g = 100, .b = 50 });
    gl.putSolid(2, 1, 'b', .{ .r = 255 }, .{ .g = 200 });
    f.tint = .{ .r = 0.5, .g = 0.5, .b = 0.5 };
    f.composite();
    f.composite(); // twice: must not compound
    try std.testing.expectEqual(@as(u8, 200), gl.fg_map[1].r);
    try std.testing.expectEqual(@as(u8, 100), gl.fg_out[1].r);
    try std.testing.expectEqual(@as(u8, 100), gl.bg_out[gl.idx(2, 1)].g);

    f.glyphGlow(1.0);
    try std.testing.expect(f.glow[1].r > 0.7 and f.glow[1 + 4].r > 0.7);
    try std.testing.expectEqual(@as(f32, 0), f.glow[0].r);
}
