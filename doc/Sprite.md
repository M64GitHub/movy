# Sprite

## Introduction

Welcome to the movy graphics engine! The `Sprite` is your **animated graphic entity** that brings movement and life to your terminal applications. Think of it as a complete animation system:
- Load graphics from PNG files
- Split sprite sheets into individual frames
- Create named animations with different loop modes
- Control position, z-index, and alpha transparency
- Integrate seamlessly with the Screen compositor

Sprites are **essential building blocks** for games, demos, and animated visualizations. Every program or game that needs animated graphics will use Sprites extensively.

**Location:** `src/graphic/Sprite.zig`

---

## Loading Sprites

### Creating from PNG with `initFromPng()`

The most common way to create a sprite is loading it from a PNG file:

**Function signature:**
```zig
pub fn initFromPng(
    allocator: std.mem.Allocator,
    file_path: []const u8,    // Path to PNG file
    name: []const u8,          // Sprite name for identification
) !*Sprite
```

**Example:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load a sprite from PNG
    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "assets/player.png",  // PNG file path
        "player",             // Sprite name
    );
    defer sprite.deinit(allocator);  // IMPORTANT: Always clean up!

    // Sprite is now ready to use
    // At this point it has 1 frame (the entire PNG image)
}
```

**What happens:**
- PNG is loaded into frame[0] as the initial image
- Both `data_surface` (source) and `output_surface` (working buffer) are created
- Dimensions are set from the PNG file size
- Alpha channel from PNG is stored in shadow_map

### Understanding Sprite Architecture

A Sprite contains multiple layers:

**SpriteFrame:**
- Each frame has two RenderSurfaces:
  - `data_surface`: Immutable source pixel data
  - `output_surface`: Working buffer for effects and rendering
- Position offsets: `x_rel`, `y_rel`
- Dimensions: `w`, `h`

**SpriteFrameSet:**
- Collection of all frames
- Tracks current frame via `frame_idx`
- Frame[0] is always the original loaded image

**Sprite:**
- Complete entity with position (x, y, z)
- Named animations (HashMap)
- Frame management
- Effect support via RenderEffectContext

---

## Creating Animations

### Splitting Sprite Sheets with `splitByWidth()`

Most sprite animations use **sprite sheets**—single PNG images containing multiple frames laid out horizontally. Use `splitByWidth()` to break them into individual animation frames.

**Function signature:**
```zig
pub fn splitByWidth(
    self: *Sprite,
    allocator: std.mem.Allocator,
    split_width: usize,  // Width of each frame in pixels
) !void
```

**CRITICAL**: After `splitByWidth()`:
- **Frame[0]** remains the original full sprite sheet
- **Frame[1], Frame[2], ... Frame[N]** are the individual animation frames
- Animations should **start at index 1**, not 0!

**Example with 16-frame sprite sheet:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load sprite sheet (256x16 pixels = 16 frames of 16x16)
    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "examples/assets/sprite16x16-16frames.png",
        "player",
    );
    defer sprite.deinit(allocator);

    // Split into 16 individual frames
    // Before: frame[0] = 256x16 full sheet
    // After:  frame[0] = 256x16 full sheet (unchanged)
    //         frame[1] = 16x16 (first animation frame)
    //         frame[2] = 16x16 (second animation frame)
    //         ...
    //         frame[16] = 16x16 (last animation frame)
    try sprite.splitByWidth(allocator, 16);

    // Now sprite.w and sprite.h are set to 16x16
}
```

**Key points:**
- PNG width must be evenly divisible by split_width
- Each frame's color_map, shadow_map, and char_map are copied
- The sprite's `w` and `h` are updated to the frame size
- Frame[0] is NOT removed (may be useful for debugging)

---

## Animation Control

### Defining Animations with `addAnimation()`

Once frames are split, create named animations using `addAnimation()`:

**Function signature:**
```zig
pub fn addAnimation(
    self: *Sprite,
    allocator: std.mem.Allocator,
    name: []const u8,           // Animation name
    anim: FrameAnimation,       // Animation definition
) !void
```

**FrameAnimation.init():**
```zig
pub fn init(
    start: usize,     // Start frame index
    end: usize,       // End frame index
    mode: LoopMode,   // How animation loops
    speed: usize,     // Frames to wait between updates
) FrameAnimation
```

**Loop Modes:**
- `.loopForward`: 1→2→3→1→2→3... (continuous)
- `.loopReverse`: 3→2→1→3→2→1... (continuous)
- `.loopPingPong`: 1→2→3→2→1→2→3... (back and forth)
- `.once`: 1→2→3 (stops, check with `finishedActiveAnimation()`)

