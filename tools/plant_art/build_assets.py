"""Builds the derived art used by the game from the supplied sprite sheets.

Run from the repository root:   python tools/plant_art/build_assets.py

Nothing in the supplied sheets is modified; every output is a new file:
  assets/plants/wall-nut/wallnut_{1,2,3}.png      healthy / cracked / badly cracked Wall-nut (with faces)
  assets/plants/jalapeno/jalapeno_face.png        complete Jalapeno WITH eyes, brows and mouth
  assets/plants/sunflower/sunflower_full.png      Sunflower assembled from the sheet's face, petals and leaves
  assets/env/shovel/shovel_cutout.png             the shovel alone (transparent), used as the held shovel
  assets/zombies/armor/{cone,bucket}_{1,2,3}.png  Conehead / Buckethead armor, intact -> damaged
  assets/ui/final_wave_text.png                   "FINAL WAVE" lettering only (photo background removed)
  assets/ui/huge_wave_text.png                    "A huge wave of zombies is approaching!" lettering, tight crop
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'plants-vs-zombies', 'assets')
os.chdir(ROOT)


def load(path):
    return Image.open(path).convert('RGBA')


def keyed(sheet, box, key_mode):
    """Crop `box` from `sheet` and make the sheet background transparent.

    key_mode: 'pink'  - the sheets with a (255,127,237) background
              'white' - white panels
              'alpha' - already transparent panels (only drops the sheet colour at the borders)
    The background is only removed where it connects to the crop border, so same-coloured
    details inside the sprite (eyes, highlights) are kept.
    """
    a = np.array(load(sheet).crop(box))
    rgb = a[..., :3].astype(int)
    # The sheets use a pink background and/or white panels (and some borders mix both).
    bg = (rgb >= 232).all(axis=2) | (np.abs(rgb - np.array([255, 127, 237])).sum(axis=2) < 60)
    bg |= a[..., 3] < 20
    lab, _ = ndimage.label(bg)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    a[np.isin(lab, list(edge)), 3] = 0
    return a


def keep_largest(a, min_fraction=0.08):
    solid = a[..., 3] > 0
    lab, n = ndimage.label(solid, structure=np.ones((3, 3)))
    sizes = ndimage.sum(solid, lab, range(1, n + 1))
    big = [i + 1 for i, s in enumerate(sizes) if s >= min_fraction * sizes.max()]
    a[~np.isin(lab, big), 3] = 0
    return a


def trim(a, pad=0):
    ys, xs = np.where(a[..., 3] > 0)
    im = Image.fromarray(a).crop((max(xs.min() - pad, 0), max(ys.min() - pad, 0), xs.max() + 1 + pad, ys.max() + 1 + pad))
    return im


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print('wrote', path, im.size)


# ---------------------------------------------------------------- Wall-nut (3 damage states)
for i, box in enumerate([(0, 0, 102, 101), (102, 0, 205, 101), (204, 0, 306, 101)], 1):
    a = keep_largest(keyed('plants/wall-nut/Wall-nut.png', box, 'pink'))
    save(trim(a), f'plants/wall-nut/wallnut_{i}.png')

# ---------------------------------------------------------------- Jalapeno (the sheet's complete face sprite)
a = keep_largest(keyed('plants/jalapeno/Jalapeno.png', (0, 189, 87, 299), 'pink'))
save(trim(a), 'plants/jalapeno/jalapeno_face.png')

# ---------------------------------------------------------------- Sunflower (assembled)
sheet = load('plants/sunflower/Sunflower.png')


def part(box):
    a = np.array(sheet.crop(box))
    rgb = a[..., :3].astype(int)
    blue = np.abs(rgb - np.array([0, 150, 255])).sum(axis=2) < 60
    a[blue | (a[..., 3] < 20), 3] = 0
    return trim(a)


face = part((3, 3, 59, 44))                       # smiling face
petals_a = [part(b) for b in [(25, 92, 39, 105), (41, 92, 55, 105), (72, 91, 85, 104), (3, 92, 12, 103), (57, 91, 69, 101), (114, 91, 131, 104)]]
petals_b = [part(b) for b in [(25, 109, 34, 117), (36, 109, 47, 118), (62, 108, 72, 117), (75, 108, 86, 118), (88, 108, 98, 118), (13, 109, 23, 120)]]
leaves = part((25, 123, 92, 161))                 # the pair of leaves

SCALE = 4                                          # draw big, then shrink: smooth edges
W, H = 112, 150
canvas = Image.new('RGBA', (W * SCALE, H * SCALE), (0, 0, 0, 0))
cx, cy = 56 * SCALE, 50 * SCALE


def paste_center(img, im, x, y, angle=0.0, scale=1.0):
    im = im.resize((max(1, int(im.width * SCALE * scale)), max(1, int(im.height * SCALE * scale))), Image.LANCZOS)
    if angle:
        im = im.rotate(angle, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(im, (int(x - im.width / 2), int(y - im.height / 2)))


# stem (outlined green tube with a slight curve), then leaves, then petals, then face
draw = ImageDraw.Draw(canvas)
pts = [(cx + math.sin(t / 10 * 2.2) * 3 * SCALE, cy + 22 * SCALE + t * 7.2 * SCALE) for t in range(0, 13)]
draw.line(pts, fill=(18, 58, 12, 255), width=11 * SCALE, joint='curve')
draw.line(pts, fill=(64, 168, 36, 255), width=7 * SCALE, joint='curve')
draw.line([(x - 1.5 * SCALE, y) for x, y in pts], fill=(120, 214, 70, 255), width=2 * SCALE, joint='curve')
paste_center(canvas, leaves, cx, cy + 82 * SCALE, 0, 0.95)
for ring, rx, ry, plist, sc, n in [(0, 33, 27, petals_a, 1.35, 14), (1, 29, 23, petals_b, 1.25, 14)]:
    for k in range(n):
        ang = 2 * math.pi * (k + 0.5 * ring) / n
        px = cx + math.cos(ang) * rx * SCALE
        py = cy + math.sin(ang) * ry * SCALE
        p = plist[(k * 5 + ring) % len(plist)]
        paste_center(canvas, p, px, py, -math.degrees(ang) - 90, sc)
paste_center(canvas, face, cx, cy, 0, 0.9)
save(canvas.resize((W, H), Image.LANCZOS), 'plants/sunflower/sunflower_full.png')

# ---------------------------------------------------------------- shovel cut-out
sh = load('env/shovel/Shovel.jpg')
s = np.array(sh).astype(int)
r, g, b = s[..., 0], s[..., 1], s[..., 2]
lum = (r + g + b) / 3
sat = s.max(axis=2) - s.min(axis=2)
# The soil tile around the shovel is brown like its shaft, so colour alone cannot separate them. Use a
# hand-placed silhouette (handle loop, shaft band, blade) and keep only the pixels inside it that are
# not soil-coloured background (soil = dark/medium brown with low red-orange saturation).
sil = Image.new('L', sh.size, 0)
d = ImageDraw.Draw(sil)
d.ellipse((78, 12, 134, 62), fill=255)                                   # handle loop
d.line([(100, 50), (76, 76), (54, 98)], fill=255, width=17)              # shaft
d.polygon([(34, 62), (56, 60), (84, 82), (80, 100), (50, 130), (20, 128), (10, 104)], fill=255)  # blade
sil = np.array(sil) > 0
sil = ndimage.binary_dilation(sil, iterations=2)
# soil pixels: brown but not metal grey / not the red-orange handle / not near-black outline
soil = (r > g + 8) & (g > b + 6) & (lum > 35) & (lum < 125) & ~((r > 170) & (g < 140)) & (sat > 30)
inner = sil & ~soil
# inside the handle loop the soil shows through; the closing below keeps the shaft joined to the blade
mask = ndimage.binary_closing(inner, iterations=2) & sil
mask = ndimage.binary_fill_holes(mask & ~(ndimage.binary_erosion(sil, iterations=1) & soil & False))
lab, n = ndimage.label(mask)
sizes = ndimage.sum(mask, lab, range(1, n + 1))
mask = lab == (1 + int(np.argmax(sizes)))
out = np.zeros((sh.height, sh.width, 4), dtype=np.uint8)
out[..., :3] = np.array(sh)[..., :3]
out[..., 3] = (ndimage.gaussian_filter(mask.astype(float), 0.7) * 255).astype(np.uint8)
save(trim(out), 'env/shovel/shovel_cutout.png')

# ---------------------------------------------------------------- zombie armor (3 damage states each)
for name, boxes in {
    'cone': [(355, 6, 417, 66), (416, 6, 478, 66), (476, 6, 538, 66)],
    'bucket': [(355, 73, 421, 144), (419, 73, 484, 144), (482, 73, 548, 144)],
}.items():
    for i, box in enumerate(boxes, 1):
        a = keep_largest(keyed('zombies/Regular_Zombies.png', box, 'white'))
        save(trim(a), f'zombies/armor/{name}_{i}.png')

# ---------------------------------------------------------------- banners
# "A huge wave...": black background -> transparent, then tight crop.
hw = np.array(load('ui/A_huge_wave_is_approaching.png')).astype(float)
mx = hw[..., :3].max(axis=2)
out = hw.copy()
out[..., 3] = np.clip((mx - 12) / 40.0, 0, 1) * 255
out = out.astype(np.uint8)
ys, xs = np.where(out[..., 3] > 8)
img = Image.fromarray(out).crop((xs.min() - 3, ys.min() - 3, xs.max() + 4, ys.max() + 4))
save(img, 'ui/huge_wave_text.png')

# "FINAL WAVE": keep only the red lettering + its dark-red outline, drop the photo behind it.
fw = np.array(load('ui/final-wave.png')).astype(int)
r, g, b = fw[..., 0], fw[..., 1], fw[..., 2]
text = (r > 3 * g + 30) & (r > 3 * b + 30) & (g < 70) & (b < 60) & (r > 55)
text = ndimage.binary_closing(text, iterations=1)
lab, n = ndimage.label(text, structure=np.ones((3, 3)))
sizes = ndimage.sum(text, lab, range(1, n + 1))
keep = [i + 1 for i, sz in enumerate(sizes) if sz >= 25]
text = np.isin(lab, keep)
alpha = ndimage.gaussian_filter(ndimage.binary_dilation(text, iterations=1).astype(float), 0.6)
out = np.zeros((fw.shape[0], fw.shape[1], 4), dtype=np.uint8)
out[..., :3] = np.array(load('ui/final-wave.png'))[..., :3]
out[..., 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
ys, xs = np.where(out[..., 3] > 8)
img = Image.fromarray(out).crop((xs.min() - 2, ys.min() - 2, xs.max() + 3, ys.max() + 3))
save(img, 'ui/final_wave_text.png')
print('done')
