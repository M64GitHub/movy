# Animation

## Introduction

Welcome to movy's animation system! This module provides utilities for creating smooth, time-based animations in your terminal applications:

- **IndexAnimator** - Cycle through frame indices with different loop modes
- **TrigWave** - Stateful sine/cosine generators for wave motion
- **Trig functions** - Pure trigonometric calculations
- **Easing** - Smooth transitions with ease-in/out curves

All animation modules are available under `movy.animation.*`.

**Location:** `src/animation/`

---

## IndexAnimator

A generic index-based animator that cycles through values between `start` and `end` based on a looping mode. Perfect for controlling sprite animation frames, cycling through states, or any sequence that needs to loop.

**Location:** `src/animation/IndexAnimator.zig`

### Creating an IndexAnimator

```zig
pub fn init(
    start: usize,      // Starting index (inclusive)
    end: usize,        // Ending index (inclusive)
    mode: LoopMode,    // How to loop
) IndexAnimator
```

**Example:**
```zig
const movy = @import("movy");

// Create animator for frames 0-7, looping forward
var animator = movy.animation.IndexAnimator.init(0, 7, .loopForward);
```

### Loop Modes

| Mode | Behavior | Use Case |
|------|----------|----------|
| `.once` | Advances from start to end once, then stops | One-shot animations (jump, attack) |
| `.loopForward` | Cycles start->end, wraps to start | Continuous animations (walk cycle) |
| `.loopBackwards` | Cycles backward end->start, wraps | Reverse animations |
| `.loopBounce` | Bounces start->end->start | Ping-pong animations (idle breathing) |

### Stepping the Animator

Call `step()` each frame to advance the animation:

```zig
pub fn step(self: *IndexAnimator) usize
```

**Example:**
```zig
var animator = movy.animation.IndexAnimator.init(0, 3, .loopForward);

// In your game loop:
const current_frame = animator.step();  // 1
const next_frame = animator.step();     // 2
// ... continues 3, 0, 1, 2, 3, 0, ...
```

### Checking Completion (.once mode)

For one-shot animations, check if the animation has finished:

```zig
if (animator.once_finished) {
    // Animation completed, switch to idle
    try sprite.startAnimation("idle");
}
```

### Usage with Sprites

IndexAnimator is used internally by `Sprite.FrameAnimation`:

```zig
var sprite = try movy.Sprite.initFromPng(allocator, "player.png", "player");
try sprite.splitByWidth(allocator, 32);

// Create animation using frames 1-8
try sprite.addAnimation(
    allocator,
    "walk",
    movy.Sprite.FrameAnimation.init(
        1,              // start frame
        8,              // end frame
        .loopForward,   // loop mode
        3,              // speed (frames to wait)
    ),
);

try sprite.startAnimation("walk");

// In game loop:
sprite.stepActiveAnimation();  // Uses IndexAnimator internally
```

### Reverse Ranges

IndexAnimator supports reverse ranges (start > end):

```zig
// Counts down: 10->9->8->7->...->0
var countdown = movy.animation.IndexAnimator.init(10, 0, .loopForward);
```

---

## TrigWave - Stateful Wave Generators

TrigWave manages stateful sine/cosine movement, perfect for bobbing, oscillation, pulsing, and any periodic motion.

**Location:** `src/animation/TrigWave.zig`

### Creating a TrigWave

```zig
pub fn init(
    duration: usize,   // Frames for a full cycle (period)
    amplitude: i32,    // Wave amplitude (peak displacement)
) TrigWave
```

**Example:**
```zig
// Horizontal wave: 120 frames per cycle, +/- 50 pixels
var wave = movy.animation.TrigWave.init(120, 100);  // amplitude 100 = +/-50
```

**Note:** Amplitude is the **full peak-to-peak range**. The wave oscillates from `-amplitude/2` to `+amplitude/2`.

### Generating Wave Values

Call `tickSine()` or `tickCosine()` each frame to get the next wave value and auto-increment:

```zig
pub fn tickSine(self: *TrigWave) i32
pub fn tickCosine(self: *TrigWave) i32
```

