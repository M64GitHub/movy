# movy Documentation

This folder contains user guide documentation for the movy terminal graphics rendering engine. Each document provides comprehensive tutorials on core structs and how to use them, written for developers new to movy.

## Available Documentation

- **[RenderSurface.md](./RenderSurface.md)** - The foundational struct for all visual content: creating surfaces, loading PNGs, adding text, and rendering to the terminal
- **[RenderEngine.md](./RenderEngine.md)** - The compositor: combining multiple surfaces with z-ordering, clipping, and alpha blending

## Code Examples

Complete, runnable code examples demonstrating the concepts in this
documentation can be found in the `../examples/` directory. These
examples can be built and run using:

```bash
zig build run-basic_surface          # RenderSurface basics
zig build run-alpha_blending         # Transparency and overlapping
zig build run-layered_scene          # Z-index layering
zig build run-png_loader             # Loading PNG images
zig build run-sprite_animation       # Sprite frame animation
zig build run-sprite_alpha_rendering # Sprites with transparency
zig build run-sprite_pool            # Managing multiple sprites
zig build run-framerate_template     # Frame-based game loop template
```

Each example corresponds to code snippets and concepts shown in the
documentation above. See **[examples/README.md](../examples/README.md)**
for more details.

## Demos

Beyond the focused examples above, movy includes full **demonstration programs** in the `../demos/` directory that show real visual applications where all concepts come together. These demos can be a good headstart for learning movy, as they showcase complete, working programs with animation, input handling, and visual effects.

For instance, `stars.zig` demonstrates steady 60 FPS framerate control with an animated starfield effect, showing how to build smooth animations with precise timing. Other demos include interactive mouse/keyboard handling, UI windows, a complete game starter template, and video playback:

**Run demos with:**
```bash
zig build run-stars          # Animated starfield with 60 FPS control
zig build run-simple_game    # Game template with shooting and collision
zig build run-blender_demo   # Alpha blending showcase with morphing effects
zig build run-mouse_demo     # Interactive input with UI Manager
zig build run-win_demo       # Multiple windows with themes
```

See **[demos/README.md](../demos/README.md)** for complete descriptions of all available demos and what each one demonstrates.

## Status

This documentation is an ongoing process. More guides covering additional movy components will be added as development continues.
