# GlyphLayer

## Introduction

The `GlyphLayer` puts **text inside a pixel scene**. It is an optional layer of characters at terminal-cell resolution, kept separate from the half-block pixels and resolved over them only when the frame is written to the terminal.

- Each cell holds a **character**, a **text color**, and a **background mode**
- `.pixels` background: the cell shows the average color of the two pixels underneath, so gradients, glow and trails show through behind the text
- `.solid` background: the cell uses its own background color
- Empty cells show the half-block pixels exactly as before

![glyph-decrypt](../examples/glyph-decrypt/screenshot.png)

*The [glyph-decrypt example](../examples/glyph-decrypt/main.zig): text scrambling and locking in while a scanner beam and a drifting color field show through behind it.*

**Location:** `src/core/GlyphLayer.zig`

---

## Why a Separate Layer?

A `RenderSurface` can already hold text in its `char_map` (`putStrXY`, `putUtf8XY`, ...). That text lives *inside* the pixel buffer: a character takes its foreground color from the pixel above and its background from the pixel below, so it **replaces** the two pixels it sits on. That is ideal for UI and HUD text, but a character can never have a light trail, a glow or a moving gradient behind it.

The GlyphLayer keeps pixels and text apart:

| | `char_map` text | GlyphLayer |
|---|---|---|
| Resolution | pixel grid, even rows only | one entry per terminal cell |
| Colors | stored in the pixels it covers | its own fg per cell |
| Background | the lower pixel's color | averaged from the pixels under it, or solid |
| Pixels under it | overwritten | kept, and shown as the background |
| Composited by RenderEngine | yes | no - resolved at output |
| Typical use | UI, HUD, windows | text effects in a scene |

Both can be used together. Where both are set, `char_map` text wins, so UI and HUD text always stays on top.

---

## The Core Workflow

1. **Create the layer** with the size of the screen in cells: `screen.w` columns and `screen.h / 2` rows
2. **Attach it** to the surface that gets written to the terminal: `screen.output_surface.setGlyphs(layer)`
3. **Draw glyphs** with `put`, `putSolid`, `putStr`, `putStrSolid`
4. **Render and output as usual** - `DiffOutput` or `screen.output()` resolves the glyphs over the final pixels

```zig
const glyphs = try movy.GlyphLayer.init(allocator, screen.w, screen.h / 2);
defer glyphs.deinit();
screen.output_surface.setGlyphs(glyphs);

// per frame
try screen.renderInit();
try screen.addRenderSurface(allocator, background);
screen.render();                                // composites pixels; glyphs untouched

glyphs.clear();
_ = glyphs.putStr(10, 5, "text in the scene", .{ .r = 200, .g = 240, .b = 255 });
_ = glyphs.putStrSolid(10, 7, " SCORE 1200 ", .{}, .{ .r = 255, .g = 120, .b = 220 });

try dout.output(&screen);                       // movy.DiffOutput
```

**Key principle:** the layer is attached to `screen.output_surface`, not to the surfaces you add to the screen. The RenderEngine does not composite glyph layers. Debug builds panic in `Screen.render()` if a layer is attached to an input surface, so a misplaced layer never disappears silently.

---

## Core Concepts

### Cells, Not Pixels

Everything in a GlyphLayer is addressed in **terminal cells**: `x` is the column, `y` is the text row. A layer for a surface of `w x h` pixels is `w x h/2` cells. The cell at `(x, y)` sits over the pixel pair `(x, 2y)` and `(x, 2y + 1)`.

### Background Modes

```zig
glyphs.put(x, y, 'A', fg);              // .pixels: bg = average of the two pixels under the cell
glyphs.putSolid(x, y, 'A', fg, bg);     // .solid:  bg = the given color
```

With `.pixels`, the background is resolved every frame from whatever pixels are underneath at that moment, so text you placed once sits inside an animated scene without being redrawn. If both pixels are transparent (`Screen` in `.transparent` mode), the cell uses the terminal's default background.

In `.pixels` mode a glyph cell shows one averaged background instead of two stacked half-block pixels. At text scale this is invisible, and with glow it looks intentional.

### Persistence

The layer keeps its contents until you change them - nothing clears it but you. Two styles both work, at the same output cost:

- **Static text:** put it once and leave it
- **Animated text:** `clear()` and redraw every frame (as the glyph-decrypt example does)

`DiffOutput` compares glyph rows against the previous frame like it compares pixel rows. A row is only re-sent when its pixels or its glyphs changed.

### Precedence

At output, each cell is resolved in this order, highest first:

1. `char_map` text of the surface (UI / HUD text)
2. GlyphLayer glyph
3. half-block pixels

### Wide Characters

A glyph occupies exactly one terminal column. Double-width codepoints (CJK, most emoji) would shift the rest of the row, so they are stored as `◉` (U+25C9) - the same rule `putUtf8XY` uses.

---

## With a Frame