**Example with multiple animations:**
```zig
const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "assets/character_sheet.png",
        "character",
    );
    defer sprite.deinit(allocator);

    // Split 64x16 sheet into 4 frames of 16x16
    try sprite.splitByWidth(allocator, 16);

    // Define "walk" animation using frames 1-4
    try sprite.addAnimation(
        allocator,
        "walk",
        movy.Sprite.FrameAnimation.init(
            1,              // Start at frame 1 (not 0!)
            4,              // End at frame 4
            .loopForward,   // Loop continuously
            3,              // Wait 3 frames between updates (slower)
        ),
    );

    // Define "idle" animation using only frame 1
    try sprite.addAnimation(
        allocator,
        "idle",
        movy.Sprite.FrameAnimation.init(
            1,              // Start at frame 1
            1,              // End at frame 1 (single frame)
            .loopForward,   // Doesn't matter for single frame
            1,              // Speed doesn't matter
        ),
    );

    // Define "jump" animation as one-shot
    try sprite.addAnimation(
        allocator,
        "jump",
        movy.Sprite.FrameAnimation.init(
            1,              // Start at frame 1
            4,              // End at frame 4
            .once,          // Play once and stop
            2,              // Speed 2
        ),
    );
}
```

### Starting and Stepping Animations

**Start an animation with `startAnimation()`:**
```zig
try sprite.startAnimation("walk");  // Activates the "walk" animation
```

**Advance the animation with `stepActiveAnimation()`:**
```zig
// Call once per frame in your game loop
sprite.stepActiveAnimation();
```

**Check if one-shot animation finished:**
```zig
if (sprite.finishedActiveAnimation()) {
    // Animation completed (only meaningful for .once mode)
    try sprite.startAnimation("idle");  // Switch to idle
}
```

### Understanding Frame Positions

**Important:** Each frame is a separate object with its own position.

When you call `setXY(x, y)`, it updates the CURRENT frame's position. The `setXY()` function internally calls `getCurrentFrameSurface()` to get the current frame and updates that specific frame's position.

**What this means:**
```zig
// You have 4 animation frames (frames 1-4)
sprite.setXY(10, 10);          // Sets frame 1's position to (10, 10)
sprite.stepActiveAnimation();  // Switches from frame 1 to frame 2
// Now the current frame is frame 2, which has its own position (likely 0, 0)
```

**Therefore: Always call setXY() AFTER stepActiveAnimation()**

```zig
// Correct pattern
sprite.stepActiveAnimation();  // Switch to next frame
sprite.setXY(10, 10);         // Position the new frame

// Incorrect pattern
sprite.setXY(10, 10);         // Position current frame
sprite.stepActiveAnimation();  // Switch to different frame (new frame not positioned!)
```

The rule is simple: **step first, position second**.

**Complete animation example:**
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

    // Load and setup sprite
    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "examples/assets/sprite16x16-16frames.png",
        "sprite1",
    );
    defer sprite.deinit(allocator);

    try sprite.splitByWidth(allocator, 16);
    try sprite.addAnimation(
        allocator,
        "flash",
        movy.Sprite.FrameAnimation.init(1, 16, .loopForward, 2),
    );
    try sprite.startAnimation("flash");

    const frame_delay_ns = 17 * std.time.ns_per_ms;  // ~60 FPS

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Handle input
        if (try movy.input.get()) |in| {
            if (in == .key and in.key.type == .Escape) break;
        }

        // Render
        try screen.renderInit();

        sprite.stepActiveAnimation();  // Advance to next frame
        sprite.setXY(5, 5);            // Position sprite

        try screen.addRenderSurface(
            allocator,
            try sprite.getCurrentFrameSurface(),  // Get current frame
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

## Alpha and Transparency

### Setting Alpha with `setAlphaCurrentFrameSurface()`

Control sprite transparency dynamically using the new convenience function:

**Function signature:**
```zig
pub fn setAlphaCurrentFrameSurface(
    self: *Sprite,
    alpha: u8,  // 0 = fully transparent, 255 = fully opaque
) !void
```

This sets the alpha for the **current frame's surface**, allowing you to fade sprites in and out or create ghost effects.

**Example with fading effect:**
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

        // Apply fading effect - cycles from 0 to 255 and wraps back to 0
        try sprite.setAlphaCurrentFrameSurface(alpha);
        alpha = @addWithOverflow(alpha, 2)[0];  // Increment with wraparound

        sprite.setXY(20, 15);

        try screen.addRenderSurface(
            allocator,
            try sprite.getCurrentFrameSurface(),
        );

        screen.renderWithAlpha();  // Use alpha blending, not binary
        try screen.output();

        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}
```

**See also:** `examples/sprite_fading.zig` for a complete example combining animation and alpha fading.

### When to Apply Alpha

**TIMING MATTERS**: Apply alpha values **before or after** splitting, depending on your needs:

**Apply to full sheet BEFORE splitting:**
```zig
var sprite = try movy.Sprite.initFromPng(allocator, "sprite.png", "sprite");

