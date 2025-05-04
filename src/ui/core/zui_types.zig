// zui_types.zig - UI-specific data types for the tzui library
// This file defines types for the Terminal Zig User Interface (tzui) library’s
// user interface components, such as windows and widgets. These types build on
// the rendering engine’s core types (see src/core/types.zig) to enable rich
// terminal-based UI functionality.

const tzui = @import("../../tzui.zig");

/// Represents dimensions (width and height) for tzui UI components.
/// Used to size windows, widgets, and other interface elements.
pub const ZuiSize = struct {
    w: usize, // Width in pixels or characters
    h: usize, // Height in pixels or characters
};

/// Represents a 2D position (x, y) for tzui UI components.
/// Used to place windows, widgets, or other elements, defaulting to (0,0).
pub const ZuiPosition2D = struct {
    x: i32 = 0, // X-coordinate in 2D space
    y: i32 = 0, // Y-coordinate in 2D space
};

/// Defines a string with foreground and background colors for tzui UI rendering.
/// Used to display styled text in windows or widgets.
pub const ZuiColoredString = struct {
    str: []const u8, // Text content to display
    fg_color: tzui.core.types.Rgb, // Foreground color (RGB)
    bg_color: tzui.core.types.Rgb, // Background color (RGB)
};

pub const ZuiWidgetType = enum {
    Widget,
    BorderedWindow,
    TitleWindow,
    TextWindow,
};

pub const ZuiWidgetInfo = struct {
    ptr: *tzui.ui.ZuiWidget,
    widget_type: ZuiWidgetType,

    /// Shorthand for checking if two widget infos refer to the same widget.
    pub fn equals(self: ZuiWidgetInfo, other: ZuiWidgetInfo) bool {
        return self.ptr == other.ptr and self.widget_type == other.widget_type;
    }

    /// Check if this info is valid (non-null pointer)
    pub fn isValid(self: ZuiWidgetInfo) bool {
        return self.ptr != null;
    }
};
