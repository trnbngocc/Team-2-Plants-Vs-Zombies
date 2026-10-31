"""Plants from original_pvz/*.webp and the Squash animation from squash_move.gif.

  sunflower/head.png, sunflower/stem.png     flower head (face + petals) and stem + leaves
  peashooter/head.png, peashooter/stem.png   head (with the leaf tuft) and stem + leaves
  jalapeno/jalapeno.png                      the whole pepper (eyes, brows and teeth are part of the art)
  squash/f##.png                             selected frames of the original Squash animation
"""
import json

from PIL import ImageDraw, ImageSequence

from charlib import *

HALF = 0.5
layout = {}


def piece(im, name, sub):
    t, off = trim(im)
    t = scaled(t, HALF)
    save(t, f'{sub}/{name}.png')
    layout[f'{sub}/{name}'] = {'offset': [off[0] * HALF, off[1] * HALF], 'size': list(t.size)}


def ellipse_poly(cx, cy, rx, ry, n=64):
    return [(cx + rx * np.cos(2 * np.pi * i / n), cy + ry * np.sin(2 * np.pi * i / n)) for i in range(n)]


# ---------------------------------------------------------------- Sunflower
sun = load_rgba(os.path.join(REFS, 'Sunflower.webp'))
print('sunflower', sun.size)
head, stem = cut(sun, ellipse_poly(462, 362, 470, 388), extend=24)
# the stem layer only needs the green stem + leaves: drop stray petal pixels (yellow) that fell outside the head cut
sa = np.array(stem)
hsv = cv2.cvtColor(sa[..., :3], cv2.COLOR_RGB2HSV)
yellow = (hsv[..., 0] >= 14) & (hsv[..., 0] <= 34) & (hsv[..., 1] > 110)
yellow = ndimage.binary_dilation(yellow, iterations=2)
sa[yellow, 3] = 0
lab, n = ndimage.label(sa[..., 3] > 0)
sizes = ndimage.sum(sa[..., 3] > 0, lab, range(1, n + 1))
sa[~np.isin(lab, [i + 1 for i, s_ in enumerate(sizes) if s_ > 0.05 * sizes.max()]), 3] = 0
stem = Image.fromarray(sa, 'RGBA')
piece(head, 'head', 'sunflower')
piece(stem, 'stem', 'sunflower')
layout['sunflower/full'] = {'size': [sun.width * HALF, sun.height * HALF], 'pivot': [520 * HALF, 745 * HALF]}   # stem top = head pivot

# ---------------------------------------------------------------- Peashooter
pea = load_rgba(os.path.join(REFS, 'Peashooter.webp'))
print('peashooter', pea.size)
head, stem = cut(pea, [(0, 0), (pea.width, 0), (pea.width, 205), (300, 224), (245, 236), (170, 228), (80, 205), (0, 178)], extend=22)
piece(head, 'head', 'peashooter')
piece(stem, 'stem', 'peashooter')
layout['peashooter/full'] = {'size': [pea.width * HALF, pea.height * HALF], 'pivot': [232 * HALF, 232 * HALF]}

# ---------------------------------------------------------------- Jalapeno
jal = load_rgba(os.path.join(REFS, 'Jalapeno.webp'))
print('jalapeno', jal.size)
piece(jal, 'jalapeno', 'jalapeno')
layout['jalapeno/full'] = {'size': [jal.width * HALF, jal.height * HALF]}

# ---------------------------------------------------------------- Squash (frames of the original animation)
gif = Image.open(os.path.join(REFS, 'squash_move.gif'))
frames = []
for fr in ImageSequence.Iterator(gif):
    frames.append(fr.convert('RGBA'))
CHOSEN = [0, 5, 10, 14, 17, 20, 23, 26, 28, 30, 32, 34, 36, 38, 40, 42, 43, 44, 45, 47, 50, 55, 59]
boxes = [frames[i].getbbox() for i in CHOSEN]
y0 = min(b[1] for b in boxes) - 4
y1 = max(b[3] for b in boxes) + 4
HALFW = 130                       # every frame is cropped around its own horizontal centre (the GIF drifts sideways
SQ = 0.4                          # while jumping; the game moves the plant itself)
for i, bx in zip(CHOSEN, boxes):
    cx = (bx[0] + bx[2]) / 2
    c = frames[i].crop((int(cx - HALFW), y0, int(cx + HALFW), y1))
    save(scaled(c, SQ), f'squash/f{i:02d}.png')
b0 = boxes[0]
layout['squash'] = {'frames': CHOSEN, 'size': [round(2 * HALFW * SQ), round((y1 - y0) * SQ)],
                    'ground': [HALFW * SQ, (b0[3] - y0) * SQ],
                    'idle_box': [(b0[2] - b0[0]) * SQ, (b0[3] - b0[1]) * SQ]}
print('squash', layout['squash'])

json.dump(layout, open(os.path.join(SCRATCH, 'plant_layout.json'), 'w'), indent=1)
imgs = [scaled(load_rgba(os.path.join(OUT, p)), 1.0) for p in ['sunflower/head.png', 'sunflower/stem.png', 'peashooter/head.png', 'peashooter/stem.png', 'jalapeno/jalapeno.png']]
preview(imgs, 'plant_parts.png')
