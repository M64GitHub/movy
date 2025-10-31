const movy = @import("../movy.zig");
const std = @import("std");

pub const RenderEngine = struct {
    /// Sorts surface indices by Z value (highest Z first, frontto-back rendering)
    /// Skips sort if all Z values are equal
    /// Handles up to 2048 surfaces with stack allocation
    fn zSort(surfaces: []const *movy.core.RenderSurface, indices: []usize) void {
        const count = @min(surfaces.len, indices.len);

        for (0..count) |i| {
            indices[i] = i;
        }

        // Quick check: if all Z equal, skip expensive sort
        if (count > 1) {
            var needs_sort = false;
            const first_z = surfaces[0].z;
            for (1..count) |i| {
                if (surfaces[i].z != first_z) {
                    needs_sort = true;
                    break;
                }
            }

            if (needs_sort) {
                std.mem.sort(usize, indices[0..count], surfaces, struct {
                    fn compareZ(
                        s: []const *movy.core.RenderSurface,
                        a: usize,
                        b: usize,
                    ) bool {
                        return s[a].z > s[b].z; // Descending: highest Z first
                    }
                }.compareZ);
            }
        }
    }

    /// Merges multiple surfaces into one with z-index and clipping
    /// Surfaces are rendered front-to-back (highest Z first)
    pub fn render(
        surfaces_in: []const *movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
    ) void {
        // Z-sort surfaces (front-to-back, highest Z first)
        var indices: [2048]usize = undefined;
        zSort(surfaces_in, &indices);
        const surface_count = @min(surfaces_in.len, 2048);

        for (indices[0..surface_count]) |i| {
            const surface_in = surfaces_in[i];
            const in_w = surface_in.w;
            const in_h = surface_in.h;
            const out_w = out_surface.w;
            const out_h = out_surface.h;

            // Early rejection - surface completely off-screen
            if (surface_in.x < -@as(i32, @intCast(surface_in.w))) continue;
            if (surface_in.y < -@as(i32, @intCast(surface_in.h))) continue;

            // Calculate clipping bounds once
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

            // Hoist invariant calculations outside inner loops
            const x_offset = surface_in.x;
            const y_offset = surface_in.y;
            const out_h_i32 = @as(i32, @intCast(out_h));
            const out_w_i32 = @as(i32, @intCast(out_w));

            // Process row by row
            for (y_start..y_end) |y| {
                // Calculate output Y position once per row
                const out_y = @as(i32, @intCast(y)) + y_offset;

                // Skip entire row if out of bounds
                if (out_y < 0 or out_y >= out_h_i32) continue;

                // Pre-compute row offsets once per row
                const out_y_usize = @as(usize, @intCast(out_y));
                const out_row_offset = out_y_usize * out_w;
                const in_row_offset = y * in_w;

                // Process each pixel in the row
                for (x_start..x_end) |x| {
                    const idx_in = in_row_offset + x;

                    // Skip transparent pixels
                    if (surface_in.shadow_map[idx_in] == 0) continue;

                    // Calculate output X position
                    const out_x = @as(i32, @intCast(x)) + x_offset;
                    if (out_x < 0 or out_x >= out_w_i32) continue;

                    // Use pre-computed row offset
                    const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                    // Only write if destination is not already occupied
                    if (out_surface.shadow_map[idx_out] != 1) {
                        out_surface.color_map[idx_out] = surface_in.color_map[idx_in];
                        out_surface.shadow_map[idx_out] = 1;
                        out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
                    }
                }
            }
        }
    }

    /// Merges multiple surfaces into one, overwriting areas
    /// Surfaces are rendered front-to-back (highest Z first)
    pub fn renderOver(
        surfaces_in: []const *movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
    ) void {
        // Z-sort surfaces (front-to-back, highest Z first)
        var indices: [2048]usize = undefined;
        zSort(surfaces_in, &indices);
        const surface_count = @min(surfaces_in.len, 2048);

        for (indices[0..surface_count]) |i| {
            const surface_in = surfaces_in[i];
            const in_w = surface_in.w;
            const in_h = surface_in.h;
            const out_w = out_surface.w;
            const out_h = out_surface.h;

            // Early rejection - surface completely off-screen
            if (surface_in.x < -@as(i32, @intCast(surface_in.w))) continue;
            if (surface_in.y < -@as(i32, @intCast(surface_in.h))) continue;

            // Calculate clipping bounds once
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

            // Hoist invariant calculations outside inner loops
            const x_offset = surface_in.x;
            const y_offset = surface_in.y;
            const out_h_i32 = @as(i32, @intCast(out_h));
            const out_w_i32 = @as(i32, @intCast(out_w));

            // Process row by row
            for (y_start..y_end) |y| {
                // Calculate output Y position once per row
                const out_y = @as(i32, @intCast(y)) + y_offset;

                // Skip entire row if out of bounds
                if (out_y < 0 or out_y >= out_h_i32) continue;

                // Pre-compute row offsets once per row
                const out_y_usize = @as(usize, @intCast(out_y));
                const out_row_offset = out_y_usize * out_w;
                const in_row_offset = y * in_w;

                // Process each pixel in the row
                for (x_start..x_end) |x| {
                    const idx_in = in_row_offset + x;

                    // Skip transparent pixels
                    if (surface_in.shadow_map[idx_in] == 0) continue;

                    // Calculate output X position
                    const out_x = @as(i32, @intCast(x)) + x_offset;
                    if (out_x < 0 or out_x >= out_w_i32) continue;

                    // Use pre-computed row offset
                    const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                    // Always overwrite (no shadow_map check)
                    // (that's the purpose of renderOver)
                    out_surface.color_map[idx_out] = surface_in.color_map[idx_in];
                    out_surface.shadow_map[idx_out] = 1;
                    out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
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

        // Early rejection - surface completely off-screen
        if (surface_in.x < -@as(i32, @intCast(surface_in.w))) return;
        if (surface_in.y < -@as(i32, @intCast(surface_in.h))) return;

        // Calculate clipping bounds once
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

        // Hoist invariant calculations outside inner loops
        const x_offset = surface_in.x;
        const y_offset = surface_in.y;
        const out_h_i32 = @as(i32, @intCast(out_h));
        const out_w_i32 = @as(i32, @intCast(out_w));

        // Process row by row
        for (y_start..y_end) |y| {
            // Calculate output Y position once per row
            const out_y = @as(i32, @intCast(y)) + y_offset;

            // Skip entire row if out of bounds
            if (out_y < 0 or out_y >= out_h_i32) continue;

            // Pre-compute row offsets once per row
            const out_y_usize = @as(usize, @intCast(out_y));
            const out_row_offset = out_y_usize * out_w;
            const in_row_offset = y * in_w;

            // Process each pixel in the row
            for (x_start..x_end) |x| {
                const idx_in = in_row_offset + x;

                // Skip transparent pixels
                if (surface_in.shadow_map[idx_in] == 0) continue;

                // Calculate output X position
                const out_x = @as(i32, @intCast(x)) + x_offset;
                if (out_x < 0 or out_x >= out_w_i32) continue;

                // Use pre-computed row offset
                const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                // Always overwrite (no shadow_map check)
                // (that's the purpose of renderSurfaceOver)
                out_surface.color_map[idx_out] = surface_in.color_map[idx_in];
                out_surface.shadow_map[idx_out] = 1;
                out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
            }
        }
    }

    /// Composites multiple input surfaces into one output surface,
    /// assuming all surfaces are the same size and ignoring position offsets.
    /// Surfaces are rendered front-to-back (highest Z first)
    pub fn renderComposite(
        surfaces_in: []const *movy.core.RenderSurface,
        out_surface: *movy.core.RenderSurface,
    ) void {
        // Z-sort surfaces (front-to-back, highest Z first)
        var indices: [2048]usize = undefined;
        zSort(surfaces_in, &indices);
        const surface_count = @min(surfaces_in.len, 2048);

        const w = out_surface.w;
        const h = out_surface.h;

        for (indices[0..surface_count]) |i| {
            const surface_in = surfaces_in[i];
            for (0..h) |y| {
                // Pre-compute row offset once per row
                const row_offset = y * w;

                for (0..w) |x| {
                    const idx = row_offset + x;
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
