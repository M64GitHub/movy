//! frame-game - a tiny platformer that shows off movy's neon-render layer:
//! `movy.Frame` (float framebuffer + persistent glow/bloom + CRT post-fx),
//! `movy.color.V3` (linear float color), and `movy.DiffOutput` (60fps dirty-row
//! terminal output). See demos/frame-game/README.md for the rendering walkthrough.
//!
//! Run:
//!   zig build run-frame-game                 play
//!     (move A/D or arrows · jump W/K/space · P pause · R restart · ESC/Q quit)
//!   zig build run-frame-game -- --shot N out.png [x]
//!     headless: a demo bot plays N frames and saves a PNG (optional spawn x).
//!     This is the dev loop - render, savePng, open/Read the image. No tty needed.
//!
//! Layout: render comes from movy; the game layer is config/input/level/player/
//! camera/game; main.zig wires the terminal lifecycle, app states, and pacing.

const std = @import("std");
const movy = @import("movy");
const cfg = @import("config.zig");
const pal = @import("pal.zig");
const input = @import("input.zig");
const game_mod = @import("game.zig");

const AppState = enum { title, playing };

const TXT = movy.core.types.Rgb{ .r = 0xd9, .g = 0xf7, .b = 0xff };
const TXT_DIM = movy.core.types.Rgb{ .r = 0x4a, .g = 0x6e, .b = 0x80 };
const TXT_GOLD = movy.core.types.Rgb{ .r = 0xff, .g = 0xc8, .b = 0x66 };
const TXT_BG = movy.core.types.Rgb{ .r = 2, .g = 5, .b = 10 };

// ---------------------------------------------------------------- headless

/// Scripted demo bot: runs right and hops - exercises the systems so a
/// screenshot shows real gameplay (it isn't meant to play well).
fn botInput(in: *input.Input, i: u32) void {
    in.right = 2;
    if (i % 38 == 0) in.jump_buf = 6;
}

fn runHeadless(allocator: std.mem.Allocator, frames: u32, path: [:0]const u8, start_x: ?i32) !void {
    const frame = try movy.Frame.init(allocator, cfg.view_w, cfg.VIEW_H);
    defer frame.deinit();
    const game = try game_mod.Game.init(allocator);
    defer game.deinit();

    if (start_x) |sx| game.plr.spawnAt(sx, 20);

    var in = input.Input{};
    var i: u32 = 0;
    while (i < frames) : (i += 1) {
        in.newFrame();
        botInput(&in, i);
        game.update(&in);
        frame.beginFrame();
        game.render(frame);
        frame.composite();
    }
    try frame.savePng(allocator, path.ptr, 6);
    std.debug.print("saved {s} (player x={d})\n", .{ path, game.plr.pxX() });
}

// ---------------------------------------------------------------- terminal

fn center(surf: *movy.RenderSurface, str: []const u8, row: usize, fg: movy.core.types.Rgb) void {
    const w: usize = @intCast(cfg.view_w);
    const col = (w -| str.len) / 2;
    _ = surf.putStrXY(str, col, row, fg, TXT_BG);
}

