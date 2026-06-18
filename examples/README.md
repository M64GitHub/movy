# Examples

Quick code examples demonstrating specific movy features.

## Running Examples

```bash
zig build run-<example_name>
```

## Available Examples

- **[logo-morph](./logo-morph/)** - the looping neon banner from the project
  README, built on the **Frame** neon-render path (persistent glow/bloom, linear
  float color). A multi-file example in its own folder, with a
  [walkthrough](./logo-morph/README.md) of how it works.
  ```bash
  zig build run-logo-morph          # ESC / q quits
  zig build run-logo-morph -- shake # add a screen shake on the ignite beat
  ```

- **basic_surface** - Creating surfaces, adding text, and basic output
  ```bash
  zig build run-basic_surface
  ```

- **alpha_blending** - Transparency and overlapping surfaces
  ```bash
  zig build run-alpha_blending
  ```

- **layered_scene** - Z-index layering with multiple surfaces
  ```bash
  zig build run-layered_scene
  ```

- **png_loader** - Loading PNG images as render surfaces
  ```bash
  zig build run-png_loader
  ```

- **sprite_animation** - Sprite loading and frame-based animation
  ```bash
  zig build run-sprite_animation
  ```

- **sprite_alpha_rendering** - Sprites with transparency effects
  ```bash
  zig build run-sprite_alpha_rendering
  ```

- **sprite_pool** - Managing multiple sprites with SpritePool
  ```bash
  zig build run-sprite_pool
  ```

- **framerate_template** - Template for frame-based game loops
  ```bash
  zig build run-framerate_template
  ```
