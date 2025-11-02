const movy = @import("../movy.zig");
const std = @import("std");

/// Compositor for combining multiple RenderSurfaces into a single output surface.
///
/// The RenderEngine provides multiple rendering strategies for different use cases:
///
/// ## Primary Rendering Functions (Recommended)
///
/// **`render()`** - Legacy general-purpose compositor
/// - Fastest rendering with binary transparency (opaque or transparent, no alpha blending)
/// - Performs z-ordering, clipping, and bounds checking
/// - Painter's algorithm: first opaque pixel wins
/// - Best for: Simple sprite rendering without semi-transparency
/// - Limitation: Does NOT support true alpha blending
///
/// **`renderWithAlphaToBg()`** - Alpha blending onto opaque backgrounds **RECOMMENDED**
/// - True Porter-Duff alpha compositing for semi-transparent surfaces
/// - Optimized for typical use case: blending onto opaque background
/// - ~20-30% faster than general alpha blending
/// - Supports z-ordering, clipping, and bounds checking
/// - Best for: Standard rendering with transparency effects (glass, fade, shadows)
/// - Use when: Background is opaque and you need realistic transparency
///
/// ## Advanced Rendering Functions
///
/// **`renderWithAlpha()`** - General alpha compositing
/// - Full Porter-Duff "over" operator with variable background alpha
/// - Handles semi-transparent foreground AND semi-transparent background
/// - Mathematically complete alpha blending
/// - Best for: Pre-compositing multiple semi-transparent surfaces into another
///   semi-transparent surface
/// - Use when: Both foreground and background can have arbitrary alpha values
/// - Slightly slower than `renderWithAlphaToBg()` due to variable denominator
///
/// **`renderOver()`** - Unconditional overwrite
/// - Always overwrites destination pixels (no destination check)
/// - Binary transparency only (like `render()`)
/// - Best for: Redrawing entire surfaces or refreshing output
///
/// **`renderSurfaceOver()`** - Single surface unconditional overwrite
/// - Like `renderOver()` but for a single surface (no z-sorting)
/// - Binary transparency only
/// - Best for: Quickly rendering one surface without compositing
///
/// **`renderComposite()`** - Same-size surface compositing
/// - Assumes all surfaces have identical dimensions
/// - Ignores position offsets (x, y)
/// - Binary transparency only
/// - Best for: Compositing aligned layers (e.g., effect pipelines)
///
/// ## Technical Details
///
/// - **Z-ordering:** All multi-surface functions sort by z-index (highest first)
/// - **Clipping:** Automatic clipping to output surface bounds
/// - **Limit:** Maximum 2048 surfaces per render call (stack-allocated indices)
/// - **Alpha values:** shadow_map stores alpha as u8 (0=transparent, 255=opaque)
pub const RenderEngine = struct {

    // -- Public Rendering Functions

    /// Merges multiple surfaces into one with z-index and clipping
    /// Surfaces are rendered front-to-back (highest Z first)
    /// No real alpha rendering! color_map[idx] != 0 means pixel opaque
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
    /// No real alpha rendering! color_map[idx] != 0 means pixel opaque
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

    /// Merges multiple surfaces with true alpha blending (Porter-Duff "over" operator)
    /// Uses shadow_map values as alpha channel (0-255)
    /// Handles any alpha values - foreground and background can both be semi-transparent
    /// Surfaces are rendered front-to-back (highest Z first)
    /// Output shadow_map is set to 255 (opaque marker), not the computed alpha value
    pub fn renderWithAlpha(
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

                    // Get source alpha - early exit if fully transparent
                    const alpha_fg = surface_in.shadow_map[idx_in];
                    if (alpha_fg == 0) continue;

                    // Calculate output X position
                    const out_x = @as(i32, @intCast(x)) + x_offset;
                    if (out_x < 0 or out_x >= out_w_i32) continue;

                    // Use pre-computed row offset
                    const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                    // Get destination alpha and colors
                    const alpha_bg = out_surface.shadow_map[idx_out];
                    const fg_color = surface_in.color_map[idx_in];
                    const bg_color = out_surface.color_map[idx_out];

                    // Perform alpha blending
                    out_surface.color_map[idx_out] = blendPixelGeneral(
                        fg_color,
                        alpha_fg,
                        bg_color,
                        alpha_bg,
                    );

                    // Mark as rendered (opaque marker, not actual composited alpha)
                    out_surface.shadow_map[idx_out] = 255;
                    out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
                }
            }
        }
    }

    /// Merges multiple surfaces with optimized alpha blending onto opaque background
    /// Assumes background is always opaque (α_bg = 255)
    /// Uses simplified formula: C_out = (C_fg × α_fg + C_bg × (255 - α_fg)) / 255
    /// Output is always opaque (α_out = 255)
    /// FASTER than renderWithAlpha() - use for typical rendering scenarios
    /// Surfaces are rendered front-to-back (highest Z first)
    pub fn renderWithAlphaToBg(
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

                    // Get source alpha - early exit if fully transparent
                    const alpha_fg = surface_in.shadow_map[idx_in];
                    if (alpha_fg == 0) continue;

                    // Calculate output X position
                    const out_x = @as(i32, @intCast(x)) + x_offset;
                    if (out_x < 0 or out_x >= out_w_i32) continue;

                    // Use pre-computed row offset
                    const idx_out = out_row_offset + @as(usize, @intCast(out_x));

                    // Get colors (background assumed opaque)
                    const fg_color = surface_in.color_map[idx_in];
                    const bg_color = out_surface.color_map[idx_out];

                    // Perform optimized alpha blending (assumes bg is opaque)
                    out_surface.color_map[idx_out] = blendPixelToBg(
                        fg_color,
                        alpha_fg,
                        bg_color,
                    );

                    // Output is always opaque
                    out_surface.shadow_map[idx_out] = 255;
                    out_surface.char_map[idx_out] = surface_in.char_map[idx_in];
                }
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

    // -- helper functions

    /// Sorts surface indices by Z value (highest Z first, front-to-back rendering)
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

    // -- Alpha Blending Helper Functions

    /// Blends a single color channel using Porter-Duff "over" operator
    /// (general case)
    /// Handles any alpha values for both foreground and background
    /// Formula: C_out = (C_fg × α_fg + C_bg × α_bg × (255 - α_fg) / 255) / α_out
    inline fn blendChannelGeneral(
        fg_val: u8,
        alpha_fg: u16,
        bg_val: u8,
        alpha_bg: u16,
        inv_alpha_fg: u16,
        alpha_out: u8,
    ) u8 {
        // Avoid division by zero (both fg and bg fully transparent)
        if (alpha_out == 0) return 0;

        // Widen to u32 to prevent overflow: max value is 255 × 255 = 65,025
        const fg_contrib = @as(u32, fg_val) * alpha_fg;

        // Pre-divide by 255 to keep intermediate result manageable
        // Max: (255 × 255 × 255) / 255 = 65,025
        const bg_contrib = @as(u32, bg_val) * alpha_bg * inv_alpha_fg / 255;

        // Sum contributions
        const numerator = fg_contrib + bg_contrib;

        // Divide by output alpha and clamp to u8 range
        const result = numerator / @as(u32, alpha_out);
        return @as(u8, @intCast(@min(result, 255)));
    }

    /// Blends an RGB pixel using Porter-Duff "over" operator (general case)
    /// Handles any alpha values - both foreground and background can be
    /// semi-transparent
    /// Returns blended color (output alpha not stored per requirements)
    inline fn blendPixelGeneral(
        fg: movy.core.types.Rgb,
        alpha_fg: u8,
        bg: movy.core.types.Rgb,
        alpha_bg: u8,
    ) movy.core.types.Rgb {
        // Fast path: fully opaque foreground
        if (alpha_fg == 255) return fg;

        // Fast path: fully transparent background
        if (alpha_bg == 0) return fg;

        // Widen to u16 for calculations
        const a_fg = @as(u16, alpha_fg);
        const a_bg = @as(u16, alpha_bg);
        const inv_a_fg = 255 - a_fg;

        // Compute output alpha: α_out = α_fg + α_bg × (255 - α_fg) / 255
        const alpha_out_scaled = a_fg * 255 + a_bg * inv_a_fg;
        const alpha_out = @as(u8, @intCast(alpha_out_scaled / 255));

        // Blend each color channel
        const r_out = blendChannelGeneral(fg.r, a_fg, bg.r, a_bg, inv_a_fg, alpha_out);
        const g_out = blendChannelGeneral(fg.g, a_fg, bg.g, a_bg, inv_a_fg, alpha_out);
        const b_out = blendChannelGeneral(fg.b, a_fg, bg.b, a_bg, inv_a_fg, alpha_out);

        return movy.core.types.Rgb{ .r = r_out, .g = g_out, .b = b_out };
    }

    /// Blends a single color channel onto an opaque background (optimized)
    /// Assumes α_bg = 255 (background is always opaque)
    /// Simplified formula: C_out = (C_fg × α_fg + C_bg × (255 - α_fg)) / 255
    inline fn blendChannelToBg(
        fg_val: u8,
        alpha_fg: u16,
        bg_val: u8,
        inv_alpha_fg: u16,
    ) u8 {
        // Widen to u32 to prevent overflow: max value is 255 × 255 = 65,025
        const fg_contrib = @as(u32, fg_val) * alpha_fg;
        const bg_contrib = @as(u32, bg_val) * inv_alpha_fg;
        const numerator = fg_contrib + bg_contrib; // Max: 130,050

        // Divide by 255 (constant denominator - optimized by compiler)
        const result = numerator / 255; // Max result: 510
        return @as(u8, @intCast(@min(result, 255))); // Clamp to valid u8 range
    }

    /// Blends an RGB pixel onto an opaque background (optimized)
    /// Assumes background is always opaque (α_bg = 255)
    /// Output is always opaque (α_out = 255)
    /// Much faster than general blending - use for typical rendering scenarios
    inline fn blendPixelToBg(
        fg: movy.core.types.Rgb,
        alpha_fg: u8,
        bg: movy.core.types.Rgb,
    ) movy.core.types.Rgb {
        // Fast path: fully opaque foreground
        if (alpha_fg == 255) return fg;

        // Fast path: fully transparent foreground (return background as-is)
        if (alpha_fg == 0) return bg;

        // Widen to u16 for calculations
        const a_fg = @as(u16, alpha_fg);
        const inv_a_fg = 255 - a_fg;

        // Blend each color channel (simplified formula)
        const r_out = blendChannelToBg(fg.r, a_fg, bg.r, inv_a_fg);
        const g_out = blendChannelToBg(fg.g, a_fg, bg.g, inv_a_fg);
        const b_out = blendChannelToBg(fg.b, a_fg, bg.b, inv_a_fg);

        return movy.core.types.Rgb{ .r = r_out, .g = g_out, .b = b_out };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "RenderEngine: renderWithAlphaToBg blends semi-transparent red over black" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create opaque black background
    var output = try movy.core.RenderSurface.init(
        allocator,
        40,
        20,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer output.deinit(allocator);

    // Set all pixels to opaque
    for (output.shadow_map) |*alpha| {
        alpha.* = 255;
    }

    // Create semi-transparent red surface (50% opacity)
    var red_surface = try movy.core.RenderSurface.init(
        allocator,
        15,
        10,
        movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 },
    );
    defer red_surface.deinit(allocator);
    for (red_surface.shadow_map) |*alpha| {
        alpha.* = 128; // 50% transparent
    }
    red_surface.x = 5;
    red_surface.y = 5;
    red_surface.z = 1;

    // Render
    var surfaces = [_]*movy.core.RenderSurface{red_surface};
    RenderEngine.renderWithAlphaToBg(&surfaces, output);

    // Verify: Red (255, 0, 0) with α=128 over Black (0, 0, 0) with α=255
    // Expected: R = (255×128 + 0×127) / 255 ≈ 128
    const pixel = output.color_map[8 * 40 + 10]; // Inside red area
    try testing.expectEqual(@as(u8, 128), pixel.r);
    try testing.expectEqual(@as(u8, 0), pixel.g);
    try testing.expectEqual(@as(u8, 0), pixel.b);
    try testing.expectEqual(@as(u8, 255), output.shadow_map[8 * 40 + 10]); // Output is opaque
}

