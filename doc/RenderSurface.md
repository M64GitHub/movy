# RenderSurface

## Introduction

Welcome to the movy graphics engine! The `RenderSurface` is the **foundational building block** for all visual content in movy. Think of it as a canvas or drawing surface where you can:
- Draw pixels with specific colors
- Set transparency/alpha values
- Change alpha value on the fly
- Overlay text characters
- Load images from PNG files
- Render everything to your terminal

Every visual element in movy—whether it's a sprite, an effect, or a UI component—ultimately uses a `RenderSurface` to store and manipulate its pixel data.

**Location:** `src/core/RenderSurface.zig`

---

## Creating a RenderSurface

### Basic Creation with `init()`

RenderSurfaces are always created on the heap and `init()` returns a pointer to the surface. This means you **must** free the memory when you're done using `deinit()`.

**Function signature:**
```zig
pub fn init(
    allocator: std.mem.Allocator,
    w: usize,              // Width in characters
    h: usize,              // Height in pixel rows (half-blocks)
    color: movy.core.types.Rgb,  // Initial fill color
) !*RenderSurface
```

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a 40x20 surface filled with red
    var surface = try movy.core.RenderSurface.init(
        allocator,
        40,  // 40 characters wide
        20,  // 20 pixel rows tall (= 10 terminal lines)
        movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 },  // Red
    );
    defer surface.deinit(allocator);  // IMPORTANT: Always clean up!

    // Your surface is ready to use
}
```

**Key points:**
- Always use `defer surface.deinit(allocator);` immediately after creation
- The surface will be filled with the specified color
- All pixels are initially set to opaque (shadow_map = 255)

---

### Loading from PNG with `createFromPng()`

For loading existing graphics, movy provides `createFromPng()` which reads both **RGB color data** and **alpha channel** from PNG files.

**Function signature:**
```zig
pub fn createFromPng(
    allocator: std.mem.Allocator,
    file_path: []const u8,  // Path to PNG file
) !*RenderSurface
```

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load a graphic from PNG file
    var graphic_surface = try movy.core.RenderSurface.createFromPng(
        allocator,
        "assets/my_graphic.png",
    );
    defer graphic_surface.deinit(allocator);

    // The surface now contains:
    // - RGB color data from the PNG
    // - Alpha channel stored in shadow_map (0-255)
    // - Dimensions matching the PNG file
}
```

**What gets loaded:**
- **RGB values:** Each pixel's color is stored in `color_map`
- **Alpha channel:** Transparency values (0=fully transparent, 255=fully opaque) are stored in `shadow_map`
- **Dimensions:** Width and height are automatically set to match the PNG

---

## Handling Transparency and Alpha Blending

### Understanding the Shadow Map

The `shadow_map` field controls pixel visibility and transparency:

**Shadow Map Values:**
- `0`: Pixel is **fully transparent** and not rendered at all
- `1-255`: Pixel is **visible** with alpha/opacity value
  - `1`: Nearly transparent (1/255 opacity)
  - `128`: Semi-transparent (50% opacity)
  - `255`: Fully opaque (100% opacity)

When rendering, the behavior depends on which render function you use:
- `Screen.render()`: Binary transparency (0 = skip, non-zero = draw fully opaque)
- `Screen.renderWithAlpha()`: True alpha blending (0 = skip, 1-255 = blend based on value)

### Setting Alpha with `setAlpha()`

You can dynamically change the alpha of all visible pixels using `setAlpha()`:

**Function signature:**
```zig
pub fn setAlpha(self: *RenderSurface, alpha: u8) void
```

