const std = @import("std");
const tzui = @import("../../../tzui.zig");

/// Base widget for all UI elements—defines dimensions and rendering surface.
pub const ZuiWidget = struct {
    // Rendered result—chars and pixels combined
    output_surface: *tzui.core.RenderSurface,
    x: i32, // X position in terminal coordinates
    y: i32, // Y position in terminal coordinates
    w: usize, // Width in characters
    h: usize, // Height in pixel rows (h/2 lines for text)
    theme: *const tzui.ui.ZuiColorTheme, // Reference to the active color theme
    style: *const tzui.ui.ZuiStyle, // Reference to the active style (chars)
    is_active: bool = false,

    /// Initializes a widget with dimensions and default theme/style—allocates
    /// output_surface.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        theme: *const tzui.ui.ZuiColorTheme,
        style: *const tzui.ui.ZuiStyle,
    ) !*ZuiWidget {
        const output_surface = try tzui.core.RenderSurface.init(
            allocator,
            w,
            h,
            theme.getColor(.BackgroundColor),
        );

        const self = try allocator.create(ZuiWidget);
        self.* = .{
            .output_surface = output_surface,
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .theme = theme,
            .style = style,
        };

        return self;
    }

    /// Frees the widget’s output_surface—caller must manage theme/style
    /// lifetimes.
    pub fn deinit(self: *ZuiWidget, allocator: std.mem.Allocator) void {
        self.output_surface.deinit(allocator);
        allocator.destroy(self);
    }

    /// Sets a new theme for the widget—updates rendering colors.
    pub fn setTheme(self: *ZuiWidget, theme: *const tzui.ui.ZuiColorTheme) void {
        self.theme = theme;
    }

    /// Retrieves the current theme—useful for rendering or inspection.
    pub fn getTheme(self: *const ZuiWidget) *const tzui.ui.ZuiColorTheme {
        return self.theme;
    }

    /// Sets a new style for the widget—updates rendering characters.
    pub fn setStyle(self: *ZuiWidget, style: *const tzui.ui.ZuiStyle) void {
        self.style = style;
    }

    /// Retrieves the current style—useful for rendering or inspection.
    pub fn getStyle(self: *const ZuiWidget) *const tzui.ui.ZuiStyle {
        return self.style;
    }

    /// Sets the widget’s position—updates x and y coordinates.
    pub fn setPosition(self: *ZuiWidget, x: i32, y: i32) void {
        var y_new: i32 = @divTrunc(y, 2);
        y_new = y_new * 2;
        self.x = x;
        self.y = y_new;
        self.output_surface.x = x;
        self.output_surface.y = y_new;
    }

    /// Gets the widget’s position—returns x and y as a ZuiPosition2D struct.
    pub fn getPosition(self: *const ZuiWidget) tzui.ui.ZuiPosition2D {
        return tzui.ui.ZuiPosition2D{ .x = self.x, .y = self.y };
    }

    /// Resizes the widget—updates w and h, recreates output_surface if
    /// dimensions change.
    pub fn resize(
        self: *ZuiWidget,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        if (w != self.w or h != self.h) {
            self.output_surface.deinit(allocator);
            allocator.destroy(self.output_surface);
            self.output_surface = try tzui.core.RenderSurface.init(
                allocator,
                w,
                h,
                self.theme.getColor(.BackgroundColor),
            );
            self.w = w;
            self.h = h;
        }
    }

    /// Retrieves the widget’s size—returns w and h as a ZuiSize struct.
    pub fn getSize(self: *const ZuiWidget) tzui.ui.ZuiSize {
        return .{ .w = self.w, .h = self.h };
    }

    /// Clears the widget’s output_surface with the background color from
    /// the theme.
    pub fn clear(self: *ZuiWidget) void {
        self.output_surface.clearColored(self.theme.getColor(.BackgroundColor));
    }

    /// Renders the widget—base implementation fills with background color.
    pub fn render(self: *ZuiWidget) *tzui.core.RenderSurface {
        self.clear(); // Simple bg fill—subclasses override for more
        return self.output_surface;
    }
};