On the [Frame](../README.md#rendering-path-2---frame-neon-render-layer) path, two more things become possible.

### Grading

`composite()` runs the scene through vignette, warmth, flash and tint. Tell the Frame about the layer and the glyphs are graded with the scene:

```zig
try frame.setGlyphs(glyphs);                    // once: grade glyphs in composite()
screen.output_surface.setGlyphs(glyphs);        // once: resolve them at output
```

Grading writes into the layer's separate output colors (`fg_out`, `bg_out`) and never into the colors you set (`fg_map`, `bg_map`). This matters for persistent text: if grading changed your colors in place, text you never redraw would be dimmed again every frame and fade to black. A white flash now also flashes the text, and the vignette darkens text near the edges like everything else. Scanlines are not applied to glyphs, because a glyph is a whole cell.

### Glyph Light

Glyphs can emit light into the Frame's persistent glow buffer, where the blur and decay turn it into bloom and trails:

```zig
frame.beginFrame();
// ... draw pixels, put glyphs ...
frame.glyphGlow(0.025);                         // every glyph glows softly in its fg color
frame.gcell(x, y, movy.color.v3(0.5, 0.9, 1.0)); // one cell flares (e.g. a character locking in)
frame.composite();
```

`glyphGlow()` skips empty cells and spaces. Keep the strength low: the glow persists and builds up over frames, so values around `0.02 - 0.05` already give a clear halo. Moving text leaves a light trail behind it.

---

## Performance

- **No layer, no cost.** `DiffOutput` is compiled in two versions, and surfaces without a glyph layer run the original pixel loop without any per-cell glyph test. At 200x50 cells with every row changing, the pixel-only path measures the same as before the GlyphLayer existed.
- **With a layer**, glyph cells cost about the same bytes as the half-block cells they replace. Color codes that are already active are not re-sent, so a run of same-colored text costs little more than the characters themselves.
- **Unchanged rows cost zero bytes**, including rows with glyphs. Static text over an animated background costs the same as the background alone. Moving text over a static background only re-sends the rows it touches.
- Frame grading and `glyphGlow()` only visit occupied cells.

---

## Seeing Glyphs Headlessly

`Frame.savePng()` has no font, so it cannot show glyphs. For the headless dev loop, write a frame's ANSI to a file and render it with `tools/ansi2html.py`:

```sh
zig build run-glyph-decrypt -- shot 0.3 /tmp/frame.ans
tools/ansi2html.py /tmp/frame.ans /tmp/frame.html --png /tmp/frame.png
```

The tool replays both `toAnsi()` and `DiffOutput` streams onto a cell grid and, with `--png`, screenshots the result with headless Chrome (set `CHROME=` if it is not found). In your own program, attach the layer to the surface you encode and write `surface.toAnsi()` to a file - see `shot()` in the example.

---

## Quick Reference

### Setup

| Call | Purpose |
|---|---|
| `GlyphLayer.init(allocator, w, h)` | New layer, `w x h` cells, all empty |
| `layer.deinit()` | Free it (surfaces never own their layer) |
| `surface.setGlyphs(layer)` / `setGlyphs(null)` | Attach to / detach from the encoded surface |
| `frame.setGlyphs(layer)` | Grade the layer in `composite()` (returns an error union) |

### Drawing

| Call | Purpose |
|---|---|
| `put(x, y, ch, fg)` | Glyph on a `.pixels` background |
| `putSolid(x, y, ch, fg, bg)` | Glyph on a `.solid` background |
| `putStr(x, y, str, fg)` | UTF-8 string; `\n` returns to `x` on the next row; returns cells written |
| `putStrSolid(x, y, str, fg, bg)` | Same, `.solid` |
| `setFg(x, y, fg)` | Recolor a cell without re-putting it |
| `erase(x, y)` | Empty one cell |
| `clear()` | Empty every cell |

All drawing calls clip silently at the edges.

### Frame

| Call | Purpose |
|---|---|
| `frame.glyphGlow(strength)` | Every glyph adds `fg * strength` to the glow buffer |
| `frame.gcell(x, y, color)` | Add glow to both pixels of one cell (`i32` cell coordinates, like all Frame calls; the layer's own calls take `usize`) |

### Fields

| Field | Meaning |
|---|---|
| `w`, `h` | Size in cells |
| `char_map` | Codepoint per cell, `0` = empty |
| `fg_map`, `bg_map` | The colors you set |
| `bg_mode` | `.pixels` or `.solid` per cell |
| `fg_out`, `bg_out` | What the encoders read - the same memory as `fg_map` / `bg_map` unless a Frame grades the layer |

---

## Important Reminders

1. **Attach the layer to `screen.output_surface`**, not to a surface you add to the screen. With a Frame, call both `frame.setGlyphs()` and `screen.output_surface.setGlyphs()`.
2. **Sizes are in cells:** `screen.w` by `screen.h / 2`.
3. **The layer persists.** Clear it yourself if you redraw per frame.
4. **Pixels cannot cover glyphs.** A sprite flying over text passes behind it. Erase the cells it covers if it should be in front.
5. **One layer per screen.** Draw several text "layers" into the same GlyphLayer in order; the last write wins.
6. **Keep glyph glow low** - it accumulates in the persistent glow buffer.