**Important behavior:**
- Only affects **non-transparent pixels** (shadow_map != 0)
- Transparent pixels (shadow_map == 0) remain transparent
- Alpha value `0` is automatically converted to `1` to maintain rendering logic

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load a graphic with transparency (e.g., a circle on transparent background)
    var surface = try movy.core.RenderSurface.createFromPng(
        allocator,
        "assets/circle.png",
    );
    defer surface.deinit(allocator);

    // Original: circle is opaque (shadow_map = 255), background is transparent (shadow_map = 0)

    // Make circle semi-transparent
    surface.setAlpha(128);
    // Result: circle pixels now have shadow_map = 128, background still 0

    // Make circle nearly invisible
    surface.setAlpha(10);
    // Result: circle pixels now have shadow_map = 10, background still 0

    // Make circle fully opaque again
    surface.setAlpha(255);
    // Result: circle pixels now have shadow_map = 255, background still 0

    // Note: Calling setAlpha(0) actually sets alpha to 1 (negligible difference)
    // This maintains the invariant: 0 = transparent, non-zero = visible
}
```

**Key points:**
- Use `setAlpha()` for fade-in/fade-out effects
- Original transparency is preserved (pixels with shadow_map=0 stay at 0)
- Works great for fading graphics, ghosts, or overlay effects
- Must use `Screen.renderWithAlpha()` for proper alpha blending

### Alpha Blending vs Binary Transparency

**Binary Transparency (`Screen.render()`):**
```zig
screen.render();  // Fast: Either draw pixel or skip it
```
- Fast rendering
- No semi-transparency
- Good for pixel art with hard edges

**Alpha Blending (`Screen.renderWithAlpha()`):**
```zig
screen.renderWithAlpha();  // Smooth: Blends based on alpha value
```
- Slower but smoother
- Proper semi-transparency (0-255 range)
- Good for fading effects, overlays, transparency
- **Required** if you use `setAlpha()` to adjust transparency

**Example: Fading effect with alpha blending**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.getSize();

    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(.bgcolor);
    screen.bg_color = movy.color.BLACK;

    var surface = try movy.core.RenderSurface.createFromPng(
        allocator,
        "assets/logo.png",
    );
    defer surface.deinit(allocator);
    surface.x = 20;
    surface.y = 10;

    var alpha: u8 = 0;

    while (true) {
        try screen.renderInit();

        // Apply fading effect
        surface.setAlpha(alpha);
        alpha = @addWithOverflow(alpha, 2)[0];  // Cycle 0->255->0

        try screen.addRenderSurface(allocator, surface);

        screen.renderWithAlpha();  // Use alpha blending, not binary
        try screen.output();

        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}
```

---

## The RenderSurface Structure

Understanding the internal structure helps you use RenderSurfaces effectively. Here are the key fields:

### Core Data Fields

#### `color_map: []movy.core.types.Rgb`
The pixel color data. Each element is an RGB struct with `.r`, `.g`, `.b` components (0-255).

```zig
// Example: Set a pixel to blue
surface.color_map[idx] = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 255 };
```

#### `shadow_map: []u8`
The alpha/transparency channel. Each value represents opacity:
- `0` = Fully transparent (invisible)
- `1-254` = Semi-transparent (alpha blending)
- `255` = Fully opaque (solid)

```zig
// Example: Make a pixel semi-transparent
surface.shadow_map[idx] = 128;  // 50% transparent
```

#### `char_map: []u21`
The Unicode text overlay layer. Stores UTF-8 codepoints (u21) for rendering text on top of graphics.

```zig
// Example: Place an 'A' character
surface.char_map[idx] = 'A';
```

**Important:** char_map is rendered **on top** of the graphics when converted to ANSI.

---

### Dimension Fields

#### `w: usize` - Width
The width of the surface in **terminal characters** (columns).

#### `h: usize` - Height
The height of the surface in **pixel rows**.

**Attention:** The height is measured in **half-blocks**, which means:
- `h = 2` represents **1 terminal line** (2 pixels stacked vertically)
- `h = 20` represents **10 terminal lines** (20 pixels = 10 lines)
- This is because movy uses half-block characters (▀ ▄) to achieve double vertical resolution

```zig
// Example: A surface that's 40 chars wide and 10 terminal lines tall
var surface = try movy.core.RenderSurface.init(
    allocator,
    40,  // 40 characters wide
    20,  // 20 pixel rows = 10 terminal lines (height / 2)
    black_color,
);
```

---

### Positioning Fields

#### `x: i32`, `y: i32` - Position
The position of the surface in terminal coordinates. Uses `i32` to support **negative coordinates** (off-screen positioning).

```zig
surface.x = 10;   // 10 characters from the left
surface.y = 5;    // 5 pixels from the top (in pixel coordinates, not lines)
surface.x = -5;   // Partially off-screen to the left
```

#### `z: i32` - Z-order
The layering priority when multiple surfaces are composited. **Higher values render on top.**

```zig
background.z = 0;   // Rendered first (back)
player.z = 10;      // Rendered on top of background
ui_overlay.z = 100; // Rendered on top of everything
```

---

## Adding Text to Surfaces

movy provides powerful text rendering capabilities that work seamlessly with the graphics layer.

### `putUtf8XY()` - Place Individual Characters

Places a single UTF-8 character (codepoint) at the specified X, and line position.

**Function signature:**
```zig
pub fn putUtf8XY(
    self: *RenderSurface,
    char: u21,                           // UTF-8 codepoint
    x: usize,                            // X position (characters)
    y: usize,                            // Y position (LINES, not pixels!)
    fg_color: movy.core.types.Rgb,      // Foreground (text) color
    bg_color: movy.core.types.Rgb,      // Background color
) void
```

**Example:**
```zig
// Place a blue 'A' on a black background at position (5, 2)
surface.putUtf8XY(
    'A',
    5,  // X position
    2,  // Y position (line 2, pixel row 4!)
    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 255 },  // Blue text
    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },    // Black background
);

// Unicode characters work too!
surface.putUtf8XY(
    '★',  // Star symbol
    10,
    4,   // Line 4
    yellow_color,
    black_color,
);
```

