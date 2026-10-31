"""Regular zombie parts (head / body / feet) from zombie_pose.jpg, plus the HD cone and bucket
cut out of conehead_zombie.webp / buckethead_zombie.webp (so they match the body's art and resolution).

Coordinates below are pixels of the keyed zombie_pose image (737 x 1212) and of the two webp references.
"""
import numpy as np
from PIL import Image
from scipy import ndimage

from charlib import *

HALF = 0.5   # everything is stored at half the reference resolution (plenty for the on-screen size)

# ---------------------------------------------------------------- regular zombie
zombie = key_checkerboard(os.path.join(REFS, 'zombie_pose.jpg'))
print('keyed zombie', zombie.size)

HEAD_POLY = [(0, 0), (372, 0), (372, 225), (340, 232), (328, 262), (326, 322), (300, 352), (250, 392), (110, 396), (0, 396)]
head, rest = cut(zombie, HEAD_POLY)
FEET_Y = 975
feet, body = cut(rest, [(0, FEET_Y), (zombie.width, FEET_Y), (zombie.width, zombie.height), (0, zombie.height)], extend=26)

# Common origin for the three parts: they keep their position inside the full-size picture, so the rig
# just places each part at (its crop offset) and every joint lines up exactly.
parts = {}
for name, im in [('head', head), ('body', body), ('feet', feet)]:
    t, off = trim(im)
    parts[name] = (scaled(t, HALF), (off[0] * HALF, off[1] * HALF))
    save(parts[name][0], f'zombie/{name}.png')
print('offsets', {k: v[1] for k, v in parts.items()}, 'full size', (zombie.width * HALF, zombie.height * HALF))

# preview: reassembled + head displaced to show the neck inpaint
canvas = Image.new('RGBA', (int(zombie.width * HALF) + 60, int(zombie.height * HALF) + 40), (0, 0, 0, 0))
for n in ['feet', 'body', 'head']:
    im, off = parts[n]
    canvas.alpha_composite(im, (int(off[0]) + 20, int(off[1]) + 20 + (10 if n == 'head' else 0)))
preview([canvas], 'zombie_reassembled.png')

# ---------------------------------------------------------------- cone (from conehead_zombie.webp)
import cv2


def hsv_of(a):
    hsv = cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2HSV)
    return hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)


def largest(mask, min_size=0):
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    return np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= max(min_size, 0.02 * sizes.max())])


cone_src = load_rgba(os.path.join(REFS, 'conehead_zombie.webp'))
a = np.array(cone_src)
h, s, v = hsv_of(a)
rows = np.arange(a.shape[0])[:, None]
orange = (h >= 8) & (h <= 26) & (s > 100) & (v > 140) & (a[..., 3] > 128) & (rows < 180)
orange = ndimage.binary_closing(orange, iterations=2)
dark = (a[..., :3].max(axis=2) < 80) & (a[..., 3] > 128) & (rows < 185)
outline = ndimage.binary_dilation(orange, iterations=4) & dark
cone_mask = ndimage.binary_fill_holes(largest(orange | outline | ndimage.binary_dilation(orange, iterations=1)))
cone = a.copy()
cone[..., 3] = (ndimage.gaussian_filter(cone_mask.astype(float), 0.6) * 255).astype(np.uint8)
cone_im, cone_off = trim(Image.fromarray(cone, 'RGBA'))
print('cone', cone_im.size, 'offset in conehead ref', cone_off)

