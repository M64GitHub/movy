const std = @import("std");

const c = @cImport({
    @cInclude("termios.h");
    @cInclude("poll.h");
    @cInclude("unistd.h");
});

pub const KeyType = enum {
    Char, // Regular printable char (e.g., 'a', '1')
    Enter, // Enter/Return key (ASCII 13 or \n)
    Escape, // Single ESC key (\x1b)
    CtrlC, // Ctrl+C (ASCII 0x03)
    Up, // Arrow Up (\x1b[A)
    Down, // Arrow Down (\x1b[B)
    Right, // Arrow Right (\x1b[C)
    Left, // Arrow Left (\x1b[D)
    CtrlLeft, // \x1b[1;5D
    CtrlRight, // \x1b[1;5C
    CtrlUp, // \x1b[1;5A
    CtrlDown, // \x1b[1;5B
    CtrlHome, // \x1b[1;5H
    CtrlEnd, // \x1b[1;5F
    ShiftLeft, // \x1b[1;2D
    ShiftRight, // \x1b[1;2C
    ShiftUp, // \x1b[1;2A
    ShiftDown, // \x1b[1;2B
    ShiftHome, // \x1b[1;2H
    ShiftEnd, // \x1b[1;2F
    F1, // F1 key (\x1bOP)
    F2, // F2 key (\x1bOQ)
    F3, // F3 key (\x1bOR)
    F4, // F4 key (\x1bOS)
    F5, // F5 key (\x1b[15~)
    F6, // F6 key (\x1b[17~)
    F7, // F7 key (\x1b[18~)
    F8, // F8 key (\x1b[19~)
    F9, // F9 key (\x1b[20~)
    F10, // F10 key (\x1b[21~)
    F11, // F11 key (\x1b[23~)
    F12, // F12 key (\x1b[24~)
    PageUp, // Page Up (\x1b[5~)
    PageDown, // Page Down (\x1b[6~)
    Home, // Home (\x1b[H)
    End, // End (\x1b[F)
    Backspace,
    Delete,
    Tab, // Tab key (\x09)
    ShiftTab, // Tab key (\x1b[Z)
    PrintScreen,
    Pause,
    ShiftPrintScreen,
    ShiftPause,
    CtrlPrintScreen,
    CtrlPause,
    Other, // Unknown sequence
};

pub const Key = struct {
    type: KeyType,
    sequence: []const u8,
};

pub const MouseEvent = enum {
    Down, // Button press
    Up, // Button release
    WheelUp, // Wheel scroll up
    WheelDown, // Wheel scroll down
    Move, // Cursor movement
};

pub const Mouse = struct {
    event: MouseEvent,
    x: i32,
    y: i32,
    button: u8,
    sequence: []const u8,
};

pub const InputEvent = union(enum) {
    key: Key,
    mouse: Mouse,
};

// Global buffer shared by all functions.
// 64 bytes is not enough - can be overflowed with ultra fast mouse
// movements. Tested with 512 bytes.
var input_buffer: [512]u8 = undefined;

var input_len: usize = 0;
var input_offset: usize = 0;

/// Gets the next key or mouse event from the terminal,
/// returning null if none available.
/// The returned sequence is valid only until the next call to this
/// or related functions.
pub fn get() !?InputEvent {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        if (try getKeyWindows()) |key| return .{ .key = key };
        if (try getMouseWindows()) |mouse| return .{ .mouse = mouse };
        return null;
    }

    // Try mouse first
    if (try getMousePosix()) |mouse| return .{ .mouse = mouse };
    // Then key
    if (try getKeyPosix()) |key| return .{ .key = key };
    return null;
}

/// Gets a mouse event non-blockingly, returning null if no mouse input is
/// available. The returned sequence is valid only until the next call to
/// this or related functions.
pub fn getMouse() !?Mouse {
    const builtin = @import("builtin");
    return switch (builtin.os.tag) {
        .windows => try getMouseWindows(),
        else => try getMousePosix(),
    };
}

