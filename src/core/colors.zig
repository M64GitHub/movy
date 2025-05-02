/// Standard color palette and color utility functions for movy
/// Provides a set of predefined Rgb colors for consistent use across
/// applications.
/// Colors are inspired by Bootstrap 5.0 for balanced, beautiful tones
/// Shades: BRIGHT_LIGHT (100), LIGHT (200), base (500), MEDIUM_DARK (600),
/// DARK (700), DARKER (800)
/// see https://getbootstrap.com/docs/5.0/customize/color/ for reference
const std = @import("std");
const types = @import("types.zig");

pub const Error = error{InvalidColorString};

/// Return a types.Rgb from HMTL color string like "#892f8c", or "892f8c",
/// or an error on invalid input string
pub fn fromHtml(html: []const u8) !types.Rgb {
    var color_str = html;

    if (color_str.len == 7 and color_str[0] == '#') {
        color_str = color_str[1..];
    }

    if (color_str.len != 6) {
        return Error.InvalidColorString;
    }

    const r = try parseHexByte(color_str[0..2]);
    const g = try parseHexByte(color_str[2..4]);
    const b = try parseHexByte(color_str[4..6]);

    return types.Rgb{ .r = r, .g = g, .b = b };
}

// Helper function for fromHtml
fn parseHexByte(slice: []const u8) !u8 {
    return std.fmt.parseUnsigned(u8, slice, 16);
}

/// Brightens the color by adding amount to each channel, clamping at 255.
/// Amount is a value from 0 to 100, treated as a direct increment.
pub fn brighterFast(color: types.Rgb, amount: u8) types.Rgb {
    const r = if (color.r + amount > 255) 255 else color.r + amount;
    const g = if (color.g + amount > 255) 255 else color.g + amount;
    const b = if (color.b + amount > 255) 255 else color.b + amount;
    return types.Rgb{ .r = r, .g = g, .b = b };
}

/// Darkens the color by subtracting amount from each channel, clamping at 0.
/// Amount is a value from 0 to 100, treated as a direct decrement.
pub fn darkerFast(color: types.Rgb, amount: u8) types.Rgb {
    const r = if (color.r < amount) 0 else color.r - amount;
    const g = if (color.g < amount) 0 else color.g - amount;
    const b = if (color.b < amount) 0 else color.b - amount;
    return types.Rgb{ .r = r, .g = g, .b = b };
}

/// Brightens the color by scaling each channel toward 255 based on amount.
/// Amount is a percentage (0-100), where 100 brightens fully to white.
pub fn brighter(color: types.Rgb, amount: u8) types.Rgb {
    const amt = @as(f32, @floatFromInt(amount)) / 100.0; // 0.0 to 1.0
    const r_dist = @as(f32, @floatFromInt(255 - color.r));
    const g_dist = @as(f32, @floatFromInt(255 - color.g));
    const b_dist = @as(f32, @floatFromInt(255 - color.b));
    const r_add = @as(u8, @intFromFloat(r_dist * amt));
    const g_add = @as(u8, @intFromFloat(g_dist * amt));
    const b_add = @as(u8, @intFromFloat(b_dist * amt));
    const r = if (color.r + r_add > 255) 255 else color.r + r_add;
    const g = if (color.g + g_add > 255) 255 else color.g + g_add;
    const b = if (color.b + b_add > 255) 255 else color.b + b_add;
    return types.Rgb{ .r = r, .g = g, .b = b };
}

/// Darkens the color by scaling each channel toward 0 based on amount.
/// Amount is a percentage (0-100), where 100 darkens fully to black.
pub fn darker(color: types.Rgb, amount: u8) types.Rgb {
    const amt = @as(f32, @floatFromInt(amount)) / 100.0; // 0.0 to 1.0
    const r_dist = @as(f32, @floatFromInt(color.r));
    const g_dist = @as(f32, @floatFromInt(color.g));
    const b_dist = @as(f32, @floatFromInt(color.b));
    const r_sub = @as(u8, @intFromFloat(r_dist * amt));
    const g_sub = @as(u8, @intFromFloat(g_dist * amt));
    const b_sub = @as(u8, @intFromFloat(b_dist * amt));
    const r = if (color.r < r_sub) 0 else color.r - r_sub;
    const g = if (color.g < g_sub) 0 else color.g - g_sub;
    const b = if (color.b < b_sub) 0 else color.b - b_sub;
    return types.Rgb{ .r = r, .g = g, .b = b };
}

