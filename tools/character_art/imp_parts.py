"""The standalone Imp.

The reference only shows the Imp riding the Gargantuar (half hidden in the barrel), so a walking Imp needs
a full body:
  head.png    the real Imp head cut from original_pvz/Gargantuar.webp (shirt, barrel, rope and hand removed)
  body.png    red shirt + shorts, drawn at 6x and shrunk, sampled colours from the reference shirt
  arm.png     a skinny skin-coloured arm with a hand
  leg.png     bare leg with shorts hem; shoe.png  small brown shoe (same palette as the regular zombie)
All layers share one origin convention: see IMP_* constants in puppet_zombie.gd.
"""
import cv2
from PIL import ImageDraw

from charlib import *

HALF = 0.6
garg = load_rgba(os.path.join(REFS, 'Gargantuar.webp'))
a = np.array(garg)
H, W = a.shape[:2]

# ------------------------------------------------------------------ head
HEAD_POLY = [(428, 0), (534, 0), (538, 22), (528, 54), (512, 72), (506, 90), (492, 106), (452, 110), (440, 100), (434, 70), (426, 40)]
zone = poly_mask((W, H), HEAD_POLY) & (a[..., 3] > 128)
hsv = cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2HSV)
h_, s_, v_ = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
xs_ = np.arange(W)[None, :]
ys_ = np.arange(H)[:, None]
# colour removal only where the shirt / barrel / rope / hand are (right and below the face), never over the mouth
shirt = (((h_ < 9) | (h_ > 168)) & (s_ > 120) & (v_ > 100)) & (xs_ >= 496)
barrel = (np.abs(a[..., :3].astype(int).max(axis=2) - a[..., :3].astype(int).min(axis=2)) < 22) & (v_ < 140) & (ys_ > 84) & (xs_ >= 490)
rope = (h_ >= 8) & (h_ <= 24) & (s_ > 80) & (v_ > 90) & (ys_ > 96)
below_chin = (ys_ > 100) & (xs_ < 482)          # the Imp's small hand gripping the rope
keep = zone & ~shirt & ~barrel & ~rope & ~below_chin
keep = ndimage.binary_opening(keep, iterations=1)
lab, n = ndimage.label(keep)
sizes = ndimage.sum(keep, lab, range(1, n + 1))
keep = lab == (1 + int(np.argmax(sizes)))
keep = ndimage.binary_fill_holes(keep)
hd = a.copy()
hd[..., 3] = (ndimage.gaussian_filter(keep.astype(float), 0.6) * 255).astype(np.uint8)
head, head_off = trim(Image.fromarray(hd, 'RGBA'))
head = scaled(head, HALF)
save(head, 'imp/head.png')

# sample the skin colour for the limbs
skin = np.median(a[(keep) & (h_ >= 25) & (h_ <= 50) & (s_ > 25) & (s_ < 110) & (v_ > 90)][:, :3], axis=0).astype(int)
red = np.median(a[shirt & (a[..., 3] > 200)][:, :3], axis=0).astype(int)
print('skin', skin, 'red', red)
SK = tuple(int(x) for x in skin) + (255,)
SK_D = tuple(int(x * 0.78) for x in skin) + (255,)
RD = tuple(int(x) for x in red) + (255,)
RD_D = tuple(int(x * 0.72) for x in red) + (255,)
RD_L = tuple(min(255, int(x * 1.25)) for x in red) + (255,)
LINE = (24, 14, 14, 255)
K = 6


def canvas(w, h):
    return Image.new('RGBA', (w * K, h * K), (0, 0, 0, 0))


def finish(im, w, h):
    return im.resize((w, h), Image.LANCZOS)