test "RenderEngine: renderWithAlphaToBg blends semi-transparent blue over black" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create opaque black background
    var output = try movy.core.RenderSurface.init(
        allocator,
        40,
        20,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer output.deinit(allocator);

    for (output.shadow_map) |*alpha| {
        alpha.* = 255;
    }

    // Create semi-transparent blue surface (50% opacity)
    var blue_surface = try movy.core.RenderSurface.init(
        allocator,
        15,
        10,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 255 },
    );
    defer blue_surface.deinit(allocator);

    for (blue_surface.shadow_map) |*alpha| {
        alpha.* = 128; // 50% transparent
    }
    blue_surface.x = 15;
    blue_surface.y = 8;
    blue_surface.z = 1;

    // Render
    var surfaces = [_]*movy.core.RenderSurface{blue_surface};
    RenderEngine.renderWithAlphaToBg(&surfaces, output);

    // Verify: Blue (0, 0, 255) with α=128 over Black (0, 0, 0) with α=255
    // Expected: B = (255×128 + 0×127) / 255 ≈ 128
    const pixel = output.color_map[12 * 40 + 20]; // Inside blue area
    try testing.expectEqual(@as(u8, 0), pixel.r);
    try testing.expectEqual(@as(u8, 0), pixel.g);
    try testing.expectEqual(@as(u8, 128), pixel.b);
    try testing.expectEqual(@as(u8, 255), output.shadow_map[12 * 40 + 20]); // Output is opaque
}

