#!/usr/bin/env python3
"""Cut the supplied Peashooter parts sheet into separate PNGs and build an assembly mockup.

Source (never modified): plants-vs-zombies/assets/plants/peashooter/168191.png (463 x 325, RGBA).
The sheet is an exploded view: parts are spread around the head and the leaf base.
Each part is cut by its own alpha mask (connected component), so the label text
baked into the sheet is never included.

Outputs:
  assets/plants/peashooter/parts/<name>.png   individual parts (original pixels)
  assets/plants/peashooter/layout.json        assembled position of every part
  assets/plants/peashooter/peashooter_layout.gd  the same layout as GDScript constants
  tools/peashooter/mockup.png                 assembled still (x4, for review)

Usage: python tools/peashooter/build_peashooter.py
"""
import json
import os
from collections import deque

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "plants-vs-zombies"))
SRC = os.path.join(GAME, "assets", "plants", "peashooter", "168191.png")
OUT = os.path.join(GAME, "assets", "plants", "peashooter")

# name: (a seed pixel inside the part on the sheet, group, draw order)
# Seeds were picked from the measured connected components of the sheet.
PARTS = {
    "crest_leaf_a": ((84, 9), "head", 0),
    "crest_leaf_b": ((95, 8), "head", 0),
    "crest_leaf_c": ((126, 30), "head", 0),
    "crest_leaf_d": ((77, 42), "head", 0),
    "crest_leaf_e": ((54, 50), "head", 0),
    "crest_leaf_f": ((31, 65), "head", 0),
    "crest_leaf_g": ((54, 84), "head", 0),
    "stem_top": ((263, 97), "stem", 1),
    "stem_bottom": ((267, 119), "stem", 1),
    "leaf_top": ((370, 24), "body", 2),
    "leaf_right_top": ((412, 42), "body", 2),
    "leaf_small_left": ((309, 55), "body", 2),
    "leaf_small_right": ((432, 60), "body", 2),
    "leaf_left": ((324, 98), "body", 3),
    "leaf_right": ((417, 80), "body", 3),
    "leaf_pair": ((367, 52), "body", 4),
    "leaf_base": ((371, 80), "body", 5),
    "head": ((111, 103), "head", 6),
    "mouth": ((178, 75), "head", 7),
    "mouth_alt": ((168, 154), "head", 7),
    "eyes_open": ((54, 141), "head", 8),
    "eyes_closed": ((111, 154), "head", 8),
}

# Exploded-view centres on the sheet and how far loose pieces are pulled back in.
GROUP_CENTRE = {"head": (111, 103), "body": (371, 80)}
PULL = {"head": 0.62, "body": 0.38}
LOOSE = {"crest_leaf_a", "crest_leaf_b", "crest_leaf_c", "crest_leaf_d", "crest_leaf_e",
         "crest_leaf_f", "crest_leaf_g", "leaf_top", "leaf_right_top", "leaf_small_left",
         "leaf_small_right", "leaf_left", "leaf_right"}

# Placement of each group on the plant canvas (canvas px; feet at bottom centre).
CANVAS = (150, 150)
BODY_AT = (78, 128)      # where the leaf base centre goes
STEM_AT = (78, 92)       # stem centre
HEAD_AT = (66, 52)       # head centre
MOUTH_OFFSET = (36, -6)  # mouth tube centre relative to head centre (on the snout)
EYES_OFFSET = (13, -11)  # eye overlay centre relative to head centre (marks land on the drawn eyes)
NOT_IN_MOCKUP = {"mouth", "eyes_open", "eyes_closed"}
# Small hand nudges (canvas px) after the pull-in, where the radial guess is off.
NUDGE = {
    "leaf_pair": (0, 12),
    "crest_leaf_a": (4, 16), "crest_leaf_b": (0, 18), "crest_leaf_c": (-8, 12),
    "stem_bottom": (0, -6),
    "leaf_left": (6, -2), "leaf_right": (-4, 0),
}


