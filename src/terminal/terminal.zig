const std = @import("std");

const c = @cImport({
    @cInclude("termios.h");
    @cInclude("poll.h");
    @cInclude("unistd.h");
    @cInclude("sys/ioctl.h"); // Added for winsize struct and TIOCGWINSZ
});

const movy = @import("../movy.zig");

// Module-level state for raw mode
var original_term: ?c.termios = null;

/// Moves the cursor up by n lines
pub fn cursorUp(n: i32) void {
    // ESC [ {n}A: Move cursor up n lines
    var buf: [32]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "\x1b[{d}A", .{n}) catch return;
    _ = std.posix.write(std.posix.STDOUT_FILENO, msg) catch {};
}

/// Moves the cursor down by n lines
pub fn cursorDown(n: i32) void {
    // ESC [ {n}B: Move cursor down n lines
    var buf: [32]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "\x1b[{d}B", .{n}) catch return;
    _ = std.posix.write(std.posix.STDOUT_FILENO, msg) catch {};
}

/// Moves the cursor left by n columns
pub fn cursorLeft(n: i32) void {
    // ESC [ {n}D: Move cursor left n columns
    var buf: [32]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "\x1b[{d}D", .{n}) catch return;
    _ = std.posix.write(std.posix.STDOUT_FILENO, msg) catch {};
}

/// Moves the cursor right by n columns
pub fn cursorRight(n: i32) void {
    // ESC [ {n}C: Move cursor right n columns
    var buf: [32]u8 = undefined;
    const msg = std.fmt.bufPrint(&buf, "\x1b[{d}C", .{n}) catch return;
    _ = std.posix.write(std.posix.STDOUT_FILENO, msg) catch {};
}