# ------------------------------------------------------------------ body (shirt + shorts), 40 x 44
BW, BH = 40, 44
im = canvas(BW, BH)
d = ImageDraw.Draw(im)
shirt_poly = [(6, 2), (34, 2), (38, 10), (35, 30), (37, 36), (30, 34), (24, 38), (17, 34), (10, 38), (4, 33), (6, 22), (2, 10)]
d.polygon([(x * K, y * K) for x, y in shirt_poly], fill=LINE)
inner = [(8, 5), (32, 5), (35, 11), (32, 29), (34, 33), (29, 31), (24, 34), (18, 31), (11, 34), (7, 30), (9, 21), (5, 11)]
d.polygon([(x * K, y * K) for x, y in inner], fill=RD)
d.polygon([(x * K, y * K) for x, y in [(8, 5), (20, 5), (14, 22), (7, 20), (5, 11)]], fill=RD_L)      # highlight
d.polygon([(x * K, y * K) for x, y in [(26, 12), (35, 11), (32, 29), (24, 30)]], fill=RD_D)           # shade
# little neck opening
d.ellipse((12 * K, 0, 28 * K, 9 * K), fill=SK_D, outline=LINE, width=K)
# shorts
d.rounded_rectangle((7 * K, 30 * K, 33 * K, 43 * K), radius=3 * K, fill=LINE)
d.rounded_rectangle((9 * K, 31 * K, 31 * K, 42 * K), radius=2 * K, fill=(70, 78, 120, 255))
save(finish(im, BW, BH), 'imp/body.png')

# ------------------------------------------------------------------ arm: 11 x 36 (shoulder at the top)
AW, AH = 11, 36
im = canvas(AW, AH)
d = ImageDraw.Draw(im)
d.rounded_rectangle((1 * K, 0, 9 * K, 27 * K), radius=4 * K, fill=LINE)
d.rounded_rectangle((2 * K, 1 * K, 8 * K, 26 * K), radius=3 * K, fill=SK)
d.rounded_rectangle((2 * K, 1 * K, 4 * K, 24 * K), radius=K, fill=tuple(min(255, c + 22) for c in SK[:3]) + (255,))
d.ellipse((0, 24 * K, 11 * K, 35 * K), fill=LINE)                    # hand
d.ellipse((1 * K, 25 * K, 10 * K, 34 * K), fill=SK)
save(finish(im, AW, AH), 'imp/arm.png')

# ------------------------------------------------------------------ leg: 11 x 26 (hip at the top), shoe 24 x 11
LW, LH = 11, 26
im = canvas(LW, LH)
d = ImageDraw.Draw(im)
d.rounded_rectangle((1 * K, 0, 10 * K, 25 * K), radius=3 * K, fill=LINE)
d.rounded_rectangle((2 * K, 0, 9 * K, 24 * K), radius=2 * K, fill=SK)
d.rounded_rectangle((2 * K, 0, 4 * K, 22 * K), radius=K, fill=tuple(min(255, c + 22) for c in SK[:3]) + (255,))
save(finish(im, LW, LH), 'imp/leg.png')

SW, SH = 24, 11
im = canvas(SW, SH)
d = ImageDraw.Draw(im)
d.rounded_rectangle((0, 0, SW * K - 1, SH * K - 1), radius=5 * K, fill=LINE)
d.rounded_rectangle((2 * K, 2 * K, (SW - 2) * K, (SH - 1) * K), radius=4 * K, fill=(112, 72, 40, 255))
d.rounded_rectangle((4 * K, 3 * K, (SW - 6) * K, 5 * K), radius=K, fill=(150, 100, 58, 255))
save(finish(im, SW, SH), 'imp/shoe.png')

# review sheet: head over body, arms and legs in place
sheet = Image.new('RGBA', (170, 190), (0, 0, 0, 0))
sheet.alpha_composite(load_rgba(os.path.join(OUT, 'imp/leg.png')), (50, 105))
sheet.alpha_composite(load_rgba(os.path.join(OUT, 'imp/leg.png')), (76, 105))
sheet.alpha_composite(load_rgba(os.path.join(OUT, 'imp/shoe.png')), (42, 128))
sheet.alpha_composite(load_rgba(os.path.join(OUT, 'imp/shoe.png')), (70, 128))
sheet.alpha_composite(load_rgba(os.path.join(OUT, 'imp/body.png')), (45, 62))
sheet.alpha_composite(load_rgba(os.path.join(OUT, 'imp/arm.png')), (33, 66))
sheet.alpha_composite(head, (30, 10))
sheet.alpha_composite(load_rgba(os.path.join(OUT, 'imp/arm.png')), (82, 68))
preview([scaled(sheet, 3)], 'imp_preview.png')
print('head', head.size, 'offset', head_off)
