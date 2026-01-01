# Screen

## Introduction

Welcome to the movy graphics engine! The `Screen` is your **terminal rendering canvas** that brings everything together. Think of it as the director of your visual content:
- Manages multiple RenderSurfaces
- Composites layers with z-index sorting
- Handles alpha blending and transparency
- Outputs the final image to your terminal

The Screen is typically the **top-level component** in any movy application. You add RenderSurfaces to it (which can come from sprites, effect chains, or plain surfaces), call `render()` to composite everything, then `output()` to display it in the terminal.

**Location:** `src/screen/Screen.zig`

---

## Working with Screen: The Core Workflow

The Screen API follows a simple, consistent pattern for every frame:

1. **`renderInit()`** - Clears the temporary list of surfaces from the previous frame
2. **`addRenderSurface(allocator, surface)`** - Adds surfaces to render. These can be:
   - From sprites: `sprite.getCurrentFrameSurface()`
   - From effect chains: `effect_context.output_surface`
   - Plain surfaces: any `RenderSurface` object
3. **`render()` or `renderWithAlpha()`** - Composites all added surfaces together
4. **`output()`** - Prints the final composited image to the terminal

**Key principle:** The Screen only manages `RenderSurface` pointers, not sprites or other entities. Everything must be converted to a RenderSurface before being added.

**Example:**
```zig
while (rendering) {
    try screen.renderInit();  // Clear the list

    // Add surfaces from various sources
    try screen.addRenderSurface(allocator, background_surface);
    try screen.addRenderSurface(allocator, try sprite.getCurrentFrameSurface());
    try screen.addRenderSurface(allocator, effect_chain.output_surface);

    screen.render();  // Composite them
    try screen.output();  // Display to terminal
}
```

---

## Core Concepts

### Screen as Compositing Layer

The Screen doesn't draw graphics itself-it's a **compositor**. You create RenderSurfaces (or get them from sprites), add them to the Screen, and the Screen blends them all together based on:
- **Z-index**: Determines which surfaces appear in front or behind
- **Position**: Each surface has x, y coordinates
- **Transparency**: Alpha values control blending

Similar to a game with background, player sprites, and UI overlays-the Screen composites all these layers into a single output.

### Height Confusion: Lines vs Pixels

**IMPORTANT**: When you create a Screen with `init(allocator, w, h)`:
- `w` is in **terminal characters** (columns)
- `h` is in **terminal lines** (rows)

But internally, movy uses **half-block rendering** where each terminal line represents 2 pixels vertically. So:
- Screen stores height as `h * 2` (in pixels)
- When positioning surfaces, use pixel coordinates
- A 40-line terminal = 80 pixels vertically

### Screen Modes

The Screen supports two rendering modes:

**`.transparent` mode:**
- Transparent pixels blend with your terminal's background
- Good for overlaying graphics on existing terminal content

**`.bgcolor` mode:**
- Fills the entire screen with a solid background color
- Provides a clean, controlled canvas
- Most common for games and full-screen applications

---

## Basic Usage

### The Standard Render Loop

Every movy application follows this pattern:

```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.getSize();

    // 1. Initialize Screen (height in LINES, not pixels!)
    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,   // Terminal width in characters
        terminal_size.height,  // Terminal height in LINES
    );
    defer screen.deinit(allocator);

    // 2. Configure screen mode and background
    screen.setScreenMode(.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // 3. Create some content
    var surface = try movy.core.RenderSurface.init(
        allocator,
        20,  // 20 chars wide
        20,  // 20 pixels tall
        movy.core.types.Rgb{ .r = 255, .g = 0, .b = 0 },  // Red
    );
    defer surface.deinit(allocator);
    surface.x = 10;  // Position at x=10
    surface.y = 10;  // Position at y=10

    // 4. Clear the surface list (required before adding)
    try screen.renderInit();

    // 5. Add surfaces to render queue
    try screen.addRenderSurface(allocator, surface);

    // 6. Composite all surfaces together
    screen.render();

    // 7. Output to terminal
    try screen.output();
}
```

**Key points:**
- `renderInit()` **must** be called before adding surfaces each frame
- It clears the internal list (but retains capacity for performance)
- `render()` composites everything into screen.output_surface
- `output()` converts to ANSI and prints to terminal

---

## Working with Sprites

### Getting Surfaces from Sprites

