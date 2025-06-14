const std = @import("std");
const movy = @import("../../../movy.zig");

/// Defines a bordered window—combines a base widget with a border overlay.
pub const BorderedWindow = struct {
    base: *movy.ui.Widget, // Base widget—background and core properties
    base_widget: *movy.ui.Widget, // for consistency
    border: movy.ui.WindowBorder, // Border widget—frame overlay

    /// Initializes a heap allocated bordered window, sets up base widget
    /// and border with same dimensions.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*BorderedWindow {
        const self = try allocator.create(BorderedWindow);
        self.* = .{
            .base = try movy.ui.Widget.init(
                allocator,
                x,
                y,
                w,
                h,
                theme,
                style,
            ),
            .border = try movy.ui.WindowBorder.init(
                allocator,
                x,
                y,
                w,
                h,
                theme,
                style,
            ),
            .base_widget = undefined,
        };
        self.base_widget = self.base;

        return self;
    }

    /// Frees the bordered window’s base and border resources.
    pub fn deinit(self: *BorderedWindow, allocator: std.mem.Allocator) void {
        self.border.deinit(allocator);
        self.base.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn setActive(self: *BorderedWindow, active: bool) void {
        self.base_widget.is_active = active;
    }

    pub fn isActive(self: *BorderedWindow) bool {
        return self.base_widget.is_active;
    }

    /// Sets a new theme for the window—propagates to base and border.
    pub fn setTheme(
        self: *BorderedWindow,
        theme: *const movy.ui.ColorTheme,
    ) void {
        self.base.setTheme(theme);
        self.border.setTheme(theme);
    }

    /// Retrieves the current theme from the base—consistent across components.
    pub fn getTheme(
        self: *const BorderedWindow,
    ) *const movy.ui.ColorTheme {
        return self.base.getTheme();
    }

    /// Sets a new style for the window—propagates to base and border.
    pub fn setStyle(
        self: *BorderedWindow,
        style: *const movy.ui.Style,
    ) void {
        self.base.setStyle(style);
        self.border.setStyle(style);
    }

    /// Retrieves the current style from the base—consistent across components.
    pub fn getStyle(self: *const BorderedWindow) *const movy.ui.Style {
        return self.base.getStyle();
    }

    /// Retrieves the window’s position—passes through to base.
    pub fn getPosition(self: *const BorderedWindow) movy.ui.Position2D {
        return self.base.getPosition();
    }

    /// Sets the window’s position—propagates to base and border.
    pub fn setPosition(self: *BorderedWindow, x: i32, y: i32) void {
        self.base.setPosition(x, y);
        self.border.setPosition(x, y);
    }

    /// Resizes the window—updates base and border dimensions.
    pub fn resize(
        self: *BorderedWindow,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        try self.base.resize(allocator, w, h);
        try self.border.resize(allocator, w, h);
    }

    /// Retrieves the window’s size—passes through to base.
    pub fn getSize(self: *const BorderedWindow) movy.ui.Size {
        return self.base.getSize();
    }

    /// Renders the bordered window—composites base and border,
    /// returns the final surface.
    pub fn render(self: *BorderedWindow) *movy.core.RenderSurface {
        _ = self.base.render(); // Render base (background)
        _ = self.border.render(); // Render border overlay
        var surfaces = [_]*movy.core.RenderSurface{
            self.border.output_surface,
            self.base.output_surface,
        };
        // Merge into base
        movy.render.RenderEngine.renderComposite(
            &surfaces,
            self.base.output_surface,
        );
        return self.base.output_surface; // Return final surface
    }
};
