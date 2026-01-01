const std = @import("std");
const movy = @import("../movy.zig");

const cimp = @cImport({
    @cInclude("lodepng.h");
});

/// Maximum bytes per pixel for ANSI escape sequences
/// Calculation: ESC[38;2;RRR;GGG;BBBm (24 bytes) +
/// ESC[48;2;RRR;GGG;BBBm (24 bytes) + UTF-8 char (4 bytes) + row control (~8)
/// = ~56 bytes worst case, 60 for safety margin
const ansi_bytes_per_pixel = 60;

/// Controls behavior when scaleInPlace target dimensions exceed buffer size
pub const ScaleMode = enum {
    clip, // Clip scaled content to fit within buffer bounds
    autoenlarge, // Automatically resize surface to accommodate target dimensions
};

/// Scaling algorithm quality/performance trade-off
pub const ScaleAlgorithm = enum {
    none, // Direct pixel mapping, no interpolation (fastest, blockiest)
    nearest_neighbor, // Pick closest source pixel (fast, blocky)
    bilinear, // Weighted average of 2x2 pixels (smooth, moderate speed)
    bicubic, // Weighted average of 4x4 pixels (smoothest, slowest)
};

/// Controls behavior when rotateInPlace dimensions exceed buffer size
pub const RotateMode = enum {
    clip, // Clip rotated content to fit within buffer bounds
    autoenlarge, // Automatically resize surface to accommodate rotated image
};

/// Rotation interpolation algorithm
pub const RotateAlgorithm = enum {
    nearest_neighbor, // Pick closest source pixel (fast, preserves pixel art)
    bilinear, // Weighted average of 2x2 pixels (smooth)
};