# ---------------------------------------------------------------- bucket (from buckethead_zombie.webp)
bk_src = load_rgba(os.path.join(REFS, 'buckethead_zombie.webp'))
a = np.array(bk_src)
rgb = a[..., :3].astype(int)
h, s, v = hsv_of(a)
neutral = (rgb.max(axis=2) - rgb.min(axis=2) <= 22) & (a[..., 3] > 128)      # bucket body + metal handle (skin is greenish)
red = (((h < 12) | (h > 165)) & (s > 55) & (v > 90)) & (a[..., 3] > 128)      # the blood on it
zone = poly_mask(bk_src.size, [(0, 0), (250, 0), (252, 150), (248, 196), (240, 215), (215, 238), (150, 266), (95, 266), (40, 232), (0, 198), (0, 150)])
rows = np.arange(a.shape[0])[:, None]
body = neutral & (v > 130) & (rows < 200)                                      # bright bucket body
wire = (rgb.max(axis=2) - rgb.min(axis=2) <= 9) & (v >= 60) & (v <= 160) & (rows >= 120) & (a[..., 3] > 128)   # grey metal handle (tight: skin is greenish)
dark = (rgb.max(axis=2) < 75) & (a[..., 3] > 128)
bk_mask = (body | wire | (red & (rows < 200))) & zone
bk_mask = ndimage.binary_closing(bk_mask, iterations=4)
bk_mask |= ndimage.binary_dilation(bk_mask, iterations=3) & dark & zone
bk_mask = ndimage.binary_opening(bk_mask, iterations=1)
lab, n = ndimage.label(bk_mask)
sizes = ndimage.sum(bk_mask, lab, range(1, n + 1))
bk_mask = lab == (1 + int(np.argmax(sizes)))                                   # body + handle are one connected piece
holes = ndimage.binary_fill_holes(bk_mask) & ~bk_mask
hl, hn = ndimage.label(holes)
hs = ndimage.sum(holes, hl, range(1, hn + 1))
bk_mask |= np.isin(hl, [i + 1 for i, s_ in enumerate(hs) if s_ < 250])         # only small holes (specular dots)
bk = a.copy()
bk[..., 3] = (ndimage.gaussian_filter(bk_mask.astype(float), 0.6) * 255).astype(np.uint8)
bucket_im, bucket_off = trim(Image.fromarray(bk, 'RGBA'))
print('bucket', bucket_im.size, 'offset in buckethead ref', bucket_off)
preview([scaled(cone_im, 1.0), scaled(bucket_im, 1.0)], 'accessories_raw.png')

# ---------------------------------------------------------------- put the accessories on the regular head
# Align by the zombies' eyes: big eye centre in each reference vs. in the regular zombie.
# regular zombie big eye (237, 170); conehead ref big eye (150, 175); buckethead ref big eye (218, 218).
def seat(acc, acc_off, ref_eye, k_ref):
    """Scale `acc` to the regular zombie and return it with the position (top-left) in zombie_pose coords."""
    s = k_ref
    im = acc.resize((round(acc.width * s), round(acc.height * s)), Image.LANCZOS)
    x = 237 + (acc_off[0] - ref_eye[0]) * s
    y = 170 + (acc_off[1] - ref_eye[1]) * s
    return im, (x, y)

cone_s, cone_pos = seat(cone_im, cone_off, (150, 175), 2.15)
# the bucket has to cover the regular zombie's (larger) head: scale it up and sit its rim on the brow
bucket_s = bucket_im.resize((round(bucket_im.width * 1.85), round(bucket_im.height * 1.85)), Image.LANCZOS)
bucket_pos = (-40.0, -129.0)
print('cone seat', cone_pos, cone_s.size, ' bucket seat', bucket_pos, bucket_s.size)

# preview: regular zombie with each accessory attached (head layer + accessory over the full body)
def composed(acc, pos, name):
    c = Image.new('RGBA', (zombie.width + 400, zombie.height + 500), (0, 0, 0, 0))
    ox, oy = 150, 400
    c.alpha_composite(zombie, (ox, oy))
    c.alpha_composite(acc, (int(ox + pos[0]), int(oy + pos[1])))
    return scaled(c, 0.45)
preview([composed(cone_s, cone_pos, 'cone'), composed(bucket_s, bucket_pos, 'bucket')], 'zombie_accessories_preview.png')

