# RenderEngine

## Introduction

The `RenderEngine` is movy's **compositor** - the system responsible for combining multiple `RenderSurfaces` into a single, final image. Think of it as a layer manager that:
- Stacks surfaces based on their z-index (z-ordering)
- Handles transparency and alpha blending
- Clips surfaces to fit within bounds
- Manages text overlay (char_map) compositing

Whether you're creating a game with multiple sprites, a UI with overlapping windows, or an animation with fading effects, the RenderEngine handles all the complex pixel-level compositing for you.

**Location:** `src/render/RenderEngine.zig`

---

## Core Concept: Compositing

### What is Compositing?

Compositing is the process of combining multiple layered images into a single final image. The RenderEngine takes several `RenderSurfaces` (each with their own position, colors, transparency, and text) and merges them together, respecting:

1. **Z-ordering:** Which surfaces appear on top of others
2. **Alpha blending:** How semi-transparent surfaces blend with what's beneath them
3. **Clipping:** Ensuring surfaces don't render outside their designated areas
4. **Text overlay:** Merging char_map text layers on top of graphics

### Z-Ordering Explained

Every RenderSurface has a `z` field (z-index) that determines its layer priority:

```zig
background.z = 0;    // Rendered first (furthest back)
player.z = 10;       // Rendered on top of background
ui_overlay.z = 100;  // Rendered on top of everything
```

**The rule:** Higher `z` values render **on top** of lower values.

The RenderEngine sorts surfaces from highest to lowest z-index before rendering (front-to-back rendering order).

### Clipping and Bounds

When a surface extends beyond the boundaries of the output surface, the RenderEngine automatically clips it:

```zig
// Output surface is 80*40
// Source surface is at position (70, 0) with size 20*10
// Result: Only the left 10 columns of the source will be visible
```

This ensures surfaces can be positioned anywhere (even partially off-screen) without causing errors.

---

## Primary Rendering Functions

The RenderEngine provides multiple rendering strategies. For most use cases, you'll use one of these two:

### `render()` - Legacy Binary Transparency

The original rendering function, optimized for speed with **binary transparency** (pixels are either fully visible or fully invisible).

**Function signature:**
```zig
pub fn render(
    surfaces_in: []const *movy.RenderSurface,
    out_surface: *movy.RenderSurface,
) void
```

**How it works:**
- Checks if `shadow_map[idx] != 0` (non-zero = opaque, zero = transparent)
- Uses **painter's algorithm:** first opaque pixel wins
- No alpha blending - pixels are either fully drawn or fully skipped
- **Very fast** - minimal overhead

**When to use:**
- Simple sprite rendering without transparency effects
- Maximum performance is required
- You don't need semi-transparent surfaces

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create output surface
    var output = try movy.RenderSurface.init(
        allocator,
        80,
        40,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },  // Black background
    );
    defer output.deinit(allocator);

    // Create a sprite
    var sprite = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/player.png",
    );
    defer sprite.deinit(allocator);
    sprite.x = 10;
    sprite.y = 5;
    sprite.z = 1;

    // Render using binary transparency
    var surfaces = [_]*movy.RenderSurface{sprite};
    movy.render.RenderEngine.render(&surfaces, output);

    // Output to terminal
    const ansi = try output.toAnsi();
    try std.io.getStdOut().writer().print("{s}", .{ansi});
}
```

**Important:** `shadow_map` values are treated as binary:
- `0` = Skip pixel (transparent)
- Any other value (1, 2, 128, 255) = Draw pixel (opaque)

---

### `renderWithAlphaToBg()` - **RECOMMENDED for Alpha Blending**

The **recommended** rendering function for modern movy applications. Provides true **Porter-Duff alpha compositing** optimized for the typical use case: blending semi-transparent surfaces onto an opaque background.

**Function signature:**
```zig
pub fn renderWithAlphaToBg(
    surfaces_in: []const *movy.RenderSurface,
    out_surface: *movy.RenderSurface,
) void
```

**How it works:**
- Uses `shadow_map` values as **alpha channel** (0-255)
- Performs **real alpha blending** for semi-transparent pixels
- Assumes background is opaque (optimized formula)
- ~20-30% **faster** than general alpha blending

**Alpha blending formula (simplified):**
```
output_color = (foreground_color * alpha + background_color * (255 - alpha)) / 255
```

**When to use:** **This should be your default choice for alpha blending!**
- Standard rendering with transparency effects
- Fading sprites (fade-in, fade-out)
- Glass-like overlays
- Shadows and lighting effects
- Any time you need semi-transparent surfaces

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create output surface (opaque black background)
    var output = try movy.RenderSurface.init(
        allocator,
        80,
        40,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
    );
    defer output.deinit(allocator);
    // Ensure background is opaque
    output.setAlpha(255); // make fully opaque (this is already the default after init)

    // Create a semi-transparent sprite
    var sprite = try movy.RenderSurface.init(
        allocator,
        20,
        20,
        movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 },  // Red
    );
    defer sprite.deinit(allocator);
    // Set to 50% transparent
    sprite.setAlpha(128);  // 50% opacity
    
    sprite.x = 10;
    sprite.y = 5;
    sprite.z = 1;

    // Render with alpha blending
    var surfaces = [_]*movy.RenderSurface{sprite};
    movy.render.RenderEngine.renderWithAlphaToBg(&surfaces, output);

    // The red sprite will be blended at 50% opacity
    // Result: Dark red on black (128, 0, 0)
}
```

