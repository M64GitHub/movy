# RenderSurface

## Introduction

Welcome to the movy graphics engine! The `RenderSurface` is the **foundational building block** for all visual content in movy. Think of it as a canvas or drawing surface where you can:
- Draw pixels with specific colors
- Set transparency/alpha values
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

    // Load a sprite from PNG file
    var sprite_surface = try movy.core.RenderSurface.createFromPng(
        allocator,
        "assets/my_sprite.png",
    );
    defer sprite_surface.deinit(allocator);

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
surface.y = 5;    // 5 lines from the top (in line coordinates, not pixels)
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

Places a single UTF-8 character (codepoint) at the specified position.

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
    2,  // Y position (line 2 - must be even!)
    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 255 },  // Blue text
    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },    // Black background
);

// Unicode characters work too!
surface.putUtf8XY(
    '★',  // Star symbol
    10,
    4,   // Line 4 (even coordinate)
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
    0,   // Top line (even coordinate)
    green,
    black,
);

// Multi-line text with newlines
_ = surface.putStrXY(
    "Line 1\nLine 2\nLine 3",
    0,
    2,  // Starting at line 2 (even coordinate)
    green,
    black,
);

// Text that wraps automatically
_ = surface.putStrXY(
    "This is a very long string that will automatically wrap to the next line when it exceeds the surface width.",
    0,
    4,  // Line 4 (even coordinate)
    green,
    black,
);
```

---

## Text Y-Coordinate Rule

**Text MUST be placed on EVEN y coordinates only!**

Due to movy's half-block rendering system, each terminal line displays **two pixel rows** stacked vertically. Text characters occupy a full line, which starts at an "upper block" position.

### Why Even Coordinates?

```
Terminal Line 0:  ▀  (upper half) ← y = 0 (even) ✓ CORRECT for text
                  ▄  (lower half) ← y = 1 (odd)  ✗ WRONG for text

Terminal Line 1:  ▀  (upper half) ← y = 2 (even) ✓ CORRECT for text
                  ▄  (lower half) ← y = 3 (odd)  ✗ WRONG for text
```

### Correct Usage

```zig
// ✓ CORRECT - Even y coordinates
surface.putStrXY("Line 0", 0, 0, white, black);  // y = 0 ✓
surface.putStrXY("Line 2", 0, 2, white, black);  // y = 2 ✓
surface.putStrXY("Line 4", 0, 4, white, black);  // y = 4 ✓

surface.putUtf8XY('A', 5, 0, white, black);  // y = 0 ✓
surface.putUtf8XY('B', 5, 2, white, black);  // y = 2 ✓
```

### Incorrect Usage (Produces Artifacts!)

```zig
// ✗ WRONG - Odd y coordinates cause rendering artifacts
surface.putStrXY("Bad Line", 0, 1, white, black);  // y = 1 ✗ WRONG!
surface.putStrXY("Bad Line", 0, 3, white, black);  // y = 3 ✗ WRONG!

surface.putUtf8XY('X', 5, 1, white, black);  // y = 1 ✗ WRONG!
```

**Rule of thumb:** When calculating text positions, use:
- `y = line_number * 2` where line_number = 0, 1, 2, 3, ...
- Or simply count by 2: 0, 2, 4, 6, 8, 10, ...

---

## Converting to Terminal Output

### `toAnsi()` - Convert to ANSI String

The `toAnsi()` function converts your RenderSurface's pixel data into a printable ANSI escape sequence string that renders the image in the terminal.

**Function signature:**
```zig
pub fn toAnsi(self: *RenderSurface) ![]u8
```

**How it works:**
- Converts pixel data to ANSI color codes
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

This means a 40×20 RenderSurface displays as:
- 40 characters wide
- 10 terminal lines tall (20 pixels ÷ 2)

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
        "assets/sprite.png",
    );
    defer my_surface.deinit(allocator);

    // Position the surface
    my_surface.x = 10;  // 10 chars from left
    my_surface.y = 5;   // 5 lines from top
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

## Complete Example: Animated Text and Graphics

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
        2,   // Y position (line 2 - even coordinate!)
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

- ✓ Always `defer surface.deinit(allocator);` after creation
- ✓ Text must be on **even y coordinates** (0, 2, 4, 6, ...)
- ✓ Height (`h`) is in **pixel rows**, not terminal lines (divide by 2 for lines)
- ✓ Higher `z` values render on top
- ✓ shadow_map: 0 = transparent, 255 = opaque

Happy rendering!
