# movy Demos

This directory contains working demonstration programs that showcase movy's capabilities in action. Each demo is a complete, runnable example that combines multiple movy features to create visual effects, interactive applications, or games.

## Quick Reference

| Demo | Description | Run Command |
|------|-------------|-------------|
| **stars** | Animated starfield with steady 60 FPS | `zig build run-stars` |
| **simple_game** | Complete game starter with player, shooting, collision | `zig build run-simple_game` |
| **mouse_demo** | Interactive mouse/keyboard input with UI Manager | `zig build run-mouse_demo` |
| **win_demo** | Multiple TextWindows with themes and styles | `zig build run-win_demo` |
| **blender_demo** | Alpha blending showcase with morphing visual effects | `zig build run-blender_demo` |
| **mplayer** | Video playback with FFmpeg (requires `-Dvideo=true`) | `zig build -Dvideo=true run-demo-mplayer <file>` |

## Detailed Descriptions

### stars.zig - Animated Starfield

**What it demonstrates:**
- Steady 60 FPS framerate control with precise timing
- Animated starfield effect with 3D depth simulation
- Modular animation components (StarField.zig module)
- Terminal size adaptation
- Clean main loop structure

**Features:**
- 300 stars with normal and flashy types
- Depth simulation
- Subpixel movement for smooth animation
- Help text overlay on animated background

**Controls:**
- ESC or 'q': Exit

**Run:**
```bash
zig build run-stars
```

---

### simple_game.zig - Game Starter Template

**What it demonstrates:**
- Complete game loop with 60 FPS control
- Sprite sheet animation with frame splitting
- Named animation sequences (idle, left, right with transitions)
- Player movement
- Shooting mechanics with projectiles
- Collision detection
- Score tracking and UI overlay

**Features:**
- IndexAnimator with multiple loop modes
- State-based animation system
- Boundary detection
- Keyboard input handling
- Accumulator pattern for smooth movement

**Controls:**
- Arrow keys: Move player
- Space: Shoot
- Escape: Exit

**Run:**
```bash
zig build run-simple_game
```

This demo serves as a foundation for building 2D games in movy.

---

### mouse_demo.zig - Interactive Input & UI

**What it demonstrates:**
- Mouse position tracking and display
- Keyboard input handling
- UI Manager system with TextWindows
- Multiple PNG sprite loading
- Text overlay on sprites
- RenderEffect system (OutlineRotator)
- TrigWave animation (sine waves)
- ColorTheme and Style systems
- Real-time performance metrics

**Features:**
- Multiple layered surfaces
- Interactive text editing in windows
- Theme support (Catppuccin Mocha, Tokyo Night Storm)
- Performance monitoring (render, output, loop times)
- Freeze/pause functionality (F1)

**Controls:**
- Mouse: Track position
- F1: Freeze/unfreeze animation
- Escape: Exit

**Run:**
```bash
zig build run-mouse_demo
```

This is the most comprehensive demo, showing UI features and input handling.

---

### win_demo.zig - UI Manager & Windows

**What it demonstrates:**
- TextWindow management with UI Manager
- Multiple windows with different positions
- Theme and style systems (Tokyo Night Storm)
- Automatic sprite lifecycle management
- Sprite positioning with sine wave animation
- OutlineRotator effect
- Centered window calculations

**Features:**
- Demonstrates UI Manager workflow
- Shows theme integration with screen background
- Multiple windows layout

**Controls:**
- Escape: Exit

**Run:**
```bash
zig build run-win_demo
```

This demo focuses on the UI system, perfect for learning window-based layouts.

---

### blender_demo.zig - Alpha Blending Showcase

**What it demonstrates:**
- Alpha blending with `screen.renderWithAlpha()` - Porter-Duff compositor
- Multiple animated sprites with 2D wave motion (sine + cosine)
- 16 sprites in rotating circle with Lissajous deformation
- Per-sprite alpha animation with phase offsets
- Scrolling text with 2D wave motion and transparency
- OutlineRotator effect on logo
- Complex multi-layer scene composition

**Features:**
- Graduated alpha values (50-255) creating depth effect
- Morphing circle using different sine wave frequencies
- Per-sprite radius wobble for organic breathing effect
- Smooth 60 FPS animation with multiple concurrent effects
- Real-time shadow_map manipulation for dynamic transparency

**Controls:**
- ESC or 'q': Exit

**Run:**
```bash
zig build run-blender_demo
```

This demo showcases the full power of movy's alpha blending system, perfect for learning advanced visual effects and animation composition.

---

### mplayer.zig - Video Playback (Experimental)

**What it demonstrates:**
- FFmpeg integration for video decoding
- Video frame scaling to terminal resolution
- Command-line argument parsing
- Video stream detection
- Codec context allocation
- FFmpeg C library interop

**Features:**
- Decodes video files using libavformat/libavcodec
- Scales frames to 200x112 terminal resolution
- Overlays M64 logo on video
- Foundation for movy_video.VideoDecoder API

**Special Requirements:**
- Must be built with video support: `-Dvideo=true`
- Requires FFmpeg libraries installed (libavformat, libavcodec, libswscale, libavutil)

**Run:**
```bash
zig build -Dvideo=true run-demo-mplayer path/to/video.mp4
```

**Note:** This is a proof-of-concept player. For production use, see the `movy_video` module with the VideoDecoder API.

---

## Learning Path

**Beginner:** Start with `stars.zig` to learn framerate control and animation basics.

**Intermediate:** Try `simple_game.zig` to understand sprite animation and input handling.

**Advanced:** Explore `blender_demo.zig` for alpha blending and complex visual effects, or dive into `mouse_demo.zig` and `win_demo.zig` for UI Manager and advanced interactions.

**Experimental:** Check out `mplayer.zig` for FFmpeg integration (requires video build).

---

## Additional Files

- **StarField.zig** - Reusable starfield animation module used by stars.zig
- **examples/framerate_template.zig** - Template for documentation purposes (not built)

For more learning resources, see the main [documentation](../doc/README.md) and [examples](../examples/).
