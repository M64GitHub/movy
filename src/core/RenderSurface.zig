const std = @import("std");
const movy = @import("../movy.zig");

const cimp = @cImport({
    @cInclude("lodepng.h");
});

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

        const ansi_bytes_per_pixel = 45; // Max: ESC[38;2;RRR;GGG;BBBm + UTF-8 char
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

        if (str.len < movy.utils.ansi_parser.ANSI_HEADER.len or !std.mem.eql(
            u8,
            str[0..movy.utils.ansi_parser.ANSI_HEADER.len],
            &movy.utils.ansi_parser.ANSI_HDR,
        )) {
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

        for (0..self.h) |y| {
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
        for (self.color_map, 0..) |*color, i| {
            color.* = c;
            self.shadow_map[i] = 255;
            self.char_map[i] = 0;
        }
    }

    /// Clears the RenderSurface to a fully transparent state with black color.
    /// Sets all color_map pixels to RGB(0,0,0), shadow_map to 0 (transparent),
    /// and char_map to 0 (no characters).
    pub fn clearTransparent(self: *RenderSurface) void {
        const c = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };
        for (0..self.w * self.h) |i| {
            self.color_map[i] = c;
            self.shadow_map[i] = 0;
            self.char_map[i] = 0;
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

        const new_rendered_str = try allocator.alloc(u8, width * height * 50);
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
            self.shadow_map[idx] = 1;
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
            self.shadow_map[idx] = 1;
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
                if (char == '\n') continue; // only when not clipping, on '\n'
            }
            idx = x + y_pixel * self.w;
            if (x < self.w and y_pixel + 1 < self.h) { // Bounds check
                self.char_map[idx] = char;
                self.color_map[idx] = fg_color; // fg at y
                self.color_map[idx + self.w] = bg_color; // bg at y+1
                self.shadow_map[idx] = 1;
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
                if (char == '\n') continue; // only when not clipping, on '\n'
            }
            idx = x + y_pixel * self.w;
            if (x < self.w and y_pixel + 1 < self.h) { // Bounds check
                if (char != ' ') {
                    self.char_map[idx] = char;
                    self.color_map[idx] = fg_color; // fg at y
                    self.color_map[idx + self.w] = bg_color; // bg at y+1
                    self.shadow_map[idx] = 1;
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
                self.shadow_map[map_idx] = 1;
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
        const idx = self.w * @as(usize, @intCast(y)) + @as(usize, @intCast(x));
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

    fn isDoubleWidth(ch: u21) bool {
        return (ch >= 0x1100 and ch <= 0x115F) or
            (ch >= 0x2E80 and ch <= 0xA4CF) or
            (ch >= 0x1F300 and ch <= 0x1F64F); // Emoji & CJK
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
};
