#!/usr/bin/env python3
"""Renders VYRO launcher/web/iOS icons and logo previews from the brand SVGs.

The brand SVGs are the source of truth: the V monogram comes from
`brand/logos/vyro-mark-dark.svg` (light variant: `vyro-mark-lime.svg`) and the
full lettering from `brand/logos/vyro-wordmark*.svg`. Shapes are parsed from
those files (polygon/path with absolute M/L/C/Z commands) and rasterised with
4x supersampling.

Usage, from the repository root (requires Pillow):

    py tool/brand/render_icons.py                 # writes all app icons
    py tool/brand/render_icons.py --previews DIR  # also writes SVG-based previews

Launcher icons use the dark V on #0B0D10; the adaptive foreground is transparent.
"""

import argparse
import json
import math
import os
import re
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SS = 4  # supersampling factor
INK_BG = (0x0B, 0x0D, 0x10)
LIGHT_BG = (0xF8, 0xFA, 0xF7)

MARK_DARK = os.path.join(ROOT, "brand", "logos", "vyro-mark-dark.svg")
MARK_LIGHT = os.path.join(ROOT, "brand", "logos", "vyro-mark-lime.svg")
WORDMARK_DARK = os.path.join(ROOT, "brand", "logos", "vyro-wordmark.svg")
WORDMARK_LIGHT = os.path.join(ROOT, "brand", "logos", "vyro-wordmark-light.svg")

# Width of the V monogram as a fraction of the icon canvas.
ICON_FRACTION = 0.6
# Adaptive foreground: the 108dp layer's circular mask keeps a 66dp safe zone
# (radius 33dp). The fraction is the content width over the 108dp canvas; it is
# chosen so the furthest point of the mark, the cap included, lies within
# ADAPTIVE_MAX_RADIUS_DP of the centre (checked in write_icons).
ADAPTIVE_FRACTION = 0.43
ADAPTIVE_MAX_RADIUS_DP = 32.0
ADAPTIVE_CANVAS_DP = 108
# Maskable web icons keep the V inside the 80% safe circle.
MASKABLE_FRACTION = 0.6


def _hex(color):
    color = color.lstrip("#")
    return tuple(int(color[i : i + 2], 16) for i in (0, 2, 4))


def _flatten_path(d):
    """Absolute M/L/C/Z path data to a list of polylines (cubics sampled)."""
    tokens = re.findall(r"[MLCZ]|-?\d+(?:\.\d+)?", d)
    subpaths, current = [], []
    command, i, cx, cy = None, 0, 0.0, 0.0

    def number():
        nonlocal i
        value = float(tokens[i])
        i += 1
        return value

    while i < len(tokens):
        token = tokens[i]
        if token in ("M", "L", "C", "Z"):
            command = token
            i += 1
            if command == "Z":
                if current:
                    subpaths.append(current)
                current = []
                continue
        if command == "M":
            if current:
                subpaths.append(current)
            cx, cy = number(), number()
            current = [(cx, cy)]
            command = "L"
        elif command == "L":
            cx, cy = number(), number()
            current.append((cx, cy))
        elif command == "C":
            x1, y1, x2, y2, x3, y3 = [number() for _ in range(6)]
            for k in range(1, 25):
                t = k / 24
                mt = 1 - t
                px = mt**3 * cx + 3 * mt * mt * t * x1 + 3 * mt * t * t * x2 + t**3 * x3
                py = mt**3 * cy + 3 * mt * mt * t * y1 + 3 * mt * t * t * y2 + t**3 * y3
                current.append((px, py))
            cx, cy = x3, y3
        else:
            raise ValueError("unsupported path command in " + d)
    if current:
        subpaths.append(current)
    return subpaths


def parse_svg(path):
    """Returns [(subpaths, fill_hex)] in document order, honouring <g fill>."""
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    shapes = []
    fills = []
    for match in re.finditer(r"<(g|/g|polygon|path|rect)\b([^>]*?)/?>", text):
        tag, attrs_text = match.group(1), match.group(2)
        attrs = dict(re.findall(r'([\w:-]+)="([^"]*)"', attrs_text))
        if tag == "g":
            fills.append(attrs.get("fill", fills[-1] if fills else None))
        elif tag == "/g":
            fills.pop()
        elif tag == "rect":
            continue  # backgrounds are drawn by the renderer
        else:
            fill = attrs.get("fill", fills[-1] if fills else None)
            if tag == "polygon":
                numbers = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", attrs["points"])]
                subpaths = [list(zip(numbers[0::2], numbers[1::2]))]
            else:
                subpaths = _flatten_path(attrs["d"])
            shapes.append((subpaths, fill))
    return shapes


def bounds(shapes):
    xs = [x for subpaths, _ in shapes for sp in subpaths for x, _ in sp]
    ys = [y for subpaths, _ in shapes for sp in subpaths for _, y in sp]
    return min(xs), min(ys), max(xs), max(ys)


def render(shapes, box, size, content_width, background=None):
    """Rasterises [shapes] so the svg-space [box] is [content_width] px wide and
    centred on a [size] canvas. Returns an RGBA image."""
    width, height = size
    x0, y0, x1, y1 = box
    scale = content_width / (x1 - x0)
    offset_x = width / 2 - (x0 + x1) / 2 * scale
    offset_y = height / 2 - (y0 + y1) / 2 * scale
    big = (width * SS, height * SS)
    canvas = Image.new("RGBA", big, (0, 0, 0, 0))
    if background is not None:
        canvas.paste(background + (255,), (0, 0, big[0], big[1]))
    for subpaths, fill in shapes:
        if fill is None or fill == "none":
            continue
        # Each element is filled with the XOR of its subpaths: this matches the
        # nonzero rule for the nested counters used by the R and O glyphs.
        mask = Image.new("L", big, 0)
        for subpath in subpaths:
            if len(subpath) < 3:
                continue
            points = [
                ((x * scale + offset_x) * SS, (y * scale + offset_y) * SS)
                for x, y in subpath
            ]
            sub = Image.new("L", big, 0)
            ImageDraw.Draw(sub).polygon(points, fill=255)
            mask = ImageChops.difference(mask, sub)
        color = _hex(fill) + (255,)
        canvas.paste(color, (0, 0, big[0], big[1]), mask)
    return canvas.resize(size, Image.LANCZOS)