---

### `putStrXY()` - Print Strings

Prints a string with automatic **wrapping** and **newline support**.

**Function signature:**
```zig
pub fn putStrXY(
    self: *RenderSurface,
    str: []const u8,                    // The string to print
    xpos: usize,                        // Starting X position
    ypos: usize,                        // Starting Y position (LINES!)
    fg_color: movy.core.types.Rgb,     // Text color
    bg_color: movy.core.types.Rgb,     // Background color
) usize  // Returns index for next cursor position
```

**Features:**
- **Automatic wrapping:** When text reaches the right edge, wraps to next line
- **Newline support:** `\n` characters start a new line
- **Y increment:** New lines advance by 1 (which is 2 pixels in half-blocks)

**Example:**
```zig
const green = movy.core.types.Rgb{ .r = 0, .g = 255, .b = 0 };
const black = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };

// Simple text
_ = surface.putStrXY(
    "Hello, movy!",
    0,   // Start at left edge
    0,   // Top line
    green,
    black,
);

// Multi-line text with newlines
_ = surface.putStrXY(
    "Line 1\nLine 2\nLine 3",
    0,
    2,  // Starting at line 2 
    green,
    black,
);

// Text that wraps automatically
_ = surface.putStrXY(
    "This is a very long string that will automatically wrap to the next line when it exceeds the surface width.",
    0,
    4,  // Line 4 
    green,
    black,
);
```

---

## Text Y-Coordinate Rule

**Text MUST be placed on EVEN y coordinates only!**

This means when you have text on a surface: you must place that surface in steps of 2 on an even Y coordinate! Moving such surfaces verticall pixel by pixel, will result in artefacts on the odd coordinates. I currently have no good concept of how to improve this.  

Due to movy's half-block rendering system, each terminal line displays **two pixel rows** stacked vertically. Text characters occupy a full line, which starts at an "upper block" position.

### Why Even Coordinates?

```
Terminal Line 0:  ▀  (upper half) ← y = 0 (even) ✓ CORRECT for text
                  ▄  (lower half) ← y = 1 (odd)  ✗ WRONG for text

Terminal Line 1:  ▀  (upper half) ← y = 2 (even) ✓ CORRECT for text
                  ▄  (lower half) ← y = 3 (odd)  ✗ WRONG for text
```

---

## Converting to Terminal Output

### `toAnsi()` - Convert to ANSI String

The `toAnsi()` function converts your RenderSurface's pixel data into a printable ANSI escape sequence string that renders the image in the terminal.

**Function signature:**
```zig
pub fn toAnsi(self: *RenderSurface) ![]u8
```

**How it works:**
- Converts pixel data to ANSI color coded pixels
- Uses half-block characters (▀ ▄) for double vertical resolution
- Overlays char_map characters on top of graphics
- Returns a string ready to print

**Example:**
```zig
// Create and draw on a surface
var surface = try movy.core.RenderSurface.init(allocator, 40, 20, black_color);
defer surface.deinit(allocator);

// ... draw something on the surface ...

// Convert to ANSI and print
const ansi_str = try surface.toAnsi();
try std.io.getStdOut().writer().print("{s}", .{ansi_str});
```

### Half-Block Rendering

movy achieves **double vertical resolution** by using Unicode half-block characters:

```
▀ (U+2580) - Upper half block
▄ (U+2584) - Lower half block
```

Each terminal character cell displays **two pixels** stacked vertically:

```
┌─────────┐
│    ▀    │  ← Upper pixel (y coordinate even)
│    ▄    │  ← Lower pixel (y coordinate odd)
└─────────┘
  One cell = 2 pixels
```

This means a 40*20 RenderSurface displays as:
- 40 characters wide
- 10 terminal lines tall (20 pixels / 2)

---

## Scaling and Resizing

movy provides powerful image scaling capabilities to resize RenderSurfaces with multiple algorithms and control modes. Scaling can be used for dynamic graphic sizes, zoom effects, and loading assets at different resolutions.

### Scaling Modes and Algorithms

Before diving into the functions, understand the two enums that control scaling behavior:

#### `ScaleMode` - Buffer Management

```zig
pub const ScaleMode = enum {
    clip,        // Clip scaled content to fit within buffer bounds
    autoenlarge, // Automatically resize surface to accommodate target dimensions
};
```

**When to use:**
- `.clip` - For in-place scaling where surface size must stay fixed
- `.autoenlarge` - When you want the surface to grow if needed

#### `ScaleAlgorithm` - Quality vs Performance