You **cannot** add a Sprite directly to the Screen. Instead, use `getCurrentFrameSurface()` to get the sprite's current frame as a RenderSurface:

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
    screen.bg_color = movy.color.DARKER_GRAY;

    // Load sprite
    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "assets/player.png",
        "player",
    );
    defer sprite.deinit(allocator);

    try screen.renderInit();

    // Get current frame's surface
    sprite.setXY(20, 15);

    try screen.addRenderSurface(
        allocator,
        try sprite.getCurrentFrameSurface(),  // ← Get the surface
    );

    screen.render();
    try screen.output();
}
```

### Animation and Positioning

When animating sprites, always follow this order:

```zig
// Correct order in render loop
while (true) {
    try screen.renderInit();

    sprite.stepActiveAnimation();  // 1. Switch to next frame
    sprite.setXY(x, y);            // 2. Position that frame

    try screen.addRenderSurface(
        allocator,
        try sprite.getCurrentFrameSurface(),
    );

    screen.render();
    try screen.output();
}
```

**Why this order matters:**

Each sprite frame is a separate object with its own position. When `stepActiveAnimation()` changes the frame index, you're now referencing a different frame object. You must call `setXY()` after switching frames to position the new frame.

```zig
// What happens internally:
sprite.stepActiveAnimation();  // frame_idx changes from 1 to 2
// Now getCurrentFrameSurface() returns frame 2's data_surface
sprite.setXY(20, 10);         // Updates frame 2's position to (20, 10)
```

### Complete Animation Example

```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const terminal_size = try movy.terminal.getSize();

    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    var screen = try movy.Screen.init(
        allocator,
        terminal_size.width,
        terminal_size.height,
    );
    defer screen.deinit(allocator);
    screen.setScreenMode(.bgcolor);
    screen.bg_color = movy.color.BLACK;

    // Load and setup sprite animation
    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "examples/assets/sprite16x16-16frames.png",
        "player",
    );
    defer sprite.deinit(allocator);

    try sprite.splitByWidth(allocator, 16);  // Split into 16px frames
    try sprite.addAnimation(
        allocator,
        "walk",
        movy.Sprite.FrameAnimation.init(1, 16, .loopForward, 3),
    );
    try sprite.startAnimation("walk");

    const frame_delay_ns = 17 * std.time.ns_per_ms;  // ~60 FPS

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Handle input
        if (try movy.input.get()) |in| {
            if (in == .key and in.key.type == .Escape) break;
        }

        // Render
        try screen.renderInit();

        sprite.stepActiveAnimation();  // Advance animation frame
        sprite.setXY(20, 15);

        try screen.addRenderSurface(
            allocator,
            try sprite.getCurrentFrameSurface(),
        );

        screen.render();
        try screen.output();

        // Frame timing
        const frame_time = std.time.nanoTimestamp() - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
```

---

## Rendering Modes

### Binary Transparency: `render()`

The standard `render()` method uses **binary transparency**:
- `shadow_map == 0`: Pixel is skipped (fully transparent)
- `shadow_map != 0`: Pixel is drawn (fully opaque)

This is fast and works well for pixel-art style graphics with no semi-transparency.

```zig
try screen.renderInit();
try screen.addRenderSurface(allocator, surface);
screen.render();  // Binary: transparent or opaque
try screen.output();
```

### Alpha Blending: `renderWithAlpha()`

For smooth transparency and fading effects, use `renderWithAlpha()`:
- `shadow_map = 0-255`: Controls opacity (0 = transparent, 255 = opaque)
- Properly blends semi-transparent surfaces
- Slightly slower but much smoother visuals

**Example with fading sprite:**
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

    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "assets/ghost.png",
        "ghost",
    );
    defer sprite.deinit(allocator);

    var alpha: u8 = 0;

    while (true) {
        try screen.renderInit();

        // Apply fading effect
        try sprite.setAlphaCurrentFrameSurface(alpha);
        alpha = @addWithOverflow(alpha, 2)[0];  // Cycle 0->255->0

        sprite.setXY(20, 15);

        try screen.addRenderSurface(
            allocator,
            try sprite.getCurrentFrameSurface(),
        );

        screen.renderWithAlpha();  // Use alpha blending
        try screen.output();

        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}
```

**When to use which:**
- Use `render()` for pixel art with hard edges
- Use `renderWithAlpha()` for smooth transparency, fading, or semi-transparent overlays

---

## Advanced Features

### Z-Index Sorting

Surfaces are automatically sorted by their `z` field before rendering:
- Lower z-index = rendered first (background)
- Higher z-index = rendered last (foreground)