import json
json.dump({
    'cone': {'seat': cone_pos, 'size': cone_s.size},
    'bucket': {'seat': bucket_pos, 'size': bucket_s.size},
    'parts': {k: {'offset': v[1], 'size': v[0].size} for k, v in parts.items()},
    'full_size': [zombie.width * HALF, zombie.height * HALF],
}, open(os.path.join(SCRATCH, 'zombie_layout.json'), 'w'), indent=1)

# ---------------------------------------------------------------- damage states (bites with a fresh dark outline)
def bite(im, notches, outline=(34, 22, 16)):
    """Remove jagged polygons (given as fractions of the sprite size) and outline the new edge."""
    a = np.array(im)
    w, h = im.size
    removed = np.zeros((h, w), bool)
    for poly in notches:
        removed |= poly_mask(im.size, [(x * w, y * h) for x, y in poly])
    solid = a[..., 3] > 128
    new_solid = solid & ~removed
    edge = ndimage.binary_dilation(removed, iterations=3) & new_solid
    out = a.copy()
    out[removed, 3] = 0
    out[edge, :3] = outline
    out[edge, 3] = 255
    return Image.fromarray(out, 'RGBA')


CONE_NOTCH_1 = [[(0.55, 0.0), (0.70, 0.10), (0.62, 0.17), (0.78, 0.24), (0.66, 0.32), (0.86, 0.36), (1.0, 0.0)]]
CONE_NOTCH_2 = CONE_NOTCH_1 + [[(0.30, 0.0), (0.47, 0.12), (0.40, 0.20), (0.55, 0.30), (0.50, 0.0)],
                               [(0.0, 0.62), (0.12, 0.68), (0.08, 0.74), (0.0, 0.78)],
                               [(1.0, 0.45), (0.80, 0.52), (0.88, 0.60), (0.74, 0.66), (1.0, 0.72)]]
BUCKET_NOTCH_1 = [[(0.70, 0.0), (0.84, 0.0), (0.80, 0.06), (0.88, 0.12), (0.76, 0.14), (0.72, 0.07)]]
BUCKET_NOTCH_2 = BUCKET_NOTCH_1 + [[(0.20, 0.0), (0.34, 0.0), (0.30, 0.07), (0.24, 0.12), (0.17, 0.06)],
                                   [(0.86, 0.22), (1.0, 0.20), (1.0, 0.34), (0.90, 0.30)],
                                   [(0.45, 0.0), (0.58, 0.0), (0.55, 0.05), (0.49, 0.08)]]

variants = {
    'cone': (cone_s, [None, CONE_NOTCH_1, CONE_NOTCH_2]),
    'bucket': (bucket_s, [None, BUCKET_NOTCH_1, BUCKET_NOTCH_2]),
}
sheet_imgs = []
for name, (base, notch_sets) in variants.items():
    for i, notches in enumerate(notch_sets, 1):
        im = base if notches is None else bite(base, notches)
        sheet_imgs.append(scaled(im, 0.6))
        save(scaled(im, HALF), f'zombie/{name}_{i}.png')
preview(sheet_imgs, 'accessory_states.png')

# the cone / bucket seat (top-left in zombie_pose coordinates, ~HALF scale for the rig)
import json
layout = json.load(open(os.path.join(SCRATCH, 'zombie_layout.json')))
layout['cone']['seat'] = [cone_pos[0] * HALF, cone_pos[1] * HALF]
layout['bucket']['seat'] = [bucket_pos[0] * HALF, bucket_pos[1] * HALF]
layout['cone']['size'] = [round(cone_s.width * HALF), round(cone_s.height * HALF)]
layout['bucket']['size'] = [round(bucket_s.width * HALF), round(bucket_s.height * HALF)]
json.dump(layout, open(os.path.join(SCRATCH, 'zombie_layout.json'), 'w'), indent=1)
print(json.dumps(layout))