pub const WHITE = types.Rgb{ .r = 0xff, .g = 0xff, .b = 0xff };
pub const BLACK = types.Rgb{ .r = 0x00, .g = 0x00, .b = 0x00 };
/// Can be useful for effects, that treat 0x00 as empty color
pub const BLACK_4 = types.Rgb{ .r = 0x04, .g = 0x04, .b = 0x04 };

// Blues
pub const BLUE = types.Rgb{ .r = 0x0d, .g = 0x6e, .b = 0xfd }; // Blue-500
pub const BRIGHT_LIGHT_BLUE = types.Rgb{ .r = 0xcf, .g = 0xe2, .b = 0xff }; // Blue-100
pub const LIGHT_BLUE = types.Rgb{ .r = 0x9e, .g = 0xc5, .b = 0xfe }; // Blue-200
pub const MEDIUM_DARK_BLUE = types.Rgb{ .r = 0x0a, .g = 0x58, .b = 0xca }; // Blue-600
pub const DARK_BLUE = types.Rgb{ .r = 0x08, .g = 0x42, .b = 0x98 }; // Blue-700
pub const DARKER_BLUE = types.Rgb{ .r = 0x05, .g = 0x2c, .b = 0x65 }; // Blue-800
pub const BLUE_100 = types.Rgb{ .r = 0xcf, .g = 0xe2, .b = 0xff };
pub const BLUE_200 = types.Rgb{ .r = 0x9e, .g = 0xc5, .b = 0xfe };
pub const BLUE_300 = types.Rgb{ .r = 0x6e, .g = 0xa8, .b = 0xfe };
pub const BLUE_400 = types.Rgb{ .r = 0x3d, .g = 0x8b, .b = 0xfd };
pub const BLUE_500 = types.Rgb{ .r = 0x0d, .g = 0x6e, .b = 0xfd };
pub const BLUE_600 = types.Rgb{ .r = 0x0a, .g = 0x58, .b = 0xca };
pub const BLUE_700 = types.Rgb{ .r = 0x08, .g = 0x42, .b = 0x98 };
pub const BLUE_800 = types.Rgb{ .r = 0x05, .g = 0x2c, .b = 0x65 };
pub const BLUE_900 = types.Rgb{ .r = 0x03, .g = 0x16, .b = 0x33 };

// Indigos
pub const INDIGO = types.Rgb{ .r = 0x66, .g = 0x10, .b = 0xf2 }; // Indigo-500
pub const BRIGHT_LIGHT_INDIGO = types.Rgb{ .r = 0xe0, .g = 0xcf, .b = 0xfc }; // Indigo-100
pub const LIGHT_INDIGO = types.Rgb{ .r = 0xc2, .g = 0x9f, .b = 0xfa }; // Indigo-200
pub const MEDIUM_DARK_INDIGO = types.Rgb{ .r = 0x52, .g = 0x0d, .b = 0xc2 }; // Indigo-600
pub const DARK_INDIGO = types.Rgb{ .r = 0x3d, .g = 0x0a, .b = 0x91 }; // Indigo-700
pub const DARKER_INDIGO = types.Rgb{ .r = 0x29, .g = 0x06, .b = 0x61 }; // Indigo-800
pub const INDIGO_100 = types.Rgb{ .r = 0xe0, .g = 0xcf, .b = 0xfc };
pub const INDIGO_200 = types.Rgb{ .r = 0xc2, .g = 0x9f, .b = 0xfa };
pub const INDIGO_300 = types.Rgb{ .r = 0xa3, .g = 0x70, .b = 0xf7 };
pub const INDIGO_400 = types.Rgb{ .r = 0x85, .g = 0x40, .b = 0xf5 };
pub const INDIGO_500 = types.Rgb{ .r = 0x66, .g = 0x10, .b = 0xf2 };
pub const INDIGO_600 = types.Rgb{ .r = 0x52, .g = 0x0d, .b = 0xc2 };
pub const INDIGO_700 = types.Rgb{ .r = 0x3d, .g = 0x0a, .b = 0x91 };
pub const INDIGO_800 = types.Rgb{ .r = 0x29, .g = 0x06, .b = 0x61 };
pub const INDIGO_900 = types.Rgb{ .r = 0x14, .g = 0x03, .b = 0x30 };

