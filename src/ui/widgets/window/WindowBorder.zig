const std = @import("std");
const movy = @import("../../../movy.zig");

/// Defines a border-only widget—renders a rectangular frame using style
/// characters.
pub const WindowBorder = struct {
    // Rendered border—chars only, transparent inner
    output_surface: *movy.core.RenderSurface,
    x: i32, // X position in terminal coordinates
    y: i32, // Y position in terminal coordinates
    w: usize, // Width in characters
    h: usize, // Height in pixel rows (h/2 lines for text)
    theme: *const movy.ui.ColorTheme, // Reference to the active color theme
    style: *const movy.ui.Style, // Reference to the active style (chars)

    /// Initializes a border widget—matches Widget dimensions,
    /// allocates output_surface.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !WindowBorder {
        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            theme.getColor(.BackgroundColor),
        );
        return WindowBorder{
            .output_surface = output_surface,
            .x = x,
            .y = y,
            .w = w,
            .h = h,
            .theme = theme,
            .style = style,
        };
    }

    /// Frees the border’s output_surface—caller manages theme/style lifetimes.
    pub fn deinit(self: *WindowBorder, allocator: std.mem.Allocator) void {
        self.output_surface.deinit(allocator);
    }

    /// Renders the border—draws a single-line rectangular frame using
    /// style characters, returns the surface.
    pub fn render(self: *WindowBorder) *movy.core.RenderSurface {
        const half_h = self.h / 2; // Lines—y * 2 for pixel rows
        const bottom_y = half_h * 2 - 2; // Bottom row—y_pixel for bottom border
        self.output_surface.clearTransparent(); // Inner stays transparent

        // Top and bottom borders
        for (0..self.w) |x| {
            if (x == 0) {
                self.output_surface.char_map[x] =
                    self.style.getChar(
                        .WindowUpperLeftCorner,
                    );
                self.output_surface.char_map[x + bottom_y * self.w] =
                    self.style.getChar(
                        .WindowLowerLeftCorner,
                    );
                self.output_surface.color_map[x] =
                    self.theme.getColor(
                        .WindowCorner,
                    );
                self.output_surface.color_map[x + bottom_y * self.w] =
                    self.theme.getColor(
                        .WindowCorner,
                    );
                self.output_surface.shadow_map[x] = 1; // Mark opaque
                self.output_surface.shadow_map[x + bottom_y * self.w] = 1;
            } else if (x == self.w - 1) {
                self.output_surface.char_map[x] =
                    self.style.getChar(
                        .WindowUpperRightCorner,
                    );
                self.output_surface.char_map[x + bottom_y * self.w] =
                    self.style.getChar(
                        .WindowLowerRightCorner,
                    );
                self.output_surface.color_map[x] =
                    self.theme.getColor(
                        .WindowCorner,
                    );
                self.output_surface.color_map[x + bottom_y * self.w] =
                    self.theme.getColor(
                        .WindowCorner,
                    );
                self.output_surface.shadow_map[x] = 1; // Mark opaque
                self.output_surface.shadow_map[x + bottom_y * self.w] = 1;
            } else {
                self.output_surface.char_map[x] =
                    self.style.getChar(
                        .WindowHorizontalBorder,
                    );
                self.output_surface.char_map[x + bottom_y * self.w] =
                    self.style.getChar(
                        .WindowHorizontalBorder,
                    );
                self.output_surface.color_map[x] =
                    self.theme.getColor(
                        .WindowBorder,
                    );
                self.output_surface.color_map[x + bottom_y * self.w] =
                    self.theme.getColor(
                        .WindowBorder,
                    );
                self.output_surface.shadow_map[x] = 1; // Mark opaque
                self.output_surface.shadow_map[x + bottom_y * self.w] = 1;
            }
            self.output_surface.color_map[x + self.w] =
                self.theme.getColor(
                    .BackgroundColor,
                ); // Bg for top
            self.output_surface.color_map[x + (bottom_y + 1) * self.w] =
                self.theme.getColor(
                    .BackgroundColor,
                ); // Bg for bottom
        }

        // Left and right borders (skip corners)
        for (1..half_h - 1) |y| {
            const y_pixel = y * 2; // Pixel rows
            self.output_surface.char_map[0 + y_pixel * self.w] =
                self.style.getChar(
                    .WindowVerticalBorder,
                );
            self.output_surface.char_map[(self.w - 1) + y_pixel * self.w] =
                self.style.getChar(
                    .WindowVerticalBorder,
                );
            self.output_surface.color_map[0 + y_pixel * self.w] =
                self.theme.getColor(
                    .WindowBorder,
                );
            self.output_surface.color_map[(self.w - 1) + y_pixel * self.w] =
                self.theme.getColor(
                    .WindowBorder,
                );
            self.output_surface.shadow_map[0 + y_pixel * self.w] = 1;
            self.output_surface.shadow_map[(self.w - 1) + y_pixel * self.w] = 1;
            self.output_surface.color_map[0 + (y_pixel + 1) * self.w] =
                self.theme.getColor(
                    .BackgroundColor,
                ); // Bg
            self.output_surface.color_map[
                (self.w - 1) + (y_pixel + 1) * self.w
            ] = self.theme.getColor(.BackgroundColor); // Bg
        }
        return self.output_surface; // Return final surface
    }

    /// Sets the border’s position—updates x and y coordinates.
    pub fn setPosition(self: *WindowBorder, x: i32, y: i32) void {
        var y_new: i32 = @divTrunc(y, 2);
        y_new = y_new * 2;
        self.x = x;
        self.y = y_new;
        self.output_surface.x = x;
        self.output_surface.y = y_new;
    }

    /// Retrieves the widget’s size—returns w and h as a Size struct.
    pub fn getSize(self: *WindowBorder) movy.ui.Size {
        return .{ .w = self.w, .h = self.h };
    }

    /// Sets a new theme for the widget—updates rendering colors.
    pub fn setTheme(
        self: *WindowBorder,
        theme: *const movy.ui.ColorTheme,
    ) void {
        self.theme = theme;
    }

    /// Retrieves the current theme—useful for rendering or inspection.
    pub fn getTheme(self: *const WindowBorder) *const movy.ui.ColorTheme {
        return self.theme;
    }

    /// Sets a new style for the widget—updates rendering characters.
    pub fn setStyle(
        self: *WindowBorder,
        style: *const movy.ui.Style,
    ) void {
        self.style = style;
    }

    /// Retrieves the current style—useful for rendering or inspection.
    pub fn getStyle(self: *const WindowBorder) *const movy.ui.Style {
        return self.style;
    }
};
