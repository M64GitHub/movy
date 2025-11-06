## Available Documentation

- **[RenderSurface.md](./RenderSurface.md)** - The foundational struct for all visual content: creating surfaces, loading PNGs, adding text, transparency, and rendering to the terminal
- **[Sprite.md](./Sprite.md)** - Animated sprites with frame management: loading sprite sheets, splitting frames, creating animations, and controlling transparency
- **[RenderEngine.md](./RenderEngine.md)** - The compositor: combining multiple surfaces with z-ordering, clipping, and alpha blending
- **[Screen.md](./Screen.md)** - The terminal rendering canvas: compositing layers, managing sprites and surfaces, and outputting to the terminal
- **[Animation.md](./Animation.md)** - Animation utilities: IndexAnimator for frame cycling, TrigWave for wave motion, easing functions for smooth transitions
- **[Colors.md](./Colors.md)** - Color constants and utilities: Bootstrap-inspired palette, HTML color parsing, brightness and darkness adjustment

## Code Examples

Runnable code examples demonstrating various concepts can be found in the `../examples/` directory. These
examples can be built and run using:

```bash
zig build run-basic_surface          # RenderSurface basics
zig build run-alpha_blending         # Transparency and overlapping
zig build run-layered_scene          # Z-index layering
zig build run-png_loader             # Loading PNG images
zig build run-sprite_animation       # Sprite frame animation
zig build run-sprite_alpha_rendering # Sprites with transparency
zig build run-sprite_pool            # Managing multiple sprites
zig build run-scale_algorithms       # Compare scaling algorithms
zig build run-scale_updown           # Interactive upscaling
zig build run-scale_animation        # Animated scaling effect
zig build run-rotate_animation       # Continuous 360-degree rotation
zig build run-rotate_angles          # Compare rotation at different angles
zig build run-rotate_interactive     # User-controlled rotation with keys
zig build run-framerate_template     # Frame-based game loop template
```

Each example corresponds to code snippets and concepts shown in the
documentation above.

## Demos

Beyond the examples above, the `../demos/` directory shows working programs with animation, input handling, and visual effects.

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