fn getMousePosix() !?Mouse {
    const builtin = @import("builtin");
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) {
        return error.NoTermiosSupport;
    }

    var fds: [1]c.pollfd = .{
        .{ .fd = c.STDIN_FILENO, .events = c.POLLIN, .revents = 0 },
    };
    const ready = c.poll(&fds, 1, 0);
    if (ready < 0) return error.PollFailed;
    if (ready > 0) {
        const n = c.read(c.STDIN_FILENO, &input_buffer, input_buffer.len);
        if (n < 0) return error.ReadFailed;
        if (n == 0) {
            if (input_offset < input_len) return null;
            return null;
        }
        input_len = @as(usize, @intCast(n));
        input_offset = 0;
    } else if (input_offset >= input_len) {
        return null;
    }

    const remaining = input_buffer[input_offset..input_len];
    if (remaining.len < 6 or remaining[0] != 0x1b or remaining[1] != '[' or
        remaining[2] != '<')
    {
        return null;
    }

    var i: usize = 3;
    while (i < remaining.len and remaining[i] != 'M' and
        remaining[i] != 'm') : (i += 1)
    {}
    if (i >= remaining.len) {
        if (ready <= 0) {
            input_offset = input_len;
        }
        return null;
    }

    const sequence = remaining[0 .. i + 1];
    var button: u8 = 0;
    var j: usize = 3;
    while (j < i and sequence[j] != ';') : (j += 1) {
        button = button * 10 + (sequence[j] - '0');
    }
    j += 1; // Skip ;
    var x: i32 = 0;
    while (j < i and sequence[j] != ';') : (j += 1) {
        x = x * 10 + (sequence[j] - '0');
    }
    j += 1; // Skip ;
    var y: i32 = 0;
    while (j < i) : (j += 1) {
        y = y * 10 + (sequence[j] - '0');
    }
    const is_press = sequence[i] == 'M';
    const event = switch (button) {
        0, 1, 2 => if (is_press) MouseEvent.Down else MouseEvent.Up,
        64 => MouseEvent.WheelUp,
        65 => MouseEvent.WheelDown,
        35 => MouseEvent.Move,
        else => MouseEvent.Move,
    };
    input_offset += i + 1;
    return Mouse{
        .event = event,
        .x = x - 1,
        .y = y - 1,
        .button = if (button < 3) button else 0,
        .sequence = sequence,
    };
}