// Apply alpha to frame[0] (the full sheet)
const frame0 = try sprite.getCurrentFrameSurface();
frame0.setAlpha(128);  // 50% opacity

// Then split - all resulting frames inherit the alpha
try sprite.splitByWidth(allocator, 16);
```

**Apply per-frame AFTER splitting:**
```zig
var sprite = try movy.Sprite.initFromPng(allocator, "sprite.png", "sprite");
try sprite.splitByWidth(allocator, 16);

// Apply different alpha to specific frames
try sprite.setFrameIndex(5);
try sprite.setAlphaCurrentFrameSurface(64);  // Make frame 5 very transparent
```

**Apply dynamically during animation:**
```zig
// In game loop
sprite.stepActiveAnimation();
try sprite.setAlphaCurrentFrameSurface(alpha);  // Alpha changes each frame
```

---

## Integration with Screen

### Getting the Current Frame Surface

To render a sprite, you need to get its current frame as a RenderSurface:

**Function signature:**
```zig
pub fn getCurrentFrameSurface(self: *Sprite) !*RenderSurface
```

This returns the `data_surface` of the frame at `frame_idx`. You then add this surface to the Screen.

### Positioning and Rendering

**The correct workflow:**
```zig
// In your render loop
try screen.renderInit();

sprite.stepActiveAnimation();      // 1. Advance animation
sprite.setXY(x, y);                // 2. Update position

try screen.addRenderSurface(       // 3. Get and add current frame
    allocator,
    try sprite.getCurrentFrameSurface(),
);

screen.render();                   // 4. Composite
try screen.output();               // 5. Display
```

**What `setXY()` does:**
- Updates sprite's `x`, `y` fields
- Updates `output_surface.x`, `output_surface.y`
- Updates current frame's `data_surface.x`, `data_surface.y`

This is why you should call `setXY()` **before** `getCurrentFrameSurface()`—it ensures the position is applied to the surface you're about to retrieve.

### Complete Integration Example

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
    screen.bg_color = movy.color.DARKER_GRAY;

    // Background layer
    var background = try movy.core.RenderSurface.init(
        allocator,
        terminal_size.width,
        terminal_size.height * 2,
        movy.core.types.Rgb{ .r = 20, .g = 40, .b = 60 },
    );
    defer background.deinit(allocator);
    background.z = 0;

    // Sprite layer
    var player = try movy.Sprite.initFromPng(
        allocator,
        "assets/player.png",
        "player",
    );
    defer player.deinit(allocator);
    try player.splitByWidth(allocator, 16);
    try player.addAnimation(
        allocator,
        "walk",
        movy.Sprite.FrameAnimation.init(1, 8, .loopForward, 3),
    );
    try player.startAnimation("walk");
    player.z = 10;

    var x: i32 = 10;
    const frame_delay_ns = 17 * std.time.ns_per_ms;

    while (true) {
        const frame_start = std.time.nanoTimestamp();

        // Input
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    if (key.type == .Escape) break;
                    if (key.type == .Char and key.sequence.len > 0) {
                        if (key.sequence[0] == 'd') x += 1;  // Move right
                        if (key.sequence[0] == 'a') x -= 1;  // Move left
                    }
                },
                else => {},
            }
        }

        // Render
        try screen.renderInit();

        // Add background
        try screen.addRenderSurface(allocator, background);

        // Add player sprite
        player.stepActiveAnimation();
        player.setXY(x, 15);

        try screen.addRenderSurface(
            allocator,
            try player.getCurrentFrameSurface(),
        );

        screen.render();
        try screen.output();

        // Timing
        const frame_time = std.time.nanoTimestamp() - frame_start;
        if (frame_time < frame_delay_ns) {
            std.Thread.sleep(@intCast(frame_delay_ns - frame_time));
        }
    }
}
```

---

## Advanced Topics

### Manual Frame Control

You can manually set the current frame without using animations:

```zig
try sprite.setFrameIndex(5);  // Jump directly to frame 5

const surface = try sprite.getCurrentFrameSurface();
// Frame 5's data_surface is now returned
```

This is useful for:
- Custom animation logic
- Frame-based state machines
- Debug visualization

### Multiple Animations

Create as many named animations as you need:

```zig
try sprite.addAnimation(allocator, "idle", ...);
try sprite.addAnimation(allocator, "walk", ...);
try sprite.addAnimation(allocator, "run", ...);
try sprite.addAnimation(allocator, "jump", ...);
try sprite.addAnimation(allocator, "attack", ...);

// Switch based on game state
if (player_attacking) {
    try sprite.startAnimation("attack");
} else if (player_moving) {
    try sprite.startAnimation("walk");
} else {
    try sprite.startAnimation("idle");
}
```