def save(image, path, opaque=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        image = image.convert("RGB")
    image.save(path, "PNG", optimize=True)
    print("wrote", os.path.relpath(path, ROOT))


def icon(shapes, box, px, fraction, background, opaque=False):
    return render(shapes, box, (px, px), px * fraction, background)


def max_radius_dp(shapes, box, fraction, canvas_dp=ADAPTIVE_CANVAS_DP):
    """Distance in dp from the canvas centre to the furthest point of the mark
    when its box is [fraction] of [canvas_dp] wide and centred on the canvas."""
    x0, _, x1, _ = box
    cx, cy = (x0 + x1) / 2, (box[1] + box[3]) / 2
    scale = fraction * canvas_dp / (x1 - x0)
    points = [(x, y) for subpaths, _ in shapes for sp in subpaths for x, y in sp]
    return max(math.hypot((x - cx) * scale, (y - cy) * scale) for x, y in points)


def write_icons(dark_shapes, box):
    # Android legacy launcher icons (full bleed, V at 60%).
    legacy = {48: "mdpi", 72: "hdpi", 96: "xhdpi", 144: "xxhdpi", 192: "xxxhdpi"}
    for px, density in legacy.items():
        folder = os.path.join(ROOT, "android", "app", "src", "main", "res", "mipmap-" + density)
        save(icon(dark_shapes, box, px, ICON_FRACTION, INK_BG), os.path.join(folder, "ic_launcher.png"))

    # Android adaptive foreground (108dp layer; transparent, mark within the safe zone).
    radius = max_radius_dp(dark_shapes, box, ADAPTIVE_FRACTION)
    print(f"adaptive foreground: max radius {radius:.2f}dp (limit {ADAPTIVE_MAX_RADIUS_DP}dp)")
    if radius > ADAPTIVE_MAX_RADIUS_DP:
        sys.exit("adaptive foreground exceeds the safe radius")
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for density, px in adaptive.items():
        folder = os.path.join(ROOT, "android", "app", "src", "main", "res", "mipmap-" + density)
        save(icon(dark_shapes, box, px, ADAPTIVE_FRACTION, None), os.path.join(folder, "ic_launcher_foreground.png"))

    # iOS: sizes come from Contents.json; the marketing icon must carry no alpha.
    appicon = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    with open(os.path.join(appicon, "Contents.json"), encoding="utf-8") as handle:
        for entry in json.load(handle)["images"]:
            points = float(entry["size"].split("x")[0])
            scale = float(entry["scale"].rstrip("x"))
            px = round(points * scale)
            image = icon(dark_shapes, box, px, ICON_FRACTION, INK_BG)
            save(image, os.path.join(appicon, entry["filename"]), opaque=True)

    # Web: favicon, standard and maskable icons.
    web = os.path.join(ROOT, "web")
    save(icon(dark_shapes, box, 32, ICON_FRACTION, INK_BG), os.path.join(web, "favicon.png"))
    for px in (192, 512):
        save(icon(dark_shapes, box, px, ICON_FRACTION, INK_BG), os.path.join(web, "icons", f"Icon-{px}.png"))
        save(
            icon(dark_shapes, box, px, MASKABLE_FRACTION, INK_BG),
            os.path.join(web, "icons", f"Icon-maskable-{px}.png"),
        )

    # Brand master (opaque).
    save(icon(dark_shapes, box, 1024, ICON_FRACTION, INK_BG), os.path.join(ROOT, "brand", "logos", "vyro-app-icon-1024.png"), opaque=True)


def write_previews(out_dir, dark_shapes, light_shapes, wordmark_dark, wordmark_light):
    """Reference renders of the brand SVGs themselves, for visual checks."""
    mark_box = bounds(dark_shapes)
    word_box = (10, 10, 482, 102)
    save(render(dark_shapes, mark_box, (512, 512), 300, INK_BG), os.path.join(out_dir, "svg-mark-dark.png"))
    save(render(light_shapes, mark_box, (512, 512), 300, LIGHT_BG), os.path.join(out_dir, "svg-mark-light.png"))
    save(render(wordmark_dark, word_box, (1000, 260), 920, INK_BG), os.path.join(out_dir, "svg-wordmark-dark.png"))
    save(render(wordmark_light, word_box, (1000, 260), 920, LIGHT_BG), os.path.join(out_dir, "svg-wordmark-light.png"))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--previews", metavar="DIR", help="also write SVG reference previews to DIR")
    args = parser.parse_args()

    dark_shapes = parse_svg(MARK_DARK)
    light_shapes = parse_svg(MARK_LIGHT)
    wordmark_dark = parse_svg(WORDMARK_DARK)
    wordmark_light = parse_svg(WORDMARK_LIGHT)
    if len(dark_shapes) != 3 or len(light_shapes) != 3:
        sys.exit("expected the V monogram to have 3 shapes (2 body strokes + cap)")
    write_icons(dark_shapes, bounds(dark_shapes))
    if args.previews:
        write_previews(args.previews, dark_shapes, light_shapes, wordmark_dark, wordmark_light)


if __name__ == "__main__":
    main()