fn getKeyPosix() !?Key {
    const builtin = @import("builtin");
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) {
        return error.NoTermiosSupport;
    }

    if (input_offset >= input_len) {
        var fds: [1]c.pollfd = .{
            .{ .fd = c.STDIN_FILENO, .events = c.POLLIN, .revents = 0 },
        };
        const ready = c.poll(&fds, 1, 0);
        if (ready < 0) return error.PollFailed;
        if (ready == 0) return null;

        const n = c.read(c.STDIN_FILENO, &input_buffer, input_buffer.len);
        if (n < 0) return error.ReadFailed;
        if (n == 0) return null;
        input_len = @as(usize, @intCast(n));
        input_offset = 0;
    }

    const remaining = input_buffer[input_offset..input_len];
    if (remaining.len == 0) return null;

    // Skip mouse events
    if (remaining.len >= 3 and remaining[0] == 0x1b and
        remaining[1] == '[' and remaining[2] == '<')
    {
        var i: usize = 3;
        while (i < remaining.len and remaining[i] != 'M' and
            remaining[i] != 'm') : (i += 1)
        {}
        input_offset += if (i < remaining.len) i + 1 else input_len;
        return null;
    }

    // F5-F12, Page Up/Down (moved up to catch before fragment check)
    if (input_len > 1 and remaining.len >= 4) {
        if (remaining[0] == 0x1b and remaining[1] == '[') {
            var i: usize = 2;
            while (i < remaining.len and remaining[i] != '~') : (i += 1) {}
            if (i < remaining.len and remaining[i] == '~') {
                var num: u32 = 0;
                for (remaining[2..i]) |digit| {
                    if (digit >= '0' and digit <= '9') {
                        num = num * 10 + (digit - '0');
                    } else {
                        break;
                    }
                }
                const seq_len = i + 1;
                const sequence = remaining[0..seq_len];
                input_offset += seq_len;
                return Key{
                    .type = switch (num) {
                        3 => .Delete,
                        5 => .PageUp,
                        6 => .PageDown,
                        15 => .F5,
                        17 => .F6,
                        18 => .F7,
                        19 => .F8,
                        20 => .F9,
                        21 => .F10,
                        23 => .F11,
                        24 => .F12,
                        else => .Other,
                    },
                    .sequence = sequence,
                };
            }
        }
    }

    // Skip suspicious mouse-like fragments if they're not handled
    if (remaining.len >= 5) {
        // Look for ';' and final M or m (but NOT if it begins with [1;
        // for Ctrl-Arrow)
        var has_semicolon = false;
        var ends_with_m = false;

        for (remaining) |byte| {
            if (byte == ';') has_semicolon = true;
            if (byte == 'M' or byte == 'm') ends_with_m = true;
        }

        const maybe_bad_mouse_fragment =
            has_semicolon and ends_with_m and !(remaining.len >= 4 and
                remaining[0] == 0x1b and remaining[1] == '[' and
                remaining[2] == '1' and remaining[3] == ';');

        if (maybe_bad_mouse_fragment) {
            input_offset = input_len;
            return null;
        }
    }

    // [[57361;5u^[[57361;2u
    if (remaining.len >= 10 and remaining[0] == 0x1b and
        remaining[1] == '[' and
        remaining[2] == '5' and
        remaining[3] == '7' and
        remaining[4] == '3' and
        remaining[5] == '6' and
        // remaining[6] == '1' or '2'
        remaining[7] == ';' and
        // remaining[8] == '2' or '5'
        remaining[9] == 'u')
    {
        const sequence = remaining[0..10];
        input_offset += 10;
        if (sequence[8] == '2')
            return Key{
                .type = switch (sequence[6]) {
                    '1' => .ShiftPrintScreen,
                    '2' => .ShiftPause,
                    else => .Other,
                },
                .sequence = sequence,
            };
        if (sequence[8] == '5')
            return Key{
                .type = switch (sequence[6]) {
                    '1' => .CtrlPrintScreen,
                    '2' => .CtrlPause,
                    else => .Other,
                },
                .sequence = sequence,
            };
    }

    // [57361u, [57362u
    if (remaining.len >= 8 and remaining[0] == 0x1b and
        remaining[1] == '[' and
        remaining[2] == '5' and
        remaining[3] == '7' and
        remaining[4] == '3' and
        remaining[5] == '6' and
        remaining[7] == 'u')
    {
        const sequence = remaining[0..7];
        input_offset += 8;
        return Key{
            .type = switch (sequence[6]) {
                '1' => .PrintScreen,
                '2' => .Pause,
                else => .Other,
            },
            .sequence = sequence,
        };
    }

    // Single-byte key
    if (remaining.len == 1 or (remaining.len >= 2 and remaining[1] != '[' and
        remaining[1] != 'O'))
    {
        const sequence = remaining[0..1];
        input_offset += 1;
        return Key{
            .type = switch (sequence[0]) {
                0x03 => .CtrlC,
                0x1b => .Escape,
                0x0d, 0x0a => .Enter,
                0x08, 0x7f => .Backspace,
                0x09 => .Tab,
                else => .Char,
            },
            .sequence = sequence,
        };
    }

    // Arrow keys, Home/End, Ctrl+Arrow
    if (remaining[0] == 0x1b and remaining[1] == '[') {
        if (remaining.len >= 3 and remaining[0] == 0x1b and
            remaining[1] == '[' and remaining[2] == '<')
        {
            // this is likely a mouse report
            return null;
        }

        if (remaining.len >= 6 and
            remaining[0] == '\x1b' and
            remaining[1] == '[' and
            remaining[2] == '1' and
            remaining[3] == ';' and
            remaining[4] == '5')
        {
            const seq_char = remaining[5];
            const sequence = remaining[0..6];
            input_offset += 6;
            return Key{
                .type = switch (seq_char) {
                    'A' => .CtrlUp,
                    'B' => .CtrlDown,
                    'C' => .CtrlRight,
                    'D' => .CtrlLeft,
                    'H' => .CtrlHome,
                    'F' => .CtrlEnd,
                    else => .Other,
                },
                .sequence = sequence,
            };
        }
        if (remaining.len >= 6 and
            remaining[0] == '\x1b' and
            remaining[1] == '[' and
            remaining[2] == '1' and
            remaining[3] == ';' and
            remaining[4] == '2')
        {
            const seq_char = remaining[5];
            const sequence = remaining[0..6];
            input_offset += 6;
            return Key{
                .type = switch (seq_char) {
                    'A' => .ShiftUp,
                    'B' => .ShiftDown,
                    'C' => .ShiftRight,
                    'D' => .ShiftLeft,
                    'H' => .ShiftHome,
                    'F' => .ShiftEnd,
                    else => .Other,
                },
                .sequence = sequence,
            };
        }

        // Fallback: 3-byte sequences like arrows, Home, End
        if (remaining.len >= 3) {
            const seq = remaining[0..3];
            input_offset += 3;
            return Key{
                .type = switch (seq[2]) {
                    'A' => .Up,
                    'B' => .Down,
                    'C' => .Right,
                    'D' => .Left,
                    'H' => .Home,
                    'F' => .End,
                    'Z' => .ShiftTab,
                    else => .Other,
                },
                .sequence = seq,
            };
        }
    }

    // F1-F4
    if (remaining[0] == 0x1b and remaining[1] == 'O' and remaining.len >= 3) {
        const sequence = remaining[0..3];
        input_offset += 3;
        return Key{
            .type = switch (sequence[2]) {
                'P' => .F1,
                'Q' => .F2,
                'R' => .F3,
                'S' => .F4,
                else => .Other,
            },
            .sequence = sequence,
        };
    }

    // Unrecognized, take printable letters
    var seq_len: usize = 0;
    for (remaining, 0..) |byte, i| {
        if (byte == 0x1b or byte == '[' or byte == '<' or byte == ';' or
            byte == 'M' or byte == 'm') break;
        if ((byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z')) {
            seq_len = i + 1;
        } else {
            break;
        }
    }
    if (seq_len == 0) {
        input_offset += 1; // Skip one byte
        return null;
    }

    const sequence = remaining[0..seq_len];
    input_offset += seq_len;
    return Key{
        .type = if (seq_len == 1) .Char else .Other,
        .sequence = sequence,
    };
}