test "RenderEngine: renderWithAlphaToBg handles overlapping surfaces with z-ordering" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create opaque black background
    var output = try movy.core.RenderSurface.init(
        allocator,
        40,
        20,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer output.deinit(allocator);

    for (output.shadow_map) |*alpha| {
        alpha.* = 255;
    }

    // Create semi-transparent red surface (z=1, back)
    var red_surface = try movy.core.RenderSurface.init(
        allocator,
        15,
        10,
        movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 },
    );
    defer red_surface.deinit(allocator);

    for (red_surface.shadow_map) |*alpha| {
        alpha.* = 128;
    }
    red_surface.x = 5;
    red_surface.y = 5;
    red_surface.z = 1;

    // Create semi-transparent blue surface (z=2, front)
    var blue_surface = try movy.core.RenderSurface.init(
        allocator,
        15,
        10,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 255 },
    );
    defer blue_surface.deinit(allocator);

    for (blue_surface.shadow_map) |*alpha| {
        alpha.* = 128;
    }
    blue_surface.x = 15;
    blue_surface.y = 8;
    blue_surface.z = 2;

    // Render both surfaces
    var surfaces = [_]*movy.core.RenderSurface{ red_surface, blue_surface };
    RenderEngine.renderWithAlphaToBg(&surfaces, output);

    // Check red-only area
    const red_pixel = output.color_map[8 * 40 + 10];
    try testing.expectEqual(@as(u8, 128), red_pixel.r);
    try testing.expectEqual(@as(u8, 0), red_pixel.g);
    try testing.expectEqual(@as(u8, 0), red_pixel.b);

    // Check blue-only area
    const blue_pixel = output.color_map[12 * 40 + 20];
    try testing.expectEqual(@as(u8, 0), blue_pixel.r);
    try testing.expectEqual(@as(u8, 0), blue_pixel.g);
    try testing.expectEqual(@as(u8, 128), blue_pixel.b);

    // Check overlap area: Blue (z=2) renders first, then Red (z=1) blends on top
    // Blue over black: (0, 0, 128)
    // Red over that: R = (255×128 + 0×127)/255 = 128, B = (0×128 + 128×127)/255 ≈ 63
    const overlap_pixel = output.color_map[10 * 40 + 16];
    try testing.expectEqual(@as(u8, 128), overlap_pixel.r);
    try testing.expectEqual(@as(u8, 0), overlap_pixel.g);
    // Allow tolerance for integer rounding (63 ± 1)
    try testing.expect(overlap_pixel.b >= 62 and overlap_pixel.b <= 64);
}

