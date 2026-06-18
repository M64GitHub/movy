# logo-morph

The looping neon banner at the top of the project [README](../../README.md), as a
small, runnable movy program. The movy logo is rebuilt every frame from its own
grayscale pixels; a flare beam sweeps across it, energizing and scattering the
pixels it touches, with a purple **ignite** beat and expanding shockwave rings -
then everything settles back to the clean logo and the loop repeats.

It is built entirely on movy's **Frame** neon-render path: a float framebuffer
with a persistent, additive glow buffer (bloom + neon trails for free) and a
built-in CRT post-fx stack. There is no per-object trail bookkeeping anywhere -
the glow you see is the Frame's own glow buffer blurring and decaying each frame.

```sh
zig build run-logo-morph          # run it (ESC / q quits)
zig build run-logo-morph -- shake # add a screen shake on the ignite beat
```

> Needs a terminal of at least **120x20 cells** (the banner is 120x40 px = 120x20
> text rows via half-block rendering). It centers itself in whatever terminal size
> you have.

## The effect, over one loop

The whole animation is driven by a single **loop phase** `n` running 0 → 1 (see
`scene()` in `main.zig`). Nothing is keyed to a frame counter, so the live view
stays smooth at 60fps and the loop length is just one constant (`LOOP_SECONDS`).

| phase `n` | what happens |
|-----------|--------------|
| `0.00` | clean logo - true grays, **no glow at rest** |
| `0.00 → 0.50` | the flare **beam sweeps** left → right (`SWEEP_FRAC`) |
| at the beam | pixels **energize** (brighten) and **scatter** outward (`disturb` + `SCATTER`), cool cyan glow |
| behind the beam | a warm **scorch** glow lingers on the bright walls, then fades (`SCORCH`) |
| `0.45` | the **ignite** beat - a magenta flash + two expanding **rings** (`IGNITE`) |
| `0.60` | a smaller, cooler **echo** beat (`BEAT2`) |
| `0.42 → 0.84` | an **afterglow swell** rises, then settles (magenta → white) |
| `→ 1.00` | glow decays back to the **clean** logo; the loop closes seamlessly |

The key idea: **glow is emitted only transiently** - where the beam is touching,
in the scorch trail just behind it, and during the afterglow swell. At rest the
logo emits no glow at all, so its real grayscale (the frame, the top/right
heat-strip gradient) stays crisp instead of being washed out by a constant bloom.

## How it uses the Frame path

Each frame the loop runs the standard Frame cycle (in `movyfx.runLive`):

```zig
frame.beginFrame();              // decay + blur the persistent glow buffer
@memset(frame.solid, BLACK);     // clear the opaque layer
scene(frame, &particles, n);     // draw this frame at loop phase n
frame.composite();               // mix solid + glow, run post-fx -> frame.surface
```

`scene()` draws into the Frame's two layers:

- **`solid`** (opaque) via `f.px` / `f.vline` - the crisp logo pixels and the
  bright white core of the sweeping beam.
- **`glow`** (additive, *persistent*) via `f.gpx` / `f.gvline` / `f.ghline` /
  `f.gring` - the energize bloom, the scorch, the horizontal anamorphic streak,
  and the shockwave rings. Because `beginFrame()` blurs and decays this buffer
  every frame, a moving emitter (the beam) leaves a soft trail and the afterglow
  fades on its own - **nothing stores or redraws a trail by hand**.

It also nudges the Frame's grading directly: `f.flash` / `f.flash_col` for the
ignite and echo beats, and `f.glow_decay` for how fast the bloom settles back.
Colors are linear-float `movy.color.V3` throughout (see `pal.zig`); `composite()`
clamps and quantizes to the terminal's 8-bit color for you.

## The logo

`logo.zig` is the movy logo as a 61x18 grayscale byte array (0 = transparent,
mid grays = the frame + heat-strip, 255 = the bright walls). It was extracted
from the real source asset,
[`demos/assets/movy-logo2.png`](../../demos/assets/movy-logo2.png).
`Particles.init` turns every non-zero pixel into one entry (`tx, ty, v, wall`)
that `scene()` reads to rebuild - and disturb - the logo each frame.

## Files

| file | role |
|------|------|
| `main.zig` | the scene (the whole effect) + a tiny `main` that inits the particles and runs the loop |
| `movyfx.zig` | the harness: canvas size, math helpers, the `Particles` system, post-fx tuning, and the 60fps live terminal loop + prompt overlay |
| `pal.zig` | named colors (re-exports `movy.color.V3` / `v3`) |
| `logo.zig` | the 61x18 grayscale logo bitmap, inlined as a byte array |

## Worth knowing

- **Phase-driven, not frame-driven.** Everything reads `n` in `[0,1)`, so timing
  is resolution-independent; `LOOP_SECONDS` alone sets the speed.
- **Half-block pixels.** A cell stacks two pixels (rendered as `▄`), so the
  40px-tall canvas is 20 text rows - vertical resolution is the expensive axis.
- **The shell prompt** under the banner (`~/get/movy  master …`) is real terminal
  text drawn onto the composited surface in `drawPrompt` - a quick demo of
  overlaying text on a Frame.
- This example began life in a separate **movy-fx** project (a family of logo
  animations that also export PNG sequences for GIFs); here it is trimmed to the
  live terminal path only.
