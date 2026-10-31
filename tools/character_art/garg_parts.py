"""Gargantuar (+ the Imp that rides it) from original_pvz/Gargantuar.webp (583 x 575).

Layers written to assets/characters/gargantuar/ :
  feet.png        both shoes + lower legs
  body.png        torso, big arms, belly, barrel (the Imp, pole and head removed, holes filled)
  head.png        the big head with the red collar
  pole.png        the telegraph-pole weapon (wood + bolts)
  hand.png        the small left hand (drawn over the pole)
  grip.png        the big arm's grip area (drawn over the pole's handle end)
  imp_rider.png   the Imp sitting on the barrel (shown until it is thrown)
and assets/characters/imp/ : the standalone Imp (head, shirt, arm) used for the walking Imp.
Offsets are stored in garg_layout.json (pixels of the original image, at HALF scale).
"""
import json

import cv2
from PIL import ImageDraw

from charlib import *

HALF = 0.6
garg = load_rgba(os.path.join(REFS, 'Gargantuar.webp'))
W, H = garg.size
print('gargantuar', garg.size)

# ---- 1. the Imp rider
IMP_POLY = [(433, 6), (500, 3), (545, 22), (556, 58), (562, 92), (526, 124), (496, 126), (470, 127), (454, 123), (444, 105), (431, 70), (432, 38)]
imp_part, rest = cut(garg, IMP_POLY, extend=0)
# fill what the Imp was sitting on: the shoulder (inpaint) and the barrel's opening (dark ellipse with a rim)
a = np.array(rest)
shoulder = poly_mask((W, H), [(448, 98), (500, 112), (560, 112), (556, 128), (480, 136), (450, 124)])
need = shoulder & (np.array(garg)[..., 3] > 8) & (a[..., 3] < 128)
bgr = cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2BGR)
a[..., :3] = cv2.cvtColor(cv2.inpaint(bgr, need.astype(np.uint8) * 255, 6, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)
a[need, 3] = 255
rest = Image.fromarray(a, 'RGBA')
d = ImageDraw.Draw(rest)
d.ellipse((501, 66, 574, 112), fill=(40, 42, 46, 255), outline=(14, 14, 16, 255), width=3)
d.arc((503, 68, 572, 110), 200, 340, fill=(120, 125, 130, 255), width=3)

# ---- 2. the pole: wood + bolts inside a polygon around it
POLE_POLY = [(0, 232), (195, 236), (205, 325), (300, 352), (425, 378), (432, 448), (300, 424), (200, 388), (120, 374), (110, 404), (36, 404), (0, 362)]
ra = np.array(rest)
hsv = cv2.cvtColor(ra[..., :3], cv2.COLOR_RGB2HSV)
h_, s_, v_ = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
zone = poly_mask((W, H), POLE_POLY) & (ra[..., 3] > 128)
wood = (h_ >= 5) & (h_ <= 22) & (s_ > 100) & (v_ > 50)
bolts = (s_ < 45) & (v_ > 130) & (np.arange(W)[None, :] < 215)
dark = (ra[..., :3].max(axis=2) < 60)
pole_mask = zone & (wood | bolts)
pole_mask = ndimage.binary_closing(pole_mask, iterations=2)
pole_mask |= ndimage.binary_dilation(pole_mask, iterations=3) & dark & zone              # its black outline
pole_mask = ndimage.binary_fill_holes(pole_mask)
lab, n = ndimage.label(pole_mask)
sizes = ndimage.sum(pole_mask, lab, range(1, n + 1))
pole_mask = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > 150])
pole_arr = ra.copy()
pole_arr[..., 3] = (ndimage.gaussian_filter(pole_mask.astype(float), 0.6) * 255).astype(np.uint8)
pole_im = Image.fromarray(pole_arr, 'RGBA')
# base without the pole: fill where it was from the surroundings
hole = ndimage.binary_dilation(pole_mask, iterations=2) & (ra[..., 3] > 8)
bgr = cv2.cvtColor(ra[..., :3], cv2.COLOR_RGB2BGR)
fill = cv2.cvtColor(cv2.inpaint(bgr, hole.astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA), cv2.COLOR_BGR2RGB)
ra[hole, :3] = fill[hole]
ra[hole, 3] = 255
# where the pole stuck out past the body into empty space there is nothing to fill: make it transparent again
orig = np.array(garg)
outside = pole_mask & (orig[..., 3] < 8)
ra[outside, 3] = 0
base = Image.fromarray(ra, 'RGBA')