**Alpha values:**
- `0` = Fully transparent (invisible)
- `128` = 50% transparent (half-blended)
- `255` = Fully opaque (solid)

---

## Advanced Rendering Functions

### `renderWithAlpha()` - General Alpha Compositing

The most mathematically complete alpha blending function. Unlike `renderWithAlphaToBg()`, this handles cases where **both foreground and background can be semi-transparent**.

**Function signature:**
```zig
pub fn renderWithAlpha(
    surfaces_in: []const *movy.RenderSurface,
    out_surface: *movy.RenderSurface,
) void
```

**How it works:**
- Full Porter-Duff "over" operator implementation
- Computes variable output alpha
- Handles semi-transparent foreground AND semi-transparent background
- Slightly slower than `renderWithAlphaToBg()` due to variable denominator

**When to use:**
- Pre-compositing multiple semi-transparent surfaces into another semi-transparent surface
- Creating transparent overlays that will be composited again later
- Advanced effects requiring precise alpha calculations

**Example:**
```zig
// Create a semi-transparent overlay (not opaque background)
var overlay = try movy.RenderSurface.init(
    allocator,
    40,
    20,
    movy.core.types.Rgb{ .r = 100, .g = 100, .b = 100 },
);
defer overlay.deinit(allocator);
// Make overlay semi-transparent
overlay.setAlpha(128);  // 50% opacity
}

// Create another semi-transparent layer
var effect = try movy.RenderSurface.init(
    allocator,
    20,
    20,
    movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 },
);
defer effect.deinit(allocator);
effect.setAlpha(128);  // 50% opacity

effect.x = 10;
effect.y = 5;
effect.z = 1;

// Blend semi-transparent onto semi-transparent
var surfaces = [_]*movy.RenderSurface{effect};
movy.render.RenderEngine.renderWithAlpha(&surfaces, overlay);

// The output overlay now has properly composited alpha values
// Can be composited again onto another surface
```

**Difference from `renderWithAlphaToBg()`:**
- `renderWithAlphaToBg()`: Assumes destination is opaque -> simpler math -> faster
- `renderWithAlpha()`: Handles any alpha values -> more complex math -> slightly slower but more flexible

---

### `renderOver()` - Unconditional Overwrite

Always overwrites destination pixels, regardless of what's already there. Uses binary transparency like `render()`.

**Function signature:**
```zig
pub fn renderOver(
    surfaces_in: []const *movy.RenderSurface,
    out_surface: *movy.RenderSurface,
) void
```

**When to use:**
- Refreshing/redrawing entire surfaces
- Updating UI elements that completely replace what was there

---

### `renderSurfaceOver()` - Single Surface Overwrite

Like `renderOver()` but for a single surface (no array, no z-sorting).

**Function signature:**
```zig
pub fn renderSurfaceOver(
    surface_in: *movy.RenderSurface,
    out_surface: *movy.RenderSurface,
) void
```

**When to use:**
- Quick rendering of one surface without compositing overhead
- Simple single-layer updates

---

### `renderComposite()` - Same-Size Surface Compositing

Optimized compositor for surfaces of identical dimensions. Ignores position offsets.

**Function signature:**
```zig
pub fn renderComposite(
    surfaces_in: []const *movy.RenderSurface,
    out_surface: *movy.RenderSurface,
) void
```

**When to use:**
- Compositing aligned layers (e.g., in effect pipelines)
- All surfaces have the same dimensions
- Position/offset calculations not needed

---

## Integration with Screen

