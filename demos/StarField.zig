// StarField - Animated starfield effect
//
// Features:
// - 300 stars with depth-based perspective
// - Smooth subpixel movement with accumulator
// - Two star types: Normal and Flashy (animated)
// - Depth-based color gradient (blue -> purple -> cyan)
// - Character variety based on depth
//
// Usage: See stars.zig for main loop integration

const std = @import("std");
const movy = @import("movy");

pub const Starfield = struct {
    stars: [MaxStars]Star = undefined,
    depth: i32 = 250,
    threshold: i32 = 900, // Threshold for movement
    frame_counter: usize = 0,
    out_surface: *movy.RenderSurface,
    rng: std.Random.DefaultPrng,

    const MaxStars = 300;

    const StarType = enum {
        Normal,
        Flashy,
    };

    const FlashyInterval: usize = 100;

    const Star = struct {
        x: i32,
        y: i32,
        z: i32, // Depth (0=close, 250=far)
        accumulator: i32, // Subpixel movement accumulator
        adder_value: i32, // Speed based on depth
        kind: StarType,
        flashy_frame: usize = 0, // Frame counter for flash timing
        flashy_interval: usize = FlashyInterval,
        flashy_ani_frame: usize = 0,
        flashy_speed: usize = 5,
        flashy_idx: usize = 0,
        flashy_char: u21 = 0x00B7,
        flashy_brightness: u8 = 0x40,
    };

    const StarKindDistribution = struct {
        const KindWeights = [_]usize{ 60, 30 };
        const KindMap = [_]StarType{ .Normal, .Flashy };

        fn randomStarKindWeighted(s: *Starfield) StarType {
            const idx = s.rng.random().weightedIndex(usize, &KindWeights);
            return KindMap[idx];
        }
    };

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*Starfield {
        const self = try allocator.create(Starfield);

        self.* = .{
            .out_surface = try movy.RenderSurface.init(
                allocator,
                screen.w,
                screen.h,
                movy.color.WHITE,
            ),
            .rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp())),
        };

        const w = screen.w;
        const h = screen.h;

        for (&self.stars) |*star| {
            const kind = StarKindDistribution.randomStarKindWeighted(self);
            const z = self.rng.random().intRangeAtMost(i32, 0, self.depth);
            star.* = .{
                .x = self.rng.random().intRangeAtMost(i32, 0, @as(
                    i32,
                    @intCast(w),
                ) - 1),
                .y = self.rng.random().intRangeAtMost(
                    i32,
                    0,
                    @as(i32, @intCast(h / 2)),
                ) * 2,
                .z = z,
                .accumulator = 0,
                .adder_value = z + 50, // Offs for z=0 to get initial brightness
                .kind = kind,
                .flashy_frame = self.rng.random().intRangeAtMost(u32, 0, 200),
            };
        }
        return self;
    }

    pub fn deinit(self: *Starfield, allocator: std.mem.Allocator) void {
        self.out_surface.deinit(allocator);
        allocator.destroy(self);
    }

    // Depth-based color gradient: Dark Blue -> Purple -> Cyan -> Bright Cyan
    fn getStarColor(z: i32) movy.core.types.Rgb {
        const color_val = @as(u8, @intCast(@min(250, z + 50)));
        const progress = @as(u16, color_val) -| 50; // 0 to 200

        // 4-stage gradient: z=0->250 maps to progress=0->200
        // Stage 1 (z~0-90): Dark blue rgb(20, 30, 80) -> Purple rgb(120, 60, 180)
        // Stage 2 (z~90-170): Purple -> Cyan rgb(60, 200, 240)
        // Stage 3 (z~170-190): Cyan (stays cyan)
        // Stage 4 (z~190-200 / z~220-250): Cyan -> Bright Cyan rgb(0, 245, 255)

        const red: u8 = if (progress < 90)
            @intCast(20 + (progress * 100) / 90) // 20->120
        else if (progress < 170)
            @intCast(120 - ((progress - 90) * 60) / 80) // 120->60
        else if (progress < 190)
            60 // stay cyan longer
        else
            @intCast(60 - ((progress - 190) * 60) / 10); // 60->0 remove red

        const green: u8 = if (progress < 90)
            @intCast(30 + (progress * 30) / 90) // 30->60
        else if (progress < 170)
            @intCast(60 + ((progress - 90) * 140) / 80) // 60->200
        else if (progress < 190)
            200 // stay cyan longer
        else
            @intCast(200 + ((progress - 190) * 45) / 10); // 200->245 brighten

        const blue: u8 = if (progress < 90)
            @intCast(80 + (progress * 100) / 90) // 80->180
        else if (progress < 170)
            @intCast(180 + ((progress - 90) * 60) / 80) // 180->240
        else if (progress < 190)
            240 // stay cyan longer
        else
            @intCast(240 + ((progress - 190) * 15) / 10); // 240->255 brighten

        return .{ .r = red, .g = green, .b = blue };
    }

    pub fn update(self: *Starfield) void {
        self.frame_counter +%= 1;
        const w = self.out_surface.w;
        const h = self.out_surface.h;

        self.out_surface.clearTransparent();

        const r = self.rng.random();

        for (&self.stars) |*star| {
            // Subpixel movement: accumulate fractional movement
            star.accumulator += star.adder_value;
            if (star.accumulator >= self.threshold) {
                star.y += 2;
                star.accumulator -= self.threshold;
            }

            // Wrap stars that move off bottom
            if (star.y >= h) {
                star.y = 0;
                star.x = r.intRangeAtMost(i32, 0, @intCast(w - 1));
                star.z = r.intRangeAtMost(i32, 0, self.depth);
                star.adder_value = star.z + 50; // Speed based on depth
                star.accumulator = 0;
            }

            // Calculate pixel index
            const map_idx =
                @as(usize, @intCast(star.y)) * w +
                @as(usize, @intCast(star.x));

            // Character size based on depth (closer = larger)
            const dot_char: u21 = switch (star.z) {
                0...99 => 0x00B7, // · (small)
                100...149 => 0x2022, // • (medium)
                150...199 => 0x02022,
                200...220 => '.',
                else => '●', // ● (large, closest)
            };

            switch (star.kind) {
                .Normal => {
                    self.out_surface.char_map[map_idx] = dot_char;
                    self.out_surface.color_map[map_idx] = getStarColor(star.z);
                },
                .Flashy => {
                    const dot_char_ani =
                        [_]u21{
                            0x2022,
                            0x2022,
                            '*',
                            0x25CF,

                            0x25C9,
                            '*',
                            0x2022,
                            0x2022,
                            // '0', '1', '2', '3', '4', '5', '6', '7',
                        };

                    const brightnesses = [_]u8{
                        0x90,
                        0xb0,
                        0xd0,
                        0xff,
                        0xff,
                        0xd0,
                        0xb0,
                        0x90,
                    };

                    star.flashy_frame += 1;

                    // do flashy updates at all
                    if (star.flashy_frame > star.flashy_interval) {
                        star.flashy_ani_frame += 1;

                        // do 1 ani step
                        if (star.flashy_ani_frame > star.flashy_speed) {
                            star.flashy_ani_frame = 0;

                            // start/advance ani
                            star.flashy_char = dot_char_ani[star.flashy_idx];
                            star.flashy_brightness =
                                brightnesses[star.flashy_idx];

                            // advance ani
                            star.flashy_idx += 1;

                            // reset to 0 if at end
                            if (star.flashy_idx >= dot_char_ani.len + 1) {
                                star.flashy_idx = 0;
                                star.flashy_frame = 0;
                                star.flashy_char = dot_char;
                                star.flashy_frame =
                                    self.rng.random().intRangeAtMost(
                                        u32,
                                        0,
                                        FlashyInterval,
                                    );
                                // will set color in else branch next
                            }
                        }

                        self.out_surface.color_map[map_idx] = .{
                            .r = star.flashy_brightness,
                            .g = star.flashy_brightness,
                            .b = star.flashy_brightness,
                        };
                    }

                    // render to surface
                    self.out_surface.char_map[map_idx] = star.flashy_char;
                },
            }

            self.out_surface.shadow_map[map_idx] = 1;
        }
    }
};