# ---- 3. hand + grip overlays (copied from the base; they are drawn OVER the pole)
HAND_POLY = [(172, 395), (205, 385), (260, 388), (300, 400), (312, 432), (292, 456), (245, 464), (200, 452), (175, 426)]
GRIP_POLY = [(384, 398), (432, 392), (482, 408), (524, 450), (502, 482), (432, 480), (384, 462)]
hand_im, _ = cut(base, HAND_POLY, extend=0)
grip_im, _ = cut(base, GRIP_POLY, extend=0)

# ---- 4. head and feet (cut from the base, base is extended into the cut)
HEAD_POLY = [(168, 185), (185, 140), (215, 108), (250, 92), (285, 95), (310, 100), (336, 112), (341, 180), (339, 250), (326, 262), (300, 287), (270, 300), (230, 302), (205, 295), (190, 287), (172, 252)]
head_im, base2 = cut(base, HEAD_POLY, extend=26)
FEET_Y = 470
feet_im, body_im = cut(base2, [(0, FEET_Y), (W, FEET_Y), (W, H), (0, H)], extend=8)

layout = {}
for name, im in [('feet', feet_im), ('body', body_im), ('head', head_im), ('pole', pole_im), ('hand', hand_im), ('grip', grip_im), ('imp_rider', imp_part)]:
    t, off = trim(im)
    save(scaled(t, HALF), f'gargantuar/{name}.png')
    layout[name] = {'offset': [off[0] * HALF, off[1] * HALF], 'size': [round(t.width * HALF), round(t.height * HALF)]}
layout['full_size'] = [W * HALF, H * HALF]
layout['pole_grip'] = [400 * HALF, 428 * HALF]       # where the big hand holds the pole (pivot)
layout['neck'] = [250 * HALF, 280 * HALF]            # head pivot
layout['hips'] = [400 * HALF, 450 * HALF]
layout['ground'] = [400 * HALF, 572 * HALF]          # between the feet, on the ground
json.dump(layout, open(os.path.join(SCRATCH, 'garg_layout.json'), 'w'), indent=1)

# ---- review sheets
def put(canvas, im, off, pad=0):
    canvas.alpha_composite(im, (int(off[0] + pad), int(off[1] + pad)))

full = Image.new('RGBA', (int(W * HALF) + 40, int(H * HALF) + 40), (0, 0, 0, 0))
for name, im in [('feet', feet_im), ('body', body_im), ('head', head_im), ('pole', pole_im), ('hand', hand_im), ('grip', grip_im), ('imp_rider', imp_part)]:
    put(full, scaled(im, HALF), (0, 0), 20)
no_imp = Image.new('RGBA', full.size, (0, 0, 0, 0))
for name, im in [('feet', feet_im), ('body', body_im), ('head', head_im), ('pole', pole_im), ('hand', hand_im), ('grip', grip_im)]:
    put(no_imp, scaled(im, HALF), (0, 0), 20)
preview([full, no_imp], 'garg_reassembled.png')

# ---- the standalone Imp: head, shirt and arm from the rider
imp_t, imp_off = trim(imp_part)
save(scaled(imp_t, HALF), 'imp/upper.png')
json.dump({'upper': {'size': [round(imp_t.width * HALF), round(imp_t.height * HALF)]}}, open(os.path.join(SCRATCH, 'imp_layout.json'), 'w'))
print('done')