// Purples
pub const PURPLE = types.Rgb{ .r = 0x6f, .g = 0x42, .b = 0xc1 }; // Purple-500
pub const BRIGHT_LIGHT_PURPLE = types.Rgb{ .r = 0xe2, .g = 0xd9, .b = 0xf3 }; // Purple-100
pub const LIGHT_PURPLE = types.Rgb{ .r = 0xc5, .g = 0xb3, .b = 0xe6 }; // Purple-200
pub const MEDIUM_DARK_PURPLE = types.Rgb{ .r = 0x59, .g = 0x35, .b = 0x9a }; // Purple-600
pub const DARK_PURPLE = types.Rgb{ .r = 0x43, .g = 0x28, .b = 0x74 }; // Purple-700
pub const DARKER_PURPLE = types.Rgb{ .r = 0x2c, .g = 0x1a, .b = 0x4d }; // Purple-800
pub const PURPLE_100 = types.Rgb{ .r = 0xe2, .g = 0xd9, .b = 0xf3 };
pub const PURPLE_200 = types.Rgb{ .r = 0xc5, .g = 0xb3, .b = 0xe6 };
pub const PURPLE_300 = types.Rgb{ .r = 0xa9, .g = 0x8e, .b = 0xda };
pub const PURPLE_400 = types.Rgb{ .r = 0x8c, .g = 0x68, .b = 0xcd };
pub const PURPLE_500 = types.Rgb{ .r = 0x6f, .g = 0x42, .b = 0xc1 };
pub const PURPLE_600 = types.Rgb{ .r = 0x59, .g = 0x35, .b = 0x9a };
pub const PURPLE_700 = types.Rgb{ .r = 0x43, .g = 0x28, .b = 0x74 };
pub const PURPLE_800 = types.Rgb{ .r = 0x2c, .g = 0x1a, .b = 0x4d };
pub const PURPLE_900 = types.Rgb{ .r = 0x16, .g = 0x0d, .b = 0x27 };

// Pinks
pub const PINK = types.Rgb{ .r = 0xd6, .g = 0x33, .b = 0x84 }; // Pink-500
pub const BRIGHT_LIGHT_PINK = types.Rgb{ .r = 0xf7, .g = 0xd6, .b = 0xe6 }; // Pink-100
pub const LIGHT_PINK = types.Rgb{ .r = 0xef, .g = 0xad, .b = 0xce }; // Pink-200
pub const MEDIUM_DARK_PINK = types.Rgb{ .r = 0xab, .g = 0x29, .b = 0x6a }; // Pink-600
pub const DARK_PINK = types.Rgb{ .r = 0x80, .g = 0x1f, .b = 0x4f }; // Pink-700
pub const DARKER_PINK = types.Rgb{ .r = 0x55, .g = 0x14, .b = 0x35 }; // Pink-800
pub const PINK_100 = types.Rgb{ .r = 0xf7, .g = 0xd6, .b = 0xe6 };
pub const PINK_200 = types.Rgb{ .r = 0xef, .g = 0xad, .b = 0xce };
pub const PINK_300 = types.Rgb{ .r = 0xe6, .g = 0x85, .b = 0xb5 };
pub const PINK_400 = types.Rgb{ .r = 0xde, .g = 0x5c, .b = 0x9d };
pub const PINK_500 = types.Rgb{ .r = 0xd6, .g = 0x33, .b = 0x84 };
pub const PINK_600 = types.Rgb{ .r = 0xab, .g = 0x29, .b = 0x6a };
pub const PINK_700 = types.Rgb{ .r = 0x80, .g = 0x1f, .b = 0x4f };
pub const PINK_800 = types.Rgb{ .r = 0x55, .g = 0x14, .b = 0x35 };
pub const PINK_900 = types.Rgb{ .r = 0x2a, .g = 0x0a, .b = 0x1a };

