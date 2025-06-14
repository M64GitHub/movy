const std = @import("std");
const movy = @import("../../movy.zig");

pub const LayoutType = enum {
    HLayout,
    VLayout,
};

pub const Layout = struct {
    type: LayoutType,
    inner_spacing: i32, // space between components
    outer_spacing: i32, // space between outer border and components
    // if true, inner spacing is ignored and assumed as 0. In case of a VLayout,
    // the lower border of the upper component is shared with the upper border
    // of the lower component
    shared_borders: bool = false,
};

pub const LayoutManager = struct {
    screen: *movy.Screen,

    pub fn init(screen: *movy.Screen) LayoutManager {
        return LayoutManager{
            .screen = screen,
        };
    }

    /// Get the x and y position as Position2D for the topleft corner of a
    /// rectangle (window, sprite, ...) of dimensions widht and height.
    pub fn getCenterCoords(
        self: *LayoutManager,
        width: usize,
        height: usize,
    ) movy.ui.Position2D {
        const center_x: i32 =
            @divTrunc(@as(i32, @intCast(self.screen.width() - width)), 2);

        const center_y: i32 =
            @divTrunc(@as(i32, @intCast(self.screen.height() - height)), 2);

        return movy.ui.Position2D{
            .x = center_x,
            .y = center_y,
        };
    }
};
