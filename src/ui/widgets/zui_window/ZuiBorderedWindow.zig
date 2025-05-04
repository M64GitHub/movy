const std = @import("std");
const tzui = @import("../../../tzui.zig");

/// Defines a bordered window—combines a base widget with a border overlay.
pub const ZuiBorderedWindow = struct {
    base: *tzui.ui.ZuiWidget, // Base widget—background and core properties
    base_widget: *tzui.ui.ZuiWidget, // for consistency
    border: tzui.ui.ZuiWindowBorder, // Border widget—frame overlay

    /// Initializes a heap allocated bordered window, sets up base widget
    /// and border with same dimensions.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        theme: *const tzui.ui.ZuiColorTheme,
        style: *const tzui.ui.ZuiStyle,
    ) !*ZuiBorderedWindow {
        const self = try allocator.create(ZuiBorderedWindow);
        self.* = .{
            .base = try tzui.ui.ZuiWidget.init(
                allocator,
                x,
                y,
                w,
                h,
                theme,
                style,
            ),
            .border = try tzui.ui.ZuiWindowBorder.init(
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
    pub fn deinit(self: *ZuiBorderedWindow, allocator: std.mem.Allocator) void {
        self.border.deinit(allocator);
        self.base.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn setActive(self: *ZuiBorderedWindow, active: bool) void {
        self.base_widget.is_active = active;
    }

    pub fn isActive(self: *ZuiBorderedWindow) bool {
        return self.base_widget.is_active;
    }

    /// Sets a new theme for the window—propagates to base and border.
    pub fn setTheme(
        self: *ZuiBorderedWindow,
        theme: *const tzui.ui.ZuiColorTheme,
    ) void {
        self.base.setTheme(theme);
        self.border.setTheme(theme);
    }

    /// Retrieves the current theme from the base—consistent across components.
    pub fn getTheme(
        self: *const ZuiBorderedWindow,
    ) *const tzui.ui.ZuiColorTheme {
        return self.base.getTheme();
    }

    /// Sets a new style for the window—propagates to base and border.
    pub fn setStyle(
        self: *ZuiBorderedWindow,
        style: *const tzui.ui.ZuiStyle,
    ) void {
        self.base.setStyle(style);
        self.border.setStyle(style);
    }

    /// Retrieves the current style from the base—consistent across components.
    pub fn getStyle(self: *const ZuiBorderedWindow) *const tzui.ui.ZuiStyle {
        return self.base.getStyle();
    }

    /// Retrieves the window’s position—passes through to base.
    pub fn getPosition(self: *const ZuiBorderedWindow) tzui.ui.ZuiPosition2D {
        return self.base.getPosition();
    }

    /// Sets the window’s position—propagates to base and border.
    pub fn setPosition(self: *ZuiBorderedWindow, x: i32, y: i32) void {
        self.base.setPosition(x, y);
        self.border.setPosition(x, y);
    }

    /// Resizes the window—updates base and border dimensions.
    pub fn resize(
        self: *ZuiBorderedWindow,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        try self.base.resize(allocator, w, h);
        try self.border.resize(allocator, w, h);
    }

    /// Retrieves the window’s size—passes through to base.
    pub fn getSize(self: *const ZuiBorderedWindow) tzui.ui.ZuiSize {
        return self.base.getSize();
    }

    /// Renders the bordered window—composites base and border,
    /// returns the final surface.
    pub fn render(self: *ZuiBorderedWindow) *tzui.core.RenderSurface {
        _ = self.base.render(); // Render base (background)
        _ = self.border.render(); // Render border overlay
        var surfaces = [_]*tzui.core.RenderSurface{
            self.border.output_surface,
            self.base.output_surface,
        };
        // Merge into base
        tzui.render.RenderEngine.renderComposite(
            &surfaces,
            self.base.output_surface,
        );
        return self.base.output_surface; // Return final surface
    }
};
