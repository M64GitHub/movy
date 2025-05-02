const std = @import("std");
const movy = @import("movy");

pub const StatusWindow = struct {
    surface: *movy.core.RenderSurface,
    fg_color: movy.core.types.Rgb,
    bg_color: movy.core.types.Rgb,

    pub fn init(
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
        fg: movy.core.types.Rgb,
        bg: movy.core.types.Rgb,
    ) !StatusWindow {
        return StatusWindow{
            .surface = try movy.core.RenderSurface.init(
                allocator,
                width,
                height,
                bg,
            ),
            .fg_color = fg,
            .bg_color = bg,
        };
    }

    pub fn update(self: *StatusWindow, text: []const u8) void {
        _ = self.surface.putStrXY(text, 1, 1, self.fg_color, self.bg_color);
    }
};