/// Defines a 2D grid for rendering pixels and text
/// supports half-block rendering and Unicode text overlays.
pub const RenderSurface = struct {
    color_map: []movy.core.types.Rgb, // RGB colors for each pixel
    shadow_map: []u8, // Transparency/opacity map (0 = transparent, 1+ = opaque)
    char_map: []u21, // Unicode codepoints for text overlay
    rendered_str: []u8, // Buffer for rendered ANSI
    w: usize, // Width in characters
    h: usize, // Height in pixel rows (h/2 lines for text)
    x: i32, // X position in terminal coordinates
    y: i32, // Y position in terminal coordinates
    z: i32, // Z-order for layering

    /// Creates a new RenderSurface with specified width, height, and color
    /// Fills the RenderSurface with a uniform color, sets all pixels to opaque,
    /// and clears all characters.
    pub fn init(
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
        color: movy.core.types.Rgb,
    ) !*RenderSurface {
        const self = try allocator.create(RenderSurface);
        errdefer allocator.destroy(self);
        self.w = w;
        self.h = h;
        self.x = 0;
        self.y = 0;
        self.z = 0;
        self.color_map = try allocator.alloc(movy.core.types.Rgb, w * h);
        errdefer allocator.free(self.color_map);
        self.shadow_map = try allocator.alloc(u8, w * h);
        errdefer allocator.free(self.shadow_map);
        self.char_map = try allocator.alloc(u21, w * h);
        errdefer allocator.free(self.char_map);

        self.rendered_str = try allocator.alloc(
            u8,
            self.w * self.h * ansi_bytes_per_pixel,
        );
        errdefer allocator.free(self.rendered_str);
        self.clearColored(color);
        return self;
    }

    /// Deinitializes a RenderSurface, freeing all its allocated resources
    pub fn deinit(self: *RenderSurface, allocator: std.mem.Allocator) void {
        allocator.free(self.color_map);
        allocator.free(self.shadow_map);
        allocator.free(self.char_map);
        allocator.free(self.rendered_str);
        allocator.destroy(self);
    }

    /// Loads an RGBA32 PNG into a new RenderSurface
    pub fn createFromPng(
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !*RenderSurface {
        var w: c_uint = 0;
        var h: c_uint = 0;
        var rgba_data: [*c]u8 = null;
        const error_code = cimp.lodepng_decode32_file(
            &rgba_data,
            &w,
            &h,
            file_path.ptr,
        );
        defer if (rgba_data != null) std.c.free(rgba_data);

        if (error_code != 0) {
            return error.InvalidPngFile;
        }

        const width = @as(usize, (w));
        const height = @as(usize, h);
        const pixel_count = width * height;

        // Create a RenderSurface with default clear color (will overwrite)
        const surface = try init(
            allocator,
            width,
            height,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(surface);

        // Fill the surface with PNG data
        for (0..pixel_count) |i| {
            const r = rgba_data[i * 4];
            const g = rgba_data[i * 4 + 1];
            const b = rgba_data[i * 4 + 2];
            const a = rgba_data[i * 4 + 3];
            surface.color_map[i] =
                movy.core.types.Rgb{ .r = r, .g = g, .b = b };

            // attempt to use shadow map as alpha channel
            // regualr RenderEngine.render() only checks if != 0  for
            // opacity!
            // -> use RenderEngine.renderWithAlpha() // TODO:
            surface.shadow_map[i] = a;
        }

        return surface;
    }

    /// Loads an RGBA32 PNG from a memory buffer into a new RenderSurface
    pub fn createFromPngData(
        allocator: std.mem.Allocator,
        png_data: []const u8,
    ) !*RenderSurface {
        var w: c_uint = 0;
        var h: c_uint = 0;
        var rgba_data: [*c]u8 = null;

        const error_code = cimp.lodepng_decode_memory(
            &rgba_data,
            &w,
            &h,
            png_data.ptr,
            png_data.len,
            cimp.LCT_RGBA,
            8,
        );
        defer if (rgba_data != null) std.c.free(rgba_data);

        if (error_code != 0) {
            return error.InvalidPngData;
        }

        const width = @as(usize, w);
        const height = @as(usize, h);
        const pixel_count = width * height;

        const surface = try init(
            allocator,
            width,
            height,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(surface);

        for (0..pixel_count) |i| {
            const r = rgba_data[i * 4];
            const g = rgba_data[i * 4 + 1];
            const b = rgba_data[i * 4 + 2];
            // const a = rgba_data[i * 4 + 3];
            surface.color_map[i] =
                movy.core.types.Rgb{ .r = r, .g = g, .b = b };
            // surface.shadow_map[i] = if (a > 0) 1 else 0;
            surface.shadow_map[i] = 1;
        }

        return surface;
    }

    /// Creates a new RenderSurface from a catimg ANSI string,
    /// calculating dimensions from the first line.
    pub fn createFromAnsi(
        allocator: std.mem.Allocator,
        str: [:0]const u8,
    ) !*RenderSurface {
        if (str.len == 0) {
            std.debug.print(
                "[movy][RenderSurface][createFromAnsi] " ++
                    "ERROR: input str null!\n",
                .{},
            );
            return error.InvalidAnsiString;
        }

        const header_len = movy.utils.ansi_parser.ANSI_HEADER.len;
        if (str.len < header_len or
            !std.mem.eql(u8, str[0..header_len], &movy.utils.ansi_parser.ANSI_HDR))
        {
            std.debug.print(
                "[movy][RenderSurface][createFromAnsi] " ++
                    "ERROR: invalid file type!\n",
                .{},
            );
            return error.InvalidAnsiString;
        }

        var pos: usize = movy.utils.ansi_parser.ANSI_HEADER.len;
        var line_nr: i32 = 0;
        var width: usize = 0;
        var height: usize = 0;

        // Calculate width and height from the ANSI string
        while (pos < (str.len -
            (movy.utils.ansi_parser.ANSI_LINE_END.len +
                movy.utils.ansi_parser.ANSI_FILE_END.len)))
        {
            var line_pos: usize = 0;
            while (str[
                pos + line_pos +
                    movy.utils.ansi_parser.ANSI_LINE_END.len - 1
            ] != 0x0a) {
                const c = str[pos + line_pos];
                if (c == 0x96 or c == 0x20) {
                    if (line_nr == 0) width += 1;
                }
                line_pos += 1;
            }
            line_pos += movy.utils.ansi_parser.ANSI_LINE_END.len;
            line_nr += 1;
            height += 2;
            pos += line_pos;
        }

        // Create the surface with calculated dimensions
        const surface = try RenderSurface.init(
            allocator,
            width,
            height,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(surface);

        // Fill the surface with ANSI data (old ansiToMaps logic)
        var map_y: usize = 0;
        const half_h = height / 2;
        pos = movy.utils.ansi_parser.ANSI_HEADER.len;

        @memset(surface.color_map, .{ .r = 0xF0, .g = 0x20, .b = 0x20 });
        @memset(surface.shadow_map, 0);

        while (map_y < half_h and
            pos < str.len - movy.utils.ansi_parser.ANSI_LINE_END.len)
        {
            var map_x: usize = 0;
            while (map_x < width and pos < str.len) {
                const result = movy.utils.ansi_parser.parseAnsiPixel(
                    str,
                    pos,
                ) catch |err| {
                    std.debug.print(
                        "[movy][RenderSurface][createFromAnsi] " ++
                            "ERROR: parsing failed at pos {}: {}\n",
                        .{ pos, err },
                    );
                    return error.AnsiParseFailed;
                };
                if (!result.valid) {
                    std.debug.print(
                        "[movy][RenderSurface][createFromAnsi] " ++
                            "ERROR: invalid pixel at pos {}\n",
                        .{pos},
                    );
                    return error.AnsiParseFailed;
                }

                const upper_idx = (map_y * 2) * width + map_x;
                const lower_idx = (map_y * 2 + 1) * width + map_x;

                surface.color_map[upper_idx] = result.upper;
                surface.color_map[lower_idx] = result.lower;
                surface.shadow_map[upper_idx] =
                    if (result.block_type == .double or
                    result.block_type == .upper) 1 else 0;
                surface.shadow_map[lower_idx] =
                    if (result.block_type == .double or
                    result.block_type == .lower) 1 else 0;

                pos = result.new_pos;
                map_x += 1;
            }
            pos += movy.utils.ansi_parser.ANSI_LINE_END.len;
            map_y += 1;
        }

        if (map_y != half_h or pos > str.len) {
            std.debug.print(
                "[movy][RenderSurface][createFromAnsi] " ++
                    "ERROR: incomplete parse, expected {} rows, got {}\n",
                .{ half_h, map_y },
            );
            return error.AnsiParseFailed;
        }

        return surface;
    }

    /// Formats a foreground color RGB triplet into ANSI escape sequence
    /// Returns the number of bytes written
    inline fn formatFgColor(buf: []u8, color: movy.core.types.Rgb) usize {
        const prefix = "\x1b[38;2;";
        @memcpy(buf[0..prefix.len], prefix);
        var idx = prefix.len;

        // Format R value
        if (color.r >= 100) {
            buf[idx] = '0' + color.r / 100;
            idx += 1;
            buf[idx] = '0' + (color.r / 10) % 10;
            idx += 1;
            buf[idx] = '0' + color.r % 10;
            idx += 1;
        } else if (color.r >= 10) {
            buf[idx] = '0' + color.r / 10;
            idx += 1;
            buf[idx] = '0' + color.r % 10;
            idx += 1;
        } else {
            buf[idx] = '0' + color.r;
            idx += 1;
        }

        buf[idx] = ';';
        idx += 1;

        // Format G value
        if (color.g >= 100) {
            buf[idx] = '0' + color.g / 100;
            idx += 1;
            buf[idx] = '0' + (color.g / 10) % 10;
            idx += 1;
            buf[idx] = '0' + color.g % 10;
            idx += 1;
        } else if (color.g >= 10) {
            buf[idx] = '0' + color.g / 10;
            idx += 1;
            buf[idx] = '0' + color.g % 10;
            idx += 1;
        } else {
            buf[idx] = '0' + color.g;
            idx += 1;
        }

        buf[idx] = ';';
        idx += 1;

        // Format B value
        if (color.b >= 100) {
            buf[idx] = '0' + color.b / 100;
            idx += 1;
            buf[idx] = '0' + (color.b / 10) % 10;
            idx += 1;
            buf[idx] = '0' + color.b % 10;
            idx += 1;
        } else if (color.b >= 10) {
            buf[idx] = '0' + color.b / 10;
            idx += 1;
            buf[idx] = '0' + color.b % 10;
            idx += 1;
        } else {
            buf[idx] = '0' + color.b;
            idx += 1;
        }

        buf[idx] = 'm';
        idx += 1;

        return idx;
    }

    /// Formats a background color RGB triplet into ANSI escape sequence
    /// Returns the number of bytes written
    inline fn formatBgColor(buf: []u8, color: movy.core.types.Rgb) usize {
        const prefix = "\x1b[48;2;";
        @memcpy(buf[0..prefix.len], prefix);
        var idx = prefix.len;

        // Format R value
        if (color.r >= 100) {
            buf[idx] = '0' + color.r / 100;
            idx += 1;
            buf[idx] = '0' + (color.r / 10) % 10;
            idx += 1;
            buf[idx] = '0' + color.r % 10;
            idx += 1;
        } else if (color.r >= 10) {
            buf[idx] = '0' + color.r / 10;
            idx += 1;
            buf[idx] = '0' + color.r % 10;
            idx += 1;
        } else {
            buf[idx] = '0' + color.r;
            idx += 1;
        }

        buf[idx] = ';';
        idx += 1;

        // Format G value
        if (color.g >= 100) {
            buf[idx] = '0' + color.g / 100;
            idx += 1;
            buf[idx] = '0' + (color.g / 10) % 10;
            idx += 1;
            buf[idx] = '0' + color.g % 10;
            idx += 1;
        } else if (color.g >= 10) {
            buf[idx] = '0' + color.g / 10;
            idx += 1;
            buf[idx] = '0' + color.g % 10;
            idx += 1;
        } else {
            buf[idx] = '0' + color.g;
            idx += 1;
        }

        buf[idx] = ';';
        idx += 1;

        // Format B value
        if (color.b >= 100) {
            buf[idx] = '0' + color.b / 100;
            idx += 1;
            buf[idx] = '0' + (color.b / 10) % 10;
            idx += 1;
            buf[idx] = '0' + color.b % 10;
            idx += 1;
        } else if (color.b >= 10) {
            buf[idx] = '0' + color.b / 10;
            idx += 1;
            buf[idx] = '0' + color.b % 10;
            idx += 1;
        } else {
            buf[idx] = '0' + color.b;
            idx += 1;
        }

        buf[idx] = 'm';
        idx += 1;

        return idx;
    }

    /// Converts the RenderSurface's color_map, shadow_map, and char_map
    /// to an ANSI string with half-block rendering.
    /// If a char (u21 UTF8) is present in char_map at an even y (line-aligned),
    /// renders it with the corresponding color_map fg.
    /// Assumes rendered_str is preallocated and will be freed on deinit.
    pub fn toAnsi(self: *RenderSurface) ![]u8 {
        var tmpstr_idx: usize = 0;

        // Stop 1 row early if height is odd to avoid accessing y+1 out of bounds
        const max_y = if (self.h % 2 == 1) self.h - 1 else self.h;

        for (0..max_y) |y| {
            if (y % 2 != 0) continue; // Step by 2—half-block pairs
            for (0..self.w) |x| {
                const idx = x + y * self.w;
                const char = self.char_map[idx];
                var char_above: u21 = 0;

                if (char == 0) {
                    if (idx > self.w) char_above = self.char_map[idx - self.w];
                }

                if ((char != 0) or (char_above != 0)) {
                    // Char present? Render it
                    if (char != 0) {
                        tmpstr_idx += formatFgColor(
                            self.rendered_str[tmpstr_idx..],
                            self.color_map[idx],
                        );
                        tmpstr_idx += formatBgColor(
                            self.rendered_str[tmpstr_idx..],
                            self.color_map[idx + self.w],
                        );
                        const char_bytes = std.unicode.utf8Encode(
                            char,
                            self.rendered_str[tmpstr_idx..][0..4],
                        ) catch unreachable;
                        tmpstr_idx += char_bytes;
                    } else {
                        tmpstr_idx += formatBgColor(
                            self.rendered_str[tmpstr_idx..],
                            self.color_map[idx],
                        );
                        tmpstr_idx += formatFgColor(
                            self.rendered_str[tmpstr_idx..],
                            self.color_map[idx + self.w],
                        );
                        const char_bytes = std.unicode.utf8Encode(
                            char_above,
                            self.rendered_str[tmpstr_idx..][0..4],
                        ) catch unreachable;
                        tmpstr_idx += char_bytes;
                    }
                } else { // No char? Render pixels in half-blocks
                    const upper = self.color_map[idx];
                    const lower = self.color_map[x + (y + 1) * self.w];
                    const upper_trans = self.shadow_map[idx] == 0;
                    const lower_trans =
                        self.shadow_map[x + (y + 1) * self.w] == 0;

                    if (upper_trans and lower_trans) {
                        const s = "\x1b[m ";
                        @memcpy(self.rendered_str[tmpstr_idx..][0..s.len], s);
                        tmpstr_idx += s.len;
                    } else if (upper_trans) {
                        const prefix = "\x1b[0;";
                        @memcpy(
                            self.rendered_str[tmpstr_idx..][0..prefix.len],
                            prefix,
                        );
                        tmpstr_idx += prefix.len;
                        tmpstr_idx += formatFgColor(
                            self.rendered_str[tmpstr_idx..],
                            lower,
                        );
                        const block = "\xE2\x96\x84";
                        @memcpy(
                            self.rendered_str[tmpstr_idx..][0..block.len],
                            block,
                        );
                        tmpstr_idx += block.len;
                    } else if (lower_trans) {
                        const prefix = "\x1b[0;";
                        @memcpy(
                            self.rendered_str[tmpstr_idx..][0..prefix.len],
                            prefix,
                        );
                        tmpstr_idx += prefix.len;
                        tmpstr_idx += formatFgColor(
                            self.rendered_str[tmpstr_idx..],
                            upper,
                        );
                        const block = "\xE2\x96\x80";
                        @memcpy(
                            self.rendered_str[tmpstr_idx..][0..block.len],
                            block,
                        );
                        tmpstr_idx += block.len;
                    } else {
                        tmpstr_idx += formatBgColor(
                            self.rendered_str[tmpstr_idx..],
                            upper,
                        );
                        tmpstr_idx += formatFgColor(
                            self.rendered_str[tmpstr_idx..],
                            lower,
                        );
                        const block = "\xE2\x96\x84";
                        @memcpy(
                            self.rendered_str[tmpstr_idx..][0..block.len],
                            block,
                        );
                        tmpstr_idx += block.len;
                    }
                }
            }

            // Move cursor back and down for next line
            {
                const left_start = tmpstr_idx;
                const left_prefix = "\x1b[";
                @memcpy(
                    self.rendered_str[tmpstr_idx..][0..left_prefix.len],
                    left_prefix,
                );
                tmpstr_idx += left_prefix.len;

                // Format width as decimal
                const w = self.w;
                if (w >= 1000) {
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast(w / 1000));
                    tmpstr_idx += 1;
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast((w / 100) % 10));
                    tmpstr_idx += 1;
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast((w / 10) % 10));
                    tmpstr_idx += 1;
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast(w % 10));
                    tmpstr_idx += 1;
                } else if (w >= 100) {
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast(w / 100));
                    tmpstr_idx += 1;
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast((w / 10) % 10));
                    tmpstr_idx += 1;
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast(w % 10));
                    tmpstr_idx += 1;
                } else if (w >= 10) {
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast(w / 10));
                    tmpstr_idx += 1;
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast(w % 10));
                    tmpstr_idx += 1;
                } else {
                    self.rendered_str[tmpstr_idx] = '0' +
                        @as(u8, @intCast(w));
                    tmpstr_idx += 1;
                }

                self.rendered_str[tmpstr_idx] = 'D';
                tmpstr_idx += 1;
                _ = left_start;
            }
            {
                const down = "\x1b[1B";
                @memcpy(self.rendered_str[tmpstr_idx..][0..down.len], down);
                tmpstr_idx += down.len;
            }
            // bounds check
            if (tmpstr_idx >= self.rendered_str.len) {
                tmpstr_idx = self.rendered_str.len;
                break;
            }
        }

        return self.rendered_str[0..tmpstr_idx];
    }

    /// Fills the RenderSurface with a uniform color, sets all pixels to opaque,
    /// and clears all characters.
    /// The provided RGB color is applied to every pixel in the color_map.
    pub fn clearColored(self: *RenderSurface, c: movy.core.types.Rgb) void {
        @memset(self.color_map, c);
        @memset(self.shadow_map, 255);
        @memset(self.char_map, 0);
    }

    /// Clears the RenderSurface to a fully transparent state with black color.
    /// Sets all color_map pixels to RGB(0,0,0), shadow_map to 0 (transparent),
    /// and char_map to 0 (no characters).
    pub fn clearTransparent(self: *RenderSurface) void {
        const c = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };
        @memset(self.color_map, c);
        @memset(self.shadow_map, 0);
        @memset(self.char_map, 0);
    }

    /// Sets the alpha (opacity) for all non-transparent pixels in the surface.
    /// Alpha values range from 0 (fully transparent) to 255 (fully opaque).
    /// Only affects pixels that are already visible (shadow_map != 0).
    /// Note: Alpha value 0 is automatically converted to 1 to maintain the
    /// shadow_map rendering logic (0 = skip pixel, non-zero = render pixel).
    pub fn setAlpha(self: *RenderSurface, alpha: u8) void {
        const actual_alpha = if (alpha == 0) 1 else alpha;
        for (self.shadow_map) |*shadow| {
            if (shadow.* != 0) {
                shadow.* = actual_alpha;
            }
        }
    }

    /// Copies the contents of another RenderSurface to this one, including
    /// all maps and dimensions.
    /// Returns an error if the input has invalid dimensions (width or height
    /// is 0) or if this surface's buffers are too small to hold the input data.
    pub fn copy(self: *RenderSurface, in: *RenderSurface) !void {
        if (in.w == 0 or in.h == 0) return error.InvalidDimensions;

        const len = in.w * in.h;
        if (self.color_map.len < len or self.shadow_map.len < len or
            self.char_map.len < len)
        {
            return error.BufferTooSmall;
        }

        @memcpy(self.color_map[0..len], in.color_map[0..len]);
        @memcpy(self.shadow_map[0..len], in.shadow_map[0..len]);
        @memcpy(self.char_map[0..len], in.char_map[0..len]);

        self.w = in.w;
        self.h = in.h;
        self.x = in.x;
        self.y = in.y;
        self.z = in.z;
    }

    /// Resizes the RenderSurface to a new width and height,
    /// reallocating all internal buffers and clearing the surface.
    ///
    /// This is typically used to expand surfaces for size-aware effects
    /// like glow, shake, stretch, etc.
    pub fn resize(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        width: usize,
        height: usize,
    ) !void {
        if (width == 0 or height == 0)
            return error.InvalidDimensions;

        const new_color_map = try allocator.alloc(
            movy.core.types.Rgb,
            width * height,
        );
        errdefer allocator.free(new_color_map);

        const new_shadow_map = try allocator.alloc(u8, width * height);
        errdefer allocator.free(new_shadow_map);

        const new_char_map = try allocator.alloc(u21, width * height);
        errdefer allocator.free(new_char_map);

        const new_rendered_str = try allocator.alloc(
            u8,
            width * height * ansi_bytes_per_pixel,
        );
        errdefer allocator.free(new_rendered_str);

        // Free old memory after successful allocs
        allocator.free(self.color_map);
        allocator.free(self.shadow_map);
        allocator.free(self.char_map);
        allocator.free(self.rendered_str);

        self.color_map = new_color_map;
        self.shadow_map = new_shadow_map;
        self.char_map = new_char_map;
        self.rendered_str = new_rendered_str;

        self.w = width;
        self.h = height;

        self.clearTransparent();
    }

    /// Writes a single character to the RenderSurface at the specified
    /// coordinates with foreground and background colors.
    /// Uses y * 2 to align with half-block rendering—clips if y exceeds h/2.
    pub fn putCharXY(
        self: *RenderSurface,
        char: u8,
        x: usize,
        y: usize,
        fg_color: movy.core.types.Rgb,
        bg_color: movy.core.types.Rgb,
    ) void {
        if (y >= self.h / 2) return; // Clip at half height
        const y_pixel = y * 2; // Line to pixel
        const idx = x + y_pixel * self.w;
        if (x < self.w and y_pixel + 1 < self.h) { // Bounds check
            self.char_map[idx] = char;
            self.color_map[idx] = fg_color; // fg at y
            self.color_map[idx + self.w] = bg_color; // bg at y+1
            self.shadow_map[idx] = 255;
        }
    }

    /// Writes a single character to the RenderSurface at the specified
    /// coordinates with foreground and background colors.
    /// Uses y * 2 to align with half-block rendering—clips if y exceeds h/2.
    pub fn putUtf8XY(
        self: *RenderSurface,
        char: u21,
        x: usize,
        y: usize,
        fg_color: movy.core.types.Rgb,
        bg_color: movy.core.types.Rgb,
    ) void {
        const print_char = if (isDoubleWidth(char)) 0x25C9 else char;

        if (y >= self.h / 2) return; // Clip at half height
        const y_pixel = y * 2; // Line to pixel
        const idx = x + y_pixel * self.w;
        if (x < self.w and y_pixel + 1 < self.h) { // Bounds check
            self.char_map[idx] = print_char;
            self.color_map[idx] = fg_color; // fg at y
            self.color_map[idx + self.w] = bg_color; // bg at y+1
            self.shadow_map[idx] = 255;
        }
    }

    /// Writes a string to the RenderSurface starting at the specified
    /// coordinates with foreground and background colors.
    /// Steps x per char, wraps to xpos and y += 2 on width exceed or \n
    /// clips if y exceeds h/2.
    /// returns index into maps for next cursor position
    pub fn putStrXY(
        self: *RenderSurface,
        str: []const u8,
        xpos: usize,
        ypos: usize,
        fg_color: movy.core.types.Rgb,
        bg_color: movy.core.types.Rgb,
    ) usize {
        var x = xpos;
        var y = ypos;
        if (y >= self.h / 2) return 0; // Clip at half height
        var y_pixel = y * 2; // Line to pixel, even rows

        var idx: usize = 0;

        for (str) |char| {
            if (char == '\n' or x >= (self.w - 1)) { // Wrap on \n or width
                x = xpos;
                y += 1;
                if (y >= (self.h / 2) - 1) return 0; // Clip
                y_pixel = y * 2;
                // Only when not clipping, on '\n'
                if (char == '\n') continue;
            }
            idx = x + y_pixel * self.w;
            if (x < self.w and y_pixel + 1 < self.h) { // Bounds check
                self.char_map[idx] = char;
                self.color_map[idx] = fg_color; // fg at y
                self.color_map[idx + self.w] = bg_color; // bg at y+1
                self.shadow_map[idx] = 255;
            }
            x += 1;
        }

        // return idx, but check wrap first
        if (x >= (self.w - 1)) { // Wrap on width
            x = xpos;
            y += 1;
            if (y >= (self.h / 2) - 1) return 0; // Clip
            y_pixel = y * 2;
        }
        idx = x + y_pixel * self.w;
        return idx;
    }

    /// Writes a string to the RenderSurface starting at the specified
    /// coordinates with foreground and background colors.
    /// Steps x per char, wraps to xpos and y += 2 on width exceed or \n
    /// clips if y exceeds h/2.
    /// returns index into maps for next cursor position
    pub fn putStrXYTransparent(
        self: *RenderSurface,
        str: []const u8,
        xpos: usize,
        ypos: usize,
        fg_color: movy.core.types.Rgb,
        bg_color: movy.core.types.Rgb,
    ) usize {
        var x = xpos;
        var y = ypos;
        if (y >= self.h / 2) return 0; // Clip at half height
        var y_pixel = y * 2; // Line to pixel, even rows

        var idx: usize = 0;

        for (str) |char| {
            if (char == '\n' or x >= (self.w - 1)) { // Wrap on \n or width
                x = xpos;
                y += 1;
                if (y >= (self.h / 2) - 1) return 0; // Clip
                y_pixel = y * 2;
                // Only when not clipping, on '\n'
                if (char == '\n') continue;
            }
            idx = x + y_pixel * self.w;
            if (x < self.w and y_pixel + 1 < self.h) { // Bounds check
                if (char != ' ') {
                    self.char_map[idx] = char;
                    self.color_map[idx] = fg_color; // fg at y
                    self.color_map[idx + self.w] = bg_color; // bg at y+1
                    self.shadow_map[idx] = 255;
                }
            }
            x += 1;
        }

        // return idx, but check wrap first
        if (x >= (self.w - 1)) { // Wrap on width
            x = xpos;
            y += 1;
            if (y >= (self.h / 2) - 1) return 0; // Clip
            y_pixel = y * 2;
        }
        idx = x + y_pixel * self.w;
        return idx;
    }

    /// Writes an StyledTextBuffer to the RenderSurface starting at the
    /// specified coordinates with foreground and background colors.
    /// StyledChar colors override the given colores.
    /// Steps x per char, wraps to xpos and y += 2 on width exceed or \n
    /// clips if y exceeds h/2.
    /// returns index into maps for StyledTextBuffer.cursor_idx
    pub fn putStyledTextXY(
        self: *RenderSurface,
        text: movy.ui.StyledTextBuffer,
        xpos: usize,
        ypos: usize,
        fg_color: movy.core.types.Rgb,
        bg_color: movy.core.types.Rgb,
    ) usize {
        var x = xpos;
        var y = ypos;
        if (y >= self.h / 2) return 0; // Clip at half height
        var y_pixel = y * 2; // Line to pixel, even rows

        var map_idx: usize = 0;
        var str_idx: usize = 0;
        var return_idx: usize = 0;

        for (0..text.last_char_idx + 1) |i| {
            const styled = text.text[i];
            const fg = styled.fg orelse fg_color;
            const bg = styled.bg orelse bg_color;
            var char = styled.char;

            if (isDoubleWidth(char)) char = '*';

            if (char == '\n' or x >= (self.w - 1)) { // Wrap on \n or width
                map_idx = x + y_pixel * self.w;
                if (str_idx == text.cursor_idx) return_idx = map_idx;
                x = xpos;
                y += 1;
                if (y >= (self.h / 2) - 1) return 0; // Clip
                y_pixel = y * 2;
                if (char == '\n') {
                    str_idx += 1;
                    continue; // only when not clipping, on '\n'
                }
            }
            map_idx = x + y_pixel * self.w;
            if (str_idx == text.cursor_idx) return_idx = map_idx;

            if (x < self.w and y_pixel + 1 < self.h) { // Bounds check
                self.char_map[map_idx] = char;
                self.color_map[map_idx] = fg; // fg at y
                self.color_map[map_idx + self.w] = bg; // bg at y+1
                self.shadow_map[map_idx] = 255;
            }
            x += 1;
            str_idx += 1;
        }

        // return idx, but check wrap first
        if (x >= (self.w - 1)) { // Wrap on width
            x = xpos;
            y += 1;
            if (y >= (self.h / 2) - 1) return 0; // Clip
            y_pixel = y * 2;
        }
        map_idx = x + y_pixel * self.w;
        if (str_idx == text.cursor_idx) return_idx = map_idx;

        return return_idx;
    }

    /// Retrieves the color at the specified 2D pixel coordinates,
    /// returning a default white color if out of bounds.
    /// Updates the provided Pixel2D struct with the RGB value from
    /// the color_map.
    pub fn getColor(self: *RenderSurface, p: *movy.core.types.Pixel2D) void {
        // Default color for out-of-bounds
        p.c = movy.core.types.Rgb{ .r = 255, .g = 255, .b = 255 };
        if (p.x < 0 or p.x >= @as(i32, @intCast(self.w)) or
            p.y < 0 or p.y >= @as(i32, @intCast(self.h))) return;
        const idx = self.w * @as(usize, @intCast(p.y)) +
            @as(usize, @intCast(p.x));
        p.c = self.color_map[idx];
    }

    /// Sets the color at the specified 2D pixel coordinates in the color_map.
    /// Does nothing if the coordinates are outside the surface bounds.
    pub fn setColor(self: *RenderSurface, p: *movy.core.types.Pixel2D) void {
        if (p.x < 0 or p.x >= @as(i32, @intCast(self.w)) or
            p.y < 0 or p.y >= @as(i32, @intCast(self.h))) return;
        const idx = self.w * @as(usize, @intCast(p.y)) +
            @as(usize, @intCast(p.x));
        self.color_map[idx] = p.c;
    }

    /// Checks if the specified coordinates have a non-transparent pixel
    /// (opacity > 0).
    /// Returns false if the coordinates are out of bounds or the pixel
    /// is transparent.
    pub fn hasColorXY(self: *RenderSurface, x: i32, y: i32) bool {
        if (x < 0 or x >= @as(i32, @intCast(self.w)) or
            y < 0 or y >= @as(i32, @intCast(self.h))) return false;
        const idx = self.w * @as(usize, @intCast(y)) + @as(usize, @intCast(x));
        return self.shadow_map[idx] != 0;
    }

    /// Checks if the specified 2D pixel has a non-transparent
    /// pixel (opacity > 0).
    /// Returns false if the coordinates are out of bounds or the pixel is
    /// transparent.
    pub fn hasColor(self: *RenderSurface, p: *movy.core.types.Pixel2D) bool {
        if (p.x < 0 or p.x >= @as(i32, @intCast(self.w)) or
            p.y < 0 or p.y >= @as(i32, @intCast(self.h))) return false;
        const idx = self.w * @as(usize, @intCast(p.y)) +
            @as(usize, @intCast(p.x));
        return self.shadow_map[idx] != 0;
    }

    /// Checks if the specified coordinates have a pixel with any RGB value
    /// exceeding the threshold.
    /// Returns false if out of bounds, transparent, or no RGB component exceeds
    /// the threshold.
    pub fn hasColorThrXY(self: *RenderSurface, x: i32, y: i32, thr: i32) bool {
        if (x < 0 or x >= @as(i32, @intCast(self.w)) or
            y < 0 or y >= @as(i32, @intCast(self.h))) return false;
        const idx = self.w * @as(usize, @intCast(y)) +
            @as(usize, @intCast(x));
        if (self.shadow_map[idx] != 0) {
            const c = self.color_map[idx];
            return c.r > thr or c.g > thr or c.b > thr;
        }
        return false;
    }

    /// Checks if the specified 2D pixel has any RGB value exceeding the
    /// threshold.
    /// Returns false if out of bounds, transparent, or no RGB component exceeds
    /// the threshold.
    pub fn hasColorThr(
        self: *RenderSurface,
        p: *movy.core.types.Pixel2D,
        thr: i32,
    ) bool {
        if (p.x < 0 or p.x >= @as(i32, @intCast(self.w)) or
            p.y < 0 or p.y >= @as(i32, @intCast(self.h))) return false;
        const idx = self.w * @as(usize, @intCast(p.y)) +
            @as(usize, @intCast(p.x));
        if (self.shadow_map[idx] != 0) {
            const c = self.color_map[idx];
            return c.r > thr or c.g > thr or c.b > thr;
        }
        return false;
    }

    // Internal scaling algorithm implementations

    /// Direct pixel mapping without interpolation
    /// Maps destination pixels to source pixels using simple ratio
    fn scaleNone(
        src_colors: []const movy.core.types.Rgb,
        src_shadow: []const u8,
        src_w: usize,
        src_h: usize,
        dst_colors: []movy.core.types.Rgb,
        dst_shadow: []u8,
        dst_w: usize,
        dst_h: usize,
    ) void {
        const x_ratio = @as(f32, @floatFromInt(src_w)) /
            @as(f32, @floatFromInt(dst_w));
        const y_ratio = @as(f32, @floatFromInt(src_h)) /
            @as(f32, @floatFromInt(dst_h));

        for (0..dst_h) |dy| {
            const sy = @min(
                @as(usize, @intFromFloat(@as(f32, @floatFromInt(dy)) * y_ratio)),
                src_h - 1,
            );

            for (0..dst_w) |dx| {
                const sx = @min(
                    @as(
                        usize,
                        @intFromFloat(@as(f32, @floatFromInt(dx)) * x_ratio),
                    ),
                    src_w - 1,
                );
                const src_idx = sy * src_w + sx;
                const dst_idx = dy * dst_w + dx;
                dst_colors[dst_idx] = src_colors[src_idx];
                dst_shadow[dst_idx] = src_shadow[src_idx];
            }
        }
    }

    /// Nearest neighbor interpolation
    /// Picks the closest source pixel for each destination pixel
    fn scaleNearestNeighbor(
        src_colors: []const movy.core.types.Rgb,
        src_shadow: []const u8,
        src_w: usize,
        src_h: usize,
        dst_colors: []movy.core.types.Rgb,
        dst_shadow: []u8,
        dst_w: usize,
        dst_h: usize,
    ) void {
        for (0..dst_h) |dy| {
            for (0..dst_w) |dx| {
                const sx = @min(
                    (dx * src_w + src_w / 2) / dst_w,
                    src_w - 1,
                );
                const sy = @min(
                    (dy * src_h + src_h / 2) / dst_h,
                    src_h - 1,
                );
                const src_idx = sy * src_w + sx;
                const dst_idx = dy * dst_w + dx;
                dst_colors[dst_idx] = src_colors[src_idx];
                dst_shadow[dst_idx] = src_shadow[src_idx];
            }
        }
    }

    /// Bilinear interpolation
    /// Weighted average of 2x2 pixel neighborhood
    fn scaleBilinear(
        src_colors: []const movy.core.types.Rgb,
        src_shadow: []const u8,
        src_w: usize,
        src_h: usize,
        dst_colors: []movy.core.types.Rgb,
        dst_shadow: []u8,
        dst_w: usize,
        dst_h: usize,
    ) void {
        const x_ratio = @as(f32, @floatFromInt(src_w - 1)) /
            @as(f32, @floatFromInt(dst_w));
        const y_ratio = @as(f32, @floatFromInt(src_h - 1)) /
            @as(f32, @floatFromInt(dst_h));

        for (0..dst_h) |dy| {
            const y_src = @as(f32, @floatFromInt(dy)) * y_ratio;
            const y_int = @as(usize, @intFromFloat(y_src));
            const y_frac = y_src - @as(f32, @floatFromInt(y_int));
            const y1 = @min(y_int + 1, src_h - 1);

            for (0..dst_w) |dx| {
                const x_src = @as(f32, @floatFromInt(dx)) * x_ratio;
                const x_int = @as(usize, @intFromFloat(x_src));
                const x_frac = x_src - @as(f32, @floatFromInt(x_int));
                const x1 = @min(x_int + 1, src_w - 1);

                // Get 2x2 neighborhood indices
                const idx_tl = y_int * src_w + x_int; // top-left
                const idx_tr = y_int * src_w + x1; // top-right
                const idx_bl = y1 * src_w + x_int; // bottom-left
                const idx_br = y1 * src_w + x1; // bottom-right

                // Bilinear weights
                const w_tl = (1.0 - x_frac) * (1.0 - y_frac);
                const w_tr = x_frac * (1.0 - y_frac);
                const w_bl = (1.0 - x_frac) * y_frac;
                const w_br = x_frac * y_frac;

                // Interpolate colors
                const r = @as(u8, @intFromFloat(
                    @as(f32, @floatFromInt(src_colors[idx_tl].r)) * w_tl +
                        @as(f32, @floatFromInt(src_colors[idx_tr].r)) * w_tr +
                        @as(f32, @floatFromInt(src_colors[idx_bl].r)) * w_bl +
                        @as(f32, @floatFromInt(src_colors[idx_br].r)) * w_br,
                ));
                const g = @as(u8, @intFromFloat(
                    @as(f32, @floatFromInt(src_colors[idx_tl].g)) * w_tl +
                        @as(f32, @floatFromInt(src_colors[idx_tr].g)) * w_tr +
                        @as(f32, @floatFromInt(src_colors[idx_bl].g)) * w_bl +
                        @as(f32, @floatFromInt(src_colors[idx_br].g)) * w_br,
                ));
                const b = @as(u8, @intFromFloat(
                    @as(f32, @floatFromInt(src_colors[idx_tl].b)) * w_tl +
                        @as(f32, @floatFromInt(src_colors[idx_tr].b)) * w_tr +
                        @as(f32, @floatFromInt(src_colors[idx_bl].b)) * w_bl +
                        @as(f32, @floatFromInt(src_colors[idx_br].b)) * w_br,
                ));

                // Interpolate alpha
                const alpha = @as(u8, @intFromFloat(
                    @as(f32, @floatFromInt(src_shadow[idx_tl])) * w_tl +
                        @as(f32, @floatFromInt(src_shadow[idx_tr])) * w_tr +
                        @as(f32, @floatFromInt(src_shadow[idx_bl])) * w_bl +
                        @as(f32, @floatFromInt(src_shadow[idx_br])) * w_br,
                ));

                const dst_idx = dy * dst_w + dx;
                dst_colors[dst_idx] = .{ .r = r, .g = g, .b = b };
                dst_shadow[dst_idx] = alpha;
            }
        }
    }

    /// Cubic interpolation helper (Catmull-Rom)
    inline fn cubicInterpolate(p: [4]f32, x: f32) f32 {
        return p[1] + 0.5 * x * (p[2] - p[0] + x * (2.0 * p[0] - 5.0 * p[1] +
            4.0 * p[2] - p[3] + x * (3.0 * (p[1] - p[2]) + p[3] - p[0])));
    }

    /// Bicubic interpolation
    /// Weighted average of 4x4 pixel neighborhood using cubic kernels
    fn scaleBicubic(
        src_colors: []const movy.core.types.Rgb,
        src_shadow: []const u8,
        src_w: usize,
        src_h: usize,
        dst_colors: []movy.core.types.Rgb,
        dst_shadow: []u8,
        dst_w: usize,
        dst_h: usize,
    ) void {
        const x_ratio = @as(f32, @floatFromInt(src_w - 1)) /
            @as(f32, @floatFromInt(dst_w));
        const y_ratio = @as(f32, @floatFromInt(src_h - 1)) /
            @as(f32, @floatFromInt(dst_h));

        for (0..dst_h) |dy| {
            const y_src = @as(f32, @floatFromInt(dy)) * y_ratio;
            const y_int = @as(isize, @intFromFloat(y_src));
            const y_frac = y_src - @as(f32, @floatFromInt(y_int));

            for (0..dst_w) |dx| {
                const x_src = @as(f32, @floatFromInt(dx)) * x_ratio;
                const x_int = @as(isize, @intFromFloat(x_src));
                const x_frac = x_src - @as(f32, @floatFromInt(x_int));

                var r_arr: [4]f32 = undefined;
                var g_arr: [4]f32 = undefined;
                var b_arr: [4]f32 = undefined;
                var a_arr: [4]f32 = undefined;

                // Sample 4x4 neighborhood
                for (0..4) |jj| {
                    const j = @as(isize, @intCast(jj));
                    const y_samp = std.math.clamp(
                        y_int - 1 + j,
                        0,
                        @as(isize, @intCast(src_h - 1)),
                    );
                    var r_row: [4]f32 = undefined;
                    var g_row: [4]f32 = undefined;
                    var b_row: [4]f32 = undefined;
                    var a_row: [4]f32 = undefined;

                    for (0..4) |ii| {
                        const i = @as(isize, @intCast(ii));
                        const x_samp = std.math.clamp(
                            x_int - 1 + i,
                            0,
                            @as(isize, @intCast(src_w - 1)),
                        );
                        const idx = @as(usize, @intCast(y_samp)) * src_w + @as(
                            usize,
                            @intCast(x_samp),
                        );
                        r_row[ii] = @floatFromInt(src_colors[idx].r);
                        g_row[ii] = @floatFromInt(src_colors[idx].g);
                        b_row[ii] = @floatFromInt(src_colors[idx].b);
                        a_row[ii] = @floatFromInt(src_shadow[idx]);
                    }

                    r_arr[jj] = cubicInterpolate(r_row, x_frac);
                    g_arr[jj] = cubicInterpolate(g_row, x_frac);
                    b_arr[jj] = cubicInterpolate(b_row, x_frac);
                    a_arr[jj] = cubicInterpolate(a_row, x_frac);
                }

                const r = @as(u8, @intFromFloat(std.math.clamp(
                    cubicInterpolate(r_arr, y_frac),
                    0.0,
                    255.0,
                )));
                const g = @as(u8, @intFromFloat(std.math.clamp(
                    cubicInterpolate(g_arr, y_frac),
                    0.0,
                    255.0,
                )));
                const b = @as(u8, @intFromFloat(std.math.clamp(
                    cubicInterpolate(b_arr, y_frac),
                    0.0,
                    255.0,
                )));
                const alpha = @as(u8, @intFromFloat(std.math.clamp(
                    cubicInterpolate(a_arr, y_frac),
                    0.0,
                    255.0,
                )));

                const dst_idx = dy * dst_w + dx;
                dst_colors[dst_idx] = .{ .r = r, .g = g, .b = b };
                dst_shadow[dst_idx] = alpha;
            }
        }
    }

    fn isDoubleWidth(ch: u21) bool {
        return (ch >= 0x1100 and ch <= 0x115F) or
            (ch >= 0x2E80 and ch <= 0xA4CF) or
            (ch >= 0x1F300 and ch <= 0x1F64F); // Emoji & CJK
    }

    // -- Rotation Helper Functions

    /// Converts degrees to radians
    pub inline fn degreesToRadians(degrees: f32) f32 {
        return degrees * std.math.pi / 180.0;
    }

    /// Converts radians to degrees
    pub inline fn radiansToDegrees(radians: f32) f32 {
        return radians * 180.0 / std.math.pi;
    }

    /// Calculates the bounding box dimensions needed to contain a rotated image
    fn calculateRotatedBounds(
        w: usize,
        h: usize,
        angle_radians: f32,
    ) struct { w: usize, h: usize } {
        const cos_a = @abs(std.math.cos(angle_radians));
        const sin_a = @abs(std.math.sin(angle_radians));
        const w_f = @as(f32, @floatFromInt(w));
        const h_f = @as(f32, @floatFromInt(h));

        const new_w = @as(usize, @intFromFloat(w_f * cos_a + h_f * sin_a + 0.5));
        const new_h = @as(usize, @intFromFloat(w_f * sin_a + h_f * cos_a + 0.5));

        return .{ .w = new_w, .h = new_h };
    }

    // -- Rotation Algorithm Implementations

    /// Nearest neighbor rotation with optimized fast paths for 90-degree multiples
    fn rotateNearestNeighbor(
        src_colors: []const movy.core.types.Rgb,
        src_shadow: []const u8,
        src_w: usize,
        src_h: usize,
        dst_colors: []movy.core.types.Rgb,
        dst_shadow: []u8,
        dst_w: usize,
        dst_h: usize,
        angle_radians: f32,
        src_cx: f32,
        src_cy: f32,
    ) void {
        // Normalize angle to 0-2π
        const two_pi = 2.0 * std.math.pi;
        var norm_angle = @mod(angle_radians, two_pi);
        if (norm_angle < 0) norm_angle += two_pi;

        const epsilon = 0.01;

        // Fast path: 0 degrees (copy)
        if (@abs(norm_angle) < epsilon or @abs(norm_angle - two_pi) < epsilon) {
            for (0..dst_h) |y| {
                for (0..dst_w) |x| {
                    if (y < src_h and x < src_w) {
                        const idx = y * dst_w + x;
                        const src_idx = y * src_w + x;
                        dst_colors[idx] = src_colors[src_idx];
                        dst_shadow[idx] = src_shadow[src_idx];
                    }
                }
            }
            return;
        }

        // Fast path: 90 degrees
        if (@abs(norm_angle - std.math.pi / 2.0) < epsilon) {
            for (0..dst_h) |y| {
                for (0..dst_w) |x| {
                    const src_x = y;
                    const src_y = src_h - 1 - x;
                    if (src_y < src_h and src_x < src_w) {
                        const idx = y * dst_w + x;
                        const src_idx = src_y * src_w + src_x;
                        dst_colors[idx] = src_colors[src_idx];
                        dst_shadow[idx] = src_shadow[src_idx];
                    }
                }
            }
            return;
        }

        // Fast path: 180 degrees
        if (@abs(norm_angle - std.math.pi) < epsilon) {
            for (0..dst_h) |y| {
                for (0..dst_w) |x| {
                    const src_x = src_w - 1 - x;
                    const src_y = src_h - 1 - y;
                    if (src_y < src_h and src_x < src_w) {
                        const idx = y * dst_w + x;
                        const src_idx = src_y * src_w + src_x;
                        dst_colors[idx] = src_colors[src_idx];
                        dst_shadow[idx] = src_shadow[src_idx];
                    }
                }
            }
            return;
        }

        // Fast path: 270 degrees
        if (@abs(norm_angle - 3.0 * std.math.pi / 2.0) < epsilon) {
            for (0..dst_h) |y| {
                for (0..dst_w) |x| {
                    const src_x = src_w - 1 - y;
                    const src_y = x;
                    if (src_y < src_h and src_x < src_w) {
                        const idx = y * dst_w + x;
                        const src_idx = src_y * src_w + src_x;
                        dst_colors[idx] = src_colors[src_idx];
                        dst_shadow[idx] = src_shadow[src_idx];
                    }
                }
            }
            return;
        }

        // General case: arbitrary angle
        const cos_theta = std.math.cos(-angle_radians);
        const sin_theta = std.math.sin(-angle_radians);
        const dst_cx = @as(f32, @floatFromInt(dst_w)) / 2.0;
        const dst_cy = @as(f32, @floatFromInt(dst_h)) / 2.0;

        for (0..dst_h) |dy| {
            for (0..dst_w) |dx| {
                const dx_f = @as(f32, @floatFromInt(dx));
                const dy_f = @as(f32, @floatFromInt(dy));

                // Inverse rotation to find source pixel
                const src_x = (dx_f - dst_cx) * cos_theta -
                    (dy_f - dst_cy) * sin_theta + src_cx;
                const src_y = (dx_f - dst_cx) * sin_theta +
                    (dy_f - dst_cy) * cos_theta + src_cy;

                const src_xi = @as(i32, @intFromFloat(src_x + 0.5));
                const src_yi = @as(i32, @intFromFloat(src_y + 0.5));

                // Bounds check
                if (src_xi >= 0 and src_xi < @as(i32, @intCast(src_w)) and
                    src_yi >= 0 and src_yi < @as(i32, @intCast(src_h)))
                {
                    const src_idx = @as(usize, @intCast(src_yi)) * src_w +
                        @as(usize, @intCast(src_xi));
                    const dst_idx = dy * dst_w + dx;
                    dst_colors[dst_idx] = src_colors[src_idx];
                    dst_shadow[dst_idx] = src_shadow[src_idx];
                }
                // else: leave transparent (default initialization)
            }
        }
    }

    /// Bilinear interpolation rotation
    fn rotateBilinear(
        src_colors: []const movy.core.types.Rgb,
        src_shadow: []const u8,
        src_w: usize,
        src_h: usize,
        dst_colors: []movy.core.types.Rgb,
        dst_shadow: []u8,
        dst_w: usize,
        dst_h: usize,
        angle_radians: f32,
        src_cx: f32,
        src_cy: f32,
    ) void {
        const cos_theta = std.math.cos(-angle_radians);
        const sin_theta = std.math.sin(-angle_radians);
        const dst_cx = @as(f32, @floatFromInt(dst_w)) / 2.0;
        const dst_cy = @as(f32, @floatFromInt(dst_h)) / 2.0;

        for (0..dst_h) |dy| {
            for (0..dst_w) |dx| {
                const dx_f = @as(f32, @floatFromInt(dx));
                const dy_f = @as(f32, @floatFromInt(dy));

                // Inverse rotation to find source pixel
                const src_x = (dx_f - dst_cx) * cos_theta -
                    (dy_f - dst_cy) * sin_theta + src_cx;
                const src_y = (dx_f - dst_cx) * sin_theta +
                    (dy_f - dst_cy) * cos_theta + src_cy;

                // Get integer parts
                const x0 = @as(i32, @intFromFloat(@floor(src_x)));
                const y0 = @as(i32, @intFromFloat(@floor(src_y)));
                const x1 = x0 + 1;
                const y1 = y0 + 1;

                // Get fractional parts
                const fx = src_x - @floor(src_x);
                const fy = src_y - @floor(src_y);

                // Check bounds for all 4 neighbors
                const valid_tl = x0 >= 0 and x0 < @as(i32, @intCast(src_w)) and
                    y0 >= 0 and y0 < @as(i32, @intCast(src_h));
                const valid_tr = x1 >= 0 and x1 < @as(i32, @intCast(src_w)) and
                    y0 >= 0 and y0 < @as(i32, @intCast(src_h));
                const valid_bl = x0 >= 0 and x0 < @as(i32, @intCast(src_w)) and
                    y1 >= 0 and y1 < @as(i32, @intCast(src_h));
                const valid_br = x1 >= 0 and x1 < @as(i32, @intCast(src_w)) and
                    y1 >= 0 and y1 < @as(i32, @intCast(src_h));

                if (!valid_tl and !valid_tr and !valid_bl and !valid_br) {
                    continue; // All neighbors out of bounds, leave transparent
                }

                // Get pixel values (use transparent black for out-of-bounds)
                const tl_idx = if (valid_tl) @as(usize, @intCast(y0)) * src_w +
                    @as(usize, @intCast(x0)) else 0;
                const tr_idx = if (valid_tr) @as(usize, @intCast(y0)) * src_w +
                    @as(usize, @intCast(x1)) else 0;
                const bl_idx = if (valid_bl) @as(usize, @intCast(y1)) * src_w +
                    @as(usize, @intCast(x0)) else 0;
                const br_idx = if (valid_br) @as(usize, @intCast(y1)) * src_w +
                    @as(usize, @intCast(x1)) else 0;

                const tl_color = if (valid_tl)
                    src_colors[tl_idx]
                else
                    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };
                const tr_color = if (valid_tr)
                    src_colors[tr_idx]
                else
                    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };
                const bl_color = if (valid_bl)
                    src_colors[bl_idx]
                else
                    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };
                const br_color = if (valid_br)
                    src_colors[br_idx]
                else
                    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };

                const tl_alpha = if (valid_tl) src_shadow[tl_idx] else 0;
                const tr_alpha = if (valid_tr) src_shadow[tr_idx] else 0;
                const bl_alpha = if (valid_bl) src_shadow[bl_idx] else 0;
                const br_alpha = if (valid_br) src_shadow[br_idx] else 0;

                // Bilinear interpolation
                const w_tl = (1.0 - fx) * (1.0 - fy);
                const w_tr = fx * (1.0 - fy);
                const w_bl = (1.0 - fx) * fy;
                const w_br = fx * fy;

                const r = @as(u8, @intFromFloat(std.math.clamp(
                    @as(f32, @floatFromInt(tl_color.r)) * w_tl +
                        @as(f32, @floatFromInt(tr_color.r)) * w_tr +
                        @as(f32, @floatFromInt(bl_color.r)) * w_bl +
                        @as(f32, @floatFromInt(br_color.r)) * w_br,
                    0.0,
                    255.0,
                )));
                const g = @as(u8, @intFromFloat(std.math.clamp(
                    @as(f32, @floatFromInt(tl_color.g)) * w_tl +
                        @as(f32, @floatFromInt(tr_color.g)) * w_tr +
                        @as(f32, @floatFromInt(bl_color.g)) * w_bl +
                        @as(f32, @floatFromInt(br_color.g)) * w_br,
                    0.0,
                    255.0,
                )));
                const b = @as(u8, @intFromFloat(std.math.clamp(
                    @as(f32, @floatFromInt(tl_color.b)) * w_tl +
                        @as(f32, @floatFromInt(tr_color.b)) * w_tr +
                        @as(f32, @floatFromInt(bl_color.b)) * w_bl +
                        @as(f32, @floatFromInt(br_color.b)) * w_br,
                    0.0,
                    255.0,
                )));
                const alpha = @as(u8, @intFromFloat(std.math.clamp(
                    @as(f32, @floatFromInt(tl_alpha)) * w_tl +
                        @as(f32, @floatFromInt(tr_alpha)) * w_tr +
                        @as(f32, @floatFromInt(bl_alpha)) * w_bl +
                        @as(f32, @floatFromInt(br_alpha)) * w_br,
                    0.0,
                    255.0,
                )));

                const dst_idx = dy * dst_w + dx;
                dst_colors[dst_idx] = .{ .r = r, .g = g, .b = b };
                dst_shadow[dst_idx] = alpha;
            }
        }
    }

    pub fn print(self: *RenderSurface) !void {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
        const stdout = &stdout_writer.interface;
        // give space for image rendering
        const h = self.h / 2;
        for (0..h) |_| {
            try stdout.print("\n", .{});
        }
        movy.terminal.cursorUp(@as(i32, @intCast(h)));

        // print image
        const str = try self.toAnsi();
        try stdout.print("{s}\n", .{str});
    }

    /// Scales the RenderSurface to new dimensions, reallocating all buffers
    /// Resizes the surface and updates w, h to the new dimensions
    /// Text overlay (char_map) is cleared as text cannot be meaningfully scaled
    ///
    /// **When to use:**
    /// - Permanently resize a surface to new dimensions
    /// - Load large images and scale them down for display
    /// - Prepare assets at specific sizes for rendering
    pub fn scale(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        target_w: usize,
        target_h: usize,
        algorithm: ScaleAlgorithm,
    ) !void {
        // Early return if dimensions unchanged
        if (target_w == self.w and target_h == self.h) return;

        if (target_w == 0 or target_h == 0) return error.InvalidDimensions;

        // Allocate temporary buffers for scaled content
        const new_color_map =
            try allocator.alloc(movy.core.types.Rgb, target_w * target_h);
        errdefer allocator.free(new_color_map);

        const new_shadow_map = try allocator.alloc(u8, target_w * target_h);
        errdefer allocator.free(new_shadow_map);

        // Apply scaling algorithm
        switch (algorithm) {
            .none => scaleNone(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                target_w,
                target_h,
            ),
            .nearest_neighbor => scaleNearestNeighbor(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                target_w,
                target_h,
            ),
            .bilinear => scaleBilinear(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                target_w,
                target_h,
            ),
            .bicubic => scaleBicubic(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                target_w,
                target_h,
            ),
        }

        // Allocate new char_map (cleared)
        const new_char_map = try allocator.alloc(u21, target_w * target_h);
        errdefer allocator.free(new_char_map);
        @memset(new_char_map, 0);

        // Reallocate rendered_str if needed
        const new_rendered_str_size = target_w * target_h * ansi_bytes_per_pixel;
        var new_rendered_str = self.rendered_str;
        if (self.rendered_str.len < new_rendered_str_size) {
            new_rendered_str = try allocator.alloc(u8, new_rendered_str_size);
            errdefer allocator.free(new_rendered_str);
            allocator.free(self.rendered_str);
        }

        // Free old buffers
        allocator.free(self.color_map);
        allocator.free(self.shadow_map);
        allocator.free(self.char_map);

        // Swap in new buffers
        self.color_map = new_color_map;
        self.shadow_map = new_shadow_map;
        self.char_map = new_char_map;
        self.rendered_str = new_rendered_str;

        // Update dimensions
        self.w = target_w;
        self.h = target_h;
    }

    /// Scales content in-place without resizing the surface itself
    /// Scales current content to target dimensions and positions it centered at
    /// (center_x, center_y). Areas outside scaled region become transparent.
    /// Text overlay (char_map) is cleared.
    ///
    /// **When to use:**
    /// - Zoom animations where surface position/size is fixed
    /// - Real-time scaling effects in games
    /// - Scale sprites within a fixed canvas
    pub fn scaleInPlace(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
        center_x: usize,
        center_y: usize,
        mode: ScaleMode,
        algorithm: ScaleAlgorithm,
    ) !void {
        // Early return if dimensions unchanged
        if (w == self.w and h == self.h) return;

        if (w == 0 or h == 0) return error.InvalidDimensions;

        // Handle autoenlarge mode if needed
        if (mode == .autoenlarge and (w > self.w or h > self.h)) {
            const new_w = @max(w, self.w);
            const new_h = @max(h, self.h);
            try self.resize(allocator, new_w, new_h);
        }

        // Calculate actual dimensions (may be clipped)
        const actual_w = @min(w, self.w);
        const actual_h = @min(h, self.h);

        // Allocate temporary buffers for scaled content
        const temp_color_map = try allocator.alloc(
            movy.core.types.Rgb,
            actual_w * actual_h,
        );
        defer allocator.free(temp_color_map);

        const temp_shadow_map = try allocator.alloc(u8, actual_w * actual_h);
        defer allocator.free(temp_shadow_map);

        // Apply scaling algorithm
        switch (algorithm) {
            .none => scaleNone(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                temp_color_map,
                temp_shadow_map,
                actual_w,
                actual_h,
            ),
            .nearest_neighbor => scaleNearestNeighbor(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                temp_color_map,
                temp_shadow_map,
                actual_w,
                actual_h,
            ),
            .bilinear => scaleBilinear(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                temp_color_map,
                temp_shadow_map,
                actual_w,
                actual_h,
            ),
            .bicubic => scaleBicubic(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                temp_color_map,
                temp_shadow_map,
                actual_w,
                actual_h,
            ),
        }

        // Clear surface to transparent
        self.clearTransparent();

        // Calculate top-left position to center the scaled content
        const half_w = actual_w / 2;
        const half_h = actual_h / 2;
        const start_x = if (center_x >= half_w) center_x - half_w else 0;
        const start_y = if (center_y >= half_h) center_y - half_h else 0;

        // Blit scaled content to surface at centered position
        for (0..actual_h) |y| {
            const dst_y = start_y + y;
            if (dst_y >= self.h) break;

            for (0..actual_w) |x| {
                const dst_x = start_x + x;
                if (dst_x >= self.w) break;

                const src_idx = y * actual_w + x;
                const dst_idx = dst_y * self.w + dst_x;

                self.color_map[dst_idx] = temp_color_map[src_idx];
                self.shadow_map[dst_idx] = temp_shadow_map[src_idx];
            }
        }

        // Reallocate rendered_str if surface was enlarged
        const needed_size = self.w * self.h * ansi_bytes_per_pixel;
        if (self.rendered_str.len < needed_size) {
            const new_rendered_str = try allocator.alloc(u8, needed_size);
            allocator.free(self.rendered_str);
            self.rendered_str = new_rendered_str;
        }
    }

    /// Convenience wrapper for scaleInPlace that centers at (w/2, h/2)
    ///
    /// **When to use:**
    /// - Scale content and center it in the surface automatically
    /// - Common case where you don't need custom center positioning
    pub fn scaleInPlaceCentered(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
        mode: ScaleMode,
        algorithm: ScaleAlgorithm,
    ) !void {
        try self.scaleInPlace(
            allocator,
            w,
            h,
            self.w / 2,
            self.h / 2,
            mode,
            algorithm,
        );
    }

    /// Loads a PNG file and scales it to target dimensions in one operation
    ///
    /// **When to use:**
    /// - Load and scale images in a single call
    /// - Prepare assets at specific sizes during initialization
    pub fn createFromPngScaled(
        allocator: std.mem.Allocator,
        file_path: []const u8,
        target_w: usize,
        target_h: usize,
        algorithm: ScaleAlgorithm,
    ) !*RenderSurface {
        const surface = try createFromPng(allocator, file_path);
        errdefer surface.deinit(allocator);
        try surface.scale(allocator, target_w, target_h, algorithm);
        return surface;
    }

    /// Scales surface by a factor, preserving aspect ratio
    /// Factor of 1.0 = original size, 2.0 = double size, 0.5 = half size
    ///
    /// **When to use:**
    /// - Proportional scaling where you want to maintain aspect ratio
    /// - Zoom effects specified as percentages or multiples
    pub fn scaleByFactor(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        factor: f32,
        algorithm: ScaleAlgorithm,
    ) !void {
        const new_w =
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.w)) * factor));
        const new_h =
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.h)) * factor));
        try self.scale(allocator, new_w, new_h, algorithm);
    }

    /// Scales surface in-place by a factor with custom center positioning
    ///
    /// **When to use:**
    /// - Proportional zoom animations with custom center point
    /// - Scale around a specific focal point
    pub fn scaleInPlaceByFactor(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        factor: f32,
        center_x: usize,
        center_y: usize,
        mode: ScaleMode,
        algorithm: ScaleAlgorithm,
    ) !void {
        const new_w =
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.w)) * factor));
        const new_h =
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.h)) * factor));
        try self.scaleInPlace(
            allocator,
            new_w,
            new_h,
            center_x,
            center_y,
            mode,
            algorithm,
        );
    }

    /// Scales surface in-place by a factor, automatically centered
    ///
    /// **When to use:**
    /// - Proportional zoom animations centered in the surface
    /// - Pulse/breathing effects on sprites
    pub fn scaleInPlaceByFactorCentered(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        factor: f32,
        mode: ScaleMode,
        algorithm: ScaleAlgorithm,
    ) !void {
        const new_w =
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.w)) * factor));
        const new_h =
            @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.h)) * factor));
        try self.scaleInPlaceCentered(allocator, new_w, new_h, mode, algorithm);
    }

    // -- Rotation Functions

    /// Rotates the RenderSurface by angle (radians), reallocating buffers
    /// Expands surface dimensions to fit entire rotated image
    /// Text overlay (char_map) is cleared as text cannot be meaningfully rotated
    ///
    /// **When to use:**
    /// - Permanently rotate a surface to a new orientation
    /// - Prepare rotated assets during initialization
    /// - Pre-rotate sprites for different viewing angles
    pub fn rotate(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        angle_radians: f32,
        algorithm: RotateAlgorithm,
    ) !void {
        // Calculate new dimensions to fit rotated image
        const new_bounds = calculateRotatedBounds(self.w, self.h, angle_radians);

        // Allocate temporary buffers for rotated content
        const new_color_map =
            try allocator.alloc(movy.core.types.Rgb, new_bounds.w * new_bounds.h);
        errdefer allocator.free(new_color_map);

        const new_shadow_map = try allocator.alloc(u8, new_bounds.w * new_bounds.h);
        errdefer allocator.free(new_shadow_map);

        // Initialize with transparent black
        @memset(new_color_map, movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 });
        @memset(new_shadow_map, 0);

        // Rotate using selected algorithm
        const src_cx = @as(f32, @floatFromInt(self.w)) / 2.0;
        const src_cy = @as(f32, @floatFromInt(self.h)) / 2.0;

        switch (algorithm) {
            .nearest_neighbor => rotateNearestNeighbor(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                new_bounds.w,
                new_bounds.h,
                angle_radians,
                src_cx,
                src_cy,
            ),
            .bilinear => rotateBilinear(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                new_bounds.w,
                new_bounds.h,
                angle_radians,
                src_cx,
                src_cy,
            ),
        }

        // Free old buffers
        allocator.free(self.color_map);
        allocator.free(self.shadow_map);

        // Update to new buffers and dimensions
        self.color_map = new_color_map;
        self.shadow_map = new_shadow_map;
        self.w = new_bounds.w;
        self.h = new_bounds.h;

        // Reallocate char_map for new dimensions
        const new_char_map = try allocator.alloc(u21, new_bounds.w * new_bounds.h);
        @memset(new_char_map, 0);
        allocator.free(self.char_map);
        self.char_map = new_char_map;

        // Reallocate rendered_str if needed
        const needed_size = new_bounds.w * new_bounds.h * ansi_bytes_per_pixel;
        if (self.rendered_str.len < needed_size) {
            allocator.free(self.rendered_str);
            self.rendered_str = try allocator.alloc(u8, needed_size);
        }
    }

    /// Rotates content in-place without resizing the surface
    /// Rotates around custom center point, areas outside become transparent
    /// Text overlay (char_map) is cleared
    ///
    /// **When to use:**
    /// - Rotation animations where surface position/size is fixed
    /// - Real-time rotation effects in games
    /// - Rotate sprites within a fixed canvas
    pub fn rotateInPlace(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        angle_radians: f32,
        center_x: usize,
        center_y: usize,
        mode: RotateMode,
        algorithm: RotateAlgorithm,
    ) !void {
        // Determine output dimensions based on mode
        var output_bounds = calculateRotatedBounds(self.w, self.h, angle_radians);
        if (mode == .clip) {
            output_bounds.w = self.w;
            output_bounds.h = self.h;
        }

        // Allocate temporary buffers
        const new_color_map = try allocator.alloc(
            movy.core.types.Rgb,
            output_bounds.w * output_bounds.h,
        );
        errdefer allocator.free(new_color_map);

        const new_shadow_map = try allocator.alloc(
            u8,
            output_bounds.w * output_bounds.h,
        );
        errdefer allocator.free(new_shadow_map);

        // Initialize with transparent black
        @memset(new_color_map, movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 });
        @memset(new_shadow_map, 0);

        // Rotate using selected algorithm
        const src_cx = @as(f32, @floatFromInt(center_x));
        const src_cy = @as(f32, @floatFromInt(center_y));

        switch (algorithm) {
            .nearest_neighbor => rotateNearestNeighbor(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                output_bounds.w,
                output_bounds.h,
                angle_radians,
                src_cx,
                src_cy,
            ),
            .bilinear => rotateBilinear(
                self.color_map,
                self.shadow_map,
                self.w,
                self.h,
                new_color_map,
                new_shadow_map,
                output_bounds.w,
                output_bounds.h,
                angle_radians,
                src_cx,
                src_cy,
            ),
        }

        // Free old buffers if dimensions changed
        if (output_bounds.w != self.w or output_bounds.h != self.h) {
            allocator.free(self.color_map);
            allocator.free(self.shadow_map);
            self.color_map = new_color_map;
            self.shadow_map = new_shadow_map;
            self.w = output_bounds.w;
            self.h = output_bounds.h;

            // Reallocate char_map for new dimensions
            const new_char_map = try allocator.alloc(
                u21,
                output_bounds.w * output_bounds.h,
            );
            @memset(new_char_map, 0);
            allocator.free(self.char_map);
            self.char_map = new_char_map;

            // Reallocate rendered_str if needed
            const needed_size = output_bounds.w * output_bounds.h *
                ansi_bytes_per_pixel;
            if (self.rendered_str.len < needed_size) {
                allocator.free(self.rendered_str);
                self.rendered_str = try allocator.alloc(u8, needed_size);
            }
        } else {
            // Same dimensions, just copy data
            @memcpy(self.color_map, new_color_map);
            @memcpy(self.shadow_map, new_shadow_map);
            allocator.free(new_color_map);
            allocator.free(new_shadow_map);

            // Clear char_map
            @memset(self.char_map, 0);
        }
    }

    /// Convenience wrapper that centers rotation at (w/2, h/2)
    ///
    /// **When to use:**
    /// - Rotate content and center it automatically
    /// - Common case where you don't need custom center positioning
    pub fn rotateInPlaceCentered(
        self: *RenderSurface,
        allocator: std.mem.Allocator,
        angle_radians: f32,
        mode: RotateMode,
        algorithm: RotateAlgorithm,
    ) !void {
        try self.rotateInPlace(
            allocator,
            angle_radians,
            self.w / 2,
            self.h / 2,
            mode,
            algorithm,
        );
    }

    /// Loads a PNG file and rotates it to angle in one operation
    ///
    /// **When to use:**
    /// - Load and rotate images in a single call
    /// - Prepare rotated assets during initialization
    pub fn createFromPngRotated(
        allocator: std.mem.Allocator,
        file_path: []const u8,
        angle_radians: f32,
        algorithm: RotateAlgorithm,
    ) !*RenderSurface {
        var surface = try RenderSurface.createFromPng(allocator, file_path);
        errdefer surface.deinit(allocator);

        try surface.rotate(allocator, angle_radians, algorithm);
        return surface;
    }
};