// Reds
pub const RED = types.Rgb{ .r = 0xdc, .g = 0x35, .b = 0x45 }; // Red-500
pub const BRIGHT_LIGHT_RED = types.Rgb{ .r = 0xf8, .g = 0xd7, .b = 0xda }; // Red-100
pub const LIGHT_RED = types.Rgb{ .r = 0xf1, .g = 0xae, .b = 0xb5 }; // Red-200
pub const MEDIUM_DARK_RED = types.Rgb{ .r = 0xb0, .g = 0x2a, .b = 0x37 }; // Red-600
pub const DARK_RED = types.Rgb{ .r = 0x84, .g = 0x20, .b = 0x29 }; // Red-700
pub const DARKER_RED = types.Rgb{ .r = 0x56, .g = 0x1c, .b = 0x1b }; // Red-800
pub const RED_100 = types.Rgb{ .r = 0xf8, .g = 0xd7, .b = 0xda };
pub const RED_200 = types.Rgb{ .r = 0xf1, .g = 0xae, .b = 0xb5 };
pub const RED_300 = types.Rgb{ .r = 0xea, .g = 0x86, .b = 0x8f };
pub const RED_400 = types.Rgb{ .r = 0xe3, .g = 0x5d, .b = 0x6a };
pub const RED_500 = types.Rgb{ .r = 0xdc, .g = 0x35, .b = 0x45 };
pub const RED_600 = types.Rgb{ .r = 0xb0, .g = 0x2a, .b = 0x37 };
pub const RED_700 = types.Rgb{ .r = 0x84, .g = 0x20, .b = 0x29 };
pub const RED_800 = types.Rgb{ .r = 0x56, .g = 0x1c, .b = 0x1b };
pub const RED_900 = types.Rgb{ .r = 0x2b, .g = 0x0e, .b = 0x0e };

// Oranges
pub const ORANGE = types.Rgb{ .r = 0xfd, .g = 0x7e, .b = 0x14 }; // Orange-500
pub const BRIGHT_LIGHT_ORANGE = types.Rgb{ .r = 0xff, .g = 0xe5, .b = 0xd0 }; // Orange-100
pub const LIGHT_ORANGE = types.Rgb{ .r = 0xff, .g = 0xcb, .b = 0x9f }; // Orange-200
pub const MEDIUM_DARK_ORANGE = types.Rgb{ .r = 0xca, .g = 0x65, .b = 0x10 }; // Orange-600
pub const DARK_ORANGE = types.Rgb{ .r = 0x98, .g = 0x4c, .b = 0x0c }; // Orange-700
pub const DARKER_ORANGE = types.Rgb{ .r = 0x65, .g = 0x32, .b = 0x08 }; // Orange-800
pub const ORANGE_100 = types.Rgb{ .r = 0xff, .g = 0xe5, .b = 0xd0 };
pub const ORANGE_200 = types.Rgb{ .r = 0xff, .g = 0xcb, .b = 0x9f };
pub const ORANGE_300 = types.Rgb{ .r = 0xff, .g = 0xb1, .b = 0x6f };
pub const ORANGE_400 = types.Rgb{ .r = 0xff, .g = 0x97, .b = 0x3e };
pub const ORANGE_500 = types.Rgb{ .r = 0xfd, .g = 0x7e, .b = 0x14 };
pub const ORANGE_600 = types.Rgb{ .r = 0xca, .g = 0x65, .b = 0x10 };
pub const ORANGE_700 = types.Rgb{ .r = 0x98, .g = 0x4c, .b = 0x0c };
pub const ORANGE_800 = types.Rgb{ .r = 0x65, .g = 0x32, .b = 0x08 };
pub const ORANGE_900 = types.Rgb{ .r = 0x32, .g = 0x19, .b = 0x04 };

// Yellows
pub const YELLOW = types.Rgb{ .r = 0xff, .g = 0xc1, .b = 0x07 }; // Yellow-500
pub const BRIGHT_LIGHT_YELLOW = types.Rgb{ .r = 0xff, .g = 0xf3, .b = 0xcd }; // Yellow-100
pub const LIGHT_YELLOW = types.Rgb{ .r = 0xff, .g = 0xe6, .b = 0x9c }; // Yellow-200
pub const MEDIUM_DARK_YELLOW = types.Rgb{ .r = 0xcc, .g = 0x9a, .b = 0x06 }; // Yellow-600
pub const DARK_YELLOW = types.Rgb{ .r = 0x99, .g = 0x74, .b = 0x04 }; // Yellow-700
pub const DARKER_YELLOW = types.Rgb{ .r = 0x66, .g = 0x4d, .b = 0x03 }; // Yellow-800
pub const YELLOW_100 = types.Rgb{ .r = 0xff, .g = 0xf3, .b = 0xcd };
pub const YELLOW_200 = types.Rgb{ .r = 0xff, .g = 0xe6, .b = 0x9c };
pub const YELLOW_300 = types.Rgb{ .r = 0xff, .g = 0xda, .b = 0x6a };
pub const YELLOW_400 = types.Rgb{ .r = 0xff, .g = 0xcd, .b = 0x39 };
pub const YELLOW_500 = types.Rgb{ .r = 0xff, .g = 0xc1, .b = 0x07 };
pub const YELLOW_600 = types.Rgb{ .r = 0xcc, .g = 0x9a, .b = 0x06 };
pub const YELLOW_700 = types.Rgb{ .r = 0x99, .g = 0x74, .b = 0x04 };
pub const YELLOW_800 = types.Rgb{ .r = 0x66, .g = 0x4d, .b = 0x03 };
pub const YELLOW_900 = types.Rgb{ .r = 0x33, .g = 0x27, .b = 0x01 };

