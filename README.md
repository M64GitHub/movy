![License](https://img.shields.io/badge/License-MIT-85adf2?style=flat)
![Version](https://img.shields.io/badge/Version-0.0.0-85adf2?style=flat)
![Zig](https://img.shields.io/badge/Zig-0.14.0-orange?style=flat)

![get-movy](https://github.com/user-attachments/assets/aa86dded-8e47-404c-bdbe-7db8b04bdbaf)

**movy** is a graphics rendering-, effects-, and animation engine for the terminal. 

It transforms your terminal into a vibrant, graphical playground — blending pixel-level rendering with event-driven interaction.

## A Hacker’s Dream Canvas

**movy** began as a rendering engine for games — with layered drawing, alpha blending, z-index ordering, and a programmable rendering pipeline that brings motion and color to the terminal.  

Designed for visual expressiveness and high frame rates, it draws with ANSI half-blocks to double vertical resolution, supports sprite rendering with transparency, and enables per-frame composition with rich visual effects.

Visual elements render into pixel matrices that can be transformed through reusable effect chains, applied in sequence to build up layered visuals and transitions. Final output is composed through a rendering pipeline that merges all surfaces into a single frame.

Animations are driven by reusable components that modulate indices and values over time. Frames can be cycled through index-based animation, while motion and transitions are controlled using waveform generators or easing curves. This makes it easy to animate frame sets, coordinates, palettes, or entire visual sequences in a smooth and expressive way.

The result is a modular visual engine that invites experimentation — composable, expressive, and built to empower you to create, style, and interact with ease.

![mouse_demo](https://github.com/user-attachments/assets/d9852663-fe6d-4119-8c15-90501a3622c1)
(alien mouse move demo)


![screenshot](https://github.com/user-attachments/assets/c5e4885b-2f31-49d7-aa35-bdc4dff5eefe)
(dev snapshot of a game)

![win_demo](https://github.com/user-attachments/assets/4ceae31d-bbb1-4a2c-95d9-8bd09e2a513b)
(window demo)

## Core Concepts

At its heart, **movy** is built on composable rendering, effect-driven visuals, and structured interaction. The system is organized around a few core types that coordinate how visuals are drawn, animated, and composed on screen.

### Rendering Engine Concepts

**movy**'s rendering engine is centered around composable surfaces and reusable visual logic.

- **RenderSurface** is the foundational structure — a 2D matrix of pixels (with optional text overlays) that anything visual draws onto. It can be resized, cleared, and converted to ANSI via `.toAnsi()`.

- **RenderEffect** modifies a RenderSurface by applying visual transformations such as blur, dim, stretch, or color shifting. It receives input and output surfaces via a `RenderEffectContext`, which handles size awareness and expansion when needed. Internally, `RenderEffect` acts as an interface and wraps an effect instance to make it compatible with chaining, pipelines, and dynamic surface management.  
  Each effect defines its own `run()` method and `validate()` method, and can optionally declare how much space it requires beyond the surface bounds. Effects can be run manually on surfaces, or exposed through a simple `asEffect()` function to integrate cleanly into the rendering system. They will automatically operate with `RenderEffectContext`, gaining full expansion handling and chaining capabilities.

- **RenderEffectContext** bundles an input surface, an output surface, and tracks any applied surface expansion. It allows effects and chains to dynamically resize their output to support visuals like glow or shake.

- **RenderEffectChain** is a reusable sequence of effects, applied in order to a `RenderEffectContext`. It takes care of intermediate surface allocation and ensures the final output is properly expanded. It's ideal for chaining multiple post-processing steps like fade → blur → glow.

- **RenderObject** combines a `RenderEffectContext` with an optional `RenderEffectChain`. It acts as a unit of rendering — providing a structured way to send a visual input surface through the effect system. The output surface is automatically created and kept in sync. (Conceptually, it's "a surface + maybe effects".)

- **RenderPipeline** processes a list of `RenderObject`s. Each object's effect chain (if present) is run, and their results are composited using the **RenderEngine**. Optionally, a final post-processing chain can be applied to the merged result.

- **RenderEngine** performs the actual surface merge. It composites multiple `RenderSurface`s into a single output, applying z-ordering, pixel blending, and visibility logic. This is used by the pipeline, UI system, and manual rendering flows.

- **Screen** holds the final output surface. Manually, it allows you to add `RenderSurface`s or `Sprite`s directly and call `screen.render()` to composite them using the **RenderEngine**. Alternatively, its output surface can be rendered by the **RenderPipeline** or the **UI Manager**. Finally, `screen.output()` prints the result to the terminal using ANSI escape sequences.



#### Sprite Rendering

- Sprites hold a **SpriteFrameSet**: an array of frames, each with its own **RenderSurface**.
- Changing the current frame index animates the sprite.

#### Animation Helpers

- **IndexAnimator** is a generic animation helper that updates indices over time. It supports forward, reverse, ping-pong, and one-shot modes, and can also be used for palette cycling, or any index based effects.
- **TrigWave** provides reusable sine and cosine generators with internal state. These simplify wave-based animations such as pulsing highlights, bobbing motion, or cyclic transitions.
- **Easing** - for easing curve based animations, functions for easing -in/-out/-inout are provided.

## movy_video

A latest addition to **movy** is **movy_video** — a video decoding and rendering module that brings full-motion video playback directly to the terminal.

**movy_video** provides a complete video decoding pipeline using FFmpeg, with support for:
- **Video decoding** for all FFmpeg-supported formats (.mp4, .h264, .avi, .mkv, .webm, etc.)
- **Audio playback** with synchronized timing using SDL2
- **Frame scaling** and conversion to RGB for terminal rendering
- **Audio/video synchronization** with configurable sync windows
- **Seeking** with forward/backward navigation
- **Frame queueing** for smooth playback

The module exposes a `VideoDecoder` type that manages the entire decode pipeline, from opening media files to extracting frames and audio samples. Video frames are automatically scaled and rendered to **movy** `RenderSurface` objects, allowing seamless integration with the rest of the rendering engine.

See [movycat](https://github.com/M64GitHub/movycat) for a complete terminal video player built with **movy_video**.

### FFmpeg Compatibility

**movy_video** has been tested and confirmed working with:
- **FFmpeg 8.0** (macOS via Homebrew)
- **FFmpeg 7.1.1** (Ubuntu via apt)

The module uses the modern FFmpeg channel layout API (`AVChannelLayout`) and is compatible with both FFmpeg 7.x and 8.x versions.

# Building

```
zig build -Dvideo=true
```
# TECH DOCS

## RENDERING A SPRITE TO THE SCREEN

```
Primitive Rendering Overview: Render a Sprite on Screen
========================================================

Use Case: Render a sprite with effects and output to terminal


┌─────────────────────────────────────────────────────────────────────────────┐
│                           SPRITE STRUCTURE                                  │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │  Sprite                                                            │     │
│  │  ┌──────────────────────────────────────────────────────────────┐  │     │
│  │  │ SpriteFrameSet                                               │  │     │
│  │  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │  │     │
│  │  │  │ SpriteFrame[0] │  │ SpriteFrame[1] │  │ SpriteFrame[n] │  │  │     │
│  │  │  │ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │  │  │     │
│  │  │  │ │data_surface│ │  │ │data_surface│ │  │ │data_surface│ │  │  │     │
│  │  │  │ │(original)  │ │  │ │(original)  │ │  │ │(original)  │ │  │  │     │
│  │  │  │ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │  │  │     │
│  │  │  │       │        │  │       │        │  │       │        │  │  │     │
│  │  │  │       ▼        │  │       ▼        │  │       ▼        │  │  │     │
│  │  │  │ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │  │  │     │
│  │  │  │ │output_     │ │  │ │output_     │ │  │ │output_     │ │  │  │     │
│  │  │  │ │ surface    │ │  │ │ surface    │ │  │ │ surface    │ │  │  │     │
│  │  │  │ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │  │  │     │
│  │  │  └────────────────┘  └────────────────┘  └────────────────┘  │  │     │
│  │  │       current_frame_index ──────────────────┘                │  │     │
│  │  └──────────────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────┬──────────────────────────────────────────┘
                                   │ Select current frame's output_surface
                                   ▼
        ┌──────────────────────────────────────────────────────────┐
        │         RenderSurface (from current frame)               │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ • color_map: []Rgb    (pixel colors)               │  │
        │  │ • shadow_map: []u8    (opacity: 0=transparent)     │  │
        │  │ • char_map: []u21     (text overlay)               │  │
        │  │ • x, y, z: position and z-order                    │  │
        │  └────────────────────────────────────────────────────┘  │
        └──────────────────┬───────────────────────────────────────┘
                           │ Used as input
                           ▼
        ┌──────────────────────────────────────────────────────────┐
        │              RENDER OBJECT                               │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ RenderEffectContext                                │  │
        │  │  ┌──────────────┐          ┌──────────────┐        │  │
        │  │  │input_surface │   ────>  │output_surface│        │  │
        │  │  │(sprite frame)│          │(transformed) │        │  │
        │  │  └──────────────┘          └──────────────┘        │  │
        │  │         │                         ▲                │  │
        │  │         │                         │                │  │
        │  │         └─────────────┬───────────┘                │  │
        │  │                       │                            │  │
        │  │         ┌─────────────▼───────────────┐            │  │
        │  │         │ RenderEffectChain (optional)│            │  │
        │  │         │  ┌─────────────────────────┐│            │  │
        │  │         │  │ Effect 1: Fade          ││            │  │
        │  │         │  │   input ──> output      ││            │  │
        │  │         │  └────────┬────────────────┘│            │  │
        │  │         │           │                 │            │  │
        │  │         │  ┌────────▼────────────────┐│            │  │
        │  │         │  │ Effect 2: Blur          ││            │  │
        │  │         │  │   input ──> output      ││            │  │
        │  │         │  └────────┬────────────────┘│            │  │
        │  │         │           │                 │            │  │
        │  │         │  ┌────────▼────────────────┐│            │  │
        │  │         │  │ Effect 3: Brighter      ││            │  │
        │  │         │  │   input ──> output      ││            │  │
        │  │         │  └─────────────────────────┘│            │  │
        │  │         └─────────────────────────────┘            │  │
        │  │                                                    │  │
        │  └────────────────────────────────────────────────────┘  │
        └──────────────────┬───────────────────────────────────────┘
                           │ .process() produces transformed output
                           ▼
        ┌──────────────────────────────────────────────────────────┐
        │              RENDER PIPELINE                             │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ render_objects: [RenderObject, RenderObject, ...]  │  │
        │  │                                                    │  │
        │  │ 1. Process each RenderObject:                      │  │
        │  │    • Run effect chain on input_surface             │  │
        │  │    • Produce output_surface                        │  │
        │  │                                                    │  │
        │  │ 2. Collect all output surfaces                     │  │
        │  │    ┌──────────┐  ┌──────────┐  ┌──────────┐        │  │
        │  │    │ surface1 │  │ surface2 │  │ surfaceN │        │  │
        │  │    └──────────┘  └──────────┘  └──────────┘        │  │
        │  │         │              │              │            │  │
        │  │         └──────────────┼──────────────┘            │  │
        │  │                        ▼                           │  │
        │  │            ┌───────────────────────┐               │  │
        │  │            │   RenderEngine.merge  │               │  │
        │  │            │ • Apply z-ordering    │               │  │
        │  │            │ • Blend pixels        │               │  │
        │  │            │ • Handle transparency │               │  │
        │  │            └───────────┬───────────┘               │  │
        │  │                        ▼                           │  │
        │  │                 result_surface                     │  │
        │  │                        │                           │  │
        │  │ 3. Optional final effect chain:                    │  │
        │  │    result ──> [post-process] ──> output_surface    │  │
        │  │                                                    │  │
        │  └────────────────────────────────────────────────────┘  │
        └──────────────────┬───────────────────────────────────────┘
                           │ Rendered to output_surface
                           ▼
        ┌──────────────────────────────────────────────────────────┐
        │                       SCREEN                             │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ output_surface ← (from pipeline or manual render)  │  │
        │  │                                                    │  │
        │  │ Manual mode:                                       │  │
        │  │   screen.addSprite(sprite)                         │  │
        │  │   screen.addRenderSurface(surface)                 │  │
        │  │   screen.render() ── uses RenderEngine.merge ──┐   │  │
        │  │                                                │   │  │
        │  │ Pipeline mode:                                 │   │  │
        │  │   pipeline.run() ── outputs to ───────────────┐│   │  │
        │  │   screen.output_surface                       ││   │  │
        │  │                                               ││   │  │
        │  │   ┌───────────────────────────────────────────▼▼─┐ │  │
        │  │   │         Final Composited Surface             │ │  │ 
        │  │   │  ┌────────────────────────────────────────┐  │ │  │ 
        │  │   │  │ All sprites/surfaces merged            │  │ │  │ 
        │  │   │  │ with z-ordering and effects applied    │  │ │  │ 
        │  │   │  └────────────────────────────────────────┘  │ │  │ 
        │  │   └───────────────────┬──────────────────────────┘ │  │ 
        │  │                       │                            │  │
        │  │                       ▼                            │  │
        │  │           screen.output() → .toAnsi()              │  │
        │  │                       │                            │  │
        │  └───────────────────────┼────────────────────────────┘  │
        └────────────────────────────┼─────────────────────────────┘
                                     │ Convert to ANSI half-blocks
                                     ▼
        ┌──────────────────────────────────────────────────────────┐
        │                    TERMINAL OUTPUT                       │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ ANSI escape sequences:                             │  │
        │  │  • Cursor positioning                              │  │
        │  │  • RGB color codes (foreground/background)         │  │
        │  │  • Half-block characters (▀ ▄) for 2x resolution   │  │
        │  │  • Text overlay from char_map                      │  │
        │  └────────────────────────────────────────────────────┘  │
        └──────────────────────────────────────────────────────────┘


KEY CONCEPTS:
=============

RenderSurface: 2D pixel matrix (color_map, shadow_map, char_map)
                └─> Basic building block for all visuals

RenderEffect:   Transformation applied to a RenderSurface
                └─> Examples: Fade, Blur, Brighter, Darker

RenderEffectChain: Sequence of effects applied in order
                   └─> Input ──> Effect1 ──> Effect2 ──> ... ──> Output

RenderEffectContext: Bundles input + output surface + expansion tracking
                     └─> Enables effects to modify surface size

RenderObject:   input_surface + optional_effect_chain ──> output_surface
                └─> Unit of rendering in pipeline

RenderEngine:   Compositor that merges multiple surfaces
                └─> Handles z-order, blending, transparency

RenderPipeline: Orchestrates multiple RenderObjects
                └─> Process all → Merge → Optional post-process

Screen:         Top-level output canvas
                └─> Converts final surface to ANSI and prints


TYPICAL FLOW:
=============

1. Load sprite from PNG → creates Sprite with SpriteFrameSet
2. Each frame has data_surface (original) and output_surface (for effects)
3. Create RenderObject with sprite's current frame output_surface as input
4. Attach RenderEffectChain to RenderObject (optional)
5. Add RenderObject to RenderPipeline
6. Pipeline.run() → processes all objects → merges via RenderEngine
7. Result written to Screen.output_surface
8. Screen.output() → converts to ANSI → prints to terminal
```

## ANIMATE A SPRITE FROM PNG SPRITESHEET

```
Animated Sprite Guide: Complete Workflow
=========================================

Use Case: Load a PNG spritesheet, auto-split into frames, animate, and render


STEP 1: PNG SPRITESHEET FILE
=============================
        ┌──────────────────────────────────────────────────────────┐
        │              PNG Spritesheet File                        │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │  "character_walk.png"                              │  │
        │  │                                                    │  │
        │  │  ┌────┬────┬────┬────┬────┬────┐                   │  │
        │  │  │ F0 │ F1 │ F2 │ F3 │ F4 │ F5 │  ← 6 frames       │  │
        │  │  │    │    │    │    │    │    │    horizontally   │  │
        │  │  └────┴────┴────┴────┴────┴────┘                   │  │
        │  │                                                    │  │
        │  │  Total width:  384 pixels (64 × 6 frames)          │  │
        │  │  Frame height:  64 pixels                          │  │
        │  │  Frame width:   64 pixels                          │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼


STEP 2: LOAD SPRITESHEET AS SPRITE
===================================
        ┌──────────────────────────────────────────────────────────┐
        │    Sprite.initFromPng("character_walk.png", "walk")      │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ Loads entire PNG as single frame (frame 0)         │  │
        │  │  • Creates Sprite with 1 frame                     │  │
        │  │  • frame_set.frames[0] = entire spritesheet        │  │
        │  │  • w = 384, h = 64 (full spritesheet dimensions)   │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼
        ┌──────────────────────────────────────────────────────────┐
        │          Initial Sprite Structure                        │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ Sprite: "walk"                                     │  │
        │  │  • w: 384, h: 64 (full spritesheet size)           │  │
        │  │                                                    │  │
        │  │  frame_set:                                        │  │
        │  │  ┌──────────────────────────────────────────────┐  │  │
        │  │  │ frame_idx: 0                                 │  │  │
        │  │  │ frames: [*SpriteFrame]                       │  │  │
        │  │  │  ┌────────────────────────────────────────┐  │  │  │
        │  │  │  │ [0]: SpriteFrame                       │  │  │  │
        │  │  │  │      w: 384, h: 64                     │  │  │  │
        │  │  │  │      data_surface: 384×64              │  │  │  │
        │  │  │  │      ┌─────────────────────────────┐   │  │  │  │
        │  │  │  │      │ ┌──┬──┬──┬──┬──┬──┐         │   │  │  │  │
        │  │  │  │      │ │F0│F1│F2│F3│F4│F5│ (full)  │   │  │  │  │
        │  │  │  │      │ └──┴──┴──┴──┴──┴──┘         │   │  │  │  │
        │  │  │  │      └─────────────────────────────┘   │  │  │  │
        │  │  │  │      output_surface: 384×64            │  │  │  │
        │  │  │  └────────────────────────────────────────┘  │  │  │
        │  │  └──────────────────────────────────────────────┘  │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼


STEP 3: SPLIT SPRITESHEET INTO FRAMES
======================================
        ┌──────────────────────────────────────────────────────────┐
        │         sprite.splitByWidth(allocator, 64)               │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ Parameters:                                        │  │
        │  │  • split_width: 64 (width of each frame)           │  │
        │  │                                                    │  │
        │  │ Process:                                           │  │
        │  │  1. Calculate: num_frames = 384 / 64 = 6           │  │
        │  │                                                    │  │
        │  │  2. For each frame (0..5):                         │  │
        │  │     • Create new SpriteFrame(64, 64)               │  │
        │  │     • Copy region from frames[0].data_surface:     │  │
        │  │       - source_x = frame_idx × 64                  │  │
        │  │       - source_y = 0                               │  │
        │  │       - Copy 64×64 pixels (color, shadow, char)    │  │
        │  │     • Append to frame_set.frames                   │  │
        │  │                                                    │  │
        │  │  3. Set frame_idx = 1 (skip original spritesheet)  │  │
        │  │  4. Update sprite.w = 64 (individual frame width)  │  │
        │  │                                                    │  │
        │  │ Result:                                            │  │
        │  │  • frames[0]: Original 384×64 spritesheet (kept)   │  │
        │  │  • frames[1]: Frame 0 (64×64)                      │  │
        │  │  • frames[2]: Frame 1 (64×64)                      │  │
        │  │  • frames[3]: Frame 2 (64×64)                      │  │
        │  │  • frames[4]: Frame 3 (64×64)                      │  │
        │  │  • frames[5]: Frame 4 (64×64)                      │  │
        │  │  • frames[6]: Frame 5 (64×64)                      │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼
        ┌──────────────────────────────────────────────────────────┐
        │           Sprite After Split                             │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ Sprite: "walk"                                     │  │
        │  │  • w: 64 (updated to frame width)                  │  │
        │  │  • h: 64                                           │  │
        │  │                                                    │  │
        │  │  frame_set:                                        │  │
        │  │  ┌──────────────────────────────────────────────┐  │  │
        │  │  │ frame_idx: 1 (starts at first split frame)   │  │  │
        │  │  │                                              │  │  │
        │  │  │ frames: [*SpriteFrame] (7 total)             │  │  │
        │  │  │  ┌────────────────────────────────────────┐  │  │  │
        │  │  │  │ [0]: Original spritesheet 384×64       │  │  │  │
        │  │  │  │      (kept but not used for animation) │  │  │  │
        │  │  │  ├────────────────────────────────────────┤  │  │  │
        │  │  │  │ [1]: Frame 0 (64×64) ← frame_idx       │  │  │  │
        │  │  │  │      data_surface:   ┌──┐              │  │  │  │
        │  │  │  │                      │F0│              │  │  │  │
        │  │  │  │                      └──┘              │  │  │  │
        │  │  │  │      output_surface: 64×64             │  │  │  │
        │  │  │  ├────────────────────────────────────────┤  │  │  │
        │  │  │  │ [2]: Frame 1 (64×64)                   │  │  │  │
        │  │  │  │      data_surface:   ┌──┐              │  │  │  │
        │  │  │  │                      │F1│              │  │  │  │
        │  │  │  │                      └──┘              │  │  │  │
        │  │  │  ├────────────────────────────────────────┤  │  │  │
        │  │  │  │ [3]: Frame 2 (64×64) ┌──┐              │  │  │  │
        │  │  │  │                      │F2│              │  │  │  │
        │  │  │  │                      └──┘              │  │  │  │
        │  │  │  ├────────────────────────────────────────┤  │  │  │
        │  │  │  │ [4]: Frame 3 (64×64) ┌──┐              │  │  │  │
        │  │  │  │                      │F3│              │  │  │  │
        │  │  │  │                      └──┘              │  │  │  │
        │  │  │  ├────────────────────────────────────────┤  │  │  │
        │  │  │  │ [5]: Frame 4 (64×64) ┌──┐              │  │  │  │
        │  │  │  │                      │F4│              │  │  │  │
        │  │  │  │                      └──┘              │  │  │  │
        │  │  │  ├────────────────────────────────────────┤  │  │  │
        │  │  │  │ [6]: Frame 5 (64×64) ┌──┐              │  │  │  │
        │  │  │  │                      │F5│              │  │  │  │
        │  │  │  │                      └──┘              │  │  │  │
        │  │  │  └────────────────────────────────────────┘  │  │  │
        │  │  └──────────────────────────────────────────────┘  │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼


STEP 4: CREATE ANIMATION WITH LOOP MODE
========================================
        ┌──────────────────────────────────────────────────────────┐
        │        Sprite.FrameAnimation.init()                      │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ Parameters:                                        │  │
        │  │  • start: 1   (frame index 1 = first split frame)  │  │
        │  │  • end: 6     (frame index 6 = last split frame)   │  │
        │  │  • mode: .loopForward                              │  │
        │  │  • speed: 1   (update every frame)                 │  │
        │  │                                                    │  │
        │  │ IMPORTANT: Animation indices start at 1, not 0!    │  │
        │  │  • Index 0 = original spritesheet (unused)         │  │
        │  │  • Index 1-6 = individual frames (used)            │  │
        │  │                                                    │  │
        │  │ var anim = Sprite.FrameAnimation.init(             │  │
        │  │     1,              // start (first split frame)   │  │
        │  │     6,              // end (last split frame)      │  │
        │  │     .loopForward,   // mode                        │  │
        │  │     1               // speed                       │  │
        │  │ );                                                 │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼
        ┌──────────────────────────────────────────────────────────┐
        │              FrameAnimation Structure                    │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ FrameAnimation                                     │  │
        │  │  • animator: IndexAnimator                         │  │
        │  │    ┌────────────────────────────────────────────┐  │  │
        │  │    │ start: 1   (not 0!)                        │  │  │
        │  │    │ end: 6                                     │  │  │
        │  │    │ mode: .loopForward                         │  │  │
        │  │    │ current: 1 (starts at frame index 1)       │  │  │
        │  │    │ direction: 1                               │  │  │
        │  │    │ once_finished: false                       │  │  │
        │  │    └────────────────────────────────────────────┘  │  │
        │  │                                                    │  │
        │  │  • speed: 1                                        │  │
        │  │  • speed_ctr: 1                                    │  │
        │  │  • just_started: true                              │  │
        │  └────────────────────────────────────────────────────┘  │
        │                                                          │
        │  Loop Modes Available:                                   │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ • .once:          1→2→3→4→5→6 [STOP]               │  │
        │  │ • .loopForward:   1→2→3→4→5→6→1→2→3...             │  │
        │  │ • .loopBackwards: 6→5→4→3→2→1→6→5→4...             │  │
        │  │ • .loopBounce:    1→2→3→4→5→6→5→4→3→2→1→2...       │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼


STEP 5: INITIALIZE SCREEN
==========================
        ┌──────────────────────────────────────────────────────────┐
        │         screen = Screen.init(allocator, 80, 40)          │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ • w: 80 chars                                      │  │
        │  │ • h: 80 pixel rows (40 × 2)                        │  │
        │  │ • output_surface: RenderSurface(80, 80)            │  │
        │  │ • sprites: [] (empty)                              │  │
        │  │ • output_surfaces: [] (empty)                      │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼


STEP 6: POSITION SPRITE & ADD TO SCREEN
========================================
        ┌──────────────────────────────────────────────────────────┐
        │             sprite.output_surface.x = 20                 │
        │             sprite.output_surface.y = 10                 │
        │             sprite.output_surface.z = 1                  │
        │                                                          │
        │             screen.addSprite(sprite)                     │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ Appends sprite pointer to screen.sprites list      │  │
        │  └────────────────────────────────────────────────────┘  │
        └────────────────────────────┬─────────────────────────────┘
                                     │
                                     ▼


STEP 7: MAIN RENDER LOOP
=========================
        ┌──────────────────────────────────────────────────────────┐
        │                    MAIN LOOP                             │
        │  ┌────────────────────────────────────────────────────┐  │
        │  │ while (running) {                                  │  │
        │  │                                                    │  │
        │  │   ┌─────────────────────────────────────────────┐  │  │
        │  │   │ STEP 7A: UPDATE ANIMATION                   │  │  │
        │  │   │ ──────────────────────────────────────────  │  │  │
        │  │   │                                             │  │  │
        │  │   │ anim.step(sprite)                           │  │  │
        │  │   │                                             │  │  │
        │  │   └─────────────────────────────────────────────┘  │  │
        │  │                        │                           │  │
        │  │                        ▼                           │  │
        │  │   ┌─────────────────────────────────────────────┐  │  │
        │  │   │ Inside anim.step():                         │  │  │
        │  │   │                                             │  │  │
        │  │   │ 1. Check speed_ctr:                         │  │  │
        │  │   │    if speed_ctr > 0:                        │  │  │
        │  │   │      speed_ctr--                            │  │  │
        │  │   │      return (wait)                          │  │  │
        │  │   │                                             │  │  │
        │  │   │ 2. Reset speed_ctr = speed                  │  │  │
        │  │   │                                             │  │  │
        │  │   │ 3. Call animator.step():                    │  │  │
        │  │   │    ┌───────────────────────────────────┐    │  │  │
        │  │   │    │ IndexAnimator.step()              │    │  │  │
        │  │   │    │                                   │    │  │  │
        │  │   │    │ For .loopForward (start=1, end=6):│    │  │  │
        │  │   │    │   if current >= 6:                │    │  │  │
        │  │   │    │     current = 1 (wrap to start)   │    │  │  │
        │  │   │    │   else:                           │    │  │  │
        │  │   │    │     current++ (1→2, 2→3, etc.)    │    │  │  │
        │  │   │    │                                   │    │  │  │
        │  │   │    │ Returns: new current index        │    │  │  │
        │  │   │    └───────────────────────────────────┘    │  │  │
        │  │   │                                             │  │  │
        │  │   │ 4. Update sprite frame:                     │  │  │
        │  │   │    sprite.frame_set.frame_idx = current     │  │  │
        │  │   │                                             │  │  │
        │  │   └─────────────────────────────────────────────┘  │  │
        │  │                        │                           │  │
        │  │                        ▼                           │  │
        │  │   ┌─────────────────────────────────────────────┐  │  │
        │  │   │ Frame Index Updated (cycles 1-6):           │  │  │
        │  │   │   Loop iter 0: frame_idx = 1 (Frame 0)      │  │  │
        │  │   │   Loop iter 1: frame_idx = 2 (Frame 1)      │  │  │
        │  │   │   Loop iter 2: frame_idx = 3 (Frame 2)      │  │  │
        │  │   │   Loop iter 3: frame_idx = 4 (Frame 3)      │  │  │
        │  │   │   Loop iter 4: frame_idx = 5 (Frame 4)      │  │  │
        │  │   │   Loop iter 5: frame_idx = 6 (Frame 5)      │  │  │
        │  │   │   Loop iter 6: frame_idx = 1 (wrapped!)     │  │  │
        │  │   │   ...                                       │  │  │
        │  │   └─────────────────────────────────────────────┘  │  │
        │  │                        │                           │  │
        │  │                        ▼                           │  │
        │  │   ┌─────────────────────────────────────────────┐  │  │
        │  │   │ STEP 7B: RENDER TO SCREEN                   │  │  │
        │  │   │ ──────────────────────────────────────────  │  │  │
        │  │   │                                             │  │  │
        │  │   │ screen.renderWithSprites()                  │  │  │
        │  │   │                                             │  │  │
        │  │   └─────────────────────────────────────────────┘  │  │
        │  │                        │                           │  │
        │  │                        ▼                           │  │
        │  │   ┌─────────────────────────────────────────────┐  │  │
        │  │   │ Inside screen.renderWithSprites():          │  │  │
        │  │   │                                             │  │  │
        │  │   │ 1. For each sprite in screen.sprites:       │  │  │
        │  │   │    surface = sprite.getCurrentFrameSurface()│  │  │
        │  │   │      → returns frames[frame_idx].data_surface│  │  │
        │  │   │      → frames[1].data_surface (Frame 0)     │  │  │
        │  │   │      → frames[2].data_surface (Frame 1)     │  │  │
        │  │   │      → ... etc based on current frame_idx   │  │  │
        │  │   │    screen.addRenderSurface(surface)         │  │  │
        │  │   │                                             │  │  │
        │  │   │ 2. Clear screen output_surface              │  │  │
        │  │   │                                             │  │  │
        │  │   │ 3. RenderEngine.render():                   │  │  │
        │  │   │    • Merge all surfaces into output_surface │  │  │
        │  │   │    • Apply x, y positioning                 │  │  │
        │  │   │    • Handle z-ordering                      │  │  │
        │  │   │    • Respect transparency (shadow_map)      │  │  │
        │  │   │                                             │  │  │
        │  │   └─────────────────────────────────────────────┘  │  │
        │  │                        │                           │  │
        │  │                        ▼                           │  │
        │  │   ┌─────────────────────────────────────────────┐  │  │
        │  │   │ STEP 7C: OUTPUT TO TERMINAL                 │  │  │
        │  │   │ ──────────────────────────────────────────  │  │  │
        │  │   │                                             │  │  │
        │  │   │ screen.output()                             │  │  │
        │  │   │   • Convert output_surface.toAnsi()         │  │  │
        │  │   │   • Print ANSI to terminal                  │  │  │
        │  │   │   • Current frame visible on screen         │  │  │
        │  │   │                                             │  │  │
        │  │   └─────────────────────────────────────────────┘  │  │
        │  │                        │                           │  │
        │  │                        ▼                           │  │
        │  │   ┌─────────────────────────────────────────────┐  │  │
        │  │   │ STEP 7D: FRAME TIMING                       │  │  │
        │  │   │ ──────────────────────────────────────────  │  │  │
        │  │   │                                             │  │  │
        │  │   │ std.time.sleep(16_000_000); // ~60 FPS      │  │  │
        │  │   │   OR                                        │  │  │
        │  │   │ std.time.sleep(33_000_000); // ~30 FPS      │  │  │
        │  │   │                                             │  │  │
        │  │   └─────────────────────────────────────────────┘  │  │
        │  │                        │                           │  │
        │  │                        │                           │  │
        │  │   ┌────────────────────┘                           │  │
        │  │   │                                                │  │
        │  │   └─────────> LOOP BACK TO TOP                     │  │
        │  │                                                    │  │
        │  │ } // end while                                     │  │
        │  └────────────────────────────────────────────────────┘  │
        └──────────────────────────────────────────────────────────┘


FRAME INDEX MAPPING:
====================

After splitByWidth(), frame indices are offset by 1:

  Spritesheet Frame   →   Frame Index   →   Animation Frame
  ─────────────────────────────────────────────────────────
  Frame 0             →   Index 1       →   Animation frame 0
  Frame 1             →   Index 2       →   Animation frame 1
  Frame 2             →   Index 3       →   Animation frame 2
  Frame 3             →   Index 4       →   Animation frame 3
  Frame 4             →   Index 5       →   Animation frame 4
  Frame 5             →   Index 6       →   Animation frame 5

  Index 0 = Original full spritesheet (not used in animation)


ANIMATION FLOW VISUALIZATION:
==============================

Frame Index Changes Over Time (.loopForward mode, indices 1-6):

 Time  →
 ────────────────────────────────────────────────────────────────>

 Index: 1   2   3   4   5   6   1   2   3   4   5   6   1   2 ...
 Frame: F0  F1  F2  F3  F4  F5  F0  F1  F2  F3  F4  F5  F0  F1...
        │   │   │   │   │   │   │   │   │   │   │   │   │   │
        ▼   ▼   ▼   ▼   ▼   ▼   ▼   ▼   ▼   ▼   ▼   ▼   ▼   ▼
       ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
       │█│ │▓│ │▒│ │░│ │ │ │█│ │█│ │▓│ │▒│ │░│ │ │ │█│ │█│ │▓│
       │█│ │▓│ │▒│ │░│ │ │ │█│ │█│ │▓│ │▒│ │░│ │ │ │█│ │█│ │▓│
       └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘
                                └───┘
                          Wraps back to index 1


═══════════════════════════════════════════════════════════════════
COMPLETE CODE EXAMPLE
═══════════════════════════════════════════════════════════════════

const std = @import("std");
const movy = @import("movy");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Setup terminal
    try movy.terminal.beginRawMode();
    defer movy.terminal.endRawMode();
    try movy.terminal.beginAlternateScreen();
    defer movy.terminal.endAlternateScreen();

    // STEP 1-2: Load spritesheet as sprite
    // ─────────────────────────────────────
    var sprite = try movy.Sprite.initFromPng(
        allocator,
        "character_walk.png",  // 384×64 spritesheet (6 frames)
        "character"
    );
    defer sprite.deinit(allocator);

    // STEP 3: Split spritesheet into individual frames
    // ─────────────────────────────────────────────────
    try sprite.splitByWidth(allocator, 64);
    // Now sprite has 7 frames:
    //   [0] = original spritesheet (unused)
    //   [1-6] = individual 64×64 frames

    // STEP 4: Create animation (indices 1-6, not 0-5!)
    // ─────────────────────────────────────────────────
    var walk_anim = movy.Sprite.FrameAnimation.init(
        1,              // start frame INDEX (not frame number!)
        6,              // end frame INDEX
        .loopForward,   // loop mode
        1               // speed (1 = update every frame)
    );

    // STEP 5: Create screen
    // ─────────────────────
    var screen = try movy.Screen.init(allocator, 80, 40);
    defer screen.deinit(allocator);
    screen.setScreenMode(.bgcolor);

    // STEP 6: Position and add sprite
    // ────────────────────────────────
    sprite.output_surface.x = 20;
    sprite.output_surface.y = 10;
    sprite.output_surface.z = 1;

    try screen.addSprite(sprite);

    // STEP 7: Main render loop
    // ─────────────────────────
    var running = true;
    while (running) {
        // Handle input (optional)
        if (try movy.input.get()) |in| {
            switch (in) {
                .key => |key| {
                    if (key.type == .Escape) running = false;
                },
                else => {},
            }
        }

        // STEP 7A: Update animation
        walk_anim.step(sprite);

        // STEP 7B: Render to screen
        try screen.renderWithSprites();

        // STEP 7C: Output to terminal
        try screen.output();

        // STEP 7D: Frame timing (60 FPS)
        std.time.sleep(16_000_000);
    }
}

═══════════════════════════════════════════════════════════════════


ALTERNATIVE: USING NAMED ANIMATIONS
====================================

For sprites with multiple animation states:

// After splitByWidth()...

// Create multiple animations
var walk_anim = movy.Sprite.FrameAnimation.init(1, 6, .loopForward, 1);
var idle_anim = movy.Sprite.FrameAnimation.init(7, 10, .loopForward, 2);
var jump_anim = movy.Sprite.FrameAnimation.init(11, 15, .once, 1);

// Add to sprite
try sprite.addAnimation(allocator, "walk", walk_anim);
try sprite.addAnimation(allocator, "idle", idle_anim);
try sprite.addAnimation(allocator, "jump", jump_anim);

// Start animation
try sprite.startAnimation("walk");

// In game loop:
sprite.stepActiveAnimation();  // Automatically updates active animation

// Switch animations:
try sprite.startAnimation("jump");


═══════════════════════════════════════════════════════════════════


KEY CONCEPTS:
=============

Sprite.initFromPng():
    • Loads entire PNG as frames[0]
    • Initial sprite dimensions = full PNG dimensions

Sprite.splitByWidth():
    • Splits frames[0] horizontally by split_width
    • Creates num_frames = full_width / split_width
    • Appends new frames as [1], [2], [3]... [n]
    • Sets frame_idx = 1 (start at first split frame)
    • Updates sprite.w = split_width
    • Keeps original spritesheet at frames[0] (can be removed later)

Frame Indexing After Split:
    • frames[0] = Original spritesheet (384×64)
    • frames[1] = First animation frame (64×64)
    • frames[2] = Second animation frame (64×64)
    • ... and so on

Animation Start/End:
    • IMPORTANT: Use indices 1-6, NOT 0-5!
    • start: 1 (first split frame, NOT the spritesheet)
    • end: 6 (last split frame)
    • Index 0 is the original spritesheet and is skipped

FrameAnimation:
    • Wraps IndexAnimator for frame control
    • step(): Updates sprite.frame_set.frame_idx
    • Works with frame indices (1-6), not frame numbers (0-5)

Why Keep Original Spritesheet?
    • Optional - can be removed if not needed
    • Useful for debugging or re-splitting with different widths
    • Minimal memory overhead (shared pixel data)


LOOP MODES EXPLAINED:
======================

.once (indices 1-6):
    1 → 2 → 3 → 4 → 5 → 6 [STOP]
    Use: One-shot animations (death, explosion, etc.)

.loopForward (indices 1-6):
    1 → 2 → 3 → 4 → 5 → 6 → 1 → 2 → 3 → 4 → 5 → 6 → ...
    Use: Continuous animations (walking, running, idle)

.loopBackwards (indices 1-6):
    6 → 5 → 4 → 3 → 2 → 1 → 6 → 5 → 4 → 3 → 2 → 1 → ...
    Use: Reverse cycling (rewind effects)

.loopBounce (indices 1-6):
    1 → 2 → 3 → 4 → 5 → 6 → 5 → 4 → 3 → 2 → 1 → 2 → 3 → ...
    Use: Smooth back-and-forth (breathing, swaying)


SPEED CONTROL:
==============

speed parameter controls update frequency:

speed = 1:  Updates every frame
    Index: 1, 2, 3, 4, 5, 6, 1, 2, 3...

speed = 2:  Waits 2 frames between updates
    Index: 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 1, 1...

speed = 5:  Waits 5 frames between updates
    Index: 1,1,1,1,1, 2,2,2,2,2, 3,3,3,3,3...

Higher speed = slower animation


COMMON SPRITESHEET LAYOUTS:
============================

Horizontal Strip (this guide):
  ┌────┬────┬────┬────┬────┬────┐
  │ F0 │ F1 │ F2 │ F3 │ F4 │ F5 │
  └────┴────┴────┴────┴────┴────┘
  Use: sprite.splitByWidth(allocator, frame_width)

Vertical Strip (not directly supported):
  ┌────┐
  │ F0 │
  ├────┤
  │ F1 │
  ├────┤
  │ F2 │
  └────┘
  Need: Custom split function or pre-split images

Grid Layout (multiple animations):
  ┌────┬────┬────┬────┐
  │ W0 │ W1 │ W2 │ W3 │  Walk animation
  ├────┼────┼────┼────┤
  │ R0 │ R1 │ R2 │ R3 │  Run animation
  ├────┼────┼────┼────┤
  │ J0 │ J1 │ J2 │ J3 │  Jump animation
  └────┴────┴────┴────┘
  Solution: Load each row as separate spritesheet


TIPS:
=====

• Always use sprite.splitByWidth() after initFromPng()
• Remember: animation indices start at 1, not 0!
• For 6 frames: use init(1, 6, ...) not init(0, 5, ...)
• Check spritesheet dimensions: width must divide evenly by frame_width
• Use renderWithSprites() for automatic frame rendering
• Set sprite z-index to control draw order
• Use speed parameter to fine-tune animation timing
• Test with different loop modes to find the right feel
```


