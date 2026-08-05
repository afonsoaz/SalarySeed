#!/usr/bin/env python3
"""Generate the four alternate app icons from the green master.

v0.16. Supporters can recolour the app, and the home-screen icon follows the
choice, so each accent needs its own 1024pt artwork.

WHY A SCRIPT AND NOT FOUR HAND-DRAWN FILES. The mark is one leaf with a soft
gradient, a highlight down the spine and a faint glow behind it. Redrawing that
four times by hand guarantees four slightly different leaves. Recolouring the
master guarantees one leaf in five colours, which is the point.

HOW THE RECOLOUR WORKS. Per pixel, in HSV: rotate hue by the difference between
the master accent and the target accent, and scale saturation by the ratio
between them. Value is left alone, which is what preserves the gradient, the
highlight and the near-black background. A flat `ImageOps.colorize` or a plain
hue rotation would lose one or the other.

Run from the repo root:  python3 tools/make_alternate_icons.py
"""

import colorsys
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "SalarySeed", "Assets.xcassets")
MASTER = os.path.join(ASSETS, "AppIcon.appiconset", "icon-1024.png")

# Must stay in step with AccentTheme.swift. If a colour changes there and not
# here, the icon and the interface disagree, which looks like a bug.
SOURCE = 0x3DDC97
TARGETS = {
    "Blue": 0x5AC8FA,
    "Purple": 0xC08BFF,
    "Pink": 0xFF8FB1,
    "Amber": 0xFFC857,
}

CONTENTS = {
    "images": [
        {
            "filename": "icon-1024.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024",
        }
    ],
    "info": {"author": "xcode", "version": 1},
}


def hsv(hex_value):
    r = (hex_value >> 16) & 0xFF
    g = (hex_value >> 8) & 0xFF
    b = hex_value & 0xFF
    return colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)


def recolour(image, hue_shift, sat_scale):
    out = image.copy()
    pixels = out.load()
    width, height = out.size
    for y in range(height):
        for x in range(width):
            r, g, b = pixels[x, y][:3]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            h = (h + hue_shift) % 1.0
            s = min(1.0, s * sat_scale)
            nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
            pixels[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255))
    return out


def main():
    if not os.path.exists(MASTER):
        sys.exit("master icon not found: %s" % MASTER)

    master = Image.open(MASTER).convert("RGB")
    src_h, src_s, _ = hsv(SOURCE)

    for name, value in TARGETS.items():
        dst_h, dst_s, _ = hsv(value)
        variant = recolour(master, dst_h - src_h, dst_s / src_s)

        folder = os.path.join(ASSETS, "AppIcon-%s.appiconset" % name)
        os.makedirs(folder, exist_ok=True)
        variant.save(os.path.join(folder, "icon-1024.png"))
        with open(os.path.join(folder, "Contents.json"), "w") as handle:
            json.dump(CONTENTS, handle, indent=2)
            handle.write("\n")
        print("wrote AppIcon-%s.appiconset" % name)


if __name__ == "__main__":
    main()
