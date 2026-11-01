"""Lawn mower layers from assets/env/lawn_mower/lawn_mover_all.png (the sheet's "Lawn Mower" block):
body, engine, wheel. They are kept separate so the game can spin the wheels while the mower runs.
Writes assets/characters/mower/{body,engine,wheel}.png and a flat preview."""
import numpy as np
from scipy import ndimage

from charlib import *

SHEET = os.path.join(ASSETS, 'env', 'lawn_mower', 'lawn_mover_all.png')
sheet = load_rgba(SHEET)


def part(box):
    a = np.array(sheet.crop(box))
    rgb = a[..., :3].astype(int)
    pink = (np.abs(rgb - np.array([255, 127, 237])).sum(axis=2) < 40) & (a[..., 3] > 200)
    a[pink, 3] = 0
    # the panel's flat green backdrop (alpha 0 in the file) must stay transparent
    solid = a[..., 3] > 0
    lab, n = ndimage.label(solid, structure=np.ones((3, 3)))
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    keep = [i + 1 for i, s in enumerate(sizes) if s >= 0.05 * sizes.max()]
    a[~np.isin(lab, keep), 3] = 0
    im, off = trim(Image.fromarray(a, 'RGBA'))
    return im


body = part((1, 22, 101, 103))
engine = part((1, 114, 40, 150))
wheel = part((82, 184, 108, 210))
save(body, 'mower/body.png')
save(engine, 'mower/engine.png')
save(wheel, 'mower/wheel.png')

# flat preview (the in-game rig uses these same offsets, see MOWER_* in main_game.gd)
canvas = Image.new('RGBA', (130, 110), (0, 0, 0, 0))
canvas.alpha_composite(wheel, (22, 62))
canvas.alpha_composite(body, (10, 6))
canvas.alpha_composite(engine, (40, 28))
canvas.alpha_composite(wheel, (68, 60))
preview([scaled(canvas, 3)], 'mower_preview.png')
print(body.size, engine.size, wheel.size)