```zig
pub const ScaleAlgorithm = enum {
    none,             // Direct pixel mapping, no interpolation (fastest, blockiest)
    nearest_neighbor, // Pick closest source pixel (fast, blocky)
    bilinear,         // Weighted average of 2x2 pixels (smooth, moderate speed)
    bicubic,          // Weighted average of 4x4 pixels (smoothest, slowest)
};
```

**Algorithm comparison:**
- `.none` - Fastest, best for extreme downscaling or when quality doesn't matter
- `.nearest_neighbor` - Fast and preserves hard edges, ideal for pixel art
- `.bilinear` - Balanced quality and speed, good for most use cases
- `.bicubic` - Highest quality, best for photographic content or upscaling

**Note:** Due to terminal's half-block rendering, differences between algorithms are subtle. Nearest neighbor can often sufficient.
Run `zig build run-scale_algorithms` for comparison, or `zig build run-scale_animation` to see where bilinear scaling makes an actual difference.
---

### Core Scaling Functions

#### `scale()` - Resize Surface Permanently

Scales the RenderSurface to new dimensions, reallocating all internal buffers. The surface's `w` and `h` fields are updated to the new size.

**Function signature:**
```zig
pub fn scale(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    target_w: usize,
    target_h: usize,
    algorithm: ScaleAlgorithm,
) !void
```

**Behavior:**
- Reallocates `color_map`, `shadow_map`, `char_map`, and `rendered_str`
- Updates `self.w` and `self.h` to new dimensions
- Clears `char_map` (text cannot be meaningfully scaled)
- Early returns if `target_w == self.w && target_h == self.h` (no-op optimization)

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load a 48x48 asteroid image
    var asteroid = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/asteroid_huge.png",
    );
    defer asteroid.deinit(allocator);

    std.debug.print("Original size: {}x{}\n", .{ asteroid.w, asteroid.h });
    // Output: Original size: 48x48

    // Scale down to 24x24 using bilinear interpolation
    try asteroid.scale(allocator, 24, 24, .bilinear);

    std.debug.print("Scaled size: {}x{}\n", .{ asteroid.w, asteroid.h });
    // Output: Scaled size: 24x24
}
```

---

#### `scaleInPlace()` - Scale Without Resizing Surface

Scales the content to new dimensions and positions it within the existing surface buffer. The surface dimensions (`w`, `h`) do NOT change. Areas outside the scaled content become transparent.

**Function signature:**
```zig
pub fn scaleInPlace(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    w: usize,
    h: usize,
    center_x: usize,
    center_y: usize,
    mode: ScaleMode,
    algorithm: ScaleAlgorithm,
) !void
```

**Parameters:**
- `w`, `h` - Target dimensions for the scaled content
- `center_x`, `center_y` - Position where scaled content is centered
- `mode` - What to do if target exceeds buffer size (clip or autoenlarge)
- `algorithm` - Scaling algorithm to use

**Behavior:**
- Clears the surface to transparent
- Scales current content to target size
- Positions scaled content centered at `(center_x, center_y)`
- With `.clip` mode: Clips if target exceeds buffer
- With `.autoenlarge` mode: Resizes surface first if needed

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a 100x100 surface with a graphic
    var surface = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/player.png",  // 32x32 graphic
    );
    defer surface.deinit(allocator);

    // Resize surface to have room for scaling
    try surface.resize(allocator, 100, 100);

    // Zoom in: Scale to 64x64 centered at (50, 50)
    try surface.scaleInPlace(
        allocator,
        64,  // Target width
        64,  // Target height
        50,  // Center X
        50,  // Center Y
        .clip,
        .nearest_neighbor,
    );

    // Surface is still 100x100, but content is now 64x64 and centered
    std.debug.print("Surface size: {}x{}\n", .{ surface.w, surface.h });
    // Output: Surface size: 100x100
}
```

---

#### `scaleInPlaceCentered()` - Convenience Wrapper

Scales in-place with automatic centering at `(w/2, h/2)`.

**Function signature:**
```zig
pub fn scaleInPlaceCentered(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    w: usize,
    h: usize,
    mode: ScaleMode,
    algorithm: ScaleAlgorithm,
) !void
```

**Example:**
```zig
// Zoom animation: pulse effect centered in surface
var scale_factor: f32 = 1.0;

while (true) {
    const target_w = @as(usize, @intFromFloat(32.0 * scale_factor));
    const target_h = @as(usize, @intFromFloat(32.0 * scale_factor));

    try graphic.scaleInPlaceCentered(
        allocator,
        target_w,
        target_h,
        .clip,
        .nearest_neighbor,
    );

    // Animate scale factor (1.0 -> 1.5 -> 1.0)
    scale_factor += 0.01;
    if (scale_factor > 1.5) scale_factor = 1.0;
}
```

---

### Convenience Functions

#### `createFromPngScaled()` - Load and Scale in One Call

Loads a PNG file and immediately scales it to the target dimensions.

