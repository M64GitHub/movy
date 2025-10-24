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