/// Shows the cursor
pub fn cursorOn() void {
    // ESC [ ?25h: Make cursor visible
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[?25h") catch {};
}

/// Hides the cursor
pub fn cursorOff() void {
    // ESC [ ?25l: Make cursor invisible
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[?25l") catch {};
}

/// Resets cursor and text attributes
pub fn cursorReset() void {
    // ESC [ 0m: Reset all terminal attributes (color, bold, etc.)
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[0m") catch {};
}

/// Moves the cursor to the home position (top-left)
pub fn cursorHome() void {
    // ESC [ H: Move cursor to home position (row 1, column 1)
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[H") catch {};
}

/// Sets the foreground text color to an RGB value
pub fn setColor(color: movy.core.types.Rgb) void {
    // ESC [ 38;2;{r};{g};{b}m: Set foreground color to RGB (truecolor)
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(
        &buf,
        "\x1b[38;2;{d};{d};{d}m",
        .{ color.r, color.g, color.b },
    ) catch return;
    _ = std.posix.write(std.posix.STDOUT_FILENO, msg) catch {};
}

/// Sets the background color to an RGB value
pub fn setBgColor(color: movy.core.types.Rgb) void {
    // ESC [ 48;2;{r};{g};{b}m: Set background color to RGB (truecolor)
    var buf: [64]u8 = undefined;
    const msg = std.fmt.bufPrint(
        &buf,
        "\x1b[48;2;{d};{d};{d}m",
        .{ color.r, color.g, color.b },
    ) catch return;
    _ = std.posix.write(std.posix.STDOUT_FILENO, msg) catch {};
}

/// Resets color to default
pub fn resetColor() void {
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[0m") catch {};
}

/// Begins alternate screen mode, preparing the terminal for full-screen use
pub fn beginAlternateScreen() !void {
    // ESC s: Save current cursor position
    _ = try std.posix.write(std.posix.STDOUT_FILENO, "\x1b[s");
    // ESC [ ?47h: Switch to alternate screen buffer
    _ = try std.posix.write(std.posix.STDOUT_FILENO, "\x1b[?47h");
    // ESC [ 2J: Clear entire screen
    _ = try std.posix.write(std.posix.STDOUT_FILENO, "\x1b[2J");
    // ESC [ H: Move cursor to home position (row 1, column 1)
    _ = try std.posix.write(std.posix.STDOUT_FILENO, "\x1b[H");
}

/// Ends alternate screen mode, returning to the normal screen buffer
pub fn endAlternateScreen() void {
    // ESC [ ?47l: Switch back to normal screen buffer
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[?47l") catch {};
    // ESC u: Restore previously saved cursor position
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[u") catch {};
}

/// Clears the terminal screen
pub fn clear() void {
    // ESC [ 2J: Clear entire screen
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[2J") catch {};
    // ESC [ H: Move cursor to home position (row 1, column 1)
    _ = std.posix.write(std.posix.STDOUT_FILENO, "\x1b[H") catch {};
}

/// Begins raw terminal mode, enabling unbuffered key and mouse input
pub fn beginRawMode() !void {
    const builtin = @import("builtin");
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) return;

    var term: c.termios = undefined;
    if (c.tcgetattr(c.STDIN_FILENO, &term) != 0) return error.TermiosFailed;

    original_term = term; // Store original terminal settings

    var raw = term;
    // Disable: ECHO (echo input), ICANON (canonical mode), ISIG (signal keys),
    // IEXTEN (extended input)
    raw.c_lflag &= ~@as(c_uint, c.ECHO | c.ICANON | c.ISIG | c.IEXTEN);
    // Disable: ICRNL (CR to NL conversion), IXON (Ctrl+S/Q flow control)
    raw.c_iflag &= ~@as(c_uint, c.ICRNL | c.IXON);
    raw.c_cc[c.VMIN] = 0; // Minimum bytes to read (0 = non-blocking)
    raw.c_cc[c.VTIME] = 0; // Timeout in deciseconds (0 = immediate)
    if (c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &raw) != 0)
        return error.TermiosFailed;

    // Enable mouse reporting
    // ESC [ ?1000h: Enable basic mouse reporting
    // ESC [ ?1006h: Enable SGR (extended) mouse reporting
    // ESC [ ?1003h: Enable "all mouse" reporting (any movement)
    const enable = "\x1b[?1000h\x1b[?1006h\x1b[?1003h";
    _ = try std.posix.write(std.posix.STDOUT_FILENO, enable);
}

/// Ends raw terminal mode, restoring the original terminal state
pub fn endRawMode() void {
    const builtin = @import("builtin");
    if (builtin.os.tag != .linux and builtin.os.tag != .macos) return;

    if (original_term) |term| {
        // Restore original termios settings
        _ = c.tcsetattr(c.STDIN_FILENO, c.TCSANOW, &term);
        // ESC [ ?1003l: Disable "all mouse" reporting
        // ESC [ ?1006l: Disable SGR (extended) mouse reporting
        // ESC [ ?1000l: Disable basic mouse reporting
        // ESC [ 0m: Reset all terminal attributes (color, etc.)
        // \n: Newline to ensure clean prompt
        const reset = "\x1b[?1003l\x1b[?1006l\x1b[?1000l\x1b[0m\n";
        _ = std.posix.write(std.posix.STDOUT_FILENO, reset) catch {};
    }
}

/// Returns the terminal size in characters (width, height)
pub fn getSize() !struct { width: usize, height: usize } {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        const windows = std.os.windows;
        const stdout_handle =
            windows.GetStdHandle(windows.STD_OUTPUT_HANDLE) orelse
            return error.NoStdOut;
        var info: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
        if (windows.GetConsoleScreenBufferInfo(stdout_handle, &info) == 0) {
            return error.GetConsoleInfoFailed;
        }
        return .{
            .width = @as(
                usize,
                @intCast(info.srWindow.Right - info.srWindow.Left + 1),
            ),
            .height = @as(
                usize,
                @intCast(info.srWindow.Bottom - info.srWindow.Top + 1),
            ),
        };
    } else {
        var winsize: c.winsize = undefined;
        const result = c.ioctl(
            c.STDOUT_FILENO,
            c.TIOCGWINSZ,
            @intFromPtr(&winsize),
        );
        if (result != 0) return error.IoctlFailed;
        return .{
            .width = @as(usize, @intCast(winsize.ws_col)),
            .height = @as(usize, @intCast(winsize.ws_row)),
        };
    }
}

var size_changed: bool = false;

/// callback for terminal size changed signal hander on posix
fn sigwinchHandler(_: c_int) callconv(.C) void {
    size_changed = true;
}

/// Sets up signal handling to detect terminal size changes (POSIX only)
pub fn detectSizeChanges() !void {
    const builtin = @import("builtin");
    if (builtin.os.tag != .windows) {
        // Set up SIGWINCH handler
        var sa = std.mem.zeroes(c.struct_sigaction);
        sa.sa_handler = sigwinchHandler; // Handler for SIGWINCH signal
        sa.sa_flags = 0; // No special flags
        if (c.sigaction(c.SIGWINCH, &sa, null) != 0) {
            return error.SigactionFailed;
        }
    }
}