**Function signature:**
```zig
pub fn createFromPngScaled(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    target_w: usize,
    target_h: usize,
    algorithm: ScaleAlgorithm,
) !*RenderSurface
```

**Example:**
```zig
// Load a large image and scale it down immediately
var icon = try movy.RenderSurface.createFromPngScaled(
    allocator,
    "assets/logo_4k.png",  // 3840x2160
    64,   // Scale to 64x64
    64,
    .bilinear,
);
defer icon.deinit(allocator);
```

---

### Factor-Based Scaling

For proportional scaling that preserves aspect ratio, use the factor-based functions. A factor of `1.0` means original size, `2.0` doubles the size, `0.5` halves it.

#### `scaleByFactor()` - Scale with Aspect Ratio Preservation

**Function signature:**
```zig
pub fn scaleByFactor(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    factor: f32,
    algorithm: ScaleAlgorithm,
) !void
```

**Example:**
```zig
var graphic = try movy.RenderSurface.createFromPng(allocator, "graphic.png");
defer graphic.deinit(allocator);

// Double the size (maintains aspect ratio)
try graphic.scaleByFactor(allocator, 2.0, .nearest_neighbor);

// Half the size
try graphic.scaleByFactor(allocator, 0.5, .bilinear);
```

---

#### `scaleInPlaceByFactor()` - In-Place Factor Scaling

**Function signature:**
```zig
pub fn scaleInPlaceByFactor(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    factor: f32,
    center_x: usize,
    center_y: usize,
    mode: ScaleMode,
    algorithm: ScaleAlgorithm,
) !void
```

---

#### `scaleInPlaceByFactorCentered()` - Centered Factor Scaling

**Function signature:**
```zig
pub fn scaleInPlaceByFactorCentered(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    factor: f32,
    mode: ScaleMode,
    algorithm: ScaleAlgorithm,
) !void
```

**Example - Breathing/Pulse Effect:**
```zig
var breath_phase: f32 = 0.0;

while (true) {
    // Calculate scale factor (oscillates between 0.8 and 1.2)
    const scale = 1.0 + 0.2 * @sin(breath_phase);

    try graphic.scaleInPlaceByFactorCentered(
        allocator,
        scale,
        .clip,
        .bilinear,
    );

    // Render graphic...

    breath_phase += 0.05;
}
```

---

### Performance Considerations

**Algorithm Speed (fastest to slowest):**
1. `.none` - Direct mapping
2. `.nearest_neighbor` - Lookup only
3. `.bilinear` - 2x2 interpolation
4. `.bicubic` - 4x4 interpolation

**Recommendations:**
- **Pixel art graphics:** Use `.nearest_neighbor` to preserve hard edges
- **Real-time animations:** Use `.nearest_neighbor` or `.bilinear`
- **Pre-processing assets:** Use `.bilinear` or `.bicubic` for quality
- **Extreme downscaling (e.g., 4x smaller):** Any algorithm works, use `.none` or `.nearest_neighbor` for speed

**Memory allocation:**
- `scale()` - Reallocates buffers, frees old ones
- `scaleInPlace()` - Allocates temporary buffers (freed immediately), may resize surface with `.autoenlarge`

---

### Complete Example: Zoom Effect

```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const term = try movy.terminal.enableRawMode();
    defer movy.terminal.disableRawMode(term);

    var screen = try movy.Screen.init(allocator, 80, 60);
    defer screen.deinit(allocator);

    // Load graphic
    var graphic = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/asteroid.png",
    );
    defer graphic.deinit(allocator);

    // Make room for scaling
    try graphic.resize(allocator, 80, 80);

    var zoom: f32 = 0.5;
    var zoom_direction: f32 = 0.02;

    while (true) {
        screen.clear();

        // Scale graphic in-place, centered
        try graphic.scaleInPlaceByFactorCentered(
            allocator,
            zoom,
            .clip,
            .nearest_neighbor,
        );

        graphic.x = 20;
        graphic.y = 20;

        // Render
        screen.renderInit();
        try screen.addRenderSurface(allocator, graphic);
        screen.render();
        try screen.output();

        // Animate zoom (0.5 <-> 2.0)
        zoom += zoom_direction;
        if (zoom >= 2.0 or zoom <= 0.5) {
            zoom_direction = -zoom_direction;
        }

        std.time.sleep(33 * std.time.ns_per_ms);  // 30 FPS

        // Check for quit input
        if (try movy.input.pollKey()) |key| {
            if (key == 'q' or key == 27) break;
        }
    }
}
```

---

### Scaling with Text

**Important:** Text (`char_map`) is **always cleared** during scaling operations, as character glyphs cannot be meaningfully scaled. If you need to preserve text:

1. Draw graphics and scale them
2. Add text **after** scaling

---

## Rotation