The `Screen` struct uses RenderEngine internally. When you call `screen.render()`, it automatically invokes `RenderEngine.render()` to composite all added surfaces.

### How `Screen` Works

```zig
// Inside Screen.render() (simplified)
pub fn render(self: *Screen) void {
    // Collect all added surfaces
    var surface_list = self.surfaces.items;

    // Use RenderEngine to composite them
    RenderEngine.render(surface_list, self.output_surface);

    // Text overlays are then applied
    // ...
}
```

### Complete Workflow Example

```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.Terminal.getTerminalSize();

    // Initialize screen
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    try screen.renderInit();

    // Create layered surfaces
    var background = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/background.png",
    );
    defer background.deinit(allocator);
    background.z = 0;  // Back layer

    var player = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/player.png",
    );
    defer player.deinit(allocator);
    player.x = 20;
    player.y = 10;
    player.z = 10;  // Middle layer

    var ui_overlay = try movy.RenderSurface.init(
        allocator,
        80,
        10,
        movy.core.types.Rgb{ .r = 0, .g = 0, .b = 100 },
    );
    defer ui_overlay.deinit(allocator);
    // Make UI semi-transparent
    ui_overlay.setAlpha(192);  // 75% opacity
    
    ui_overlay.y = 0;
    ui_overlay.z = 100;  // Top layer

    // Add surfaces to screen
    try screen.addRenderSurface(allocator, background);
    try screen.addRenderSurface(allocator, player);
    try screen.addRenderSurface(allocator, ui_overlay);

    // Render and output
    // screen.render() internally calls RenderEngine.render()
    screen.render();
    try screen.output();
}
```

---

## Technical Details

### Surface Limit

The RenderEngine can handle up to **2048 surfaces** per render call. This limit comes from stack-allocated index arrays used for z-sorting.

```zig
// Inside RenderEngine
var indices: [2048]usize = undefined;
const surface_count = @min(surfaces_in.len, 2048);
```

If you need more surfaces, consider:
- Grouping surfaces into layers
- Pre-compositing some surfaces together
- Using separate render passes

### Alpha Value Range

All alpha-related functions use **u8 values (0-255)**:
- `0` = Fully transparent (0% opacity)
- `128` = Semi-transparent (50% opacity)
- `255` = Fully opaque (100% opacity)

### Performance Characteristics

**Fastest to Slowest:**
1. `render()` - Binary transparency, no blending
2. `renderSurfaceOver()` - Single surface, no z-sort
3. `renderWithAlphaToBg()` - Optimized alpha blending
4. `renderWithAlpha()` - General alpha blending
5. `renderOver()` - Always overwrites
6. `renderComposite()` - Same-size optimization

**Recommendation:** Use `renderWithAlphaToBg()` by default. The performance difference from `render()` is minimal for most use cases, and you gain full transparency support.

### Half-Block Coordinate System

Remember that movy uses half-block rendering:
- `y` coordinates are in **terminal lines** (not pixels)
- Each line displays **2 pixel rows** stacked vertically
- Height calculations: `pixel_height = line_height * 2`

---

## Common Patterns

### Pattern 1: Layered Scene Rendering

```zig
// Multiple layers at different depths
var backgrounds = [_]*movy.RenderSurface{
    sky,        // z = 0
    mountains,  // z = 5
    trees,      // z = 10
};

var characters = [_]*movy.RenderSurface{
    npc1,    // z = 20
    player,  // z = 25
    npc2,    // z = 20
};

var ui_elements = [_]*movy.RenderSurface{
    health_bar,  // z = 100
    score_text,  // z = 101
};

// Combine all surfaces
var all_surfaces = backgrounds ++ characters ++ ui_elements;

// Render with alpha blending
movy.render.RenderEngine.renderWithAlphaToBg(&all_surfaces, output);
```

### Pattern 2: Fade-In Effect

```zig
// Gradually increase alpha for fade-in
var alpha: u8 = 0;
while (alpha < 255) : (alpha += 5) {
    // Set sprite alpha
    sprite.setAlpha(alpha);
    
    // Render frame
    try screen.renderInit();
    try screen.addRenderSurface(allocator, background);
    try screen.addRenderSurface(allocator, sprite);
    screen.render();  // Uses RenderEngine internally
    try screen.output();

    std.time.sleep(16_000_000);  // ~60 FPS
}
```

### Pattern 3: Overlapping Text and Graphics

