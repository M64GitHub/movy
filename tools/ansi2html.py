#!/usr/bin/env python3
"""ansi2html - render movy's terminal output to HTML (and optionally a PNG).

The headless dev loop for glyphs: Frame.savePng() has no font, so it cannot
show GlyphLayer text. Instead, write a frame's ANSI to a file and look at it
here - e.g. with the glyph-decrypt example:

    zig build run-glyph-decrypt -- shot 0.6 /tmp/frame.ans
    tools/ansi2html.py /tmp/frame.ans /tmp/frame.html --png /tmp/frame.png

Understands what movy emits: truecolor SGR (38;2 / 48;2 / 0 / 39 / 49) and
cursor movement (CUP `H`, `A` / `B` / `C` / `D`), so both RenderSurface.toAnsi()
and DiffOutput streams work. The output is a cell grid in a monospace <pre>;
half-block pixels show as the block characters they are.

--png screenshots the HTML with headless Chrome/Chromium (set CHROME=path if
it is not found). The screenshot's gaps between half-block rows, if any, come
from the browser's line height, not from movy.
"""

import argparse
import html
import os
import re
import shutil
import subprocess
import sys

TOKEN = re.compile(r"\x1b\[([0-9;?]*)([A-Za-z])|(\n)|(.)", re.S)


def parse(data):
    """Replay the stream onto a sparse cell grid: {(row, col): (ch, fg, bg)}."""
    cells = {}
    row = col = 0
    save = (0, 0)
    fg = bg = None
    for m in TOKEN.finditer(data):
        params, cmd, newline, ch = m.groups()
        if ch is not None:
            if ch == "\r":
                col = 0
                continue
            cells[(row, col)] = (ch, fg, bg)
            col += 1
            continue
        if newline is not None:
            row += 1
            col = 0
            continue
        nums = [int(x) for x in params.replace("?", "").split(";") if x]
        n = nums[0] if nums else 1
        if cmd == "m":
            p = nums or [0]
            i = 0
            while i < len(p):
                if p[i] == 0:
                    fg = bg = None
                elif p[i] == 38 and i + 4 < len(p) and p[i + 1] == 2:
                    fg = tuple(p[i + 2 : i + 5])
                    i += 4
                elif p[i] == 48 and i + 4 < len(p) and p[i + 1] == 2:
                    bg = tuple(p[i + 2 : i + 5])
                    i += 4
                elif p[i] == 39:
                    fg = None
                elif p[i] == 49:
                    bg = None
                i += 1
        elif cmd in "Hf":
            row = (nums[0] if len(nums) > 0 else 1) - 1
            col = (nums[1] if len(nums) > 1 else 1) - 1
        elif cmd == "A":
            row = max(0, row - n)
        elif cmd == "B":
            row += n
        elif cmd == "C":
            col += n
        elif cmd == "D":
            col = max(0, col - n)
        elif cmd == "s":
            save = (row, col)
        elif cmd == "u":
            row, col = save
        # anything else (J, K, l, h, ...) does not draw
    return cells


def to_html(cells, font_px):
    if not cells:
        return "<!doctype html><html><body></body></html>", 1, 1, font_px
    rows = max(r for r, _ in cells) + 1
    cols = max(c for _, c in cells) + 1
    top = min(r for r, _ in cells)
    left = min(c for _, c in cells)
    line_px = round(font_px * 1.125)
    out = [
        "<!doctype html><html><head><meta charset='utf-8'></head>"
        "<body style='margin:0;background:#000'>"
        f"<pre style='margin:0;font:{font_px}px/{line_px}px Menlo,Consolas,monospace'>"
    ]
    for r in range(top, rows):
        for c in range(left, cols):
            ch, fg, bg = cells.get((r, c), (" ", None, None))
            style = "color:rgb(%d,%d,%d);" % fg if fg else "color:#ccc;"
            if bg:
                style += "background:rgb(%d,%d,%d);" % bg
            out.append(f"<span style='{style}'>{html.escape(ch)}</span>")
        out.append("\n")
    out.append("</pre></body></html>")
    return "".join(out), cols - left, rows - top, line_px


def find_chrome():
    env = os.environ.get("CHROME")
    if env:
        return env
    for name in ("google-chrome", "chromium", "chromium-browser", "chrome"):
        path = shutil.which(name)
        if path:
            return path
    mac = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    return mac if os.path.exists(mac) else None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("input", help="file with the ANSI stream")
    ap.add_argument("output", help="HTML file to write")
    ap.add_argument("--png", help="also screenshot the HTML to this PNG (headless Chrome)")
    ap.add_argument("--font", type=int, default=16, help="font size in px (default 16)")
    args = ap.parse_args()

    with open(args.input, encoding="utf-8", errors="replace") as f:
        cells = parse(f.read())
    page, cols, rows, line_px = to_html(cells, args.font)
    with open(args.output, "w", encoding="utf-8") as f:
        f.write(page)

    if args.png:
        chrome = find_chrome()
        if not chrome:
            sys.exit("no Chrome/Chromium found; set CHROME=/path/to/chrome")
        width = int(cols * args.font * 0.62) + 16
        height = rows * line_px + 8
        subprocess.run(
            [
                chrome, "--headless", "--disable-gpu", "--hide-scrollbars",
                f"--window-size={width},{height}",
                f"--screenshot={os.path.abspath(args.png)}",
                "file://" + os.path.abspath(args.output),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


if __name__ == "__main__":
    main()
