# Release Notes

## v0.1.0

# Performance Optimization - movy v0.1.0

In v0.1.0, I finally took the time to address the main bottleneck in the rendering pipeline: the excessive use of `std.fmt.bufPrint` in `RenderSurface.toAnsi()`. This function is responsible for converting pixel data into ANSI terminal escape sequences and is called for every frame, making it critical to overall performance.

## Results Summary

The result is a **5.5x speedup** on 64x64 sprites!

### Performance Comparison (64x64 Sprite)

#### Before Optimization
```
Time per iteration:  58.48 µs
Throughput:          70.04 MP/sec
```

#### After Optimization
```
Time per iteration:  10.68 µs
Throughput:         383.53 MP/sec

Speedup:            5.5x faster (447% improvement)
```

## Full Performance Comparison Table

Performance improvements across all tested sprite sizes:

| Sprite Size | Before (µs) | After (µs) | Speedup | Before (MP/s) | After (MP/s) |
|-------------|-------------|------------|---------|---------------|--------------|
| 10x10       | 1.55        | 0.29       | **5.3x** | 64.60         | 339.90       |
| 20x20       | 5.84        | 1.17       | **5.0x** | 68.48         | 341.59       |
| 40x40       | 22.76       | 4.78       | **4.8x** | 70.30         | 334.92       |
| 64x64       | 58.48       | 10.68      | **5.5x** | 70.04         | 383.53       |
| 80x80       | 90.06       | 18.55      | **4.9x** | 71.06         | 345.01       |
| 100x100     | 140.74      | 28.55      | **4.9x** | 71.05         | 350.21       |
| 200x200     | 563.13      | 111.77     | **5.0x** | 71.03         | 357.89       |

**Average speedup: 5.1x across all sprite sizes**

## Technical Details

**Optimization:** Replaced `std.fmt.bufPrint` with manual RGB formatting using direct digit conversion.

**Impact:**
- Eliminated format string parsing overhead
- Removed function call overhead in hot path
- Maintained exact same output format

**Location:** `src/core/RenderSurface.zig` - Added inline `formatFgColor()` and `formatBgColor()` helper functions.

## What This Means

This optimization enables significantly more complex terminal graphics! The rendering pipeline can now handle:
- More sprites per frame at 60 FPS
- Larger screen sizes with less overhead
- More complex effect chains without performance degradation

---

## v0.0.4, 0.0.5 

<img width="895" height="423" alt="image" src="https://github.com/user-attachments/assets/e233388d-b858-4c41-8c63-d2639f594f1e" />


# MOVY Performance Suite

I built this to be able to trace down and measure performance bottlenecks / -improvements.  

The performance suite tests three critical parts of the MOVY rendering pipeline: ANSI conversion, sprite rendering, and the combined render-to-ANSI flow. It runs 100-thousands of iterations, collects detailed metrics, and generates an interactive visualization dashboard so you can actually see what's going on.

## Quick Start

Run the full test suite:

```bash
zig build perf-runner
```

This takes a few minutes (it runs 100,000 iterations by default). When it's done, you'll get:
- JSON files with raw performance data in `perf-results/<timestamp>/`
- An automatically generated HTML dashboard at `perf-results/index.html`

Open the dashboard:

```bash
open perf-results/index.html
# or click in your file manager
```

You'll see a retro synthwave-themed dashboard with interactive charts showing throughput, and performance profiles across different sprite sizes and rendering configurations.

## What Gets Tested

The suite runs three test types, each targeting a specific part of the rendering pipeline:

### 1. RenderSurface.toAnsi
Tests ANSI conversion performance—how fast we can convert raw pixel data into terminal escape sequences.

**Tests sizes:** 10x10, 25x25, 50x50, 64x64, 100x100, 150x150, 200x200

**Why it matters:** ANSI conversion is our main bottleneck. Every frame needs to be converted before it hits the terminal, so this needs to be fast. The test shows how conversion time scales with sprite size.

### 2. RenderEngine.render_stable
Tests static (not moving / animating) sprite rendering performance—compositing multiple sprites into a single output surface.

**Tests configurations:**
- Square outputs: 64x64, 96x96, 128x128, 160x160, 192x192, 256x256
- 16:9 horizontal: Various widescreen sizes
- 9:16 vertical: Portrait-oriented sizes

**Why it matters:** This is the core rendering loop. It handles z-ordering, alpha blending, and pixel composition. Understanding how it scales across different output sizes and aspect ratios helps optimization.

### 3. RenderEngine.render_stable_with_toAnsi
Tests the full pipeline—render sprites AND convert to ANSI in one measurement.

