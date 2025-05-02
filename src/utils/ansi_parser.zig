const std = @import("std");
const movy = @import("../movy.zig");
const stdout = std.io.getStdOut().writer();

// ANSI sequences for parsing input from catimg

/// ANSI header sequence to prepare terminal rendering.
/// Saves the cursor position (\x1b[s) and hides the cursor (\x1b[?25l) for
/// clean rendering.
pub const ANSI_HEADER = [_]u8{
    0x1b, 0x5b, 0x73, // \x1b[s: Save cursor position
    0x1b, 0x5b, 0x3f, 0x32, 0x35, 0x6c, // \x1b[?25l: Hide cursor
};

/// ANSI sequence to end a terminal render line.
/// Resets all attributes (\x1b[m) and moves to the next line (\n).
pub const ANSI_LINE_END = [_]u8{
    0x1b, 0x5b, 0x6d, // \x1b[m: Reset all attributes
    0x0a, // \n: Newline
};

/// ANSI sequence to finalize terminal rendering.
/// Shows the cursor (\x1b[?25h) to restore normal terminal interaction.
pub const ANSI_FILE_END = [_]u8{
    0x1b, 0x5b, 0x3f, 0x32, 0x35, 0x68, // \x1b[?25h: Show cursor
};

/// Result for parseAnsiPixel: returns the block type, it's colors,
/// and the new position in the buffer after the pixel data.
/// valid will be false, if no pixel data was found
pub const ParseResult = struct {
    upper: movy.core.types.Rgb,
    lower: movy.core.types.Rgb,
    block_type: enum { double, upper, lower, space },
    new_pos: usize,
    valid: bool,
};

/// Parses an ANSI pixel from a string at the given position,
/// returning the result
pub fn parseAnsiPixel(str: [:0]const u8, pos: usize) !ParseResult {
    if (pos + 3 >= str.len) return ParseResult{
        .upper = .{ .r = 0xF0, .g = 0x20, .b = 0x20 },
        .lower = .{ .r = 0xF0, .g = 0x20, .b = 0x20 },
        .block_type = .space,
        .new_pos = pos,
        .valid = false,
    };

    const trans = movy.core.types.Rgb{ .r = 0xF0, .g = 0x20, .b = 0x20 };

    if (std.mem.startsWith(u8, str[pos..], "\x1b[m ") and pos + 4 <= str.len) {
        return ParseResult{
            .upper = trans,
            .lower = trans,
            .block_type = .space,
            .new_pos = pos + 4,
            .valid = true,
        };
    }

    if (pos + 7 < str.len and
        std.mem.startsWith(u8, str[pos..], "\x1b[48;2;"))
    {
        var idx = pos + 7;
        var r1: u8 = 0;
        var g1: u8 = 0;
        var b1: u8 = 0;
        var r2: u8 = 0;
        var g2: u8 = 0;
        var b2: u8 = 0;
        var num_start = idx;
        var num_count: usize = 0;

        while (idx < str.len and str[idx] != 'm') : (idx += 1) {
            if (str[idx] == ';') {
                const slice = str[num_start..idx];
                if (num_count == 0) r1 = try std.fmt.parseInt(u8, slice, 10);
                if (num_count == 1) g1 = try std.fmt.parseInt(u8, slice, 10);
                num_start = idx + 1;
                num_count += 1;
            }
        }
        if (num_count == 2 and idx + 8 < str.len and str[idx] == 'm' and
            std.mem.startsWith(u8, str[idx + 1 ..], "\x1b[38;2;"))
        {
            b1 = try std.fmt.parseInt(u8, str[num_start..idx], 10);
            idx += 8;
            num_start = idx;
            num_count = 0;

            while (idx < str.len and str[idx] != 'm') : (idx += 1) {
                if (str[idx] == ';') {
                    const slice = str[num_start..idx];
                    if (num_count == 0) r2 =
                        try std.fmt.parseInt(u8, slice, 10);
                    if (num_count == 1) g2 =
                        try std.fmt.parseInt(u8, slice, 10);
                    num_start = idx + 1;
                    num_count += 1;
                }
            }
            if (num_count == 2 and idx + 3 < str.len and str[idx] == 'm' and
                std.mem.startsWith(u8, str[idx + 1 ..], "\xe2\x96\x84"))
            {
                b2 = try std.fmt.parseInt(u8, str[num_start..idx], 10);
                return ParseResult{
                    .upper = .{ .r = r1, .g = g1, .b = b1 },
                    .lower = .{ .r = r2, .g = g2, .b = b2 },
                    .block_type = .double,
                    .new_pos = idx + 4,
                    .valid = true,
                };
            }
        }
        try stdout.print(
            "[parseAnsiPixel()] ERROR: incomplete double pixel at pos " ++
                "{}, idx = " ++
                "{}, next 20 bytes: " ++
                "{x}\n",
            .{ pos, idx, str[idx..@min(idx + 20, str.len)] },
        );
        return error.InvalidFormat;
    }

    if (pos + 9 < str.len and
        std.mem.startsWith(u8, str[pos..], "\x1b[0;38;2;"))
    {
        var idx = pos + 9;
        var r: u8 = 0;
        var g: u8 = 0;
        var b: u8 = 0;
        var num_start = idx;
        var num_count: usize = 0;

        while (idx < str.len and str[idx] != 'm') : (idx += 1) {
            if (str[idx] == ';') {
                const slice = str[num_start..idx];
                if (num_count == 0) r = try std.fmt.parseInt(u8, slice, 10);
                if (num_count == 1) g = try std.fmt.parseInt(u8, slice, 10);
                num_start = idx + 1;
                num_count += 1;
            }
        }
        if (num_count == 2 and idx < str.len and str[idx] == 'm') {
            b = try std.fmt.parseInt(u8, str[num_start..idx], 10);
            idx += 1;

            var lookahead: usize = 0;
            while (idx + lookahead < str.len and
                !std.mem.startsWith(
                    u8,
                    str[idx + lookahead ..],
                    "\xe2\x96\x84",
                ) and
                !std.mem.startsWith(
                    u8,
                    str[idx + lookahead ..],
                    "\xe2\x96\x80",
                ) and
                lookahead < 25) : (lookahead += 1)
            {}
            if (idx + lookahead + 2 < str.len) {
                if (std.mem.startsWith(
                    u8,
                    str[idx + lookahead ..],
                    "\xe2\x96\x84",
                )) {
                    return ParseResult{
                        .upper = trans,
                        .lower = .{ .r = r, .g = g, .b = b },
                        .block_type = .lower,
                        .new_pos = idx + lookahead + 3,
                        .valid = true,
                    };
                } else if (std.mem.startsWith(
                    u8,
                    str[idx + lookahead ..],
                    "\xe2\x96\x80",
                )) {
                    return ParseResult{
                        .upper = .{ .r = r, .g = g, .b = b },
                        .lower = trans,
                        .block_type = .upper,
                        .new_pos = idx + lookahead + 3,
                        .valid = true,
                    };
                }
            }
        }
        try stdout.print(
            "[parseAnsiPixel()] ERROR: no block char after single pixel at" ++
                " pos {}, idx = {}, next 20 bytes: {x}\n",
            .{ pos, idx, str[idx..@min(idx + 20, str.len)] },
        );
        return error.InvalidFormat;
    }

    try stdout.print(
        "[parseAnsiPixel()] ERROR: no match at pos {}, next 20 bytes: {x}\n",
        .{ pos, str[pos..@min(pos + 20, str.len)] },
    );
    return error.InvalidFormat;
}
