const std = @import("std");
const movy = @import("../../../movy.zig");

/// Defines a top-level window—wraps a titled window for manager rendering.
pub const Window = struct {
    base: movy.ui.TitleWindow, // Base titled window—bg, border, title
    base_widget: *movy.ui.Widget,

    /// Initializes a window—sets up base with title.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        window_title: []const u8,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*Window {
        var self = try allocator.create(Window);

        self.* = .{
            .base = try movy.ui.TitleWindow.init(
                allocator,
                x,
                y,
                w,
                h,
                window_title,
                theme,
                style,
            ),
        };
        self.base_widget = self.base.base_widget;
    }

    /// Frees the window’s base resources.
    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        self.base.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn setActive(self: *Window, active: bool) void {
        self.base_widget.is_active = active;
    }

    pub fn isActive(self: *Window) bool {
        return self.base_widget.is_active;
    }

    /// Sets a new theme for the window—propagates to base.
    pub fn setTheme(
        self: *Window,
        theme: *const movy.ui.ColorTheme,
    ) void {
        self.base.setTheme(theme);
    }

    /// Retrieves the current theme from the base.
    pub fn getTheme(self: *const Window) *const movy.ui.ColorTheme {
        return self.base.getTheme();
    }

    /// Sets a new style for the window—propagates to base.
    pub fn setStyle(self: *Window, style: *const movy.ui.Style) void {
        self.base.setStyle(style);
    }

    /// Retrieves the current style from the base.
    pub fn getStyle(self: *const Window) *const movy.ui.Style {
        return self.base.getStyle();
    }

    /// Sets the window title—propagates to base.
    pub fn setTitle(self: *Window, title: []const u8) void {
        self.base.setTitle(title);
    }

    /// Retrieves the current window title from the base.
    pub fn getTitle(self: *const Window) []const u8 {
        return self.base.getTitle();
    }

    /// Retrieves the window’s position—passes through to base.
    pub fn getPosition(self: *const Window) movy.ui.Position2D {
        return self.base.getPosition();
    }

    /// Sets the window’s position—propagates to base.
    pub fn setPosition(self: *Window, x: i32, y: i32) void {
        self.base.setPosition(x, y);
    }

    /// Resizes the window—updates base dimensions.
    pub fn resize(
        self: *Window,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        try self.base.resize(allocator, w, h);
    }

    /// Retrieves the window’s size—passes through to base.
    pub fn getSize(self: *const Window) movy.ui.Size {
        return self.base.getSize();
    }

    /// Checks if the given coordinates are within the window's bounds
    /// Uses absolute coordinates.
    pub fn isInBounds(self: *const Window, x: i32, y: i32) bool {
        const pos = self.getPosition();
        const size = self.getSize();
        return x >= pos.x and x < pos.x + @as(i32, @intCast(size.w)) and
            y >= pos.y and y < pos.y + @as(i32, @intCast(size.h));
    }

    /// Checks if the given coordinates are within the
    /// window's title bounds (first row).
    pub fn isInTitleBounds(self: *const Window, x: i32, y: i32) bool {
        const pos = self.getPosition();
        const size = self.getSize();
        // Check if within x bounds and in the first row (y == pos.y)
        return x >= pos.x and x < pos.x + @as(i32, @intCast(size.w)) and
            y == pos.y;
    }

    /// Renders the window—composites base, returns the final surface
    /// for manager use.
    pub fn render(self: *Window) *movy.core.RenderSurface {
        // Render base (bg, border, title)—pass final surface
        return self.base.render();
        //  TODO: Add content (buttons, text)
    }
};
