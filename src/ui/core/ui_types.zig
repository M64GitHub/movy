// zui_types.zig - UI-specific data types for the movy library
// This file defines types for the Terminal Zig User Interface (movy) library’s
// user interface components, such as windows and widgets. These types build on
// the rendering engine’s core types (see src/core/types.zig) to enable rich
// terminal-based UI functionality.

const movy = @import("../../movy.zig");

/// Represents dimensions (width and height) for movy UI components.
/// Used to size windows, widgets, and other interface elements.
pub const Size = struct {
    w: usize, // Width in pixels or characters
    h: usize, // Height in pixels or characters
};

/// Represents a 2D position (x, y) for movy UI components.
/// Used to place windows, widgets, or other elements, defaulting to (0,0).
pub const Position2D = struct {
    x: i32 = 0, // X-coordinate in 2D space
    y: i32 = 0, // Y-coordinate in 2D space
};

/// Defines a string with foreground and background colors for movy UI rendering.
/// Used to display styled text in windows or widgets.
pub const ColoredString = struct {
    str: []const u8, // Text content to display
    fg_color: movy.core.types.Rgb, // Foreground color (RGB)
    bg_color: movy.core.types.Rgb, // Background color (RGB)
};

pub const WidgetType = enum {
    Widget,
    BorderedWindow,
    TitleWindow,
    TextWindow,
};

pub const WidgetInfo = struct {
    ptr: *movy.ui.Widget,
    widget_type: WidgetType,

    /// Shorthand for checking if two widget infos refer to the same widget.
    pub fn equals(self: WidgetInfo, other: WidgetInfo) bool {
        return self.ptr == other.ptr and self.widget_type == other.widget_type;
    }

    /// Check if this info is valid (non-null pointer)
    pub fn isValid(self: WidgetInfo) bool {
        return self.ptr != null;
    }
};