def component(alpha, seed):
    h, w = alpha.shape
    sy, sx = seed[1], seed[0]
    # nearest solid pixel to the seed
    ys, xs = np.nonzero(alpha)
    k = np.argmin((ys - sy) ** 2 + (xs - sx) ** 2)
    sy, sx = ys[k], xs[k]
    seen = np.zeros_like(alpha, bool)
    q = deque([(sy, sx)])
    seen[sy, sx] = True
    while q:
        y, x = q.popleft()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and alpha[yy, xx] and not seen[yy, xx]:
                    seen[yy, xx] = True
                    q.append((yy, xx))
    return seen


def main():
    sheet = np.asarray(Image.open(SRC).convert("RGBA"))
    solid = sheet[..., 3] > 0
    os.makedirs(os.path.join(OUT, "parts"), exist_ok=True)
    layout = {}
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    placed = []
    for name, (seed, group, order) in PARTS.items():
        mask = component(solid, seed)
        ys, xs = np.nonzero(mask)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        part = sheet[y0:y1, x0:x1].copy()
        part[..., 3] = np.where(mask[y0:y1, x0:x1], part[..., 3], 0)
        img = Image.fromarray(part, "RGBA")
        img.save(os.path.join(OUT, "parts", name + ".png"))
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        # assembled centre
        if group == "stem":
            sc = (np.mean([263, 267]), np.mean([97, 119]))
            ax, ay = STEM_AT[0] + (cx - sc[0]), STEM_AT[1] + (cy - sc[1])
        elif name == "mouth_alt":
            # narrow tube: resting pose (leaves both eyes visible)
            ax, ay = HEAD_AT[0] + MOUTH_OFFSET[0], HEAD_AT[1] + MOUTH_OFFSET[1]
        elif name == "mouth":
            # wide flared tube: firing pose, nudged forward so it clears the eye
            ax, ay = HEAD_AT[0] + MOUTH_OFFSET[0] + 3, HEAD_AT[1] + MOUTH_OFFSET[1]
        elif name.startswith("eyes"):
            ax, ay = HEAD_AT[0] + EYES_OFFSET[0], HEAD_AT[1] + EYES_OFFSET[1]
        else:
            gx, gy = GROUP_CENTRE[group]
            f = PULL[group] if name in LOOSE else 1.0
            at = HEAD_AT if group == "head" else BODY_AT
            ax, ay = at[0] + (cx - gx) * f, at[1] + (cy - gy) * f
        dx, dy = NUDGE.get(name, (0, 0))
        ax, ay = ax + dx, ay + dy
        layout[name] = {"centre": [round(ax, 1), round(ay, 1)], "size": [int(x1 - x0), int(y1 - y0)],
                        "z": order, "sheet_rect": [int(x0), int(y0), int(x1), int(y1)]}
        if name not in NOT_IN_MOCKUP:
            placed.append((order, img, ax, ay))
    for order, img, ax, ay in sorted(placed, key=lambda p: p[0]):
        canvas.alpha_composite(img, (int(round(ax - img.size[0] / 2)), int(round(ay - img.size[1] / 2))))
    with open(os.path.join(OUT, "layout.json"), "w") as f:
        json.dump({"canvas": CANVAS, "feet": [CANVAS[0] // 2, CANVAS[1]], "parts": layout}, f, indent=1)
    lines = [
        "# Generated by tools/peashooter/build_peashooter.py - do not edit by hand.",
        "# Part centres are in canvas pixels; the plant's feet are at FEET.",
        "extends RefCounted",
        "",
        "const CANVAS := Vector2(%d, %d)" % CANVAS,
        "const FEET := Vector2(%d, %d)" % (CANVAS[0] // 2, CANVAS[1]),
        "const PARTS := {",
    ]
    for name, v in sorted(layout.items(), key=lambda kv: (kv[1]["z"], kv[0])):
        lines.append('\t"%s": {"centre": Vector2(%s, %s), "z": %d},'
                     % (name, v["centre"][0], v["centre"][1], v["z"]))
    lines.append("}")
    with open(os.path.join(OUT, "peashooter_layout.gd"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    bg = Image.new("RGBA", CANVAS, (96, 150, 70, 255))
    bg.alpha_composite(canvas)
    bg.resize((CANVAS[0] * 4, CANVAS[1] * 4), Image.NEAREST).save(os.path.join(HERE, "mockup.png"))
    print("parts:", len(PARTS), "-> mockup", os.path.join(HERE, "mockup.png"))


if __name__ == "__main__":
    main()
