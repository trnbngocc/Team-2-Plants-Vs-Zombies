"""Shared helpers for building the character art from assets/references/original_pvz.

All outputs are NEW files under plants-vs-zombies/assets/characters/ ; the references and the older
supplied sheets are never modified.
"""
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
ASSETS = os.path.join(REPO, 'plants-vs-zombies', 'assets')
REFS = os.path.join(ASSETS, 'references', 'original_pvz')
OUT = os.path.join(ASSETS, 'characters')
SCRATCH = os.environ.get('PVZ_SCRATCH', os.path.join(REPO, 'build', 'character_art'))
os.makedirs(SCRATCH, exist_ok=True)


def load_rgba(path):
    return Image.open(path).convert('RGBA')


def save(im, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print('wrote', rel, im.size)
    return path


def key_checkerboard(path):
    """zombie_pose.jpg has a checkerboard (white / light grey) and black side bars baked into its
    pixels. Remove exactly those colours where they connect to the border, keep every interior pixel."""
    a = np.array(Image.open(path).convert('RGB')).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    neutral = (np.abs(r - g) <= 3) & (np.abs(g - b) <= 3)
    chk = neutral & ((np.abs(r - 255) <= 4) | (np.abs(r - 239) <= 4) | (np.abs(r - 240) <= 3))
    black = (r < 16) & (g < 16) & (b < 16)
    lab, _ = ndimage.label(chk | black)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    mask = np.isin(lab, list(edge))
    for _ in range(2):   # anti-aliased light fringe next to the removed background
        ring = ndimage.binary_dilation(mask) & ~mask
        light = (np.abs(r - g) <= 10) & (np.abs(g - b) <= 10) & (r > 200)
        mask |= ring & light
    alpha = ~mask
    lab2, n2 = ndimage.label(alpha)
    sizes = ndimage.sum(alpha, lab2, range(1, n2 + 1))
    alpha = np.isin(lab2, [i + 1 for i, s in enumerate(sizes) if s > 2000])
    alpha = ndimage.gaussian_filter(alpha.astype(float), 0.7)
    out = np.dstack([a.astype(np.uint8), (np.clip(alpha * 1.2, 0, 1) * 255).astype(np.uint8)])
    im = Image.fromarray(out, 'RGBA')
    return im.crop(im.getbbox())


def poly_mask(size, polygon):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).polygon(polygon, fill=255)
    return np.array(m) > 0


def cut(im, polygon, extend=22):
    """Split `im` along `polygon` into (part, remainder).

    part      = the pixels inside the polygon.
    remainder = everything else, with its border extended `extend` px into the cut area by inpainting, so
                that the two pieces still overlap a little when the part is moved / rotated at its joint.
    """
    a = np.array(im)
    inside = poly_mask(im.size, polygon)
    solid = a[..., 3] > 8
    part = a.copy()
    part[~inside, 3] = 0
    rem = a.copy()
    rem[inside, 3] = 0
    rem_solid = (rem[..., 3] > 128)
    near = (ndimage.binary_dilation(rem_solid, iterations=extend) & inside & solid) if extend > 0 else np.zeros_like(inside)
    if near.any():
        bgr = cv2.cvtColor(rem[..., :3], cv2.COLOR_RGB2BGR)
        fill = cv2.inpaint(bgr, (near.astype(np.uint8)) * 255, 5, cv2.INPAINT_TELEA)
        fill = cv2.cvtColor(fill, cv2.COLOR_BGR2RGB)
        rem[near, :3] = fill[near]
        rem[near, 3] = 255
    return Image.fromarray(part, 'RGBA'), Image.fromarray(rem, 'RGBA')


def trim(im, pad=0):
    box = im.getbbox()
    if not box:
        return im, (0, 0)
    box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, im.width), min(box[3] + pad, im.height))
    return im.crop(box), (box[0], box[1])


def scaled(im, k):
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


def preview(images, name, bg=(110, 170, 110, 255), pad=10):
    """Contact sheet for visual review (written to the scratch dir, not the project)."""
    w = sum(i.width for i in images) + pad * (len(images) + 1)
    h = max(i.height for i in images) + 2 * pad
    sheet = Image.new('RGBA', (w, h), bg)
    x = pad
    for i in images:
        sheet.alpha_composite(i, (x, pad))
        x += i.width + pad
    path = os.path.join(SCRATCH, name)
    sheet.convert('RGB').save(path)
    return path
