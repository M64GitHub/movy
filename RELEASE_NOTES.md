# movy v0.4.0 - The Glyph Layer & VideoExport

Text joins the pixel scene. Until now, text in movy lived *inside* the pixel
buffer: a character took its colors from the two pixels it covered and replaced
them. The new **`GlyphLayer`** keeps text separate - characters at
terminal-cell resolution, resolved over the half-block pixels only when the
frame is written to the terminal. Glow, gradients and trails now show through
behind text, and text can light up the scene in return.

It works with `DiffOutput`, `toAnsi()` and the `Frame` post-fx stack, costs
nothing for programs that don't use it, and ships with the **`glyph-decrypt`**
example, a full guide in [doc/GlyphLayer.md](./doc/GlyphLayer.md), and a
headless ANSI-to-PNG tool.

And movy programs can now **record themselves**. **`VideoExport`** renders
every frame on a fixed clock into a PNG - pixels, text and glyphs, with a baked
font - and `tools/makevideo.sh` turns the frames into a 1080p60 mp4 with sound.
No screen capture, no dropped frames. The new **`glyph-reel`** showcase uses
both - and its video was made exactly that way.

![glyph-decrypt](./examples/glyph-decrypt/screenshot.png)

> The full version history lives in [CHANGELOG.md](./CHANGELOG.md).

---

## `GlyphLayer` - text inside the scene

A GlyphLayer is a grid of cells, one per terminal cell. Each cell holds a
character, a text color and a background mode:

- **`.pixels`** - the background is the average of the two pixels under the
  cell, resolved every frame. Text you place once sits inside an animated scene
  without being redrawn.
- **`.solid`** - the cell uses its own background color.

Empty cells stay half-block pixels, exactly as before.

```zig
const glyphs = try movy.GlyphLayer.init(allocator, screen.w, screen.h / 2);
defer glyphs.deinit();
screen.output_surface.setGlyphs(glyphs);

glyphs.put(10, 5, 'A', .{ .r = 255, .g = 120, .b = 220 });          // over the pixels
_ = glyphs.putStr(10, 7, "text in the scene", .{ .r = 200, .g = 240, .b = 255 });
_ = glyphs.putStrSolid(10, 9, " SCORE 1200 ", .{}, .{ .r = 255, .g = 120, .b = 220 });
```

Drawing calls: `put`, `putSolid`, `putStr`, `putStrSolid` (UTF-8, `\n`
returns to the start column), `setFg`, `erase`, `clear`. They all clip at the
edges. Double-width codepoints become `◉`, the same rule `putUtf8XY` uses, so a
row never shifts.

### Where it lives

The layer is attached to the surface that gets written to the terminal -
`screen.output_surface` - through the new `RenderSurface.glyphs` field and
`setGlyphs()`. It is resolved at output, not composited by the RenderEngine:

- **Precedence**, highest first: `char_map` text (UI / HUD) > glyphs > pixels.
  Existing text keeps working and always stays on top.
- **One layer per screen.** Draw several text "layers" into it in order; the
  last write wins.
- **Pixels cannot cover glyphs** - a sprite flying over text passes behind it.
  Erase the cells it covers if it should be in front.
- **Debug builds catch mistakes:** `Screen.render()` panics with a clear
  message if a glyph layer is attached to an input surface, where it would
  otherwise be dropped silently.

---

## `DiffOutput` and `toAnsi()` resolve glyphs

Both encoders resolve glyph cells over the final composited pixels.

- **Changed-row detection includes glyphs.** A row is re-sent only when its
  pixels or its glyphs changed, so static text over a static background costs
  zero bytes, and static text over an animated background costs the same as the
  background alone.
- **Color codes that are already active are not re-sent**, so a run of
  same-colored text costs little more than its characters.
- **No layer, no cost.** `DiffOutput` is compiled in two versions; surfaces
  without a glyph layer run the unchanged pixel loop with no per-cell glyph
  test. At 200x50 cells with every row changing, the pixel-only path measures
  the same as in 0.3.1 (98.0 us/frame on both).
- **`DiffOutput.initSize(allocator, w, h, mode)`** - new: a DiffOutput for a
  surface size, without a `Screen`.

---

## `Frame` integration - grading and glyph light

Tell the Frame about the layer, and glyphs become part of the neon look:

```zig
try frame.setGlyphs(glyphs);                     // grade glyphs in composite()
screen.output_surface.setGlyphs(glyphs);         // resolve them at output

frame.beginFrame();
// ... draw pixels, put glyphs ...
frame.glyphGlow(0.025);                          // text blooms into the glow buffer
frame.gcell(x, y, movy.color.v3(0.5, 0.9, 1.0)); // one cell flares up
frame.composite();
```

- **Grading:** `composite()` runs glyph colors through vignette, warmth, flash
  and tint, like the pixels (no scanline: a glyph is a whole cell). It writes
  into the layer's separate output colors (`fg_out` / `bg_out`) and never into
  the colors you set, so text you keep across frames is not graded again every
  frame. A white flash now flashes the text too.
