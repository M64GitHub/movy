# Colors

## Introduction

Movy provides a comprehensive color system with Bootstrap-inspired constants and utility functions for color manipulation. All colors are `Rgb` structs with `.r`, `.g`, `.b` components (0-255).

**Location:** `src/core/colors.zig`

---

## Using Color Constants

Access predefined colors via `movy.color.*`:

```zig
const movy = @import("movy");

// Basic colors
screen.bg_color = movy.color.BLACK;
const white_text = movy.color.WHITE;

// Named colors (500 shade = base)
const blue = movy.color.BLUE;
const red = movy.color.RED;
const green = movy.color.GREEN;

// Specific shades
const light_blue = movy.color.LIGHT_BLUE;        // 200
const dark_blue = movy.color.DARK_BLUE;          // 700
const darker_blue = movy.color.DARKER_BLUE;      // 800
```

**Example - Setting sprite and background colors:**
```zig
screen.bg_color = movy.color.DARKER_GRAY;

var sprite = try movy.Sprite.initFromPng(allocator, "player.png", "player");

// Use in text rendering
_ = surface.putStrXY(
    "Score: 100",
    10, 2,
    movy.color.BRIGHT_LIGHT_YELLOW,  // Text color
    movy.color.BLACK,                 // Background
);
```

---

## Bootstrap Color Palette

Movy's colors are inspired by Bootstrap 5.0 for balanced, beautiful tones. Each color family has multiple shades from light (100) to dark (900).

### Available Color Families

| Family | Base Constant | Example Shades |
|--------|---------------|----------------|
| Blue | `BLUE` | `LIGHT_BLUE`, `DARK_BLUE`, `BLUE_300`, `BLUE_700` |
| Indigo | `INDIGO` | `LIGHT_INDIGO`, `DARK_INDIGO`, `INDIGO_200`, `INDIGO_800` |
| Purple | `PURPLE` | `LIGHT_PURPLE`, `DARK_PURPLE`, `PURPLE_400`, `PURPLE_600` |
| Pink | `PINK` | `BRIGHT_LIGHT_PINK`, `DARKER_PINK`, `PINK_100`, `PINK_900` |
| Red | `RED` | `LIGHT_RED`, `DARK_RED`, `RED_500`, `RED_700` |
| Orange | `ORANGE` | `LIGHT_ORANGE`, `DARKER_ORANGE`, `ORANGE_200`, `ORANGE_800` |
| Yellow | `YELLOW` | `BRIGHT_LIGHT_YELLOW`, `DARK_YELLOW`, `YELLOW_100`, `YELLOW_600` |
| Green | `GREEN` | `LIGHT_GREEN`, `DARKER_GREEN`, `GREEN_300`, `GREEN_900` |
| Teal | `TEAL` | `LIGHT_TEAL`, `DARK_TEAL`, `TEAL_500`, `TEAL_700` |
| Cyan | `CYAN` | `BRIGHT_LIGHT_CYAN`, `DARKER_CYAN`, `CYAN_100`, `CYAN_800` |
| Gray | `GRAY` | `LIGHT_GRAY`, `DARKER_GRAY`, `GRAY_400`, `GRAY_800` |

### Shade Naming Convention

Each color family has two naming systems:

**Descriptive names:**
- `BRIGHT_LIGHT_*` - 100 (lightest)
- `LIGHT_*` - 200
- Base name (e.g., `BLUE`) - 500
- `MEDIUM_DARK_*` - 600
- `DARK_*` - 700
- `DARKER_*` - 800

**Numeric shades:**
- `*_100` to `*_900` (lightest to darkest)
- 500 is the base color
- Lower numbers = lighter, higher numbers = darker

**Example:**
```zig
// These are equivalent:
const blue1 = movy.color.BLUE;       // Base blue (500)
const blue2 = movy.color.BLUE_500;   // Same as BLUE

const light1 = movy.color.LIGHT_BLUE;  // Blue-200
const light2 = movy.color.BLUE_200;    // Same as LIGHT_BLUE
```

### Special Colors

```zig
movy.color.WHITE        // #FFFFFF
movy.color.BLACK        // #000000
movy.color.BLACK_4      // #040404 (near-black, useful for effects that treat #000000 as empty)
```

---

## Color Utility Functions

### Parsing HTML Colors

Convert HTML color strings to Rgb:

```zig
pub fn fromHtml(html: []const u8) !types.Rgb
```

**Accepts:**
- With hash: `"#FF0000"`
- Without hash: `"FF0000"`

**Example:**
```zig
const red = try movy.color.fromHtml("#DC3545");
const blue = try movy.color.fromHtml("0D6EFD");

// Use in your application
screen.bg_color = try movy.color.fromHtml("#1A1A1A");
```