fn getKeyWindows() !?Key {
    const windows = std.os.windows;
    const stdin = windows.GetStdHandle(windows.STD_INPUT_HANDLE) orelse
        return error.NoStdIn;

    var input_records: [1]windows.INPUT_RECORD = undefined;
    var num_read: u32 = 0;

    if (windows.PeekConsoleInputA(stdin, &input_records, 1, &num_read) == 0) {
        return error.PeekFailed;
    }
    if (num_read == 0) return null;

    if (windows.ReadConsoleInputA(stdin, &input_records, 1, &num_read) == 0) {
        return error.ReadFailed;
    }

    const event = input_records[0];
    if (event.EventType != windows.KEY_EVENT or
        !event.Event.KeyEvent.bKeyDown)
    {
        return null;
    }

    const vk = event.Event.KeyEvent.wVirtualKeyCode;
    const ascii = event.Event.KeyEvent.uChar.AsciiChar;

    // Write directly into input_buffer
    if (vk == windows.VK_ESCAPE) {
        input_buffer[0] = 0x1b;
        input_len = 1;
    } else if (vk == windows.VK_RETURN) {
        input_buffer[0] = 0x0d;
        input_len = 1;
    } else if (vk == windows.VK_UP) {
        input_buffer[0..3].* = "\x1b[A".*;
        input_len = 3;
    } else if (vk == windows.VK_DOWN) {
        input_buffer[0..3].* = "\x1b[B".*;
        input_len = 3;
    } else if (vk == windows.VK_RIGHT) {
        input_buffer[0..3].* = "\x1b[C".*;
        input_len = 3;
    } else if (vk == windows.VK_LEFT) {
        input_buffer[0..3].* = "\x1b[D".*;
        input_len = 3;
    } else if (ascii != 0) {
        input_buffer[0] = ascii;
        input_len = 1;
    } else {
        return null;
    }

    const sequence = input_buffer[0..input_len];
    return Key{
        .type = switch (vk) {
            windows.VK_ESCAPE => .Escape,
            windows.VK_RETURN => .Enter,
            windows.VK_UP => .Up,
            windows.VK_DOWN => .Down,
            windows.VK_RIGHT => .Right,
            windows.VK_LEFT => .Left,
            else => if (ascii != 0) .Char else .Other,
        },
        .sequence = sequence,
    };
}