- **Glyph light:** `glyphGlow(strength)` adds every glyph's color to the
  persistent glow buffer; its blur and decay turn that into a bloom halo, and
  moving text leaves a light trail. `gcell(x, y, color)` lights up a single
  cell. Keep strengths low (around `0.02 - 0.05`): the glow accumulates.

---

## `VideoExport` - a movy program records itself

Drive your program on a fixed clock and hand each frame's surface to
`writeFrame()`:

```zig
const ve = try movy.VideoExport.init(allocator, cols, rows, .{ .out_dir = "export" });
defer ve.deinit();

while (ve.frame_n < total_frames) {
    const t = ve.time(); // frame_n / 60 - instead of the wall clock
    drawMyScene(t);
    try ve.writeFrame(surface); // -> export/frame_000000.png, ...
}
```

```sh
tools/makevideo.sh export out.mp4 --audio music.wav    # 1920x1080 @ 60fps H.264 + AAC
```

- **Terminal-true:** the cell rules are DiffOutput's - `char_map` text >
  glyphs (graded, `.pixels` / `.solid` backgrounds) > half-block pixels. Block
  elements and braille are drawn procedurally to fill the cell.
- **Fonts:** JetBrains Mono (default) or DejaVu Sans Mono (the Menlo
  look-alike), baked into cell-sized alpha bitmaps at 19x38 and 10x20 px.
  `tools/bakefont.py` bakes any other monospace TTF, on any OS.
- **Pixel-pure 1080p:** at 19x38 px per cell, half-block pixels are exact
  19x19 squares; a 100x28 cell screen becomes 1900x1064 and pads to
  1920x1080 with no rescaling.
- **Audio:** frame 0 is t = 0, so a track starting at 0 is in sync by
  construction; `--offset MS` nudges it, sample-accurate.
- **Stale frames** from a longer previous export are removed by `init()`.
- **No new dependencies** - movy's bundled lodepng; the video step needs
  ffmpeg. About 38 fps export at 1900x1064 (ReleaseFast).

Full guide: [doc/VideoExport.md](./doc/VideoExport.md).

---

## New example: `glyph-reel`

The v0.4.0 showcase, a ~40 second timeline: the news decrypts behind a scanner
beam, the movy logo rises from below the frame, a `.solid` bar fades in, a
glyph storm throws text off the wave crests, VideoExport decrypts behind a
reverse beam with a `REC` timecode, a v0.3.0 recap, and a closing card.

```sh
zig build run-glyph-reel                     # live, loops (needs 100x28)
zig build run-glyph-reel -- once             # play once, hold the card
zig build run-glyph-reel -- pal ember        # palettes: aurora, decrypt, ember
zig build -Doptimize=ReleaseFast && zig-out/bin/glyph-reel export
tools/makevideo.sh export glyph-reel.mp4     # the video
```

---

## New example: `glyph-decrypt`

A decrypt-style text reveal, TerminalTextEffects-style, in movy's neon look:
characters scramble through random glyphs, lock in left to right with a flash
of light, hold, and dissolve, while a scanner beam and a slowly drifting color
field show through behind them. A status bar shows the `.solid` background
mode.

```sh
zig build run-glyph-decrypt                       # ESC / q quits (needs 100x26)
zig build run-glyph-decrypt -- shot 0.3 out.ans   # headless: write one frame's ANSI
```

---

## New tool: `tools/ansi2html.py`

`Frame.savePng()` has no font, so it cannot show glyphs. `tools/ansi2html.py`
renders movy's terminal output - `toAnsi()` and `DiffOutput` streams alike - to
HTML, and with `--png` to a screenshot via headless Chrome:

```sh
tools/ansi2html.py out.ans out.html --png out.png
```

---

## Docs

- New guide: [doc/VideoExport.md](./doc/VideoExport.md) - the workflow,
  options and fonts, cell rules, audio sync, and a quick reference.
- New guide: [doc/GlyphLayer.md](./doc/GlyphLayer.md) - the workflow,
  background modes, persistence and precedence, Frame grading and glyph glow,
  performance, the headless dev loop, and a quick reference.
- README: a *Glyph Layer* section with a code sample, and the glyph-decrypt
  screenshot.

---

## Behavior changes

None that should affect existing code:

- **`RenderSurface` has a new field**, `glyphs: ?*GlyphLayer`, defaulting to
  `null` and set to `null` by `init()`. Code that never attaches a layer
  renders byte-for-byte as before.
- **`RenderSurface.isDoubleWidth()` is now public** (the GlyphLayer uses it).
- **New top-level exports** `movy.VideoExport` and `movy.video_export`
  (fonts and options) - nothing is compiled in unless you use them.
- **`Frame.composite()`** moved its grading into a shared helper; the math and
  the output are unchanged.

The compositing path, the RenderEngine, `char_map` text, sprites, input and the
existing demos are untouched.