// Tests

test "RenderSurface.scale - basic upscaling" {
    const allocator = std.testing.allocator;

    var surface =
        try RenderSurface.init(allocator, 10, 10, .{ .r = 255, .g = 0, .b = 0 });
    defer surface.deinit(allocator);

    try surface.scale(allocator, 20, 20, .nearest_neighbor);
    try std.testing.expectEqual(@as(usize, 20), surface.w);
    try std.testing.expectEqual(@as(usize, 20), surface.h);
}

test "RenderSurface.scale - basic downscaling" {
    const allocator = std.testing.allocator;

    var surface =
        try RenderSurface.init(allocator, 20, 20, .{ .r = 0, .g = 255, .b = 0 });
    defer surface.deinit(allocator);

    try surface.scale(allocator, 10, 10, .bilinear);
    try std.testing.expectEqual(@as(usize, 10), surface.w);
    try std.testing.expectEqual(@as(usize, 10), surface.h);
}

test "RenderSurface.scale - no-op when dimensions unchanged" {
    const allocator = std.testing.allocator;

    var surface =
        try RenderSurface.init(allocator, 10, 10, .{ .r = 100, .g = 100, .b = 100 });
    defer surface.deinit(allocator);

    const original_ptr = surface.color_map.ptr;
    try surface.scale(allocator, 10, 10, .nearest_neighbor);

    // Should early return without reallocating
    try std.testing.expectEqual(original_ptr, surface.color_map.ptr);
    try std.testing.expectEqual(@as(usize, 10), surface.w);
    try std.testing.expectEqual(@as(usize, 10), surface.h);
}