**Example - Horizontal Wave Motion:**
```zig
var wave = movy.animation.TrigWave.init(120, 100);
const center_x: i32 = 50;

// In game loop:
const offset = wave.tickSine();  // Returns -50 to +50
sprite.setXY(center_x + offset, y);
```

### 2D Motion (Combining Sine + Cosine)

Create circular or elliptical motion by combining sine and cosine:

```zig
var horizontal_wave = movy.animation.TrigWave.init(120, 60);  // +/-30 horizontal
var vertical_wave = movy.animation.TrigWave.init(120, 40);    // +/-20 vertical

// In game loop:
const x = center_x + horizontal_wave.tickSine();
const y = center_y + vertical_wave.tickCosine();
sprite.setXY(x, y);  // Creates circular motion
```

### Alpha Pulsing

Animate transparency for fade effects:

```zig
var alpha_wave = movy.animation.TrigWave.init(60, 254);  // 60 frames, 0-254 range

// In game loop:
const alpha_offset = alpha_wave.tickSine();  // -127 to +127
const alpha = @as(u8, @intCast(128 + alpha_offset));  // 1 to 255

try sprite.setAlphaCurrentFrameSurface(alpha);
```

### Phase Offset - Distributing Animations

Create wave effects across multiple objects by pre-ticking to different phases:

```zig
var waves: [8]movy.animation.TrigWave = undefined;

for (0..8) |i| {
    waves[i] = movy.animation.TrigWave.init(120, 80);

    // Offset each wave by 15 frames (120/8 = 15 frames apart)
    for (0..(i * 15)) |_| {
        _ = waves[i].tickSine();
    }
}

// Now each wave is at a different phase of the cycle
```

### Real-World Example

See `demos/blender_demo.zig` for extensive TrigWave usage:
- Logo horizontal sine wave motion (line 113)
- Scrolling text with alpha pulsing (line 135)
- Vertical bobbing motion (line 137-140)
- 8 sprites with distributed 2D wave motion (lines 183, 193)
- 16 circle sprites with pulsing alpha and radius modulation (lines 248-251)
- Flashing text effect (line 295)

**Run demo:**
```bash
zig build run-blender_demo
```

---

## Trig Functions - Pure Calculations

Pure sine/cosine functions for frame-based calculations without state.

**Location:** `src/animation/trig.zig`

### Functions

```zig
pub fn sine(frame: usize, duration: usize, amplitude: i32) i32
pub fn cosine(frame: usize, duration: usize, amplitude: i32) i32
```

**When to use:**
- You want to calculate a wave value for a specific frame
- You're managing the frame counter yourself
- You need pure functions without state

**When to use TrigWave instead:**
- You want automatic frame incrementing
- You're animating in a game loop
- You want simpler API (most common case)

**Example:**
```zig
const movy = @import("movy");

const frame = 30;
const duration = 120;
const amplitude = 100;

const value = movy.animation.trig.sine(frame, duration, amplitude);
// Returns position at frame 30 in a 120-frame cycle
```

**Math:**
- Maps `frame % duration` to 0-2π
- Applies sin/cos function
- Scales by amplitude/2
- Returns rounded i32

---

## Easing - Smooth Transitions

Easing functions provide smooth acceleration/deceleration for animations, making movement feel more natural.

**Location:** `src/animation/ease.zig`

### Easing Functions

Three quadratic easing curves:

```zig
pub fn easeIn(t: f32) f32        // Slow start, fast end (t*t)
pub fn easeOut(t: f32) f32       // Fast start, slow end
pub fn easeInOut(t: f32) f32     // Slow start, fast middle, slow end
```

**Parameter `t`:** Normalized time from 0.0 to 1.0

### Applying Easing to Values

Use `applyEaseFn()` to interpolate between values with easing:

```zig
pub fn applyEaseFn(
    easing: *const fn (t: f32) f32,
    start: f32,
    end: f32,
    frame: usize,
    duration: usize,
) f32
```

**Example - Smooth Sprite Movement:**
```zig
const movy = @import("movy");

const start_x: f32 = 10.0;
const end_x: f32 = 100.0;
const duration: usize = 60;  // 60 frames (1 second at 60 FPS)

var frame: usize = 0;

// In game loop:
const x = movy.animation.ease.applyEaseFn(
    movy.animation.ease.easeInOut,
    start_x,
    end_x,
    frame,
    duration,
);

sprite.setXY(@intFromFloat(x), y);
frame += 1;
```

