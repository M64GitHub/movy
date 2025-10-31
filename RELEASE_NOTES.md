# Release Notes

## v0.0.3 - Performance Optimizations & Z-Ordering Implementation

### Performance Improvements

#### RenderEngine Optimizations

All render functions in `RenderEngine` have been optimized with overdue performance improvements:

**Optimized Functions:**
- `render()` - Core surface compositing with z-index and clipping
- `renderOver()` - Surface compositing with overwrite behavior
- `renderSurfaceOver()` - Single surface rendering with overwrite
- `renderComposite()` - Aligned surface compositing

**Optimization Techniques Applied:**
1. **Hoisted invariant calculations** - Position offsets, dimension casts computed once per surface instead of per-pixel
2. **Pre-computed row offsets** - Row multiplication eliminated from inner loops (computed once per row instead of per-pixel)
3. **Early row rejection** - Entire rows skipped when out of bounds
4. **Reduced type conversions** - Integer casts moved outside hot loops

**Performance Impact:**
- Cleaner, more maintainable code
- Better compiler optimization opportunities
- Eliminates hundreds of redundant calculations per frame (if not hoisted by compiler)
- Modest performance gains (0.7-2% in stress tests, but more significant in complex scenes)

### Z-Index Ordering Implementation

**New/overdue Feature:** All render functions now properly respect surface z-index values for correct layering.

#### New `zSort()` Helper Function

An efficient z-ordering implementation optimized for typical use cases:

```zig
/// Sorts surface indices by Z value (highest Z first, back-to-front rendering)
/// Optimized: skips sort if all Z values are equal -> previous behaviour
/// Handles up to 2048 surfaces with stack allocation
fn zSort(surfaces: []const *RenderSurface, indices: []usize) void
```

**Key Features:**
- **Smart optimization:** Zero-cost when all Z values are equal (common single-layer case)
- **Stack allocation:** Uses 16 KB stack buffer for up to 2048 surfaces
- **Stable sort:** Preserves insertion order for surfaces with equal Z values
- **Graceful handling:** Silent truncation beyond 2048 surfaces (extremely rare edge case)
- **Back-to-front rendering:** Highest Z renders first (foreground), lowest Z renders last (background)

**Rendering Order:**
- **Before:** Surfaces rendered in array insertion order
- **After:** Surfaces rendered by Z value

**Performance Overhead:**
- ~2% when sorting needed (2-20 surfaces typical)
- 0% when all Z values equal (optimization skips sort)

### Render Performance Testing Infrastructure

#### New Stress Test

Added `examples/render_stress_test.zig`:
- 100,000 iteration render benchmark
- 200×100 pixel output surface
- 2 moving, overlapping sprites
- Reports: iterations/sec, time per iteration, megapixels/sec
- Run with: `zig build run-render_stress_test`

**Baseline Performance (Apple Silicon M4-series):**
- ~50,000 iterations/second
- ~19-20 µs per iteration
- ~1,000-1,040 megapixels/second
- 100k iterations in ~1.9-2.0 seconds

### Technical Details

#### Modified Files:
- `src/render/RenderEngine.zig` - All optimizations and z-ordering
- `examples/render_stress_test.zig` - New performance testing tool
- `build.zig` - Added stress test build target

#### API Compatibility:
- **No breaking changes** - All function signatures unchanged
- **Behavioral change:** Z-index now properly respected (surfaces with higher Z render first)
- **Performance:** Optimizations are transparent

#### Code Quality:
- Added comments explaining optimizations
- DRY principle: Single `zSort()` function reused across all render methods
- Improved code readability with clearer variable names
- Better documentation of rendering order

---

### Impact on Applications

**Before these changes:**
- Surface layering was depended on insertion order
- Wasted CPU cycles on redundant calculations

**After these changes:**
- **Proper z-ordering:** Set `surface.z` to control layering (higher Z = foreground)
- **Better performance:** Cleaner code enables better compiler optimizations

**Migration Notes:**
- If you were relying on insertion order for layering, you may need to set explicit Z values
- Default Z value is 0 - surfaces with same Z maintain insertion order (stable sort)
- For most applications, no changes required