test "RenderSurface.scale - all algorithms execute" {
    const allocator = std.testing.allocator;

    const algorithms = [_]ScaleAlgorithm{
        .none,
        .nearest_neighbor,
        .bilinear,
        .bicubic,
    };

    for (algorithms) |algo| {
        var surface = try RenderSurface.init(allocator, 10, 10, .{
            .r = 200,
            .g = 150,
            .b = 100,
        });
        defer surface.deinit(allocator);

        try surface.scale(allocator, 5, 5, algo);
        try std.testing.expectEqual(@as(usize, 5), surface.w);
        try std.testing.expectEqual(@as(usize, 5), surface.h);
    }
}

test "RenderSurface.scale - char_map cleared after scaling" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 10, 10, .{
        .r = 255,
        .g = 255,
        .b = 255,
    });
    defer surface.deinit(allocator);

    // Add some characters
    surface.char_map[0] = 'A';
    surface.char_map[5] = 'B';

    try surface.scale(allocator, 20, 20, .nearest_neighbor);

    // Check all chars are cleared
    for (surface.char_map) |ch| {
        try std.testing.expectEqual(@as(u21, 0), ch);
    }
}

test "RenderSurface.scaleInPlace - basic operation" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 100, 100, .{
        .r = 255,
        .g = 0,
        .b = 0,
    });
    defer surface.deinit(allocator);

    try surface.scaleInPlace(
        allocator,
        50,
        50,
        50,
        50,
        .clip,
        .nearest_neighbor,
    );

    // Surface dimensions should not change
    try std.testing.expectEqual(@as(usize, 100), surface.w);
    try std.testing.expectEqual(@as(usize, 100), surface.h);
}

