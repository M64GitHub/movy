const movy = @import("../movy.zig");

pub const RenderEngine = struct {
    /// Merges multiple surfaces into one with z-index and clipping
    pub fn render(
        surfaces_in: []const *movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
    ) void {
        for (0..surfaces_in.len) |i| {
            const surface_in = surfaces_in[i];
            const in_w = surface_in.w;
            const in_h = surface_in.h;
            const out_w = out_surface.w;
            const out_h = out_surface.h;

            // clip

            if (surface_in.x < -@as(i32, @intCast(surface_in.w))) continue;
            if (surface_in.y < -@as(i32, @intCast(surface_in.h))) continue;

            const x_start = if (surface_in.x < 0)
                @as(usize, @intCast(-surface_in.x))
            else
                0;

            const y_start = if (surface_in.y < 0)
                @as(usize, @intCast(-surface_in.y))
            else
                0;

            const x_end = if (surface_in.x < 0)
                @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
            else
                @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

            const y_end = if (surface_in.y < 0)
                @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
            else
                @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

            // render
            for (y_start..y_end) |y| {
                for (x_start..x_end) |x| {
                    const idx_in = x + y * in_w;
                    if (surface_in.shadow_map[idx_in] != 0) {
                        const out_x = @as(i32, @intCast(x)) + surface_in.x;
                        const out_y = @as(i32, @intCast(y)) + surface_in.y;
                        if (out_x >= 0 and out_y >= 0 and out_x < @as(
                            i32,
                            @intCast(out_w),
                        ) and out_y < @as(i32, @intCast(out_h))) {
                            const idx_out = @as(usize, @intCast(out_x)) +
                                @as(usize, @intCast(out_y)) * out_w;
                            if (out_surface.shadow_map[idx_out] != 1) {
                                out_surface.color_map[idx_out] =
                                    surface_in.color_map[idx_in];
                                out_surface.shadow_map[idx_out] = 1;
                                out_surface.char_map[idx_out] =
                                    surface_in.char_map[idx_in];
                            }
                        }
                    }
                }
            }
        }
    }

    /// Merges multiple surfaces into one, overwriting areas
    pub fn renderOver(
        surfaces_in: []const *movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
    ) void {
        for (0..surfaces_in.len) |i| {
            const surface_in = surfaces_in[i];
            const in_w = surface_in.w;
            const in_h = surface_in.h;
            const out_w = out_surface.w;
            const out_h = out_surface.h;

            // clip

            if (surface_in.x < -@as(i32, @intCast(surface_in.w))) continue;
            if (surface_in.y < -@as(i32, @intCast(surface_in.h))) continue;

            const x_start = if (surface_in.x < 0)
                @as(usize, @intCast(-surface_in.x))
            else
                0;

            const y_start = if (surface_in.y < 0)
                @as(usize, @intCast(-surface_in.y))
            else
                0;

            const x_end = if (surface_in.x < 0)
                @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
            else
                @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

            const y_end = if (surface_in.y < 0)
                @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
            else
                @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

            // render
            for (y_start..y_end) |y| {
                for (x_start..x_end) |x| {
                    const idx_in = x + y * in_w;
                    if (surface_in.shadow_map[idx_in] != 0) {
                        const out_x = @as(i32, @intCast(x)) + surface_in.x;
                        const out_y = @as(i32, @intCast(y)) + surface_in.y;
                        if (out_x >= 0 and out_y >= 0 and out_x < @as(
                            i32,
                            @intCast(out_w),
                        ) and out_y < @as(i32, @intCast(out_h))) {
                            const idx_out = @as(usize, @intCast(out_x)) +
                                @as(usize, @intCast(out_y)) * out_w;
                            out_surface.color_map[idx_out] =
                                surface_in.color_map[idx_in];
                            out_surface.shadow_map[idx_out] = 1;
                            out_surface.char_map[idx_out] =
                                surface_in.char_map[idx_in];
                        }
                    }
                }
            }
        }
    }

    /// Render a surface onto another, overwriting areas
    pub fn renderSurfaceOver(
        surface_in: *movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
    ) void {
        const in_w = surface_in.w;
        const in_h = surface_in.h;
        const out_w = out_surface.w;
        const out_h = out_surface.h;

        // clip

        if (surface_in.x < -@as(i32, @intCast(surface_in.w))) return;
        if (surface_in.y < -@as(i32, @intCast(surface_in.h))) return;

        const x_start = if (surface_in.x < 0)
            @as(usize, @intCast(-surface_in.x))
        else
            0;

        const y_start = if (surface_in.y < 0)
            @as(usize, @intCast(-surface_in.y))
        else
            0;

        const x_end = if (surface_in.x < 0)
            @min(in_w, out_w + @as(usize, @intCast(-surface_in.x)))
        else
            @min(in_w, out_w - @as(usize, @intCast(surface_in.x)));

        const y_end = if (surface_in.y < 0)
            @min(in_h, out_h + @as(usize, @intCast(-surface_in.y)))
        else
            @min(in_h, out_h - @as(usize, @intCast(surface_in.y)));

        // render
        for (y_start..y_end) |y| {
            for (x_start..x_end) |x| {
                const idx_in = x + y * in_w;
                if (surface_in.shadow_map[idx_in] != 0) {
                    const out_x = @as(i32, @intCast(x)) + surface_in.x;
                    const out_y = @as(i32, @intCast(y)) + surface_in.y;
                    if (out_x >= 0 and out_y >= 0 and out_x < @as(
                        i32,
                        @intCast(out_w),
                    ) and out_y < @as(i32, @intCast(out_h))) {
                        const idx_out = @as(usize, @intCast(out_x)) +
                            @as(usize, @intCast(out_y)) * out_w;
                        out_surface.color_map[idx_out] =
                            surface_in.color_map[idx_in];
                        out_surface.shadow_map[idx_out] = 1;
                        out_surface.char_map[idx_out] =
                            surface_in.char_map[idx_in];
                    }
                }
            }
        }
    }

    /// Composites multiple input surfaces into one output surface,
    /// assuming all surfaces are the same size and ignoring position offsets.
    pub fn renderComposite(
        surfaces_in: []const *movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
    ) void {
        const w = out_surface.w;
        const h = out_surface.h;

        for (0..surfaces_in.len) |i| {
            const surface_in = surfaces_in[i];
            for (0..h) |y| {
                for (0..w) |x| {
                    const idx = x + y * w;
                    if (surface_in.shadow_map[idx] != 0) {
                        if (out_surface.shadow_map[idx] != 1) {
                            out_surface.color_map[idx] =
                                surface_in.color_map[idx];
                            out_surface.shadow_map[idx] = 1;
                            out_surface.char_map[idx] =
                                surface_in.char_map[idx];
                        }
                    }
                }
            }
        }
    }
};
