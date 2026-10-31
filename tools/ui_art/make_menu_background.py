#!/usr/bin/env python3
"""Make the main-menu background from the supplied menu.jpg (source never modified).

Only the publisher badge (bottom-right corner) is removed, as requested; the game
title artwork and the rest of the picture are kept. The badge region is masked and
filled by multi-scale diffusion from the surrounding background, then given light
fine grain so the fill does not look flat.

  assets/menu.jpg -> assets/ui/menu_background.jpg

Usage: python tools/ui_art/make_menu_background.py [preview_mask.png]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "plants-vs-zombies"))

# Regions measured on menu.jpg (1200 x 758).
BADGE_ELLIPSE = (1060, 606, 1214, 772)                          # publisher badge
FEATHER = 6


def build_mask(size):
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    d.ellipse(BADGE_ELLIPSE, fill=255)
    return m


def diffuse_fill(img, mask):
    """Fill mask>0 pixels by repeated neighbour averaging, coarse-to-fine."""
    a = img.astype(np.float32)
    hole = mask > 0
    levels = []
    cur_a, cur_h = a, hole
    while min(cur_a.shape[:2]) > 24:
        levels.append((cur_a, cur_h))
        h2, w2 = cur_a.shape[0] // 2, cur_a.shape[1] // 2
        cur_a = np.asarray(Image.fromarray(cur_a.astype(np.uint8)).resize((w2, h2), Image.BOX)).astype(np.float32)
        cur_h = np.asarray(Image.fromarray(cur_h.astype(np.uint8) * 255).resize((w2, h2), Image.BOX)) > 0
    levels.append((cur_a, cur_h))
    guess = None
    for la, lh in reversed(levels):
        f = la.copy()
        if guess is not None:
            up = np.asarray(Image.fromarray(np.clip(guess, 0, 255).astype(np.uint8)).resize((la.shape[1], la.shape[0]), Image.BILINEAR)).astype(np.float32)
            f[lh] = up[lh]
        else:
            f[lh] = la[~lh].mean(axis=0)
        for _ in range(60):
            p = np.pad(f, ((1, 1), (1, 1), (0, 0)), mode="edge")
            avg = (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:]) / 4
            f[lh] = avg[lh]
        guess = f
    return guess


def main():
    src = Image.open(os.path.join(GAME, "assets", "menu.jpg")).convert("RGB")
    mask = build_mask(src.size)
    filled = diffuse_fill(np.asarray(src), np.asarray(mask))
    # Light fine grain so the filled area matches the JPEG texture around it.
    base = np.asarray(src).astype(np.float32)
    rng = np.random.default_rng(7)
    filled = filled + rng.normal(0.0, 2.5, filled.shape[:2])[..., None]
    soft = mask.filter(ImageFilter.GaussianBlur(FEATHER))
    k = np.asarray(soft).astype(np.float32)[..., None] / 255.0
    out = base * (1 - k) + filled * k
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    dst = os.path.join(GAME, "assets", "ui", "menu_background.jpg")
    img.save(dst, quality=92)
    print("menu", src.size, "->", dst)
    if len(sys.argv) > 1:
        prev = src.copy()
        ImageDraw.Draw(prev).ellipse(BADGE_ELLIPSE, outline=(255, 0, 0), width=3)
        prev.save(sys.argv[1])


if __name__ == "__main__":
    main()