test "RenderSurface.scaleInPlace - autoenlarge mode" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 50, 50, .{
        .r = 0,
        .g = 255,
        .b = 0,
    });
    defer surface.deinit(allocator);

    try surface.scaleInPlace(
        allocator,
        80,
        80,
        40,
        40,
        .autoenlarge,
        .nearest_neighbor,
    );

    // Surface should have been enlarged
    try std.testing.expectEqual(@as(usize, 80), surface.w);
    try std.testing.expectEqual(@as(usize, 80), surface.h);
}

test "RenderSurface.scaleInPlace - clip mode" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 50, 50, .{
        .r = 0,
        .g = 0,
        .b = 255,
    });
    defer surface.deinit(allocator);

    // Try to scale larger than surface, should clip
    try surface.scaleInPlace(
        allocator,
        80,
        80,
        25,
        25,
        .clip,
        .nearest_neighbor,
    );

    // Surface dimensions should not change
    try std.testing.expectEqual(@as(usize, 50), surface.w);
    try std.testing.expectEqual(@as(usize, 50), surface.h);
}

test "RenderSurface.scaleInPlaceCentered - convenience wrapper" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 100, 100, .{
        .r = 128,
        .g = 128,
        .b = 128,
    });
    defer surface.deinit(allocator);

    try surface.scaleInPlaceCentered(allocator, 50, 50, .clip, .bilinear);

    try std.testing.expectEqual(@as(usize, 100), surface.w);
    try std.testing.expectEqual(@as(usize, 100), surface.h);
}

