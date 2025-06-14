const std = @import("std");
const movy = @import("../../../movy.zig");

/// Base widget for all UI elements—defines dimensions and rendering surface.
pub const Widget = struct {
    // Rendered result—chars and pixels combined
    output_surface: *movy.core.RenderSurface,
    x: i32, // X position in terminal coordinates
    y: i32, // Y position in terminal coordinates
    w: usize, // Width in characters
    h: usize, // Height in pixel rows (h/2 lines for text)
    theme: *const movy.ui.ColorTheme, // Reference to the active color theme
    style: *const movy.ui.Style, // Reference to the active style (chars)
    is_active: bool = false,

    /// Initializes a widget with dimensions and default theme/style—allocates
    /// output_surface.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*Widget {
        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            theme.getColor(.BackgroundColor),
        );

        const self = try allocator.create(Widget);
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
    pub fn deinit(self: *Widget, allocator: std.mem.Allocator) void {
        self.output_surface.deinit(allocator);
        allocator.destroy(self);
    }

    /// Sets a new theme for the widget—updates rendering colors.
    pub fn setTheme(self: *Widget, theme: *const movy.ui.ColorTheme) void {
        self.theme = theme;
    }

    /// Retrieves the current theme—useful for rendering or inspection.
    pub fn getTheme(self: *const Widget) *const movy.ui.ColorTheme {
        return self.theme;
    }

    /// Sets a new style for the widget—updates rendering characters.
    pub fn setStyle(self: *Widget, style: *const movy.ui.Style) void {
        self.style = style;
    }

    /// Retrieves the current style—useful for rendering or inspection.
    pub fn getStyle(self: *const Widget) *const movy.ui.Style {
        return self.style;
    }

    /// Sets the widget’s position—updates x and y coordinates.
    pub fn setPosition(self: *Widget, x: i32, y: i32) void {
        var y_new: i32 = @divTrunc(y, 2);
        y_new = y_new * 2;
        self.x = x;
        self.y = y_new;
        self.output_surface.x = x;
        self.output_surface.y = y_new;
    }

    /// Gets the widget’s position—returns x and y as a Position2D struct.
    pub fn getPosition(self: *const Widget) movy.ui.Position2D {
        return movy.ui.Position2D{ .x = self.x, .y = self.y };
    }

    /// Resizes the widget—updates w and h, recreates output_surface if
    /// dimensions change.
    pub fn resize(
        self: *Widget,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        if (w != self.w or h != self.h) {
            self.output_surface.deinit(allocator);
            allocator.destroy(self.output_surface);
            self.output_surface = try movy.core.RenderSurface.init(
                allocator,
                w,
                h,
                self.theme.getColor(.BackgroundColor),
            );
            self.w = w;
            self.h = h;
        }
    }

    /// Retrieves the widget’s size—returns w and h as a Size struct.
    pub fn getSize(self: *const Widget) movy.ui.Size {
        return .{ .w = self.w, .h = self.h };
    }

    /// Clears the widget’s output_surface with the background color from
    /// the theme.
    pub fn clear(self: *Widget) void {
        self.output_surface.clearColored(self.theme.getColor(.BackgroundColor));
    }

    /// Renders the widget—base implementation fills with background color.
    pub fn render(self: *Widget) *movy.core.RenderSurface {
        self.clear(); // Simple bg fill—subclasses override for more
        return self.output_surface;
    }
};
