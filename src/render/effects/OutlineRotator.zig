const std = @import("std");
const movy = @import("../../movy.zig");
const Error = movy.render.RenderEffectError;
const RenderEffect = movy.render.RenderEffect;
const SurfaceExpand = movy.render.Effect.SurfaceExpand;
pub const EffectDirection = movy.render.Effect.EffectDirection;

pub const OutlineRotator = struct {
    surface_expand: ?SurfaceExpand = null,
    start_x: i32 = 0,
    start_y: i32 = 0,
    direction: EffectDirection = .right,

    pub fn validate(self: *OutlineRotator) !void {
        if (self.start_x < 0 or self.start_y < 0) return Error.InvalidPosition;
    }

    pub fn run(
        self: *OutlineRotator,
        in_surface: *const movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
        frame: usize,
    ) void {
        _ = frame;
        _ = in_surface;

        var direction = self.direction;

        var p_init = movy.core.types.Pixel2D{
            .x = self.start_x,
            .y = self.start_y,
            .c = .{ .r = 0, .g = 0, .b = 0 },
        };
        var p_current = p_init;
        var p_next = p_current;

        // Get initial color at start position
        out_surface.getColor(&p_init);
        p_current = p_init;
        p_next = p_current;

        var stop = false;
        while (!stop) {
            if (direction == .left) {
                p_next.x -= 1;
                if (!out_surface.hasColorThr(&p_next, 3)) {
                    p_next.x += 1;
                    if (out_surface.hasColorThrXY(
                        p_current.x,
                        p_current.y + 1,
                        3,
                    )) {
                        direction = .down;
                        continue;
                    }
                    if (out_surface.hasColorThrXY(
                        p_current.x,
                        p_current.y - 1,
                        3,
                    )) {
                        direction = .up;
                        continue;
                    }
                    stop = true;
                    continue;
                }
            } else if (direction == .down) {
                p_next.y += 1;
                if (!out_surface.hasColorThr(&p_next, 3)) {
                    p_next.y -= 1;
                    if (out_surface.hasColorThrXY(
                        p_current.x + 1,
                        p_current.y,
                        3,
                    )) {
                        direction = .right;
                        continue;
                    }
                    if (out_surface.hasColorThrXY(
                        p_current.x - 1,
                        p_current.y,
                        3,
                    )) {
                        direction = .left;
                        continue;
                    }
                    stop = true;
                    continue;
                }
            } else if (direction == .right) {
                p_next.x += 1;
                if (!out_surface.hasColorThr(&p_next, 3)) {
                    p_next.x -= 1;
                    if (out_surface.hasColorThrXY(
                        p_current.x,
                        p_current.y + 1,
                        3,
                    )) {
                        direction = .down;
                        continue;
                    }
                    if (out_surface.hasColorThrXY(
                        p_current.x,
                        p_current.y - 1,
                        3,
                    )) {
                        direction = .up;
                        continue;
                    }
                    stop = true;
                    continue;
                }
            } else if (direction == .up) {
                p_next.y -= 1;
                if (!out_surface.hasColorThr(&p_next, 3)) {
                    p_next.y += 1;
                    if (out_surface.hasColorThrXY(
                        p_current.x + 1,
                        p_current.y,
                        3,
                    )) {
                        direction = .right;
                        continue;
                    }
                    if (out_surface.hasColorThrXY(
                        p_current.x - 1,
                        p_current.y,
                        3,
                    )) {
                        direction = .left;
                        continue;
                    }
                    stop = true;
                    continue;
                }
            }

            // Get color from next position, move current position,
            // set previous color
            out_surface.getColor(&p_next);
            p_current.x = p_next.x;
            p_current.y = p_next.y;
            out_surface.setColor(&p_current); // Use p_current.c as is
            p_current = p_next;

            // Stop if back at start
            if (p_current.x == p_init.x and p_current.y == p_init.y) {
                stop = true;
            }
        }
    }

    /// Helper to wrap this effect into a RenderEffect.
    pub fn asEffect(self: *OutlineRotator) RenderEffect {
        return RenderEffect.init(
            OutlineRotator,
            self,
            OutlineRotator.run,
            OutlineRotator.validate,
        );
    }
};
