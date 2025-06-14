const std = @import("std");
const movy = @import("../../../movy.zig");

/// Defines a titled window—adds a centered title to a bordered window.
pub const TitleWindow = struct {
    base: *movy.ui.BorderedWindow,
    base_widget: *movy.ui.Widget,
    title: []const u8, // Window title text

    /// Initializes a heap allocated titled window, sets up base and title.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        window_title: []const u8,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*TitleWindow {
        var self = try allocator.create(TitleWindow);
        self.* = .{
            .base = try movy.ui.BorderedWindow.init(
                allocator,
                x,
                y,
                w,
                h,
                theme,
                style,
            ),
            .title = window_title,
            .base_widget = undefined,
        };
        self.base_widget = self.base.base_widget;
        return self;
    }

    /// Frees the titled window’s base resources—caller manages title memory.
    pub fn deinit(self: *TitleWindow, allocator: std.mem.Allocator) void {
        self.base.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn setActive(self: *TitleWindow, active: bool) void {
        self.base_widget.is_active = active;
    }

    pub fn isActive(self: *TitleWindow) bool {
        return self.base_widget.is_active;
    }

    /// Sets a new theme for the window—propagates to base.
    pub fn setTheme(
        self: *TitleWindow,
        theme: *const movy.ui.ColorTheme,
    ) void {
        self.base.setTheme(theme);
    }

    /// Retrieves the current theme from the base.
    pub fn getTheme(self: *const TitleWindow) *const movy.ui.ColorTheme {
        return self.base.getTheme();
    }

    /// Sets a new style for the window—propagates to base.
    pub fn setStyle(
        self: *TitleWindow,
        style: *const movy.ui.Style,
    ) void {
        self.base.setStyle(style);
    }

    /// Retrieves the current style from the base.
    pub fn getStyle(self: *const TitleWindow) *const movy.ui.Style {
        return self.base.getStyle();
    }

    /// Sets the window title—updates the displayed text.
    pub fn setTitle(self: *TitleWindow, title: []const u8) void {
        self.title = title;
    }

    /// Retrieves the current window title.
    pub fn getTitle(self: *const TitleWindow) []const u8 {
        return self.title;
    }

    /// Retrieves the window’s position—passes through to base.
    pub fn getPosition(self: *const TitleWindow) movy.ui.Position2D {
        return self.base.getPosition();
    }

    /// Sets the window’s position—propagates to base.
    pub fn setPosition(self: *TitleWindow, x: i32, y: i32) void {
        self.base.setPosition(x, y);
    }

    /// Resizes the window—updates base dimensions.
    pub fn resize(
        self: *TitleWindow,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        try self.base.resize(allocator, w, h);
    }

    /// Retrieves the window’s size—passes through to base.
    pub fn getSize(self: *const TitleWindow) movy.ui.Size {
        return self.base.getSize();
    }

    /// Checks if the given coordinates are within the window's bounds
    /// Uses absolute coordinates.
    pub fn isInBounds(self: *const TitleWindow, x: i32, y: i32) bool {
        const pos = self.getPosition();
        const size = self.getSize();
        return x >= pos.x and x < pos.x + @as(i32, @intCast(size.w)) and
            y >= pos.y and y < pos.y + @as(i32, @intCast(size.h));
    }

    /// Checks if the given coordinates are within the
    /// window's title bounds (first row).
    pub fn isInTitleBounds(self: *const TitleWindow, x: i32, y: i32) bool {
        const pos = self.getPosition();
        const size = self.getSize();
        // Check if within x bounds and in the first row (y == pos.y)
        return x >= pos.x and x < pos.x + @as(i32, @intCast(size.w)) and
            y == pos.y;
    }

    /// Renders the titled window—composites base and title, returns the
    /// final surface.
    pub fn render(self: *TitleWindow) *movy.core.RenderSurface {
        _ = self.base.render(); // Render base (bg + border)—discard tmp surface
        // Trim to w-2
        const title_len = @min(self.title.len, self.base.getSize().w - 2);
        const start_x = if (self.base.getSize().w > title_len + 2)
            (self.base.getSize().w - title_len) / 2
        else
            1; // Center or x=1
        for (1..self.base.getSize().w - 1) |x| { // Clear top row (y=0)
            self.base.base.output_surface.char_map[x] = 0;
            self.base.base.output_surface.shadow_map[x] = 0;
        }

        _ = self.base.base.output_surface.putStrXY(
            self.title[0..title_len],
            start_x,
            0,
            self.base.getTheme().getColor(.WindowTitle),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.base.base.output_surface.putUtf8XY(
            self.base.getStyle().getChar(.WindowTitleLeft),
            start_x - 1,
            0,
            self.base.getTheme().getColor(.WindowCorner),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.base.base.output_surface.putUtf8XY(
            self.base.getStyle().getChar(.WindowTitleRight),
            start_x + title_len,
            0,
            self.base.getTheme().getColor(.WindowCorner),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        var surfaces = [_]*movy.core.RenderSurface{
            self.base.base.output_surface,
            self.base.border.output_surface,
        };
        // Merge all
        movy.render.RenderEngine.renderComposite(
            &surfaces,
            self.base.base.output_surface,
        );
        return self.base.base.output_surface; // Return final surface
    }
};