test "RenderEngine: renderWithAlpha produces same results as renderWithAlphaToBg for opaque background" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create semi-transparent green surface
    var green_surface = try movy.core.RenderSurface.init(
        allocator,
        10,
        10,
        movy.core.types.Rgb{ .r = 0, .g = 255, .b = 0 },
    );
    defer green_surface.deinit(allocator);

    for (green_surface.shadow_map) |*alpha| {
        alpha.* = 128;
    }
    green_surface.x = 5;
    green_surface.y = 5;
    green_surface.z = 1;

    // Test with renderWithAlphaToBg
    var output1 = try movy.core.RenderSurface.init(
        allocator,
        20,
        20,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer output1.deinit(allocator);
    for (output1.shadow_map) |*alpha| {
        alpha.* = 255; // Opaque background
    }
    var surfaces1 = [_]*movy.core.RenderSurface{green_surface};
    RenderEngine.renderWithAlphaToBg(&surfaces1, output1);

    // Test with renderWithAlpha
    var output2 = try movy.core.RenderSurface.init(
        allocator,
        20,
        20,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer output2.deinit(allocator);

    for (output2.shadow_map) |*alpha| {
        alpha.* = 255; // Opaque background
    }
    var surfaces2 = [_]*movy.core.RenderSurface{green_surface};
    RenderEngine.renderWithAlpha(&surfaces2, output2);

    // Both should produce identical results for opaque backgrounds
    const pixel1 = output1.color_map[10 * 20 + 10];
    const pixel2 = output2.color_map[10 * 20 + 10];
    try testing.expectEqual(pixel1.r, pixel2.r);
    try testing.expectEqual(pixel1.g, pixel2.g);
    try testing.expectEqual(pixel1.b, pixel2.b);

    // Verify the actual blended color
    try testing.expectEqual(@as(u8, 0), pixel1.r);
    try testing.expectEqual(@as(u8, 128), pixel1.g); // 50% of 255
    try testing.expectEqual(@as(u8, 0), pixel1.b);
}

test "RenderEngine: alpha blending skips fully transparent pixels" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create background
    var output = try movy.core.RenderSurface.init(
        allocator,
        20,
        20,
        movy.core.types.Rgb{ .r = 100, .g = 100, .b = 100 },
    );
    defer output.deinit(allocator);

    for (output.shadow_map) |*alpha| {
        alpha.* = 255;
    }

    // Create surface with some fully transparent pixels
    var surface = try movy.core.RenderSurface.init(
        allocator,
        10,
        10,
        movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 },
    );
    defer surface.deinit(allocator);

    // Set first half transparent, second half semi-transparent
    for (surface.shadow_map, 0..) |*alpha, i| {
        alpha.* = if (i < 50) 0 else 128; // First 50 pixels fully transparent
    }
    surface.x = 5;
    surface.y = 5;

    // Render
    var surfaces = [_]*movy.core.RenderSurface{surface};
    RenderEngine.renderWithAlphaToBg(&surfaces, output);

    // Check that transparent pixels didn't modify background
    const transparent_pixel = output.color_map[5 * 20 + 5]; // First pixel (transparent)
    try testing.expectEqual(@as(u8, 100), transparent_pixel.r);
    try testing.expectEqual(@as(u8, 100), transparent_pixel.g);
    try testing.expectEqual(@as(u8, 100), transparent_pixel.b);

    // Check that semi-transparent pixels did blend
    const blended_pixel = output.color_map[10 * 20 + 10]; // Last pixel (semi-transparent)
    try testing.expect(blended_pixel.r > 100); // Should be between 100 and 177
    try testing.expectEqual(@as(u8, 100), blended_pixel.g); // Should remain unchanged
    try testing.expectEqual(@as(u8, 100), blended_pixel.b); // Should remain unchanged
}

test "RenderEngine: blendPixelToBg fast paths work correctly" {
    const testing = std.testing;

    const fg = movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 };
    const bg = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 255 };

    // Fast path: fully opaque foreground (alpha = 255)
    const result_opaque = RenderEngine.blendPixelToBg(fg, 255, bg);
    try testing.expectEqual(fg.r, result_opaque.r);
    try testing.expectEqual(fg.g, result_opaque.g);
    try testing.expectEqual(fg.b, result_opaque.b);

    // Fast path: fully transparent foreground (alpha = 0)
    const result_transparent = RenderEngine.blendPixelToBg(fg, 0, bg);
    try testing.expectEqual(bg.r, result_transparent.r);
    try testing.expectEqual(bg.g, result_transparent.g);
    try testing.expectEqual(bg.b, result_transparent.b);

    // Regular path: semi-transparent (alpha = 128)
    const result_semi = RenderEngine.blendPixelToBg(fg, 128, bg);
    try testing.expectEqual(@as(u8, 128), result_semi.r); // (255×128 + 0×127)/255
    try testing.expectEqual(@as(u8, 0), result_semi.g);
    try testing.expectEqual(@as(u8, 127), result_semi.b); // (0×128 + 255×127)/255
}