fn runTerminal(allocator: std.mem.Allocator) !void {
    const term = try movy.terminal.getSize();
    if (term.width < @as(usize, @intCast(cfg.MIN_VIEW_W)) or term.height < 36) {
        std.debug.print(
            "needs a terminal of at least {d}x36 cells (yours is {d}x{d}).\n",
            .{ cfg.MIN_VIEW_W, term.width, term.height },
        );
        return;
    }

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // turn off all-motion mouse reporting (movy enables it; it floods stdin)
    _ = std.posix.system.write(std.posix.STDOUT_FILENO, "\x1b[?1003l\x1b[?1006l\x1b[?1000l", 24);

    const kitty = movy.input.detectKittyKeyboard(200);
    if (kitty) movy.input.enableKittyKeyboard();
    defer if (kitty) movy.input.disableKittyKeyboard();

    // adapt the viewport width to the terminal
    cfg.view_w = std.math.clamp(@as(i32, @intCast(term.width)), cfg.MIN_VIEW_W, cfg.MAX_VIEW_W);
    const view_rows: usize = @intCast(@divTrunc(cfg.VIEW_H, 2));

    var screen = try movy.Screen.init(allocator, @intCast(cfg.view_w), view_rows);
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = .{ .r = 0, .g = 0, .b = 0 };

    // center the play area in the terminal
    const off_cols = @as(i32, @intCast(term.width)) - cfg.view_w;
    const off_rows = @as(i32, @intCast(term.height)) - @as(i32, @intCast(view_rows));
    screen.setXY(@divTrunc(off_cols, 2), @divTrunc(off_rows, 2) * 2);

    const frame = try movy.Frame.init(allocator, cfg.view_w, cfg.VIEW_H);
    defer frame.deinit();

    var game = try game_mod.Game.init(allocator);
    defer game.deinit();

    // dirty-row terminal output + non-blocking writer thread
    var dout = try movy.DiffOutput.init(allocator, &screen, .threaded);
    defer dout.deinit();

    var app: AppState = .title;
    var paused = false;
    var hud_buf: [64]u8 = undefined;
    var in = input.Input{ .kitty = kitty };

    var next_deadline: i128 = blk: { var ts: std.c.timespec = undefined; _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts); break :blk @as(i128, ts.sec) * 1_000_000_000 + ts.nsec; };
    while (true) {
        next_deadline += cfg.FRAME_NS;

        // ---- input
        in.newFrame();
        while (try movy.input.get()) |ev| in.feed(ev);
        if (in.quit) break;

        switch (app) {
            .title => if (in.confirm) {
                app = .playing;
            },
            .playing => {
                if (in.pause) paused = !paused;
                if (in.restart) {
                    game.deinit();
                    game = try game_mod.Game.init(allocator);
                    paused = false;
                }
                if (!paused) game.update(&in);
            },
        }

        // ---- render
        frame.beginFrame();
        game.render(frame);
        if (paused) frame.tint = pal.v3(0.5, 0.6, 0.8);
        frame.composite();

        try screen.renderInit();
        try screen.addRenderSurface(allocator, frame.surface);
        screen.render();

        // ---- overlays (drawn onto the composited surface)
        const hud = std.fmt.bufPrint(&hud_buf, " SCORE {d:0>6}", .{game.score}) catch " SCORE";
        _ = screen.output_surface.putStrXY(hud, 1, 0, TXT, TXT_BG);
        switch (app) {
            .title => {
                center(screen.output_surface, "F R A M E - G A M E", 14, TXT);
                center(screen.output_surface, ">> PRESS SPACE TO START <<", 17, TXT_GOLD);
                center(screen.output_surface, "move A/D  jump W/K/space  stomp the orange  P pause  Q quit", 20, TXT_DIM);
            },
            .playing => if (paused) center(screen.output_surface, "  P A U S E D  ", 16, TXT),
        }

        try dout.output(&screen);

        // ---- deadline pacing (drift-compensating)
        const now = blk: { var ts: std.c.timespec = undefined; _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts); break :blk @as(i128, ts.sec) * 1_000_000_000 + ts.nsec; };
        if (now < next_deadline) {
            _ = std.c.nanosleep(&.{ .sec = 0, .nsec = @intCast(next_deadline - now) }, null);
        } else {
            next_deadline = now;
        }
    }
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = &[_][]const u8{"prog"};
    // defer std.process.argsFree(allocator, args); // removed for 0.16

    if (args.len >= 2 and std.mem.eql(u8, args[1], "--shot")) {
        if (args.len < 4) {
            std.debug.print("usage: frame-game --shot <frames> <out.png> [x]\n", .{});
            return;
        }
        const frames = try std.fmt.parseInt(u32, args[2], 10);
        const start_x: ?i32 = if (args.len >= 5)
            (std.fmt.parseInt(i32, args[4], 10) catch null)
        else
            null;
        try runHeadless(allocator, frames, args[3], start_x);
        return;
    }

    try runTerminal(allocator);
}