movy provides image rotation capabilities to rotate RenderSurfaces by arbitrary angles with multiple algorithms and control modes. Rotation can be used for spinning effects, sprite orientation, and dynamic visual transformations.

### Rotation Modes and Algorithms

Before diving into the functions, understand the two enums that control rotation behavior:

#### `RotateMode` - Buffer Management

```zig
pub const RotateMode = enum {
    clip,        // Clip rotated content to fit within buffer bounds
    autoenlarge, // Automatically resize surface to accommodate rotated image
};
```

**When to use:**
- `.clip` - For in-place rotation where surface size must stay fixed
- `.autoenlarge` - When you want the surface to grow to fit the rotated bounds

**Note:** Rotating a square by 45 degrees expands its bounding box by approximately 1.41x (sqrt(2)).

#### `RotateAlgorithm` - Quality vs Performance

```zig
pub const RotateAlgorithm = enum {
    nearest_neighbor, // Pick closest source pixel (fast, preserves pixel art)
    bilinear,         // Weighted average of 2x2 pixels (smooth, moderate speed)
};
```

**Algorithm comparison:**
- `.nearest_neighbor` - Fast and preserves hard edges, ideal for pixel art. Includes optimized fast paths for 0, 90, 180, and 270-degree rotations.
- `.bilinear` - Smooth interpolation, reduces aliasing artifacts, best for photographic content or when quality matters.

**Note:** For 90-degree multiples (0, 90, 180, 270), nearest_neighbor uses optimized direct pixel copying for maximum performance.

Run `zig build run-rotate_angles` to compare algorithms, `zig build run-rotate_animation` for continuous rotation, or `zig build run-rotate_interactive` for hands-on experimentation.

---

### Angle Conversion Helpers

Rotation functions accept angles in **radians**. Helper functions are provided for conversion:

#### `degreesToRadians()` - Convert Degrees to Radians

```zig
pub inline fn degreesToRadians(degrees: f32) f32
```

**Example:**
```zig
const angle_45_deg = movy.RenderSurface.degreesToRadians(45.0);
// Returns: ~0.785 radians
```

#### `radiansToDegrees()` - Convert Radians to Degrees

```zig
pub inline fn radiansToDegrees(radians: f32) f32
```

**Example:**
```zig
const degrees = movy.RenderSurface.radiansToDegrees(std.math.pi);
// Returns: 180.0 degrees
```

---

### Core Rotation Functions

#### `rotate()` - Rotate and Resize Surface

Rotates the RenderSurface by the specified angle, automatically expanding dimensions to fit the rotated content. The surface's `w` and `h` fields are updated to the new bounding box size.

**Function signature:**
```zig
pub fn rotate(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    angle_radians: f32,
    algorithm: RotateAlgorithm,
) !void
```

**Behavior:**
- Calculates new dimensions needed to contain rotated image
- Reallocates `color_map`, `shadow_map`, `char_map`, and `rendered_str`
- Updates `self.w` and `self.h` to new dimensions
- Centers rotated content in new buffer
- Clears `char_map` (text cannot be meaningfully rotated)

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load a 48x48 asteroid image
    var asteroid = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/asteroid_huge.png",
    );
    defer asteroid.deinit(allocator);

    std.debug.print("Original size: {}x{}\n", .{ asteroid.w, asteroid.h });
    // Output: Original size: 48x48

    // Rotate by 45 degrees
    const angle = movy.RenderSurface.degreesToRadians(45.0);
    try asteroid.rotate(allocator, angle, .bilinear);

    std.debug.print("Rotated size: {}x{}\n", .{ asteroid.w, asteroid.h });
    // Output: Rotated size: 68x68 (expanded to fit diagonal)
}
```

---

#### `rotateInPlace()` - Rotate with Custom Center Point

Rotates the content around a custom center point and positions it within the existing surface buffer. The surface dimensions (`w`, `h`) may change only if `mode` is `.autoenlarge`.

**Function signature:**
```zig
pub fn rotateInPlace(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    angle_radians: f32,
    center_x: usize,
    center_y: usize,
    mode: RotateMode,
    algorithm: RotateAlgorithm,
) !void
```

**Parameters:**
- `angle_radians` - Rotation angle in radians (positive = counter-clockwise)
- `center_x`, `center_y` - Point around which to rotate
- `mode` - What to do if rotated bounds exceed buffer size (clip or autoenlarge)
- `algorithm` - Rotation algorithm to use

**Behavior:**
- Rotates content around `(center_x, center_y)`
- With `.clip` mode: Clips if rotated content exceeds buffer
- With `.autoenlarge` mode: Resizes surface first if needed
- Areas outside rotated content become transparent

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a surface with a graphic
    var surface = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/player.png",  // 32x32 graphic
    );
    defer surface.deinit(allocator);

    // Resize surface to have room for rotation
    try surface.resize(allocator, 100, 100);

    // Rotate 90 degrees around point (50, 50)
    const angle_90 = movy.RenderSurface.degreesToRadians(90.0);
    try surface.rotateInPlace(
        allocator,
        angle_90,
        50,  // Center X
        50,  // Center Y
        .clip,
        .nearest_neighbor,
    );

    // Surface is still 100x100, but content is now rotated
    std.debug.print("Surface size: {}x{}\n", .{ surface.w, surface.h });
    // Output: Surface size: 100x100
}
```

