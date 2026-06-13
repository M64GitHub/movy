# frame-game

A tiny terminal platformer that shows off movy's **neon-render layer** - the
float framebuffer with persistent glow/bloom, linear float color, and the 60fps
dirty-row output path. Run it, read it, copy it as the starting point for your
own glowing terminal game or demo.

![frame-game](screenshot.png)

```sh
zig build run-frame-game        # play
#   move A/D or arrows · jump W/K/space · P pause · R restart · ESC/Q quit

# headless dev loop - render N frames to a PNG (no terminal needed), then look:
zig build run-frame-game -- --shot 160 out.png        # demo bot plays 160 frames
zig build run-frame-game -- --shot 160 out.png 90     # ...spawned at x=90 px
```

## The new way of rendering

Instead of writing colors straight to a `RenderSurface`, you draw into a
**`movy.Frame`** - a float framebuffer with two layers and a post-processing
stack that gives the neon look essentially for free.

```zig
const movy = @import("movy");
const v3 = movy.color.v3;

const frame = try movy.Frame.init(allocator, w, h); // w×h pixels (h/2 text rows)
defer frame.deinit();

// per frame:
frame.beginFrame();                       // decay + blur the persistent glow
frame.rect(x, y, 4, 4, v3(0.1, 0.8, 0.9)); // opaque -> the `solid` layer
frame.grect(x-1, y-1, 6, 6, v3(0.05,0.27,0.34)); // additive light -> the `glow` layer
frame.composite();                        // mix + grade -> frame.surface (u8)
```

### 1. `movy.Frame` - solid + persistent glow

Two float (`V3`) layers, composited:

- **`solid`** - opaque colors (background, bodies, tiles). You rewrite it each
  frame (fill the whole frame, or `@memset(frame.solid, ...)` first).
- **`glow`** - additive light, **persistent**: every `beginFrame()` it is blurred
  and decayed, then this frame's emissions are added on top. A bright thing drawn
  at a still spot each frame → a stable bloom; if it moves → a neon **trail**, with
  zero per-object trail bookkeeping. (Watch the player's glow and the enemy's halo.)

`composite()` = `clamp(solid + glow)` → vignette → scanline → warmth → flash → tint,
written into the owned `frame.surface` (a `RenderSurface`) that `Screen`/`DiffOutput`
consume.

Draw API (all take `color.V3`):
- solid: `px, rect, rectOutline, hline, vline, shadeRect`
- glow (additive): `gpx, grect, ghline, gvline, gring`

Tunable fields (set any time): `glow_decay`, `glow_blur`, `scanline_mul`,
`vignette_amt` (via `setVignette()`), plus grading state `warmth` (a symmetric
R↔B swap for a warm/cool or polarity palette flip), `flash` / `flash_col`, and
`tint` (e.g. this demo dims `tint` while paused).

### 2. `movy.color.V3` - linear float color

`V3{ r, g, b }` (0..1, may exceed 1.0 while light accumulates - that's how glow
blooms). Helpers: `v3(r,g,b)`, `.add/.scale/.mul/.lerp`, `.toRgb()`/`.fromRgb()`,
and `WHITE_F`/`BLACK_F`. Work in `V3` while drawing; `composite()` clamps and
quantizes to the terminal's 8-bit `Rgb` for you. Keep your palette in one file
(see `pal.zig`, which just re-exports `movy.color`).

### 3. `movy.DiffOutput` - 60fps terminal output

Terminal *output* is the real cost (a full ANSI repaint is hundreds of KB; the
blocking `write()` stalls under tmux/ssh). `DiffOutput` re-sends only the rows
that changed and, in `.threaded` mode, hands the write to a background thread -
dropping a frame instead of freezing the loop.

```zig
var dout = try movy.DiffOutput.init(allocator, &screen, .threaded);
defer dout.deinit();
// after screen.render() + any text overlays:
try dout.output(&screen);
```

### The loop, end to end

```
input → game.update() → frame.beginFrame() → game.render(frame) → frame.composite()
      → screen.renderInit()/addRenderSurface(frame.surface)/render()
      → text overlays onto screen.output_surface → dout.output(&screen)
      → sleep to the next frame deadline
```

## Worth knowing

- **Half-block pixels.** A cell stacks 2 pixels (upper/lower, rendered as `▄`),
  so an `h`-pixel-tall frame is `h/2` text rows; vertical resolution is the
  expensive axis.
- **Clear `solid` each frame.** It is not auto-cleared. The demo's full-screen
  background gradient does this; otherwise `@memset(frame.solid, movy.color.BLACK_F)`.
  The `glow` buffer is managed for you by `beginFrame()`.
- **Stepped time clocks.** For anything meant to look static, keep it
  byte-identical between frames (`@floor(t*N)/N`) so the dirty-row diff skips it -
  the static gradient background costs ~0 bytes for exactly this reason.
- **Scanlines band flat fills.** The CRT scanline darkens odd rows; large flat
  blocks look striped. Add vertical detail / internal gradients (or lean on the
  glow), as the player and tile sprites do.
- **`savePng` needs libC.** `Frame.savePng` uses movy's bundled lodepng, so the
  build links libC (`fg_exe.linkLibC()` in `build.zig`). That's the headless
  screenshot path that makes `--shot` work.

## Files

| file | role |
|------|------|
| `main.zig` | terminal lifecycle, title/playing/paused states, the frame loop, `--shot` |
| `game.zig` | orchestrator: level + player + camera + a patrolling/stompable enemy; holds `LEVEL_DATA` |
| `player.zig` | sub-pixel physics: accel/friction, fixed jump arc, coyote time, jump buffer, pixel-stepped collision |
| `level.zig` | ASCII tile world + collision queries + neon-edge render |
| `camera.zig` | eased follow + clamp + trauma shake |
| `input.zig` | hold-window + kitty input model (terminals have no key-release events) |
| `config.zig` | all tuning constants (view, physics, key timing) |
| `pal.zig` | named colors (re-exports `movy.color.V3`/`v3`) |
