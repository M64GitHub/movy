const std = @import("std");
const movy = @import("../movy.zig");
const stdout = std.io.getStdOut().writer();

/// Manages terminal display and renders attached elements like sprites.
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

    /// Initializes a new Screen with the given width and height in characters
    pub fn init(allocator: std.mem.Allocator, w: usize, h: usize) !Screen {
        var screen = Screen{
            .w = w,
            .h = h * 2,
            .sprites = std.ArrayList(*movy.graphic.Sprite).init(allocator),
            .sub_screens = std.ArrayList(*Screen).init(allocator),
            .output_surfaces = std.ArrayList(
                *movy.core.RenderSurface,
            ).init(allocator),
        };
        screen.output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h * 2,
            screen.bg_color,
        );
        try screen.colorClear(allocator);
        return screen;
    }

    /// Frees all resources allocated for the Screen
    pub fn deinit(self: *Screen, allocator: std.mem.Allocator) void {
        if (self.clr_line) |cl| allocator.free(cl);
        self.sprites.deinit();
        self.sub_screens.deinit();
        self.output_surfaces.deinit();
        self.output_surface.deinit(allocator);
        allocator.destroy(self.output_surface);
    }

    /// Adds a Sprite to the Screen for rendering its output_surface
    pub fn addSprite(self: *Screen, spr: *movy.graphic.Sprite) !void {
        try self.sprites.append(spr);
    }

    /// Adds an output surface to the Screen for rendering
    pub fn addRenderSurface(self: *Screen, rs: *movy.core.RenderSurface) !void {
        try self.output_surfaces.append(rs);
    }

    /// Returns the height of the Screen in half block characters
    pub fn height(self: Screen) usize {
        return self.h;
    }

    /// Returns the width of the Screen in characters
    pub fn width(self: Screen) usize {
        return self.w;
    }

    /// Sets the x and y coordinates of the Screen
    pub fn setXY(self: *Screen, px: i32, py: i32) void {
        self.x = px;
        self.y = py;
        if (self.is_subscreen) {
            self.output_surface.x = px;
            self.output_surface.y = py;
        }
    }

    /// Clears the Screen with the background color
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
            try stdout.print("{s}", .{self.clr_line.?});
        }
        try stdout.print("\x1b[0m", .{});

        self.output_surface.clearColored(self.bg_color);
    }

    /// Merges down all elements into a final output surface
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

    pub fn renderInit(self: *Screen) !void {
        self.output_surfaces.clearRetainingCapacity();
    }

    // renders sprites and surfaces
    pub fn renderWithSprites(self: *Screen) !void {
        for (self.sprites.items) |sprite| {
            if (sprite.active_animation) |_| {
                const rs =
                    try sprite.getCurrentFrameSurface();
                try self.addRenderSurface(rs);
            } else try self.addRenderSurface(sprite.output_surface);
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

    /// Renders output_surfaces on top of current output_surface, without
    /// clearing
    pub fn renderOnTop(self: *Screen) void {
        if (self.output_surfaces.items.len == 0) return;

        movy.render.RenderEngine.renderOver(
            self.output_surfaces.items,
            self.output_surface,
        );
    }

    pub fn output(self: *Screen) !void {
        movy.terminal.cursorHome();
        if (self.x > 0) movy.terminal.cursorRight(self.x);

        const half_y = @divTrunc(self.y, 2);
        if (half_y >= 1) movy.terminal.cursorDown(half_y);

        const rendered_ansi = try self.output_surface.toAnsi();

        try stdout.writeAll(rendered_ansi);
    }

    /// Sets the rendering mode of the Screen (transparent or bgcolor)
    pub fn setScreenMode(self: *Screen, m: Mode) void {
        self.screen_mode = m;
    }

    /// Get the x and y position as for the topleft corner of a
    /// rectangle (window, sprite, ...) of dimensions widht and height.
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
