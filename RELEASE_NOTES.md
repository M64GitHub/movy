# movy v0.3.1 - Modifier Keys, Scanline Mask & the logo-morph Banner

A point release that rounds out the **input layer** introduced in 0.3.0. Keys now
tell you which modifiers were held, Ctrl+ and Alt+ chords arrive as their own key
types (so they can never leak into a text field), and F-key / Insert coverage is
complete across kitty, xterm and legacy terminals. On the render side, `Frame`
gains a per-pixel **scanline exemption** for HUD text, the build now honors the
standard `-Doptimize` option, and the README's neon banner ships as the runnable
**`logo-morph`** example.

> The full version history lives in [CHANGELOG.md](./CHANGELOG.md).

---

## Modifier flags on `Key`

`movy.input.Key` gained three booleans, all `false` by default:

```zig
pub const Key = struct {
    type: KeyType,
    sequence: []const u8,
    event: KeyEvent = .Press,
    shift: bool = false, // new
    alt: bool = false,   // new
    ctrl: bool = false,  // new
};
```

They are set on keys whose **type** does not already encode the modifier, so an
existing consumer that ignores them keeps working - an Alt+Up is still `.Up`, it
just says `alt = true` now.

- **Arrows / Home / End** carry `alt`. `CSI 1;3A` (Alt+Up) used to be
  indistinguishable from a bare Up; it is also parsed on the legacy path. Ctrl and
  Shift arrows keep their dedicated `Ctrl*` / `Shift*` types.
- **F-keys** carry `alt` / `ctrl` / `shift` - Alt+F9, Ctrl+F5, Shift+F6, Alt+F1 -
  with the same grammar on kitty and xterm.
- **Named keys** (Backspace, Delete, Enter, Escape, Tab, Insert) carry them on
  kitty CSI-u, so Shift+Backspace no longer arrives as a plain Backspace.
- **Shift+Space** sets `shift` on a `.Char` key (kitty only - legacy input cannot
  tell it from a bare space; both are a single `0x20` byte).

Only kitty / xterm modifier-parameter forms can set the flags. Bare legacy
sequences carry no modifier field and stay `false`.

## `CtrlChar` and `AltChar` - chords are commands, not text

Two new `KeyType`s. In both, `sequence` holds the **lowercase character
itself** - never a control byte - so you can bind Ctrl+`-` and Ctrl+`=`, not
just letters.

- **`.CtrlChar`** - Ctrl + any printable. Kitty CSI-u on modern terminals; on
  legacy terminals every C0 control byte (Ctrl+A..Z) maps here too. `.CtrlC`
  keeps its own type.
- **`.AltChar`** - Alt + any printable, kitty CSI-u only (legacy input spells Alt
  as an ESC prefix, which no parser can tell from a real Escape followed by
  typing). `shift` carries the other half of Alt+Shift+X, since the protocol
  reports the base codepoint.

They get their own types on purpose: a chord is a *command*, and a consumer that
routes `.Char` into a text field or a piano must never see it.

```zig
if (try movy.input.get()) |ev| switch (ev) {
    .key => |key| switch (key.type) {
        .Char => typeInto(&editor, key.sequence), // text only - chords never land here
        .CtrlChar => switch (key.sequence[0]) {
            's' => try save(),
            '-' => zoomOut(),
            '=' => zoomIn(),
            else => {},
        },
        .AltChar => if (key.shift) transposeOctave(key.sequence[0])
                    else transposeSemitone(key.sequence[0]),
        .Up, .Down => if (key.alt) jumpPattern(key.type) else moveCursor(key.type),
        .F9 => if (key.alt) toggleDebugHud(),
        .Backspace => if (key.shift) deleteRow() else insertRow(),
        else => {},
    },
    .mouse => {},
};
```

## More keys

- **`KeyType.Insert`** (`CSI 2~`) - previously fell through to `.Other`.
- **F1-F4 in every spelling:** kitty's `CSI 1;mods {P,Q,S}` and `CSI 13~` for F3,
  the xterm legacy `CSI 11~`..`14~`, and the parameterless `CSI P` / `Q` / `S`.

## `Frame.scanline_mask` - keep HUD text above the scanline

A strong `scanline_mul` looks great on the playfield and terrible on small text.
The Frame now has a per-pixel **scanline exemption**: pixels you mark keep full
brightness on odd rows in `composite()`, while every other grade (vignette /
warmth / flash / tint) still applies.

```zig
frame.beginFrame();                 // also clears the mask
frame.rect(x, y, 40, 8, hud_bg);    // draw the HUD as usual
frame.slrect(x, y, 40, 8);          // ...and exempt it from the CRT stripe
// slpx(x, y) marks a single pixel
frame.composite();
```

The mask is a **per-frame transient** - `beginFrame()` clears it, so drawing code
simply re-marks while it stamps each frame.

## New example: `logo-morph`

The looping neon banner at the top of the README is a live movy program, and now
it lives in the repo. The logo is rebuilt every frame from its own grayscale
pixels; a flare beam sweeps across it, energizing and scattering what it touches;
a magenta *ignite* beat fires expanding shockwave rings; then everything settles
back to the clean logo and the loop repeats. Every trail and bloom you see is the
Frame's persistent glow buffer blurring and decaying on its own - there is no
per-object trail bookkeeping anywhere.

```sh
zig build run-logo-morph          # ESC / q quits
zig build run-logo-morph -- shake # add a screen shake on the ignite beat
```

Needs at least a 120x20-cell terminal. The
[examples/logo-morph](./examples/logo-morph/) walkthrough explains the phase-driven
timeline and how each piece maps onto the Frame API.

## Build: the standard optimize option

`build.zig` now uses `b.standardOptimizeOption(.{})` like any Zig project -
**Debug by default**, `-Doptimize=ReleaseFast` for the fast build. It had been a
hard-coded `ReleaseFast` for years; a Debug build keeps the safety checks (leak
detection above all) that the hard-coded mode hid.

If you depend on movy, pass your own mode through as usual:

```zig
const movy_dep = b.dependency("movy", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("movy", movy_dep.module("movy"));
```

---

## Behavior changes

- **`KeyType` grew three values** - `CtrlChar`, `AltChar`, `Insert`. If you
  `switch (key.type)` exhaustively (no `else` arm), the compiler will stop you
  until they are handled: add `.CtrlChar, .AltChar, .Insert => ...` arms, or an
  `else => {}`. Switches that already have `else` are unaffected.
- **Legacy (non-kitty) terminals:** C0 control bytes (Ctrl+A..Z, except `^C` /
  `^H` / `^I` / `^J` / `^M`, which keep their types) now arrive as `.CtrlChar`
  carrying the letter, instead of `.Char` carrying the raw control byte. If you
  matched on the raw byte, match on `.CtrlChar` + the letter instead.
- **Build mode:** movy no longer forces `ReleaseFast` on itself. A dependent
  building in Debug now gets a Debug movy (slower render loop, full safety
  checks). Pass `.optimize = .ReleaseFast` to the dependency to keep the old
  behavior.

No other API changes - the compositing path, `Frame`, `DiffOutput` and the
existing demos are untouched.