```zig
// Create layered scene
var background = try movy.core.RenderSurface.init(
    allocator,
    80,
    40,
    movy.core.types.Rgb{ .r = 20, .g = 40, .b = 60 },
);
background.z = 0;  // Back layer

var player = try movy.Sprite.initFromPng(
    allocator,
    "assets/player.png",
    "player",
);
player.z = 10;  // Middle layer
player.setXY(30, 20);

var ui_surface = try movy.core.RenderSurface.init(
    allocator,
    80,
    4,
    movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
);
ui_surface.z = 100;  // Front layer

// Add in any order - Screen sorts by z-index
try screen.renderInit();
try screen.addRenderSurface(allocator, try player.getCurrentFrameSurface());
try screen.addRenderSurface(allocator, background);
try screen.addRenderSurface(allocator, ui_surface);

screen.render();  // Automatically sorted: background -> player -> UI
try screen.output();
```

### Multiple Surfaces and Sprites

You can add as many surfaces as you need:

```zig
try screen.renderInit();

// Add background
try screen.addRenderSurface(allocator, background);

// Add multiple sprites
try screen.addRenderSurface(allocator, try player.getCurrentFrameSurface());
try screen.addRenderSurface(allocator, try enemy1.getCurrentFrameSurface());
try screen.addRenderSurface(allocator, try enemy2.getCurrentFrameSurface());

// Add UI overlays
try screen.addRenderSurface(allocator, score_display);
try screen.addRenderSurface(allocator, health_bar);

screen.render();
try screen.output();
```

### Terminal Setup for Full-Screen Applications

For interactive applications (games, animations), you typically want:

```zig
// Enable raw mode (unbuffered keyboard input)
try movy.terminal.beginRawMode();
defer movy.terminal.endRawMode();

// Use alternate screen buffer (preserves existing terminal content)
try movy.terminal.beginAlternateScreen();
defer movy.terminal.endAlternateScreen();

// Hide cursor for cleaner rendering
// (Screen.init() does this automatically, restored by deinit())

var screen = try movy.Screen.init(allocator, width, height);
defer screen.deinit(allocator);

// Your render loop here...
```

---

## Quick Reference

### Core Functions

| Function | Purpose |
|----------|---------|
| `init(allocator, w, h)` | Create screen (h is in **lines**, not pixels!) |
| `deinit(allocator)` | Clean up and restore terminal |
| `renderInit()` | Clear surface list (call before adding surfaces each frame) |
| `addRenderSurface(allocator, surface)` | Add a surface to the render queue |
| `render()` | Composite with binary transparency (fast) |
| `renderWithAlpha()` | Composite with alpha blending (smooth) |
| `output()` | Print to terminal |
| `setScreenMode(mode)` | Set `.transparent` or `.bgcolor` mode |
| `colorClear(allocator)` | Fill entire screen with bg_color |

### Screen Fields

| Field | Type | Purpose |
|-------|------|---------|
| `w`, `h` | `usize` | Dimensions (h is in **pixels**, not lines!) |
| `x`, `y` | `i32` | Screen offset for rendering |
| `z` | `i32` | Not commonly used for Screen itself |
| `bg_color` | `Rgb` | Background color (used in `.bgcolor` mode) |
| `output_surface` | `*RenderSurface` | Internal composited result |
| `screen_mode` | `Mode` | `.transparent` or `.bgcolor` |
| `output_surfaces` | `ArrayList` | List of surfaces to render |

### Common Patterns

**Basic render loop:**
```zig
while (true) {
    try screen.renderInit();
    // Add surfaces here
    screen.render();
    try screen.output();
}
```

**With sprite animation:**
```zig
while (true) {
    try screen.renderInit();
    sprite.stepActiveAnimation();
    sprite.setXY(x, y);
    try screen.addRenderSurface(allocator, try sprite.getCurrentFrameSurface());
    screen.render();
    try screen.output();
}
```

**With alpha transparency:**
```zig
while (true) {
    try screen.renderInit();
    try sprite.setAlphaCurrentFrameSurface(alpha);
    sprite.setXY(x, y);
    try screen.addRenderSurface(allocator, try sprite.getCurrentFrameSurface());
    screen.renderWithAlpha();  // Note: renderWithAlpha instead of render
    try screen.output();
}
```

---

## Important Reminders

**Always call `renderInit()` before adding surfaces each frame**
- It clears the surface list but retains capacity
- Forgetting this will accumulate surfaces from previous frames

**Height is in LINES at init, PIXELS internally**
- `Screen.init(allocator, 80, 40)` creates a 40-line (80-pixel) tall screen
- Internally stored as `h * 2` pixels

**Call setXY() after stepActiveAnimation()**
- Each frame has its own position
- stepActiveAnimation() switches to a different frame
- Call setXY() after switching to position the new frame

**Use `renderWithAlpha()` for transparency effects**
- `render()` is binary: transparent or opaque
- `renderWithAlpha()` supports 0-255 alpha values

**Surfaces are NOT copied, only pointers stored**
- The Screen holds pointers to your surfaces
- Don't free surfaces until after `render()` is called

Happy rendering!
