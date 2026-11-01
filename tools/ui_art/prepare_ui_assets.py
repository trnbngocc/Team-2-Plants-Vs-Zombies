#!/usr/bin/env python3
"""Prepare processed UI copies from the supplied source images (sources are never modified).

  assets/ui/buttons.jpg        -> assets/ui/buttons/{quit,pause,play,restart,tick}.png
  assets/projectiles/shoot.jpg -> assets/projectiles/pea_projectile.png

Buttons: each button is cropped from its measured region (plus a 3 px margin) and
the white page background is removed by flood-filling near-white pixels from the
crop border. The dark outline stops the fill, so the button art itself is untouched.
The projectile is handled the same way, then cropped to its visible circle.

Usage: python tools/ui_art/prepare_ui_assets.py
"""
import os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "plants-vs-zombies"))

# Regions measured in buttons.jpg (1199 x 661): x0, y0, x1, y1 (exclusive).
BUTTONS = {
    "quit": (34, 20, 352, 159),      # "QUIT" text button
    "pause": (37, 502, 376, 641),    # "PAUSE" text button
    "play": (420, 502, 586, 641),    # play-triangle icon (Play / Resume)
    "restart": (220, 178, 386, 317), # circular-arrow icon (Play Again)
    "tick": (1012, 337, 1172, 489),  # round confirm button (menu: confirm username)
}
MARGIN = 3
WHITE_MIN = 200  # a pixel is background if all channels >= this and it touches the border


def remove_border_white(rgb):
    a = np.asarray(rgb).astype(int)
    h, w, _ = a.shape
    white = a.min(axis=2) >= WHITE_MIN
    bg = np.zeros((h, w), bool)
    q = deque((y, x) for y in range(h) for x in (0, w - 1))
    q.extend((y, x) for x in range(w) for y in (0, h - 1))
    while q:
        y, x = q.popleft()
        if 0 <= y < h and 0 <= x < w and white[y, x] and not bg[y, x]:
            bg[y, x] = True
            q.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([a.astype(np.uint8), alpha]), "RGBA")


def main():
    src = Image.open(os.path.join(GAME, "assets", "ui", "buttons.jpg")).convert("RGB")
    out_dir = os.path.join(GAME, "assets", "ui", "buttons")
    os.makedirs(out_dir, exist_ok=True)
    for name, (x0, y0, x1, y1) in BUTTONS.items():
        crop = src.crop((x0 - MARGIN, y0 - MARGIN, x1 + MARGIN, y1 + MARGIN))
        img = remove_border_white(crop)
        img = img.crop(img.getbbox())
        img.save(os.path.join(out_dir, name + ".png"))
        print("button", name, "region", (x0, y0, x1, y1), "->", img.size)

    pea = Image.open(os.path.join(GAME, "assets", "projectiles", "shoot.jpg")).convert("RGB")
    img = remove_border_white(pea)
    img = img.crop(img.getbbox())
    # The pea is a circle: replace the hard flood-fill edge with an anti-aliased disc
    # (drawn 4x larger, then downsampled) slightly inside the JPEG fringe.
    w, h = img.size
    ss = 4
    disc = Image.new("L", (w * ss, h * ss), 0)
    r = (min(w, h) / 2 - 0.6) * ss
    cx, cy = w * ss / 2, h * ss / 2
    ImageDraw.Draw(disc).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    img.putalpha(disc.resize((w, h), Image.LANCZOS))
    img.save(os.path.join(GAME, "assets", "projectiles", "pea_projectile.png"))
    print("projectile", pea.size, "->", img.size)


if __name__ == "__main__":
    main()