**Uses same configurations as render_stable**

**Why it matters:** This is what happens in practice. Every frame needs both rendering and ANSI conversion, so measuring them together shows the true end-to-end performance. Comparing this with the individual tests reveals overhead and bottlenecks.

## Directory Structure

```
perf-tst/
├── README.md              # You are here
├── runner.zig             # Test orchestrator
├── html_generator.zig     # Builds the visualization dashboard
├── html_gen_main.zig      # Standalone HTML regeneration tool
├── types.zig              # Shared data structures
├── json_writer.zig        # JSON output formatting
├── tests/                 # Individual test implementations
│   ├── toAnsi_test.zig
│   ├── render_stable_test.zig
│   └── render_stable_with_toAnsi_test.zig
├── web-assets/            # Dashboard templates and styling
│   ├── template.html
│   ├── style.css          # Synthwave theme with neon glow effects
│   └── visualizer.js      # Chart rendering and interactivity
└── assets/
    └── movy-logo.png      # For the dashboard header

perf-results/              # Generated output directory
├── <timestamp-1>/         # Each run gets its own directory
│   ├── RenderSurface.toAnsi_<timestamp>.json
│   ├── RenderEngine.render_stable_<timestamp>.json
│   └── RenderEngine.render_stable_with_toAnsi_<timestamp>.json
├── <timestamp-2>/
│   └── ...
├── index.html             # Interactive dashboard
├── style.css              # Copied from web-assets
├── visualizer.js          # Copied from web-assets
└── movy-logo.png          # Copied from assets
```

Each test run creates a new timestamped directory (e.g., `2025-11-19T14-33-08`). This makes it easy to compare runs over time or after code changes.

## Understanding the Dashboard

The visualization dashboard is designed around a simple idea: show everything that matters, make it easy to explore, and access the raw data.

### Navigation

Click the hamburger menu (top-right) to jump between sections:
- **Overview** - High-level stats and test descriptions
- **Benchmark Runs** - Table of all test runs with system info
- **Performance Charts** - Interactive visualizations
- **Raw Data** - Direct links to JSON files

The menu slides in from the left and closes when you click anywhere outside it, press Escape, or select a section.

### Chart Types

The dashboard includes several chart types, each showing a different perspective on performance:

**Per-Test Charts:**
- Line charts showing throughput (megapixels/sec) vs size
- Bar charts showing time per iteration
- Scatter plots revealing scaling behavior

**Comparison Charts** (comparing all three test types at 64x64):

1. **Simple Bar Chart** - Direct throughput comparison
   - Shows which test is fastest at a glance
   - Typically render_stable is 5-10x faster than the combined pipeline

2. **Grouped Bar Chart** - Multi-metric view with dual Y-axes
   - Left axis (cyan): Megapixels/sec and Speed Index
   - Right axis (magenta): Iterations/sec
   - Shows both throughput and latency characteristics
   - Dual axes solve the scale problem (iterations/sec is ~1000x larger than other metrics)

3. **Radar Chart** - Performance profile across 5 dimensions
   - Normalized metrics show relative strengths
   - Easy to see which test excels where
   - Good for presentations and high-level comparisons

### Interpreting Metrics

**Megapixels/sec (MP/sec)** - Higher is better
- Measures throughput: how many pixels processed per second
- Useful for comparing different implementations
- Scales with sprite/output size

**Iterations/sec** - Higher is better
- How many complete test iterations completed per second
- Better for comparing efficiency across different sizes
- More stable metric for micro-benchmarks

**Time per iteration (μs)** - Lower is better
- Latency metric: how long each iteration takes
- More intuitive for understanding frame budgets
- "Can I hit 60 FPS?" → Need < 16,667 μs per frame

**Speed Index** - Higher is better
- Computed as `(1 / time_per_iter_us) × 1000`
- Inverse of latency, normalized for visibility in charts
- Matches the intuition that "faster = higher"

## Advanced Usage

### Running Specific Tests

```bash
# Only test ANSI conversion
zig build perf-runner -- -tests "toAnsi"

# Test rendering only (skip ANSI conversion)
zig build perf-runner -- -tests "render_stable"

# Run multiple tests
zig build perf-runner -- -tests "toAnsi,render_stable"
```

### Custom Iteration Count

The default 100,000 iterations is thorough but might be slow on your system. Reduce it for quick checks:

```bash
# Fast run for development (still statistically valid)
zig build perf-runner -- -iterations 10000

# Very quick sanity check
zig build perf-runner -- -iterations 1000
```

