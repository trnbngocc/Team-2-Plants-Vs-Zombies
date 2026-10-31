#!/usr/bin/env python3
"""Make NEXT, BACK and LEADERBOARD buttons in the style of the supplied stone buttons.

The sheet (assets/ui/buttons.jpg) has no NEXT or BACK button. They are built from the already extracted
assets/ui/buttons/quit.png: its "QUIT" glyphs are painted over with the flat face colour and the new word is
drawn with the same ink colour, cap height and stroke width, on the same pixel grid. The border, slab and
proportions are therefore identical to QUIT.

Usage: python tools/ui_art/make_nav_buttons.py   (run after prepare_ui_assets.py)
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.normpath(os.path.join(HERE, "..", "..", "plants-vs-zombies", "assets", "ui", "buttons"))

FACE = (159, 187, 208, 255)
INK = (62, 98, 124, 255)
UNIT = 6                       # one font pixel (the QUIT letters are ~6 px strokes, ~7 units tall)
GAP = 1                        # blank units between letters
ERASE = (66, 28, 252, 98)      # interior box that holds the QUIT letters (x0, y0, x1, y1)

FONT = {
    "N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
}


def make(word, base, unit=UNIT):
    im = base.copy()
    px = im.load()
    x0, y0, x1, y1 = ERASE
    for y in range(y0, y1):
        for x in range(x0, x1):
            px[x, y] = FACE
    units = len(word) * 5 + (len(word) - 1) * GAP
    left = (im.width - units * unit) // 2
    top = 36 + (7 * UNIT - 7 * unit) // 2
    for n, ch in enumerate(word):
        gx = left + n * (5 + GAP) * unit
        for r, row in enumerate(FONT[ch]):
            for c, bit in enumerate(row):
                if bit == "1":
                    for dy in range(unit):
                        for dx in range(unit):
                            px[gx + c * unit + dx, top + r * unit + dy] = INK
    return im


def main():
    base = Image.open(os.path.join(DIR, "quit.png")).convert("RGBA")
    # LEADERBOARD is 11 letters: it needs a smaller font pixel (4) to fit the same button face.
    for word, unit in (("NEXT", UNIT), ("BACK", UNIT), ("LEADERBOARD", 4)):
        out = make(word, base, unit)
        out.save(os.path.join(DIR, word.lower() + ".png"))
        print("button", word.lower(), out.size)


if __name__ == "__main__":
    main()