---

#### `rotateInPlaceCentered()` - Convenience Wrapper

Rotates in-place with automatic centering at `(w/2, h/2)`.

**Function signature:**
```zig
pub fn rotateInPlaceCentered(
    self: *RenderSurface,
    allocator: std.mem.Allocator,
    angle_radians: f32,
    mode: RotateMode,
    algorithm: RotateAlgorithm,
) !void
```

**Example:**
```zig
// Spinning animation: continuous rotation centered in surface
var angle: f32 = 0.0;

while (true) {
    const angle_rad = movy.RenderSurface.degreesToRadians(angle);

    try graphic.rotateInPlaceCentered(
        allocator,
        angle_rad,
        .autoenlarge,
        .nearest_neighbor,
    );

    // Render graphic...

    // Animate rotation (0 -> 360 degrees)
    angle += 2.0;
    if (angle >= 360.0) angle = 0.0;
}
```

---

### Convenience Functions

#### `createFromPngRotated()` - Load and Rotate in One Call

Loads a PNG file and immediately rotates it to the specified angle.

**Function signature:**
```zig
pub fn createFromPngRotated(
    allocator: std.mem.Allocator,
    file_path: []const u8,
    angle_radians: f32,
    algorithm: RotateAlgorithm,
) !*RenderSurface
```

**Example:**
```zig
// Load an image and rotate it 180 degrees immediately
const angle_180 = movy.RenderSurface.degreesToRadians(180.0);
var upside_down = try movy.RenderSurface.createFromPngRotated(
    allocator,
    "assets/logo.png",
    angle_180,
    .nearest_neighbor,
);
defer upside_down.deinit(allocator);
```

---

### Performance Considerations

**Algorithm Speed:**
1. `.nearest_neighbor` - Fast, with optimized fast paths for 0, 90, 180, 270 degrees
2. `.bilinear` - Slower, performs 2x2 neighborhood interpolation for every pixel

**Recommendations:**
- **Pixel art graphics:** Use `.nearest_neighbor` to preserve hard edges
- **Real-time animations:** Use `.nearest_neighbor` for performance
- **High-quality rotations:** Use `.bilinear` for smoother results
- **90-degree rotations:** Always fast with `.nearest_neighbor` (uses optimized path)

**Memory allocation:**
- `rotate()` - Reallocates buffers, frees old ones
- `rotateInPlace()` - Allocates temporary buffers (freed immediately), may resize surface with `.autoenlarge`

---

### Complete Example: Spinning Asteroid

```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_width: usize = 120;
    const terminal_height: usize = 80;

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(
        allocator,
        terminal_width,
        terminal_height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(movy.Screen.Mode.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Load original asteroid image
    const original = try movy.RenderSurface.createFromPng(
        allocator,
        "assets/asteroid_huge.png",
    );
    defer original.deinit(allocator);

    // Pre-allocate rotated surface
    var rotated = try movy.RenderSurface.init(
        allocator,
        original.w,
        original.h,
        movy.color.BLACK,
    );
    defer rotated.deinit(allocator);

    var angle_degrees: f32 = 0.0;
    const rotation_step: f32 = 2.0;  // 2 degrees per frame

    while (true) {
        // Handle input
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    switch (key.type) {
                        .Escape => break,
                        .Char => {
                            if (key.sequence.len > 0) {
                                const ch = key.sequence[0];
                                if (ch == 'q' or ch == 'Q') break;
                            }
                        },
                        else => {},
                    }
                },
                .mouse => {},
            }
        }

        // Update rotation angle
        angle_degrees += rotation_step;
        if (angle_degrees >= 360.0) {
            angle_degrees -= 360.0;
        }

        // Convert to radians and rotate
        const angle_radians = movy.RenderSurface.degreesToRadians(angle_degrees);
        try rotated.resize(allocator, original.w, original.h);
        try rotated.copy(original);
        try rotated.rotateInPlaceCentered(
            allocator,
            angle_radians,
            .autoenlarge,
            .nearest_neighbor,
        );

        // Center the rotated surface on screen
        const center_x = @as(i32, @intCast(terminal_width / 2)) -
            @as(i32, @intCast(rotated.w / 2));
        const center_y = @as(i32, @intCast(terminal_height / 2)) -
            @as(i32, @intCast(rotated.h / 2));
        rotated.x = center_x;
        rotated.y = center_y;

        // Render
        try screen.renderInit();
        try screen.addRenderSurface(allocator, rotated);
        screen.render();
        try screen.output();

        std.Thread.sleep(16_666_667);  // 60 FPS
    }
}
```