### Easing Curves

**easeIn** - Accelerating (t²):
```
0.0 -> slow
0.5 -> medium
1.0 -> fast
```

**easeOut** - Decelerating:
```
0.0 -> fast
0.5 -> medium
1.0 -> slow
```

**easeInOut** - Smooth start and end:
```
0.0 -> slow
0.5 -> fast
1.0 -> slow
```

### Common Use Cases

| Easing | Use Case |
|--------|----------|
| easeIn | Object falling, gaining speed |
| easeOut | Object sliding to a stop |
| easeInOut | UI transitions, camera movement |

---

## Quick Reference

### IndexAnimator

| Function | Purpose |
|----------|---------|
| `init(start, end, mode)` | Create animator with loop mode |
| `step()` | Advance to next index |
| `.once_finished` | Check if .once animation completed |

**Loop Modes:** `.once`, `.loopForward`, `.loopBackwards`, `.loopBounce`

### TrigWave

| Function | Purpose |
|----------|---------|
| `init(duration, amplitude)` | Create wave generator |
| `tickSine()` | Get sine value and increment |
| `tickCosine()` | Get cosine value and increment |

**Fields:** `tick` (current frame), `duration` (period), `amplitude` (range)

### Trig Functions

| Function | Purpose |
|----------|---------|
| `sine(frame, duration, amplitude)` | Calculate sine value for frame |
| `cosine(frame, duration, amplitude)` | Calculate cosine value for frame |

### Easing

| Function | Purpose |
|----------|---------|
| `easeIn(t)` | Quadratic ease-in (acceleration) |
| `easeOut(t)` | Quadratic ease-out (deceleration) |
| `easeInOut(t)` | Quadratic ease-in-out (smooth) |
| `applyEaseFn(fn, start, end, frame, duration)` | Apply easing to value over time |

---

## Common Patterns

### Sprite Frame Animation

```zig
try sprite.addAnimation(
    allocator,
    "walk",
    movy.Sprite.FrameAnimation.init(1, 8, .loopForward, 3),
);
try sprite.startAnimation("walk");

// In loop:
sprite.stepActiveAnimation();  // Uses IndexAnimator internally
```

### Horizontal Wave Motion

```zig
var wave = movy.animation.TrigWave.init(120, 100);

// In loop:
sprite.setXY(center_x + wave.tickSine(), y);
```

### Circular Motion

```zig
var h_wave = movy.animation.TrigWave.init(120, 60);
var v_wave = movy.animation.TrigWave.init(120, 60);

// In loop:
sprite.setXY(
    center_x + h_wave.tickSine(),
    center_y + v_wave.tickCosine(),
);
```

### Alpha Pulsing

```zig
var alpha_wave = movy.animation.TrigWave.init(60, 254);

// In loop:
const alpha = @as(u8, @intCast(128 + alpha_wave.tickSine()));
try sprite.setAlphaCurrentFrameSurface(alpha);
```

### Smooth Transition

```zig
const x = movy.animation.ease.applyEaseFn(
    movy.animation.ease.easeInOut,
    start_x,
    end_x,
    frame,
    duration,
);
sprite.setXY(@intFromFloat(x), y);
```

---

## Tips

**Frame Rate Considerations:**
- TrigWave duration is in frames, not seconds
- At 60 FPS: duration=60 = 1 second cycle, duration=120 = 2 seconds
- Adjust durations based on your target frame rate

**Amplitude Notes:**
- TrigWave amplitude is full range (peak-to-peak)
- Wave oscillates from `-amplitude/2` to `+amplitude/2`
- For +/-50 pixel motion, use amplitude=100

**Phase Distribution:**
- Pre-tick TrigWave to start at different phases
- Useful for creating wave effects across multiple objects
- See `demos/blender_demo.zig` for examples

**Easing vs Waves:**
- Easing: One-time smooth transition (A to B)
- Waves: Continuous periodic motion (cycles forever)

Happy animating!
