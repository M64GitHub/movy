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

- **[glyph-reel](./glyph-reel/)** - the v0.4.0 showcase: a ~40s timeline on the
  **GlyphLayer** + **Frame** paths - beam-decrypted news, the logo rising from
  below, a glyph storm, **VideoExport**, a v0.3.0 recap and a closing card. It
  records itself to an mp4. See its [README](./glyph-reel/README.md) for the
  timeline and the video steps.
  ```bash
  zig build run-glyph-reel                # loops; ESC / q quits
  zig build run-glyph-reel -- once        # play once and hold the card
  zig build run-glyph-reel -- wide        # 120x20 banner instead of 100x28 (16:9)
  zig build run-glyph-reel -- pal ember   # palettes: aurora (default), decrypt, ember
  zig build run-glyph-reel -- export      # 60fps PNGs -> export/, then tools/makevideo.sh
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