test "RenderSurface.scaleByFactor - double size" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 10, 10, .{
        .r = 255,
        .g = 255,
        .b = 255,
    });
    defer surface.deinit(allocator);

    try surface.scaleByFactor(allocator, 2.0, .nearest_neighbor);

    try std.testing.expectEqual(@as(usize, 20), surface.w);
    try std.testing.expectEqual(@as(usize, 20), surface.h);
}

test "RenderSurface.scaleByFactor - half size" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 20, 20, .{
        .r = 100,
        .g = 100,
        .b = 100,
    });
    defer surface.deinit(allocator);

    try surface.scaleByFactor(allocator, 0.5, .bilinear);

    try std.testing.expectEqual(@as(usize, 10), surface.w);
    try std.testing.expectEqual(@as(usize, 10), surface.h);
}

test "RenderSurface.scaleByFactor - no change at 1.0" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 10, 10, .{
        .r = 50,
        .g = 50,
        .b = 50,
    });
    defer surface.deinit(allocator);

    const original_ptr = surface.color_map.ptr;
    try surface.scaleByFactor(allocator, 1.0, .nearest_neighbor);

    // Early return should preserve pointer
    try std.testing.expectEqual(original_ptr, surface.color_map.ptr);
    try std.testing.expectEqual(@as(usize, 10), surface.w);
    try std.testing.expectEqual(@as(usize, 10), surface.h);
}