// Greens
pub const GREEN = types.Rgb{ .r = 0x19, .g = 0x87, .b = 0x54 }; // Green-500
pub const BRIGHT_LIGHT_GREEN = types.Rgb{ .r = 0xd1, .g = 0xe7, .b = 0xdd }; // Green-100
pub const LIGHT_GREEN = types.Rgb{ .r = 0xa3, .g = 0xcf, .b = 0xbb }; // Green-200
pub const MEDIUM_DARK_GREEN = types.Rgb{ .r = 0x14, .g = 0x6c, .b = 0x43 }; // Green-600
pub const DARK_GREEN = types.Rgb{ .r = 0x0f, .g = 0x51, .b = 0x32 }; // Green-700
pub const DARKER_GREEN = types.Rgb{ .r = 0x0a, .g = 0x36, .b = 0x22 }; // Green-800
pub const GREEN_100 = types.Rgb{ .r = 0xd1, .g = 0xe7, .b = 0xdd };
pub const GREEN_200 = types.Rgb{ .r = 0xa3, .g = 0xcf, .b = 0xbb };
pub const GREEN_300 = types.Rgb{ .r = 0x75, .g = 0xb7, .b = 0x98 };
pub const GREEN_400 = types.Rgb{ .r = 0x47, .g = 0x9f, .b = 0x76 };
pub const GREEN_500 = types.Rgb{ .r = 0x19, .g = 0x87, .b = 0x54 };
pub const GREEN_600 = types.Rgb{ .r = 0x14, .g = 0x6c, .b = 0x43 };
pub const GREEN_700 = types.Rgb{ .r = 0x0f, .g = 0x51, .b = 0x32 };
pub const GREEN_800 = types.Rgb{ .r = 0x0a, .g = 0x36, .b = 0x22 };
pub const GREEN_900 = types.Rgb{ .r = 0x05, .g = 0x1b, .b = 0x11 };

// Teals
pub const TEAL = types.Rgb{ .r = 0x20, .g = 0xc9, .b = 0x97 }; // Teal-500
pub const BRIGHT_LIGHT_TEAL = types.Rgb{ .r = 0xd2, .g = 0xf4, .b = 0xea }; // Teal-100
pub const LIGHT_TEAL = types.Rgb{ .r = 0xa6, .g = 0xe9, .b = 0xd5 }; // Teal-200
pub const MEDIUM_DARK_TEAL = types.Rgb{ .r = 0x1a, .g = 0xa1, .b = 0x79 }; // Teal-600
pub const DARK_TEAL = types.Rgb{ .r = 0x13, .g = 0x79, .b = 0x5b }; // Teal-700
pub const DARKER_TEAL = types.Rgb{ .r = 0x0d, .g = 0x50, .b = 0x3c }; // Teal-800
pub const TEAL_100 = types.Rgb{ .r = 0xd2, .g = 0xf4, .b = 0xea };
pub const TEAL_200 = types.Rgb{ .r = 0xa6, .g = 0xe9, .b = 0xd5 };
pub const TEAL_300 = types.Rgb{ .r = 0x79, .g = 0xdf, .b = 0xc1 };
pub const TEAL_400 = types.Rgb{ .r = 0x4d, .g = 0xd4, .b = 0xac };
pub const TEAL_500 = types.Rgb{ .r = 0x20, .g = 0xc9, .b = 0x97 };
pub const TEAL_600 = types.Rgb{ .r = 0x1a, .g = 0xa1, .b = 0x79 };
pub const TEAL_700 = types.Rgb{ .r = 0x13, .g = 0x79, .b = 0x5b };
pub const TEAL_800 = types.Rgb{ .r = 0x0d, .g = 0x50, .b = 0x3c };
pub const TEAL_900 = types.Rgb{ .r = 0x06, .g = 0x28, .b = 0x1e };