---

### Rotation Examples

For hands-on learning, explore these examples:

- **`zig build run-rotate_animation`** - Continuous 360-degree rotation
- **`zig build run-rotate_angles`** - Compare rotation at different angles (0, 45, 90, 135, 180, 270) with both algorithms
- **`zig build run-rotate_interactive`** - User-controlled rotation with arrow keys, algorithm/mode toggling

---

### Rotation with Text

**Important:** Text (`char_map`) is **always cleared** during rotation operations, as character glyphs cannot be meaningfully rotated. If you need to preserve text:

1. Rotate graphics first
2. Add text **after** rotation

---

## Using with Screen

The `Screen` struct is movy's top-level rendering canvas. RenderSurfaces are added to a Screen and then composited together.

### Typical Workflow

```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get terminal size
    const terminal_size = try movy.terminal.getSize();

    // -- Initialize screen (height in line numbers, not pixels!)
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,   // Width in characters
        terminal_size.height,  // Height in LINES
    );
    defer screen.deinit(allocator);

    // Configure screen settings
    screen.setScreenMode(.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Clear screen surfaces
    try screen.renderInit();

    // -- Create a RenderSurface with graphics
    var my_surface = try movy.core.RenderSurface.createFromPng(
        allocator,
        "assets/graphic.png",
    );
    defer my_surface.deinit(allocator);

    // Position the surface
    my_surface.x = 10;  // 10 chars from left
    my_surface.y = 5;   // 5 pixels from top
    my_surface.z = 1;   // Layer 1

    // -- ADD RENDERSURFACE TO SCREEN
    try screen.addRenderSurface(allocator, my_surface);

    // -- Render and output
    screen.render();      // Composite all surfaces
    try screen.output();  // Print to terminal
}
```

### Key Screen Functions

#### `addRenderSurface()`
```zig
try screen.addRenderSurface(allocator, surface_ptr);
```
Adds a RenderSurface to the screen's render list.

#### `render()`
```zig
screen.render();
```
Composites all added surfaces using the RenderEngine. This is where z-ordering, clipping, and alpha blending happen.

#### `output()`
```zig
try screen.output();
```
Converts the final composited image to ANSI and prints it to the terminal.

#### `renderInit()`
```zig
try screen.renderInit();
```
Clears the screen's internal surfaces, preparing for a new frame.

---

## Screen Modes

### `Mode.transparent`
Surfaces blend with terminal's existing content (default).

### `Mode.bgcolor`
Surfaces render on top of a solid background color (specified by `screen.bg_color`).

```zig
screen.setScreenMode(.bgcolor);
screen.bg_color = movy.core.types.Rgb{ .r = 0x20, .g = 0x20, .b = 0x20 };  // Dark gray
```

---

## Complete Example: Text and Graphics

```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.getSize();

    // Initialize screen
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Create a surface with graphics
    var background = try movy.core.RenderSurface.init(
        allocator,
        40,
        20,  // 10 lines tall
        movy.core.types.Rgb{ .r = 0, .g = 50, .b = 100 },  // Dark blue
    );
    defer background.deinit(allocator);
    background.z = 0;

    // Add some text to the surface
    const white = movy.core.types.Rgb{ .r = 255, .g = 255, .b = 255 };
    const black = movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 };

    _ = background.putStrXY(
        "Welcome to movy!",
        2,   // X position
        2,   // Y position
        white,
        black,
    );

    _ = background.putStrXY(
        "Text and graphics\ntogether in harmony.",
        2,
        4,  // Line 4 (even coordinate)
        white,
        black,
    );

    // Add some Unicode symbols
    background.putUtf8XY('★', 0, 0, movy.core.types.Rgb{ .r = 255, .g = 255, .b = 0 }, black);
    background.putUtf8XY('♪', 4, 0, movy.core.types.Rgb{ .r = 0, .g = 255, .b = 255 }, black);

    // Render to screen
    try screen.renderInit();
    try screen.addRenderSurface(allocator, background);
    screen.render();
    try screen.output();
}
```

---

### Important Reminders

- Always `defer surface.deinit(allocator);` after creation
- Text must be on **even y coordinates** (0, 2, 4, 6, ...)
- Height (`h`) is in **pixel rows**, not terminal lines (divide by 2 for lines)
- Higher `z` values render on top
- shadow_map: 0 = transparent (not rendered), 1-255 = alpha/opacity value
- Use `setAlpha(alpha)` to change transparency; preserves original transparent pixels

Happy rendering!