```zig
// Graphics layer
var game_world = try movy.RenderSurface.createFromPng(
    allocator,
    "world.png",
);
defer game_world.deinit(allocator);
game_world.z = 0;

// Text overlay layer
var text_layer = try movy.RenderSurface.init(
    allocator,
    80,
    40,
    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
);
defer text_layer.deinit(allocator);
// Make text layer mostly transparent
text_layer.setAlpha(32);  // Very transparent background

// Add text
const white = movy.core.types.Rgb{ .r = 255, .g = 255, .b = 255 };
const trans = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };
_ = text_layer.putStrXY(
    "GAME PAUSED",
    35,
    20,  // Center-ish, even coordinate
    white,
    trans,
);

text_layer.z = 100;  // On top

// Render
var surfaces = [_]*movy.RenderSurface{ game_world, text_layer };
movy.render.RenderEngine.renderWithAlphaToBg(&surfaces, output);
```

### Pattern 4: Pre-Compositing Complex Effects

```zig
// Create intermediate surface for complex effect
var effect_buffer = try movy.RenderSurface.init(
    allocator,
    40,
    40,
    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
);
defer effect_buffer.deinit(allocator);

// Make buffer semi-transparent
effect_buffer.setAlpha(128);
}

// Composite multiple layers into the effect buffer
var effect_layers = [_]*movy.RenderSurface{
    glow_layer,
    particle_layer,
    flash_layer,
};
movy.render.RenderEngine.renderWithAlpha(&effect_layers, effect_buffer);

// Now composite the pre-composited effect onto the main scene
effect_buffer.z = 50;
var final_surfaces = [_]*movy.RenderSurface{
    background,
    player,
    effect_buffer,  // Pre-composited effect
};
movy.render.RenderEngine.renderWithAlphaToBg(&final_surfaces, output);
```

---

## Understanding the Math: Alpha Blending Simplified

### Binary Transparency (render())
```
if (alpha == 0):
    skip pixel
else:
    draw pixel fully
```

Simple and fast, but no in-between states.

### True Alpha Blending (renderWithAlphaToBg())
```
output_red = (fg_red * alpha + bg_red * (255 - alpha)) / 255
output_green = (fg_green * alpha + bg_green * (255 - alpha)) / 255
output_blue = (fg_blue * alpha + bg_blue * (255 - alpha)) / 255
```

**Example:**
- Foreground: Red (255, 0, 0), alpha = 128 (50%)
- Background: Blue (0, 0, 255), alpha = 255 (100%)
- Result: Purple (128, 0, 127)

**Calculation:**
```
R = (255 * 128 + 0 * 127) / 255 = 32640 / 255 = 128
G = (0 * 128 + 0 * 127) / 255 = 0
B = (0 * 128 + 255 * 127) / 255 = 32385 / 255 ~= 127
```

---

## Choosing the Right Function

### Decision Tree

**Do you need semi-transparent surfaces?**
- **No** -> Use `render()` (fastest)
- **Yes** -> Continue...

**Are you rendering onto an opaque background?**

- **Yes** -> Use `renderWithAlphaToBg()` **(RECOMMENDED)**
- **No (both fg and bg can be semi-transparent)** -> Use `renderWithAlpha()`

**Special cases:**
- **Single surface only?** -> Use `renderSurfaceOver()`
- **All surfaces same size and aligned?** -> Use `renderComposite()`
- **Need to forcefully overwrite?** -> Use `renderOver()`

---

## Quick Reference

### Function Summary

| Function | Alpha Blending | Performance | Use Case |
|----------|---------------|-------------|----------|
| `render()` | No (binary) | Fastest | Simple sprites |
| `renderWithAlphaToBg()`  | Yes (optimized) |  Fast | Standard rendering |
| `renderWithAlpha()` | Yes (complete) |  Slower | Pre-compositing |
| `renderOver()` | No (binary) |  Fast | Force overwrite |
| `renderSurfaceOver()` | No (binary) |  Fastest | Single surface |
| `renderComposite()` | No (binary) |  Fast | Aligned layers |

### Common Code Snippets

**Basic rendering:**
```zig
var surfaces = [_]*movy.RenderSurface{ sprite1, sprite2 };
movy.render.RenderEngine.renderWithAlphaToBg(&surfaces, output);
```

**Set alpha for transparency:**
```zig
surface.setAlpha(128);  // 50% transparent
}
```

**Use with Screen:**
```zig
try screen.addRenderSurface(allocator, surface);
screen.render();  // Calls RenderEngine internally
try screen.output();
```

---

Happy compositing!
