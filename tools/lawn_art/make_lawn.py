#!/usr/bin/env python3
"""Build the in-game lawn background from the untouched source grid.jpg.

Source:  plants-vs-zombies/grid.jpg            (886 x 514, never modified)
Output:  plants-vs-zombies/assets/lawn/lawn_game.jpg

Processing:
  1. Upscale x2 with Lanczos (the game shows the lawn at 1.3x-2.5x, so the
     GPU then scales down/near 1:1 instead of blowing up a small JPEG).
  2. Add PAD source pixels of soft margin on every side: edge-extended
     colours, heavily blurred and slightly darkened. The margin only fills
     window space outside the original picture (other aspect ratios); the
     original picture area stays pixel-for-pixel the upscaled source.
No crop is applied: the 9 x 5 lawn and its surroundings are kept whole.

Usage: python tools/lawn_art/make_lawn.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter

UPSCALE = 2
PAD = 120          # in source pixels, each side
BLUR = 18          # Gaussian radius in output pixels
EDGE_DARKEN = 0.72 # brightness at the outermost margin pixel

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.normpath(os.path.join(here, "..", ".."))
src_path = os.path.join(root, "plants-vs-zombies", "grid.jpg")
out_dir = os.path.join(root, "plants-vs-zombies", "assets", "lawn")


def main():
    src = Image.open(src_path).convert("RGB")
    w, h = src.size
    big = src.resize((w * UPSCALE, h * UPSCALE), Image.LANCZOS)
    p = PAD * UPSCALE
    arr = np.asarray(big).astype(np.float32)
    padded = np.pad(arr, ((p, p), (p, p), (0, 0)), mode="edge")
    soft = np.asarray(
        Image.fromarray(padded.astype(np.uint8)).filter(ImageFilter.GaussianBlur(BLUR))
    ).astype(np.float32)
    H, W = padded.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    # distance (px) outside the original picture rectangle
    dx = np.maximum(np.maximum(p - xx, xx - (W - p - 1)), 0)
    dy = np.maximum(np.maximum(p - yy, yy - (H - p - 1)), 0)
    dist = np.sqrt(dx.astype(np.float32) ** 2 + dy.astype(np.float32) ** 2)
    outside = dist > 0
    shade = 1.0 - (1.0 - EDGE_DARKEN) * np.clip(dist / p, 0, 1)
    out = padded.copy()
    out[outside] = soft[outside] * shade[outside][:, None]
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    os.makedirs(out_dir, exist_ok=True)
    dst = os.path.join(out_dir, "lawn_game.jpg")
    img.save(dst, quality=92, subsampling=0)
    print("source", src.size, "->", dst, img.size,
          "| original picture at", (p, p), "size", big.size)


if __name__ == "__main__":
    main()