---

### Brightening Colors

Two functions for making colors brighter:

#### `brighter()` - Percentage-based (recommended)

Scales toward white (255) based on percentage:

```zig
pub fn brighter(color: types.Rgb, amount: u8) types.Rgb
```

**Amount:** 0-100 (percentage)
- 0 = no change
- 50 = halfway to white
- 100 = fully white

**Example:**
```zig
const dark_blue = movy.color.DARK_BLUE;         // #084298
const lighter = movy.color.brighter(dark_blue, 30);  // 30% toward white
const much_lighter = movy.color.brighter(dark_blue, 70);  // 70% toward white
```

#### `brighterFast()` - Direct addition

Adds amount directly to each RGB channel:

```zig
pub fn brighterFast(color: types.Rgb, amount: u8) types.Rgb
```

**Amount:** 0-100 (added to each channel, clamped at 255)

**Example:**
```zig
const color = movy.color.BLUE;  // #0D6EFD
const brighter = movy.color.brighterFast(color, 50);  // Add 50 to each channel
```

**When to use which:**
- `brighter()` - More natural, preserves color relationships, recommended
- `brighterFast()` - Faster, linear adjustment, good for animations

---

### Darkening Colors

Two functions for making colors darker:

#### `darker()` - Percentage-based (recommended)

Scales toward black (0) based on percentage:

```zig
pub fn darker(color: types.Rgb, amount: u8) types.Rgb
```

**Amount:** 0-100 (percentage)
- 0 = no change
- 50 = halfway to black
- 100 = fully black

**Example:**
```zig
const yellow = movy.color.YELLOW;         // #FFC107
const darker = movy.color.darker(yellow, 40);  // 40% toward black
const much_darker = movy.color.darker(yellow, 80);  // 80% toward black
```

#### `darkerFast()` - Direct subtraction

Subtracts amount directly from each RGB channel:

```zig
pub fn darkerFast(color: types.Rgb, amount: u8) types.Rgb
```

**Amount:** 0-100 (subtracted from each channel, clamped at 0)

**Example:**
```zig
const color = movy.color.RED;  // #DC3545
const darker = movy.color.darkerFast(color, 50);  // Subtract 50 from each channel
```

---

## Quick Reference

### Basic Colors

| Constant | Hex | RGB |
|----------|-----|-----|
| `WHITE` | #FFFFFF | (255, 255, 255) |
| `BLACK` | #000000 | (0, 0, 0) |
| `BLACK_4` | #040404 | (4, 4, 4) |

### Color Families

All available as `movy.color.*`:

**Blues:** `BLUE`, `BLUE_100` to `BLUE_900`, `LIGHT_BLUE`, `DARK_BLUE`, etc.

**Reds:** `RED`, `RED_100` to `RED_900`, `LIGHT_RED`, `DARK_RED`, etc.

**Greens:** `GREEN`, `GREEN_100` to `GREEN_900`, `LIGHT_GREEN`, `DARK_GREEN`, etc.

**Other families:** INDIGO, PURPLE, PINK, ORANGE, YELLOW, TEAL, CYAN, GRAY

### Functions

| Function | Purpose | Parameter |
|----------|---------|-----------|
| `fromHtml(html)` | Parse HTML color string | "#RRGGBB" or "RRGGBB" |
| `brighter(color, amount)` | Scale toward white | 0-100 (percent) |
| `brighterFast(color, amount)` | Add to channels | 0-100 (direct) |
| `darker(color, amount)` | Scale toward black | 0-100 (percent) |
| `darkerFast(color, amount)` | Subtract from channels | 0-100 (direct) |

---

## Common Patterns

### Theme Colors

```zig
// Define theme colors
const theme = struct {
    const bg = movy.color.DARKER_GRAY;
    const text = movy.color.LIGHT_GRAY;
    const accent = movy.color.CYAN;
    const danger = movy.color.RED;
    const success = movy.color.GREEN;
};

screen.bg_color = theme.bg;
```

### Dynamic Color Adjustment

```zig
// Pulsing effect with brightness
const base_color = movy.color.BLUE;
const brightness = @as(u8, @intCast(@abs(wave.tickSine()) / 2));
const pulsed = movy.color.brighter(base_color, brightness);
```

### Hover/Active States

```zig
const button_color = movy.color.BLUE;
const button_hover = movy.color.brighter(button_color, 20);
const button_active = movy.color.darker(button_color, 20);
```

### Custom Colors from Design

```zig
// Import colors from design system
const brand_primary = try movy.color.fromHtml("#3A86FF");
const brand_secondary = try movy.color.fromHtml("#8338EC");
```

---

Happy coloring!