fn getMouseWindows() !?Mouse {
    const windows = std.os.windows;
    const stdin = windows.GetStdHandle(windows.STD_INPUT_HANDLE) orelse
        return error.NoStdIn;

    var mode: windows.DWORD = 0;
    _ = windows.GetConsoleMode(stdin, &mode);
    try windows.SetConsoleMode(stdin, mode | windows.ENABLE_MOUSE_INPUT);
    defer windows.SetConsoleMode(stdin, mode) catch {};

    var input_records: [1]windows.INPUT_RECORD = undefined;
    var num_read: u32 = 0;

    if (windows.PeekConsoleInputA(stdin, &input_records, 1, &num_read) == 0) {
        return error.PeekFailed;
    }
    if (num_read == 0) return null;

    if (windows.ReadConsoleInputA(stdin, &input_records, 1, &num_read) == 0) {
        return error.ReadFailed;
    }

    const input_event = input_records[0];
    if (input_event.EventType != windows.MOUSE_EVENT) return null;

    const mouse = input_event.Event.MouseEvent;
    const x = mouse.dwMousePosition.X;
    const y = mouse.dwMousePosition.Y;
    const button_state = mouse.dwButtonState;
    const flags = mouse.dwEventFlags;

    var mouse_event: MouseEvent = undefined;
    var button: u8 = 0;
    if (flags & windows.MOUSE_WHEELED != 0) {
        mouse_event = if (@as(i32, @bitCast(mouse.dwButtonState)) > 0)
            .WheelUp
        else
            .WheelDown;
    } else if (flags & windows.MOUSE_MOVED != 0) {
        mouse_event = .Move;
    } else if (button_state & windows.FROM_LEFT_1ST_BUTTON_PRESSED != 0) {
        mouse_event = .Down;
        button = 0;
    } else if (button_state & windows.RIGHTMOST_BUTTON_PRESSED != 0) {
        mouse_event = .Down;
        button = 2;
    } else if (button_state & windows.MIDDLE_BUTTON_PRESSED != 0) {
        mouse_event = .Down;
        button = 1;
    } else {
        mouse_event = .Up;
        button = if (button_state == 0) @as(u8, @truncate(flags)) else 0;
    }

    // Format the sequence directly into input_buffer
    input_len = try std.fmt.bufPrint(
        input_buffer[0..],
        "\x1b[<{};{};{}{}",
        .{ button, x + 1, y + 1, if (mouse_event == .Down) 'M' else 'm' },
    ).len;

    const sequence = input_buffer[0..input_len];
    return Mouse{
        .event = mouse_event,
        .x = x,
        .y = y,
        .button = button,
        .sequence = sequence,
    };
}
