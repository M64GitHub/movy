# movy v0.3.0 - Frame Rendering & the Neon-Render Layer

This release adds a second, game-focused **rendering path** alongside the existing
surface-compositing pipeline. Instead of compositing many surfaces, you draw into a
single float framebuffer and get **glow / bloom** and a **CRT post-fx stack**
essentially for free - then push it to the terminal at **60fps** with the new
diffing output. A complete **`frame-game`** demo ties it all together.

> The full version history lives in [CHANGELOG.md](./CHANGELOG.md).

---

## Frame rendering path - `movy.Frame`

A float framebuffer (built on `RenderSurface`) with two layers and its own
post-processing stack - the "neon-render layer".

- **Two layers.** A `solid` layer for opaque colors (background, bodies, tiles),
  rewritten each frame, and a `glow` layer that is **additive and persistent**: every
  `beginFrame()` blurs and decays it, then this frame's emissions are added on top.
  A bright thing at a still spot becomes a stable **bloom**; if it moves you get a
  neon **trail** - with zero per-object bookkeeping.
- **`composite()` post-fx stack.** `clamp(solid + glow)` → vignette → scanline →
  warmth → flash → tint, written into an owned `RenderSurface` that `Screen` /
  `DiffOutput` consume.
- **Draw API.** `px`, `rect`, `rectOutline`, `hline`, `vline`, `shadeRect` for the
  solid layer; `gpx`, `grect`, `ghline`, `gvline`, `gring` for the additive glow.
- **Tunable any time.** `glow_decay`, `glow_blur`, `scanline_mul`, `vignette_amt`
  (via `setVignette()`), plus grading state `warmth`, `flash` / `flash_col`, `tint`.
- **Headless dev loop.** `savePng()` writes the composited frame to a nearest-upscaled
  PNG (movy's bundled lodepng; requires `exe.linkLibC()`), so you can iterate on
  visuals without a real terminal.

```zig
const frame = try movy.Frame.init(allocator, w, h); // w×h pixels (h/2 text rows)
defer frame.deinit();

// per frame:
frame.beginFrame();                              // decay + blur the persistent glow
frame.rect(x, y, 4, 4, v3(0.1, 0.8, 0.9));       // opaque  -> the `solid` layer
frame.grect(x - 1, y - 1, 6, 6, v3(0.05, 0.27, 0.34)); // light -> the `glow` layer
frame.composite();                               // mix + grade -> frame.surface
```

Exposed as `movy.Frame` (and `movy.render.Frame`).

## Linear float color - `movy.color.V3`

The working color type for the Frame path.

- `V3{ r, g, b }` - linear float color, 0..1 nominal (may exceed 1.0 while light
  accumulates, which is exactly what makes glow bloom).
- Helpers: `v3(r, g, b)` constructor, `add` / `scale` / `mul` / `lerp`,
  `toRgb()` / `fromRgb()`, and `WHITE_F` / `BLACK_F`.

## High-throughput output - `movy.DiffOutput`

A faster, drop-in replacement for `screen.output()`.

- **Dirty rows.** Each terminal row is compared against the previous frame; unchanged
  rows cost **zero bytes**, and fg/bg codes already active are never re-sent.
- **`.threaded` mode.** A background writer thread owns the blocking `write()` with a
  latest-wins mailbox - the render loop never stalls; if the terminal can't keep up, a
  frame is **dropped instead of freezing** the app. Essential under tmux / ssh.
- `force_full` repaints everything (e.g. after an external clear).

```zig
var dout = try movy.DiffOutput.init(allocator, &screen, .threaded);
defer dout.deinit();
// after screen.render() and any text overlays:
try dout.output(&screen);
```

## Kitty keyboard protocol input

`movy.input` now speaks the
[kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/),
delivering real key **press / repeat / release** events on supporting terminals
(kitty, ghostty, wezterm, foot, recent iTerm2). Legacy terminals are unaffected and
keep reporting `.Press`.

- `enableKittyKeyboard()` / `disableKittyKeyboard()` - push/pop the protocol flags
  (call after entering the alternate screen).
- `detectKittyKeyboard(timeout_ms)` - autodetect support via a `CSI ? u` + Primary
  Device Attributes handshake (no fixed sleep in the common case).
- `Key.event` is now a `KeyEvent` (`.Press`, `.Repeat`, `.Release`).

## New demo: `frame-game`

A complete, copy-able neon platformer that exercises the whole new path - `Frame`
glow/bloom, `V3` color, 60fps `DiffOutput`, and kitty input - alongside sub-pixel
platformer physics, pixel-stepped tile collision, a follow camera with screen shake,
and the headless `--shot` PNG dev loop. It's the recommended starting point for your
own glowing terminal game.

```sh
zig build run-frame-game                         # play
zig build run-frame-game -- --shot 160 out.png   # headless: render 160 frames to a PNG
```

See [demos/frame-game](./demos/frame-game/) for a full walkthrough of the Frame path.

---

## Notes

- Both rendering paths share the same `RenderSurface`, `Screen`, and terminal output,
  so you can mix them freely.
- No breaking changes to the compositing path or existing demos.
