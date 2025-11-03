const std = @import("std");
const movy = @import("../movy.zig");

/// Terminal rendering canvas for compositing and displaying visual content.
/// Manages sprites and render surfaces, composites them, and outputs to
/// terminal using ANSI codes.
pub const Screen = struct {
    w: usize = 0,
    h: usize = 0,
    x: i32 = 0,
    y: i32 = 0,
    bg_color: movy.core.types.Rgb = .{ .r = 0x20, .g = 0x20, .b = 0x20 },
    output_surface: *movy.core.RenderSurface = undefined,
    sprites: std.ArrayList(*movy.graphic.Sprite),
    sub_screens: std.ArrayList(*Screen),
    output_surfaces: std.ArrayList(*movy.core.RenderSurface),
    rendered_ansi: ?[]u8 = null,
    screen_mode: Mode = .transparent,
    clr_line: ?[]u8 = null,
    is_subscreen: bool = false,

    pub const Mode = enum {
        transparent,
        bgcolor,
    };

    /// Creates a Screen with the given dimensions (w, h in terminal chars).
    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize) !Screen {
        var screen = Screen{
            .w = w,
            .h = h * 2,
            .sprites = std.ArrayList(*movy.graphic.Sprite){},
            .sub_screens = std.ArrayList(*Screen){},
            .output_surfaces = std.ArrayList(
                *movy.core.RenderSurface,
            ){},
        };
        try screen.sprites.ensureTotalCapacity(allocator, 8);
        try screen.sub_screens.ensureTotalCapacity(allocator, 2);
        try screen.output_surfaces.ensureTotalCapacity(allocator, 8);
        screen.output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h * 2,
            screen.bg_color,
        );
        try screen.colorClear(allocator);

        movy.terminal.cursorOff();
        return screen;
    }

    /// Frees all resources and restores terminal cursor visibility.
    pub fn deinit(self: *Screen, allocator: std.mem.Allocator) void {
        if (self.clr_line) |cl| allocator.free(cl);
        self.sprites.deinit(allocator);
        self.sub_screens.deinit(allocator);
        self.output_surfaces.deinit(allocator);
        self.output_surface.deinit(allocator);
        movy.terminal.cursorOn();
    }

    /// Adds a sprite to be rendered (use with renderWithSprites).
    pub fn addSprite(self: *Screen, allocator: std.mem.Allocator, spr: *movy.graphic.Sprite) !void {
        try self.sprites.append(allocator, spr);
    }

    /// Adds a render surface for compositing in the next render call.
    pub fn addRenderSurface(self: *Screen, allocator: std.mem.Allocator, rs: *movy.core.RenderSurface) !void {
        try self.output_surfaces.append(allocator, rs);
    }

    /// Returns height in pixels (double vertical resolution).
    pub fn height(self: Screen) usize {
        return self.h;
    }

    /// Returns width in terminal characters.
    pub fn width(self: Screen) usize {
        return self.w;
    }

    /// Sets the screen position offset for rendering.
    pub fn setXY(self: *Screen, px: i32, py: i32) void {
        self.x = px;
        self.y = py;
        if (self.is_subscreen) {
            self.output_surface.x = px;
            self.output_surface.y = py;
        }
    }

    /// Clears the entire terminal screen with the background color.
    pub fn colorClear(self: *Screen, allocator: std.mem.Allocator) !void {
        if (self.clr_line == null) {
            var clr_line = try allocator.alloc(u8, @intCast(self.w + 2));
            @memset(clr_line[0..@intCast(self.w)], ' ');
            clr_line[@intCast(self.w)] = 0x0a;
            clr_line[@intCast(self.w + 1)] = 0x00;
            self.clr_line = clr_line;
        }

        movy.terminal.cursorHome();
        movy.terminal.setColor(self.bg_color);
        movy.terminal.setBgColor(self.bg_color);
        const half_h: usize = @as(usize, @intCast(self.h)) / 2;
        for (0..half_h) |_| {
            _ = try std.posix.write(std.posix.STDOUT_FILENO, self.clr_line.?);
        }
        _ = try std.posix.write(std.posix.STDOUT_FILENO, "\x1b[0m");

        self.output_surface.clearColored(self.bg_color);
    }

    /// Composites all added surfaces into the output surface.
    pub fn render(self: *Screen) void {
        if (self.output_surfaces.items.len == 0) return;

        if (self.screen_mode == .transparent) {
            self.output_surface.clearTransparent();
        } else {
            self.output_surface.clearColored(self.bg_color);
        }

        movy.render.RenderEngine.render(
            self.output_surfaces.items,
            self.output_surface,
        );
    }

    /// Composites all surfaces with alpha blending to background.
    pub fn renderWithAlpha(self: *Screen) void {
        if (self.output_surfaces.items.len == 0) return;

        if (self.screen_mode == .transparent) {
            self.output_surface.clearTransparent();
        } else {
            self.output_surface.clearColored(self.bg_color);
        }

        movy.render.RenderEngine.renderWithAlphaToBg(
            self.output_surfaces.items,
            self.output_surface,
        );
    }

    /// Clears the list of surfaces to render (call before adding surfaces).
    pub fn renderInit(self: *Screen) !void {
        self.output_surfaces.clearRetainingCapacity();
    }

    /// Renders all added sprites and surfaces together.
    pub fn renderWithSprites(self: *Screen, allocator: std.mem.Allocator) !void {
        for (self.sprites.items) |sprite| {
            if (sprite.active_animation) |_| {
                const rs =
                    try sprite.getCurrentFrameSurface();
                try self.addRenderSurface(allocator, rs);
            } else try self.addRenderSurface(allocator, sprite.output_surface);
        }
        if (self.output_surfaces.items.len == 0) return;

        if (self.screen_mode == .transparent) {
            self.output_surface.clearTransparent();
        } else {
            self.output_surface.clearColored(self.bg_color);
        }

        movy.render.RenderEngine.render(
            self.output_surfaces.items,
            self.output_surface,
        );
    }

    /// Renders surfaces on top of existing output without clearing.
    pub fn renderOnTop(self: *Screen) void {
        if (self.output_surfaces.items.len == 0) return;

        movy.render.RenderEngine.renderOver(
            self.output_surfaces.items,
            self.output_surface,
        );
    }

    /// Outputs the composited result to terminal as ANSI codes.
    pub fn output(self: *Screen) !void {
        movy.terminal.cursorHome();
        if (self.x > 0) movy.terminal.cursorRight(self.x);

        const half_y = @divTrunc(self.y, 2);
        if (half_y >= 1) movy.terminal.cursorDown(half_y);

        const rendered_ansi = try self.output_surface.toAnsi();

        _ = try std.posix.write(std.posix.STDOUT_FILENO, rendered_ansi);
    }

    /// Sets the rendering mode of the Screen (transparent or bgcolor)
    pub fn setScreenMode(self: *Screen, m: Mode) void {
        self.screen_mode = m;
    }

    /// Returns centered position for a rectangle of given dimensions.
    pub fn getCenterCoords(
        self: *Screen,
        w: usize,
        h: usize,
    ) struct { x: i32, y: i32 } {
        const center_x: i32 =
            @divTrunc(@as(i32, @intCast(self.w - w)), 2);

        const center_y: i32 =
            @divTrunc(@as(i32, @intCast(self.h - h)), 2);

        return .{
            .x = center_x,
            .y = center_y,
        };
    }
};