Higher iteration counts give more stable numbers but take longer. 10,000 is usually enough for development work.

### Regenerating Visualizations

Made changes to the dashboard CSS or JavaScript? Regenerate the HTML without rerunning tests:

```bash
zig build perf-html-gen
```

This scans `perf-results/` for all test runs and rebuilds `index.html` with the updated styling and charts. Useful when tweaking the visualization or adding new chart types.

You can also run the generator directly with a custom directory:

```bash
./zig-out/bin/perf-html-gen my-custom-results
```

### Custom Output Directory

```bash
zig build perf-runner -- -output_dir my-results
```

Results will go to `my-results/<timestamp>/` instead of the default `perf-results/`.

## Technical Notes

### JSON Output Format

Each test produces a JSON file with this structure:

```json
{
  "test_name": "RenderSurface.toAnsi",
  "timestamp": "2025-11-19T14-33-08",
  "system_info": {
    "cpu_model": "aarch64 (apple_m4)",
    "cpu_cores": 10,
    "os": "macos",
    "zig_version": "0.15.2",
    "build_mode": "ReleaseFast"
  },
  "results": [
    {
      "name": "64x64",
      "width": 64,
      "height": 64,
      "pixels": 4096,
      "iterations": 100000,
      "elapsed_ns": 5869437000,
      "time_per_iter_us": 58.69,
      "iter_per_sec": 17039.91,
      "megapixels_per_sec": 69.79
    }
  ]
}
```

All timing fields use high-precision measurements. The `elapsed_ns` field is the raw nanosecond count from `std.time.nanoTimestamp()`. Derived metrics are calculated to avoid rounding errors.

### Build Integration

The performance suite is fully integrated with the main MOVY build system:

- `perf-runner` - Runs tests and generates HTML
- `perf-html-gen` - Regenerates HTML only
- Individual test executables (for debugging):
  - `perf-RenderSurface.toAnsi`
  - `perf-RenderEngine.render_stable`
  - `perf-RenderEngine.render_stable_with_toAnsi`

All executables are built to `zig-out/bin/` and use `ReleaseFast` optimization.

### Adding New Tests

To add a new performance test:

1. Create a new test file in `perf-tst/tests/your_test.zig`
2. Implement the test structure (see existing tests as examples)
3. Add the test to `runner.zig` in the `available_tests` array
4. Update `build.zig` to build your test executable
5. Results will automatically appear in the dashboard

The visualization system is data-driven. As long as your test outputs the standard JSON format, charts will be generated automatically.

### Extending Visualizations

The dashboard uses Chart.js for rendering. To add new chart types:

1. Edit `web-assets/visualizer.js`
2. Add your chart rendering function
3. Call it from the appropriate section (e.g., `renderCharts()`)
4. Regenerate with `zig build perf-html-gen`

The embedded JSON data is available in JavaScript as `embeddedData[runKey]`, where each runKey is formatted as `"YYYY-MM-DD/HH-MM-SS"`. No need to deal with fetch() or CORS—everything's embedded directly in the HTML.

## Why These Specific Tests?

I picked these tests to answer specific questions:

**RenderSurface.toAnsi** → "How expensive is terminal output rendering?"
- ANSI conversion is pure overhead
- Can't be skipped in real usage
- Shows if we should cache ANSI strings or convert on-demand

**RenderEngine.render_stable** → "How fast is the core compositor?"
- No ANSI conversion noise in the measurements
- Tests z-ordering, alpha blending, pixel-level operations
- Different aspect ratios reveal cache and memory access patterns

**render_stable_with_toAnsi** → "What's the real-world performance?"
- Measures what actually happens in production
- Gap between this and sum of parts shows hidden overhead
- Helps identify optimization opportunities

## Interpreting Results

A few rules of thumb when looking at the data:

**Megapixels/sec increases with size?**
That's good. It means you're getting more efficient with larger sprites (better cache utilization, less per-pixel overhead).

**render_stable_with_toAnsi takes longer than render_stable + toAnsi separately?**
There's overhead in the combined pipeline.

**Big gap between 16:9 and square outputs?**
Memory layout matters. Might be worth profiling to see if certain sizes/strides perform better.

**Performance varies between runs?**
Make sure you're in ReleaseFast mode and nothing else is hogging the CPU. Also check if your test is too short (increase iterations).

## So ...

The visualization dashboard is self-contained HTML/CSS/JS with no build dependencies. If you want to customize it, just edit the files in `web-assets/` and regenerate. The code is commented and follows standard Chart.js patterns.

Happy benchmarking!

---

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