test "RenderSurface.scaleInPlaceByFactor - basic operation" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 100, 100, .{
        .r = 200,
        .g = 100,
        .b = 50,
    });
    defer surface.deinit(allocator);

    try surface.scaleInPlaceByFactor(allocator, 0.5, 50, 50, .clip, .nearest_neighbor);

    // Surface size unchanged
    try std.testing.expectEqual(@as(usize, 100), surface.w);
    try std.testing.expectEqual(@as(usize, 100), surface.h);
}

test "RenderSurface.scaleInPlaceByFactorCentered - basic operation" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 100, 100, .{
        .r = 150,
        .g = 200,
        .b = 250,
    });
    defer surface.deinit(allocator);

    try surface.scaleInPlaceByFactorCentered(allocator, 0.75, .clip, .bilinear);

    try std.testing.expectEqual(@as(usize, 100), surface.w);
    try std.testing.expectEqual(@as(usize, 100), surface.h);
}

test "RenderSurface.scale - invalid dimensions error" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 10, 10, .{
        .r = 255,
        .g = 255,
        .b = 255,
    });
    defer surface.deinit(allocator);

    try std.testing.expectError(error.InvalidDimensions, surface.scale(
        allocator,
        0,
        10,
        .nearest_neighbor,
    ));
    try std.testing.expectError(error.InvalidDimensions, surface.scale(
        allocator,
        10,
        0,
        .nearest_neighbor,
    ));
}

test "RenderSurface.scaleInPlace - invalid dimensions error" {
    const allocator = std.testing.allocator;

    var surface = try RenderSurface.init(allocator, 10, 10, .{
        .r = 255,
        .g = 255,
        .b = 255,
    });
    defer surface.deinit(allocator);

    try std.testing.expectError(error.InvalidDimensions, surface.scaleInPlace(
        allocator,
        0,
        10,
        5,
        5,
        .clip,
        .nearest_neighbor,
    ));
}