// Cyans
pub const CYAN = types.Rgb{ .r = 0x0d, .g = 0xca, .b = 0xf0 }; // Cyan-500
pub const BRIGHT_LIGHT_CYAN = types.Rgb{ .r = 0xcf, .g = 0xf4, .b = 0xfc }; // Cyan-100
pub const LIGHT_CYAN = types.Rgb{ .r = 0x9e, .g = 0xea, .b = 0xf9 }; // Cyan-200
pub const MEDIUM_DARK_CYAN = types.Rgb{ .r = 0x0a, .g = 0xa2, .b = 0xc0 }; // Cyan-600
pub const DARK_CYAN = types.Rgb{ .r = 0x08, .g = 0x79, .b = 0x90 }; // Cyan-700
pub const DARKER_CYAN = types.Rgb{ .r = 0x05, .g = 0x51, .b = 0x60 }; // Cyan-800
pub const CYAN_100 = types.Rgb{ .r = 0xcf, .g = 0xf4, .b = 0xfc };
pub const CYAN_200 = types.Rgb{ .r = 0x9e, .g = 0xea, .b = 0xf9 };
pub const CYAN_300 = types.Rgb{ .r = 0x6d, .g = 0xdc, .b = 0xf7 };
pub const CYAN_400 = types.Rgb{ .r = 0x3d, .g = 0xcb, .b = 0xf5 };
pub const CYAN_500 = types.Rgb{ .r = 0x0d, .g = 0xca, .b = 0xf0 };
pub const CYAN_600 = types.Rgb{ .r = 0x0a, .g = 0xa2, .b = 0xc0 };
pub const CYAN_700 = types.Rgb{ .r = 0x08, .g = 0x79, .b = 0x90 };
pub const CYAN_800 = types.Rgb{ .r = 0x05, .g = 0x51, .b = 0x60 };
pub const CYAN_900 = types.Rgb{ .r = 0x03, .g = 0x28, .b = 0x30 };

// Grays
pub const GRAY = types.Rgb{ .r = 0x6c, .g = 0x75, .b = 0x7d }; // Gray-600
pub const BRIGHT_LIGHT_GRAY = types.Rgb{ .r = 0xf8, .g = 0xf9, .b = 0xfa }; // Gray-100
pub const LIGHT_GRAY = types.Rgb{ .r = 0xe9, .g = 0xec, .b = 0xef }; // Gray-200
pub const MEDIUM_DARK_GRAY = types.Rgb{ .r = 0x6c, .g = 0x75, .b = 0x7d }; // Gray-600 (same as base)
pub const DARK_GRAY = types.Rgb{ .r = 0x49, .g = 0x50, .b = 0x57 }; // Gray-700
pub const DARKER_GRAY = types.Rgb{ .r = 0x34, .g = 0x3a, .b = 0x40 }; // Gray-800
pub const GRAY_100 = types.Rgb{ .r = 0xf8, .g = 0xf9, .b = 0xfa };
pub const GRAY_200 = types.Rgb{ .r = 0xe9, .g = 0xec, .b = 0xef };
pub const GRAY_300 = types.Rgb{ .r = 0xde, .g = 0xe2, .b = 0xe6 };
pub const GRAY_400 = types.Rgb{ .r = 0xce, .g = 0xd4, .b = 0xda };
pub const GRAY_500 = types.Rgb{ .r = 0xad, .g = 0xb5, .b = 0xbd };
pub const GRAY_600 = types.Rgb{ .r = 0x6c, .g = 0x75, .b = 0x7d };
pub const GRAY_700 = types.Rgb{ .r = 0x49, .g = 0x50, .b = 0x57 };
pub const GRAY_800 = types.Rgb{ .r = 0x34, .g = 0x3a, .b = 0x40 };
pub const GRAY_900 = types.Rgb{ .r = 0x21, .g = 0x25, .b = 0x29 };