### Effect System Integration

Sprites have built-in support for RenderEffects via `effect_ctx`:

```zig
// The sprite's effect_ctx can be used with RenderEffectChain
// See render/RenderEffect.zig for details

sprite.effect_ctx.input_surface   // Current frame's data_surface
sprite.effect_ctx.output_surface  // Sprite's output_surface

// Effects can be applied to transform the sprite
// (Advanced topic - see RenderEffect documentation)
```

### Getting Specific Frame Surfaces

If you need access to a specific frame (not just the current one):

```zig
const frame3 = try sprite.getFrameSurface(3);  // Get frame 3's surface
// Returns error.EmptyFrameSet or error.InvalidFrameIndex if invalid
```

---

## Quick Reference

### Core Functions

| Function | Purpose |
|----------|---------|
| `initFromPng(allocator, path, name)` | Load sprite from PNG file |
| `deinit(allocator)` | Clean up sprite and all frames |
| `splitByWidth(allocator, width)` | Split frame[0] into animation frames |
| `addAnimation(allocator, name, anim)` | Define a named animation |
| `startAnimation(name)` | Activate an animation by name |
| `stepActiveAnimation()` | Advance animation to next frame |
| `finishedActiveAnimation()` | Check if .once animation completed |
| `getCurrentFrameSurface()` | Get current frame as RenderSurface |
| `setXY(x, y)` | Set sprite position |
| `setFrameIndex(idx)` | Manually set current frame |
| `setAlphaCurrentFrameSurface(alpha)` | Set transparency (0-255) |

### FrameAnimation Functions

| Function | Purpose |
|----------|---------|
| `init(start, end, mode, speed)` | Create animation definition |
| `step(sprite)` | Advance animation (called internally) |
| `finished()` | Check if animation completed |

### Loop Modes

| Mode | Behavior |
|------|----------|
| `.loopForward` | 1→2→3→1→2→3... |
| `.loopReverse` | 3→2→1→3→2→1... |
| `.loopPingPong` | 1→2→3→2→1→2→3... |
| `.once` | 1→2→3 (stops) |

### Sprite Fields

| Field | Type | Purpose |
|-------|------|---------|
| `name` | `[]u8` | Sprite identifier |
| `w`, `h` | `usize` | Frame dimensions (after split) |
| `x`, `y`, `z` | `i32` | Position and depth |
| `frame_set` | `SpriteFrameSet` | All frames and frame_idx |
| `animations` | `HashMap` | Named animations |
| `active_animation` | `?[]const u8` | Currently playing animation |
| `output_surface` | `*RenderSurface` | Working buffer |
| `effect_ctx` | `RenderEffectContext` | For render effects |

### Common Patterns

**Load and split sprite:**
```zig
var sprite = try movy.Sprite.initFromPng(allocator, "sprite.png", "sprite");
try sprite.splitByWidth(allocator, 16);
```

**Define and start animation:**
```zig
try sprite.addAnimation(
    allocator,
    "walk",
    movy.Sprite.FrameAnimation.init(1, 8, .loopForward, 3),
);
try sprite.startAnimation("walk");
```

**Render sprite to screen:**
```zig
sprite.stepActiveAnimation();
sprite.setXY(x, y);
try screen.addRenderSurface(allocator, try sprite.getCurrentFrameSurface());
```

**Fade sprite in/out:**
```zig
try sprite.setAlphaCurrentFrameSurface(alpha);
screen.renderWithAlpha();  // Don't forget to use renderWithAlpha!
```

---

## Important Reminders

**Frame[0] is the original sprite sheet**
- After `splitByWidth()`, frame[0] still contains the full PNG
- Animations should start at frame 1, not frame 0
- Use `init(1, N, ...)` not `init(0, N, ...)`

**Always use `getCurrentFrameSurface()` for rendering**
- Don't try to render `sprite.output_surface` directly
- The current frame's `data_surface` is what should be added to Screen

**Call stepActiveAnimation() before setXY()**
- Each frame has its own position stored in its data_surface
- stepActiveAnimation() switches to a different frame object
- Call setXY() after switching to position the new frame
- setXY() internally calls getCurrentFrameSurface() and updates that frame's position

**Use `renderWithAlpha()` for transparency**
- If you use `setAlphaCurrentFrameSurface()`, render with alpha blending
- Binary `render()` will treat any alpha > 0 as fully opaque

**Animation speed is a wait counter**
- speed=1: Changes every frame (fastest)
- speed=3: Waits 3 frames between changes (slower)
- Higher number = slower animation

**Call `stepActiveAnimation()` once per frame**
- Calling it multiple times per frame will speed up animation
- Call it exactly once in your render loop

Happy animating!
