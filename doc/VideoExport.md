# VideoExport

## Introduction

`VideoExport` lets a movy program **record itself**. It rasterizes exactly what the terminal would show - half-block pixels, `char_map` text and GlyphLayer glyphs - into an RGB image and writes it as a numbered PNG. `tools/makevideo.sh` then turns the frames, plus an optional audio track, into an mp4.

- **No screen capture:** you drive the program on a fixed clock (frame N = t = N / 60), so every frame is rendered, none are dropped, and the result is smoother than any live recording
- **Terminal-true:** the per-cell rules are DiffOutput's; text is drawn from a baked monospace font, block elements and braille fill the cell like a terminal draws them
- **Pixel-pure 1080p:** the default 19x38 px cell makes half-block pixels exact 19x19 squares; a 100x28 cell screen becomes 1900x1064 and pads to 1920x1080 with no rescaling
- **No new dependencies:** pure Zig plus the lodepng movy already bundles; the video step needs `ffmpeg`

**Location:** `src/export/VideoExport.zig`, fonts in `src/export/fonts/`

---

## The Workflow

```zig
const ve = try movy.VideoExport.init(allocator, cols, rows, .{ .out_dir = "export" });
defer ve.deinit();

while (ve.frame_n < total_frames) {
    const t = ve.time(); // frame_n / fps - use this instead of the wall clock
    drawMyScene(t); // update + render into a surface (e.g. frame.composite())
    try ve.writeFrame(surface); // rasterize -> export/frame_000000.png, ...
}
```

Then:

```sh
tools/makevideo.sh export out.mp4                          # 1920x1080 @ 60fps H.264
tools/makevideo.sh export out.mp4 --audio music.wav        # with sound
tools/makevideo.sh export out.mp4 --audio music.wav --offset 5   # video 5ms later than the audio
```

`surface` is the one you would hand to the terminal: with a `Frame`, its `frame.surface` (attach the GlyphLayer to it with `surface.setGlyphs(gl)`, since there is no `Screen`); with a `Screen`, its `output_surface` after `screen.render()`. It must be `cols` wide and `rows * 2` pixels tall.

The [glyph-reel example](../examples/glyph-reel/) is a complete program with a live mode and an `export` mode sharing one `frameStep()`.

---

## Options

```zig
pub const Options = struct {
    font: Font = default_font, // .jetbrains_mono (default) or .dejavu_sans_mono
    cell: CellSize = .@"19x38", // or .@"10x20" for GIFs, banners, previews
    out_dir: []const u8 = "export",
    background: Rgb = black, // what transparent pixels show
    fps: f32 = 60.0, // for time()
};
```

| font | notes |
|---|---|
| `.jetbrains_mono` | the default (`video_export.default_font`), SIL OFL 1.1 |
| `.dejavu_sans_mono` | the closest match to macOS Menlo, which is derived from it |

| cell | image for 100x28 cells | use |
|---|---|---|
| `.@"19x38"` | 1900x1064 | 1080p video, square pixels |
| `.@"10x20"` | 1000x560 | small renders, GIFs |

---

## Core Concepts

### The Cell Rules

Each terminal cell is painted by the same precedence DiffOutput uses:

1. a `char_map` character on the cell's upper pixel row: fg = the upper pixel color, bg = the lower one
2. a `char_map` character on the lower row: the same, colors swapped
3. a GlyphLayer glyph: fg = its graded `fg_out`, bg from its mode (`.pixels` average or `.solid`)
4. otherwise two stacked half-block pixels; transparent pixels show `background`

### Fonts

Text comes from fonts baked into cell-sized 8-bit alpha bitmaps: ASCII plus a set of common extras (`·`, `•`, `…`, arrows, box drawing, geometric shapes, a few accented letters). A codepoint the font lacks renders its background only. Block elements (U+2580..259F) and braille (U+2800..28FF) are drawn procedurally so they fill the cell exactly.

To bake another font or cell size (any OS, needs Python 3 + Pillow):

```sh
tools/bakefont.py MyFont.ttf my_font_19x38 19 38 src/export/fonts --label "My Font" --license "..."
```

Then add it to `Font` / `atlas()` in `VideoExport.zig`, and look at the generated preview sheet (`my_font_19x38.png`).

### Stale Frames

`init()` removes old `frame_NNNNNN.png` files from `out_dir` (only that exact pattern). Without that, a shorter export would leave higher-numbered frames from a previous run behind, and ffmpeg would append them to the video.

---

## Audio Sync

Frame 0 is t = 0, so a sound track that starts at t = 0 is in sync by construction. `--offset MS` shifts the audio against the video, sample-accurate and in milliseconds (decimals fine): positive makes the video appear later than the audio, which can make beat visuals feel like they land *on* the beat. With `--audio`, the video ends at the shorter of the two.

---

## Performance

The glyph-reel exports at about 38 fps at 1900x1064 in a ReleaseFast build (most of it is PNG encoding): 40 seconds of video in about a minute. PNGs of this size are ~50-200 KB each (~120 MB for the reel).

---

## Quick Reference

```zig
movy.VideoExport.init(allocator, cols, rows, opts) !*VideoExport
ve.deinit()
ve.time() f32                          // frame_n / fps
ve.writeFrame(surface) !void           // rasterize + frame_NNNNNN.png, frame_n += 1
ve.rasterize(surface) void             // into ve.rgb (img_w x img_h x 3)
ve.savePng(path) !void                 // the last rasterized image
movy.video_export.atlas(font, cell)    // a baked font (lookup: .glyph(cp))
```

```sh
tools/makevideo.sh DIR OUT.mp4 [--audio FILE] [--offset MS] [--fps N] [--size WxH | --native] [--crf N]
tools/bakefont.py FONT.ttf NAME CELL_W CELL_H OUT_DIR [--label L] [--license L]
```

## Important Reminders

1. **Link libc:** the exe needs `exe.linkLibC()` (lodepng), like `Frame.savePng()`
2. **Fixed clock:** drive animation from `ve.time()`, never the wall clock, or the video speed depends on export speed
3. **Build ReleaseFast** for exports - Debug is many times slower
4. **Attach glyphs to the exported surface** - `surface.setGlyphs(gl)` - when there is no `Screen` doing it
