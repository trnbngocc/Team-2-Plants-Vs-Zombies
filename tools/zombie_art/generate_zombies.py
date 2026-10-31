#!/usr/bin/env python3
"""Procedural generator for the original "Lilac Shambler" zombie sprites.

Every pixel is drawn from code below (polygons, ellipses and capsules on a
small 2D rig). No external image, screenshot or game sprite is used as a
source, traced or sampled.

Outputs (into plants-vs-zombies/assets/zombies/ by default):
    zombie_regular.png, zombie_cone.png, zombie_bucket.png   sprite sheets
    headwear_cone.png, headwear_bucket.png                   knocked-off props
    tools/zombie_art/preview.png                             contact sheet (not imported)

Sheet layout: one row per animation (ANIMS order), one column per frame,
FRAME_W x FRAME_H cells, transparent background. Every frame shares the same
pivot PIVOT (ground point under the hips), so frames never jump.

Usage:  python tools/zombie_art/generate_zombies.py [out_dir]
Requires Pillow.
"""

import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw

FRAME_W, FRAME_H = 192, 200
PIVOT = (80, 190)
SS = 4  # supersampling factor for anti-aliasing

# name, frame count, fps, loop
ANIMS = [
    ("idle", 6, 6, True),
    ("walk", 8, 8, True),
    ("eat", 6, 8, True),
    ("hurt", 4, 12, False),
    ("death", 10, 10, False),
]
MAX_FRAMES = max(a[1] for a in ANIMS)

# ---------------------------------------------------------------- palette
OUT = (40, 30, 52)
SKIN = (168, 162, 198)
SKIN_SH = (132, 124, 168)
SKIN_DK = (104, 96, 140)
CARD = (216, 168, 60)
CARD_SH = (172, 126, 40)
STRIPE_A = (58, 138, 140)
STRIPE_B = (234, 226, 200)
PANTS = (106, 82, 112)
PANTS_SH = (80, 60, 88)
PATCH = (146, 170, 86)
SNEAKER = (204, 62, 54)
SOLE = (238, 234, 222)
BOOT = (112, 80, 52)
SOCK = (236, 236, 236)
EYE_W = (246, 240, 210)
EYE_RED = (214, 120, 120)
PUPIL = (28, 22, 30)
MOUTH = (66, 26, 48)
TONGUE = (206, 96, 118)
TOOTH = (238, 232, 200)
GOLD = (244, 196, 58)
BTN_RED = (196, 52, 52)
BTN_BLUE = (60, 92, 190)
HAIR = (52, 44, 60)

CONE = (242, 120, 30)
CONE_SH = (198, 86, 18)
CONE_HI = (255, 170, 90)
BAND = (246, 242, 230)
BAND_SH = (206, 200, 186)

METAL = (150, 164, 172)
METAL_SH = (108, 120, 130)
METAL_HI = (206, 216, 220)
RUST = (162, 86, 44)
RUST_DK = (120, 60, 30)


# ---------------------------------------------------------------- affine helpers
def mat_mul(a, b):
    """a after b."""
    a0, a1, a2, a3, a4, a5 = a
    b0, b1, b2, b3, b4, b5 = b
    return (
        a0 * b0 + a1 * b3, a0 * b1 + a1 * b4, a0 * b2 + a1 * b5 + a2,
        a3 * b0 + a4 * b3, a3 * b1 + a4 * b4, a3 * b2 + a4 * b5 + a5,
    )


def T(x, y):
    return (1, 0, x, 0, 1, y)


def R(deg):
    """Screen-space rotation (y down): positive turns +y toward -x."""
    t = math.radians(deg)
    c, s = math.cos(t), math.sin(t)
    return (c, -s, 0, s, c, 0)


def chain(*ms):
    out = (1, 0, 0, 0, 1, 0)
    for m in ms:
        out = mat_mul(out, m)
    return out


def apply(m, pts):
    return [(m[0] * x + m[1] * y + m[2], m[3] * x + m[4] * y + m[5]) for x, y in pts]


def ellipse_pts(cx, cy, rx, ry, rot=0.0, n=36):
    t = math.radians(rot)
    c, s = math.cos(t), math.sin(t)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = rx * math.cos(a), ry * math.sin(a)
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return pts


def capsule_pts(p1, p2, r1, r2, n=10):
    (x1, y1), (x2, y2) = p1, p2
    ang = math.atan2(y2 - y1, x2 - x1)
    pts = []
    for i in range(n + 1):
        a = ang - math.pi / 2 + math.pi * i / n
        pts.append((x2 + r2 * math.cos(a), y2 + r2 * math.sin(a)))
    for i in range(n + 1):
        a = ang + math.pi / 2 + math.pi * i / n
        pts.append((x1 + r1 * math.cos(a), y1 + r1 * math.sin(a)))
    return pts


# ---------------------------------------------------------------- canvas
class Canvas:
    def __init__(self):
        self.size = (FRAME_W * SS, FRAME_H * SS)
        self.img = Image.new("RGBA", self.size, (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)
        self.G = T(*PIVOT)

    def _px(self, m, pts):
        return [(x * SS, y * SS) for x, y in apply(mat_mul(self.G, m), pts)]

    def poly(self, m, pts, fill, outline=OUT, ow=1.3):
        p = self._px(m, pts)
        if outline is not None and ow > 0:
            w = max(1, int(round(ow * 2 * SS)))
            self.d.line(p + [p[0], p[1]], fill=outline, width=w, joint="curve")
            self.d.polygon(p, fill=outline)
        self.d.polygon(p, fill=fill)

    def ell(self, m, cx, cy, rx, ry, fill, rot=0.0, outline=OUT, ow=1.3):
        self.poly(m, ellipse_pts(cx, cy, rx, ry, rot), fill, outline, ow)

    def cap(self, m, p1, p2, r1, r2, fill, outline=OUT, ow=1.3):
        self.poly(m, capsule_pts(p1, p2, r1, r2), fill, outline, ow)

    def line(self, m, pts, color, w=1.0):
        p = self._px(m, pts)
        width = max(1, int(round(w * SS)))
        self.d.line(p, fill=color, width=width, joint="curve")
        r = width / 2
        for x, y in (p[0], p[-1]):
            self.d.ellipse((x - r, y - r, x + r, y + r), fill=color)

    def clipped(self, m, clip_pts, draw_fn):
        """Draw with draw_fn(canvas) onto a layer masked by clip_pts."""
        saved_img, saved_d = self.img, self.d
        layer = Image.new("RGBA", self.size, (0, 0, 0, 0))
        self.img, self.d = layer, ImageDraw.Draw(layer)
        draw_fn(self)
        self.img, self.d = saved_img, saved_d
        mask = Image.new("L", self.size, 0)
        ImageDraw.Draw(mask).polygon(self._px(m, clip_pts), fill=255)
        layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
        self.img.alpha_composite(layer)

    def snap_to_ground(self):
        """Move everything drawn so far so its lowest solid pixel rests on the pivot line."""
        bbox = self.img.getchannel("A").point(lambda a: 255 if a > 96 else 0).getbbox()
        if bbox is None:
            return
        shift = (PIVOT[1] + 1) * SS - bbox[3]
        moved = Image.new("RGBA", self.size, (0, 0, 0, 0))
        moved.paste(self.img, (0, int(shift)))
        self.img, self.d = moved, ImageDraw.Draw(moved)

    def finish(self, flash=0.0, alpha=1.0):
        img = self.img
        if flash > 0:
            white = Image.new("RGBA", img.size, (255, 250, 240, 255))
            mixed = Image.blend(img, white, min(0.55, flash * 0.55))
            mixed.putalpha(img.getchannel("A"))
            img = mixed
        if alpha < 1.0:
            img.putalpha(img.getchannel("A").point(lambda a: int(a * alpha)))
        return img.resize((FRAME_W, FRAME_H), Image.LANCZOS)


# ---------------------------------------------------------------- pose
DEFAULT_POSE = dict(
    dx=0.0, dy=0.0, hip_drop=0.0, lean=6.0, fall=0.0,
    head_tilt=0.0, jaw=0.1, squint=0.0, xeyes=False,
    legF=4.0, kneeF=6.0, legB=-6.0, kneeB=4.0,
    armF=60.0, elbowF=18.0, armB=45.0, elbowB=15.0,
    hat_rot=0.0, hat_free=None,  # hat_free: (x, y, rot) in body space
    ground=True, flash=0.0, alpha=1.0,
)

HIP_Y = -45.0
THIGH, SHIN = 22.0, 21.0
UPPER_ARM, FOREARM = 16.0, 16.0
NECK = (-5.0, -37.0)
HEAD_OFF = (-5.0, -19.0)
SHOULDER_F = (-8.0, -31.0)
SHOULDER_B = (7.0, -32.0)


def leg_mats(pose, hip, side):
    a = pose["leg" + side]
    k = pose["knee" + side]
    thigh = chain(T(*hip), R(a))
    shin = chain(thigh, T(0, THIGH), R(-k))
    foot = chain(shin, T(0, SHIN), R(-(a - k) * 0.7))
    return thigh, shin, foot


SNEAKER_PTS = [(5, -3), (6, 4), (-12, 5.5), (-15, 3), (-13, -1.5), (-5, -4)]
BOOT_PTS = [(5, -5), (6, 5), (-11, 5.5), (-13, 2), (-11, -2), (-3, -4)]


def build(pose):
    hip = (pose["dx"], HIP_Y + pose["hip_drop"] + pose["dy"])
    mats = {}
    for side in "FB":
        mats["leg" + side] = leg_mats(pose, hip, side)
    if pose["ground"]:
        lowest = -1e9
        for side in "FB":
            foot = mats["leg" + side][2]
            for _, y in apply(foot, [(6, 5.5), (-12, 5.5)]):
                lowest = max(lowest, y)
        shift = -lowest
        hip = (hip[0], hip[1] + shift)
        for side in "FB":
            mats["leg" + side] = leg_mats(pose, hip, side)
    torso = chain(T(*hip), R(-pose["lean"] + pose["fall"]))
    head = chain(torso, T(*NECK), R(-pose["head_tilt"]), T(*HEAD_OFF))
    arms = {}
    for side, sh in (("F", SHOULDER_F), ("B", SHOULDER_B)):
        upper = chain(torso, T(*sh), R(pose["arm" + side]))
        fore = chain(upper, T(0, UPPER_ARM), R(pose["elbow" + side]))
        arms[side] = (upper, fore)
    return hip, torso, head, arms, mats


# ---------------------------------------------------------------- body parts
def draw_leg(cv, mats, front):
    thigh, shin, foot = mats
    base = PANTS if front else PANTS_SH
    cv.cap(thigh, (0, 0), (0, THIGH), 7.5, 6.5, base)
    cv.cap(shin, (0, 0), (0, SHIN - 3), 6.5, 6.0, base)
    if front:
        # Patch with stitches on the front thigh.
        cv.poly(thigh, [(-5, 6), (3, 5), (4, 13), (-4, 14)], PATCH, ow=0.9)
        for y in (7, 10, 13):
            cv.line(thigh, [(-6, y), (-3, y + 0.5)], OUT, 0.7)
        # Rolled cuff and striped sock.
        cv.cap(shin, (0, SHIN - 5), (0, SHIN - 3), 7.2, 7.2, PANTS_SH, ow=1.0)
        cv.cap(shin, (0, SHIN - 1), (0, SHIN + 1), 4.0, 4.0, SOCK, ow=0.9)
        cv.line(shin, [(-4, SHIN), (4, SHIN)], STRIPE_A, 1.2)
        cv.poly(foot, SNEAKER_PTS, SNEAKER)
        cv.poly(foot, [(6, 2.5), (6, 4.5), (-12, 6), (-14.5, 3.5), (-12, 3)], SOLE, ow=0.8)
        cv.line(foot, [(-8, -2), (-4, -3)], SOLE, 0.9)
        cv.line(foot, [(-9, 0), (-5, -1)], SOLE, 0.9)
    else:
        # Torn hem and a battered boot with a toe poking out.
        cv.poly(shin, [(-6, SHIN - 5), (-3, SHIN - 2), (0, SHIN - 5), (3, SHIN - 2),
                       (6, SHIN - 5), (6, SHIN - 1), (-6, SHIN - 1)], PANTS_SH, ow=0.9)
        cv.poly(foot, BOOT_PTS, BOOT)
        cv.ell(foot, -12.5, 1.5, 2.6, 2.4, SKIN_SH, ow=0.8)
        cv.line(foot, [(-2, -3), (1, 3)], OUT, 0.7)


def draw_arm(cv, upper, fore, front):
    sleeve = CARD if front else CARD_SH
    skin = SKIN if front else SKIN_SH
    cv.cap(fore, (0, 0), (0, FOREARM), 4.2, 3.6, skin)
    # Hand: palm and three bony fingers plus thumb.
    hand = chain(fore, T(0, FOREARM + 2))
    for ang, ln in ((-24, 8), (0, 9), (22, 8)):
        f = chain(hand, R(ang))
        cv.cap(f, (0, 2), (0, ln), 1.9, 1.5, skin, ow=1.0)
    cv.cap(chain(hand, R(-70)), (0, 0), (0, 6), 1.8, 1.5, skin, ow=1.0)
    cv.ell(hand, 0, 1.5, 4.2, 4.0, skin, ow=1.0)
    cv.cap(upper, (0, 0), (0, UPPER_ARM + 2), 6.3, 5.4, sleeve)
    # Ragged cuff.
    cv.poly(upper, [(-5.8, UPPER_ARM - 1), (-3, UPPER_ARM + 4), (0, UPPER_ARM + 1),
                    (3, UPPER_ARM + 5), (5.8, UPPER_ARM)], sleeve, ow=1.0)
    if front:
        cv.ell(upper, 2.0, 7, 2.2, 3.4, CARD_SH, outline=None)


TORSO_PTS = [(-14, 2), (-17, -14), (-15, -30), (-8, -38), (6, -38),
             (14, -31), (16, -14), (14, 2)]
HEM_PTS = [(14, 2), (10, 7), (6, 3), (1, 8), (-4, 3), (-9, 8), (-14, 2)]
SHIRT_PTS = [(-15.5, -2), (-17, -14), (-15, -30), (-10, -36), (-5, -36),
             (-7, -20), (-8, 4), (-14, 4)]


def draw_torso(cv, torso):
    cv.poly(torso, TORSO_PTS + HEM_PTS[1:-1], CARD)
    cv.poly(torso, [(6, -36), (14, -31), (16, -14), (14, 2), (10, 6), (8, -10)],
            CARD_SH, outline=None)

    def stripes(c):
        c.poly(torso, SHIRT_PTS, STRIPE_B, outline=None)
        for y in range(-38, 6, 6):
            c.poly(torso, [(-20, y), (0, y - 1), (0, y + 2.6), (-20, y + 3.6)],
                   STRIPE_A, outline=None)

    cv.clipped(torso, SHIRT_PTS, stripes)
    cv.line(torso, [(-5, -36), (-7, -20), (-8, 4)], OUT, 1.3)
    cv.line(torso, [(-15.5, -2), (-17, -14), (-15, -30)], OUT, 1.3)
    cv.ell(torso, -5.2, -24, 2.2, 2.2, BTN_RED, ow=0.8)
    cv.ell(torso, -6.2, -12, 2.0, 2.4, BTN_BLUE, ow=0.8)
    # Pocket with a torn corner.
    cv.poly(torso, [(0, -14), (9, -14), (9, -6), (3, -5), (0, -8)], CARD_SH, ow=0.9)
    cv.line(torso, [(0, -12.5), (9, -12.5)], OUT, 0.6)
    # Collar.
    cv.poly(torso, [(-8, -38), (-2, -33), (6, -38), (2, -40), (-5, -40)], CARD_SH, ow=1.0)


def draw_head(cv, head, pose, armor):
    if armor == "bucket" and pose["hat_free"] is None:
        # Wire handle dangling behind the head.
        cv.line(head, [(24, -16), (26, -2), (20, 14), (8, 20), (-2, 12)], OUT, 2.2)
        cv.line(head, [(24, -16), (26, -2), (20, 14), (8, 20), (-2, 12)], METAL_SH, 1.0)

    # Ear (with a notch) behind the cranium edge.
    cv.ell(head, 12, 1, 5, 7, SKIN_SH, ow=1.1)
    cv.ell(head, 12.5, 1.5, 2.2, 3.6, SKIN_DK, outline=None)
    cv.poly(head, [(14.5, -5), (17.5, -6), (16.5, -2)], SKIN_SH, outline=None)

    # Cranium (slightly lumpy egg).
    skull = ellipse_pts(0, -2, 21.5, 23.5, 0, 44)
    skull = [(x - 1.5 if y < -14 and x < 0 else x, y) for x, y in skull]
    cv.poly(head, skull, SKIN)
    cv.ell(head, 9, -4, 9, 15, SKIN_SH, rot=-8, outline=None)
    cv.ell(head, -8, -16, 6, 3.5, (190, 186, 216), rot=-20, outline=None)

    # Hair: three wiry strands.
    if armor == "none" or pose["hat_free"] is not None:
        cv.line(head, [(-2, -24), (-5, -32), (-1, -36)], HAIR, 1.6)
        cv.line(head, [(3, -24), (4, -33), (9, -35)], HAIR, 1.6)
        cv.line(head, [(7, -23), (12, -29)], HAIR, 1.6)

    # Stitched scar across the forehead.
    cv.line(head, [(3, -18), (14, -9)], SKIN_DK, 1.2)
    for t in (0.2, 0.5, 0.8):
        x, y = 3 + 11 * t, -18 + 9 * t
        cv.line(head, [(x - 2, y + 2.2), (x + 2, y - 2.2)], OUT, 0.8)

    # Rotten cheek spot.
    cv.ell(head, -4, 8, 4, 3, SKIN_SH, outline=None)
    cv.ell(head, -3, 8.5, 1.4, 1.1, SKIN_DK, outline=None)

    # Mouth cavity, upper teeth (one gold), tongue and the hinged jaw.
    jaw = chain(head, T(8, 8), R(-pose["jaw"] * 22), T(-8, -8))
    cv.poly(head, [(-20, 5), (-21, 13), (-8, 18), (8, 12), (6, 6)], MOUTH, ow=1.0)
    cv.ell(jaw, -8, 13, 6, 3, TONGUE, outline=None)
    for x, col in ((-17, TOOTH), (-12.5, GOLD), (-8, TOOTH), (-3.5, TOOTH)):
        cv.poly(head, [(x - 2, 5.5), (x + 2, 5.5), (x + 1.5, 9.5), (x - 1.5, 9.5)], col, ow=0.7)
    jaw_pts = [(-21, 9), (-23, 15), (-19, 23), (-7, 26), (5, 21), (9, 11), (6, 9),
               (-6, 14)]
    cv.poly(jaw, jaw_pts, SKIN)
    cv.ell(jaw, 0, 18, 5, 4, SKIN_SH, outline=None)
    # Underbite: two crooked lower fangs.
    cv.poly(jaw, [(-19, 12), (-15.5, 12.5), (-16.5, 6.5)], TOOTH, ow=0.7)
    cv.poly(jaw, [(-11, 13.5), (-8, 13.5), (-8.5, 8.5)], TOOTH, ow=0.7)

    # Nose bump with nostril.
    cv.ell(head, -21, 0, 3.6, 3.2, SKIN, ow=1.1)
    cv.ell(head, -21.5, 1.2, 1.1, 0.9, OUT, outline=None)

    # Eyes.
    if pose["xeyes"]:
        for cx, cy, r in ((-12, -6, 5), (2, -8, 3.5)):
            cv.line(head, [(cx - r, cy - r), (cx + r, cy + r)], OUT, 1.6)
            cv.line(head, [(cx - r, cy + r), (cx + r, cy - r)], OUT, 1.6)
    elif pose["squint"] >= 0.75:
        cv.line(head, [(-18, -9), (-12, -5), (-17, -2)], OUT, 1.6)
        cv.line(head, [(-1, -10), (4, -7), (0, -5)], OUT, 1.4)
    else:
        sq = pose["squint"]
        # Big bulging front eye with red rim.
        cv.ell(head, -12, -6, 8.2, 9 * (1 - 0.5 * sq), EYE_RED, ow=1.2)
        cv.ell(head, -12, -6, 6.8, 7.6 * (1 - 0.5 * sq), EYE_W, outline=None)
        cv.ell(head, -15, -5, 2.9, 3.2 * (1 - 0.4 * sq), PUPIL, outline=None)
        cv.ell(head, -16, -6.4, 0.9, 0.9, (255, 255, 255), outline=None)
        # Small droopy back eye.
        cv.ell(head, 2.5, -7, 6, 4.4, SKIN_DK, outline=None)
        cv.ell(head, 2, -8, 4.6, 4.0, EYE_W, ow=1.0)
        cv.ell(head, 0.5, -7.4, 1.6, 1.8, PUPIL, outline=None)
        cv.poly(head, [(-3, -12.5), (7, -12.5), (7, -8 + 2 * sq), (-3, -7.5 + 2 * sq)],
                SKIN_SH, ow=1.0)
    # Brows.
    cv.line(head, [(-20, -17), (-13, -20), (-6, -17)], OUT, 2.0)
    cv.line(head, [(-2, -14), (7, -12)], OUT, 1.8)


# ---------------------------------------------------------------- headwear
def draw_cone(cv, m):
    """Traffic-style cone, local origin at the middle of its base."""
    cv.poly(m, [(-17, 0), (-3.5, -40), (-1.5, -43), (1, -42), (3.5, -40), (17, 0)], CONE)
    cv.poly(m, [(6, 0), (2.5, -40), (3.5, -40), (17, 0)], CONE_SH, outline=None)
    cv.poly(m, [(-12, -6), (-3, -36), (-1.5, -36), (-9, -6)], CONE_HI, outline=None)
    for y0, y1 in ((-27, -21), (-15, -9)):
        w0 = 17 - 13.5 * (-y0) / 40
        w1 = 17 - 13.5 * (-y1) / 40
        cv.poly(m, [(-w1, y1), (-w0, y0), (w0, y0), (w1, y1)], BAND, ow=0.9)
        cv.poly(m, [(w1 * 0.4, y1), (w0 * 0.4, y0), (w0, y0), (w1, y1)], BAND_SH, outline=None)
    # Chipped tip and scuffs.
    cv.poly(m, [(-1.5, -43), (1, -42), (0.5, -39), (-1, -40)], CONE_SH, outline=None)
    cv.line(m, [(-8, -4), (-5, -6)], CONE_SH, 0.9)
    cv.line(m, [(9, -32), (7, -29)], OUT, 0.7)
    # Square base flange.
    cv.poly(m, [(-23, 0), (-21, -4), (21, -4), (23, 0), (22, 4), (-22, 4)], CONE_SH, ow=1.2)
    cv.line(m, [(-20, -2), (20, -2)], CONE, 1.0)


def draw_bucket(cv, m):
    """Upside-down galvanised bucket, local origin at the middle of the rim."""
    cv.poly(m, [(-26, 0), (-20, -32), (20, -32), (26, 0)], METAL)
    cv.poly(m, [(10, 0), (8, -32), (20, -32), (26, 0)], METAL_SH, outline=None)
    cv.poly(m, [(-19, -2), (-15, -30), (-11, -30), (-14, -2)], METAL_HI, outline=None)
    # Embossed rings.
    for y in (-11, -22):
        w = 26 - 6 * (-y) / 32
        cv.line(m, [(-w + 0.5, y), (w - 0.5, y)], OUT, 1.0)
        cv.line(m, [(-w + 1, y + 1.6), (w - 1, y + 1.6)], METAL_HI, 0.9)
    # Rust patches.
    cv.poly(m, [(4, -30), (12, -31), (14, -25), (9, -21), (5, -24)], RUST, outline=None)
    cv.ell(m, 9, -26, 1.6, 1.3, RUST_DK, outline=None)
    cv.poly(m, [(-22, -4), (-16, -6), (-12, -2), (-20, -1)], RUST, outline=None)
    # Dent near the top front.
    cv.ell(m, -8, -27, 5, 2.6, METAL_SH, rot=-10, outline=None)
    cv.line(m, [(-12, -25.5), (-4, -24.5)], METAL_HI, 0.8)
    # Flat closed bottom (now the top) and rolled rim.
    cv.poly(m, [(-21, -32), (-18, -36), (18, -36), (21, -32)], METAL_SH, ow=1.2)
    cv.poly(m, [(-28, 0), (-27, -4), (27, -4), (28, 0), (27, 3), (-27, 3)], METAL_SH, ow=1.2)
    cv.line(m, [(-26, -1.5), (26, -1.5)], METAL_HI, 0.9)
    # Rivet where the handle used to attach.
    cv.ell(m, 22, -14, 2.2, 2.2, METAL_HI, ow=0.9)


HAT_SEAT = {"cone": (2.0, -18.0, 10.0), "bucket": (1.0, -11.0, -6.0)}


def draw_hat(cv, head, pose, armor):
    if armor == "none":
        return
    painter = draw_cone if armor == "cone" else draw_bucket
    if pose["hat_free"] is not None:
        x, y, rot = pose["hat_free"]
        painter(cv, chain(T(x, y), R(rot)))
        return
    sx, sy, srot = HAT_SEAT[armor]
    painter(cv, chain(head, T(sx, sy), R(srot + pose["hat_rot"])))


# ---------------------------------------------------------------- frame
def render(armor, **kw):
    pose = dict(DEFAULT_POSE)
    pose.update(kw)
    _, torso, head, arms, legs = build(pose)
    cv = Canvas()
    draw_arm(cv, *arms["B"], front=False)
    draw_leg(cv, legs["legB"], front=False)
    draw_leg(cv, legs["legF"], front=True)
    draw_torso(cv, torso)
    # Neck.
    cv.cap(torso, (NECK[0], NECK[1] + 4), (NECK[0] - 2, NECK[1] - 8), 5.5, 5, SKIN_SH)
    draw_head(cv, head, pose, armor)
    if pose["hat_free"] is None:
        draw_hat(cv, head, pose, armor)
    draw_arm(cv, *arms["F"], front=True)
    if not pose["ground"]:
        cv.snap_to_ground()
    if pose["hat_free"] is not None:
        draw_hat(cv, head, pose, armor)
    return cv.finish(pose["flash"], pose["alpha"])


# ---------------------------------------------------------------- animations
def walk_pose(t):
    ph = 2 * math.pi * t
    return dict(
        legF=24 * math.sin(ph), kneeF=6 + 30 * max(0.0, math.cos(ph)),
        legB=-16 * math.sin(ph), kneeB=6 + 22 * max(0.0, -math.cos(ph)),
        lean=9 + 2 * math.sin(2 * ph),
        head_tilt=5 * math.sin(ph + 0.6),
        armF=80 + 7 * math.sin(ph + 1.0), elbowF=10 + 6 * math.sin(ph),
        armB=72 + 7 * math.sin(ph + 2.6), elbowB=16,
        jaw=0.18 + 0.15 * math.sin(2 * ph),
        hat_rot=3 * math.sin(ph + 1.2),
    )


def idle_pose(t):
    ph = 2 * math.pi * t
    return dict(
        legF=6, kneeF=8, legB=-7, kneeB=5,
        lean=5 + 2 * math.sin(ph), hip_drop=1.5 * (1 - math.cos(ph)) / 2,
        head_tilt=4 * math.sin(ph), armF=52 + 7 * math.sin(ph + 0.5), elbowF=22,
        armB=38 + 5 * math.sin(ph + 1.0), elbowB=18,
        jaw=0.12 + 0.12 * math.sin(ph), hat_rot=1.5 * math.sin(ph + 0.8),
    )


def eat_pose(t):
    ph = 2 * math.pi * t
    s = math.sin(ph)
    return dict(
        legF=16, kneeF=16, legB=-13, kneeB=6,
        lean=17 + 6 * s, head_tilt=12 + 11 * s,
        jaw=0.55 - 0.5 * s,
        armF=74 + 14 * math.sin(ph + 0.4), elbowF=32 + 10 * s,
        armB=66 + 10 * math.sin(ph + 1.2), elbowB=30,
        hat_rot=-3 * s,
    )


def hurt_pose(i):
    base = walk_pose(0.0)
    steps = [
        dict(flash=0.9, lean=-4, head_tilt=-15, squint=1.0, dx=3, jaw=0.7, armF=100, armB=88),
        dict(flash=0.5, lean=-1, head_tilt=-10, squint=1.0, dx=2, jaw=0.5, armF=92, armB=82),
        dict(flash=0.2, lean=4, head_tilt=-4, squint=0.5, dx=1, jaw=0.3, armF=86),
        dict(flash=0.0, lean=8, head_tilt=0, squint=0.0, dx=0, jaw=0.2),
    ]
    base.update(steps[i])
    return base


def death_pose(i, armor):
    # Knocked-off headwear flight path in body space: (x, y, rotation).
    if armor == "cone":
        hat_path = [None, (-4, -130, -10), (-20, -142, 60), (-36, -122, 140),
                    (-50, -84, 220), (-58, -40, 300)]
        rest = (-62, -23, 450)
    else:
        hat_path = [None, (-4, -120, -30), (-20, -132, -70), (-34, -112, -110),
                    (-44, -78, -140), (-50, -48, -165)]
        rest = (-50, -36, -180)
    frames = [
        dict(flash=0.4, lean=-6, head_tilt=-12, jaw=1.0, squint=1.0,
             armF=125, elbowF=10, armB=110, legF=6, kneeF=8),
        dict(lean=12, head_tilt=14, jaw=0.8, squint=1.0, armF=60, elbowF=5,
             armB=40, legF=10, kneeF=26, legB=-4, kneeB=22),
        dict(lean=22, head_tilt=20, jaw=0.9, xeyes=True, hip_drop=10, armF=30,
             armB=20, legF=22, kneeF=60, legB=6, kneeB=55),
        dict(ground=False, lean=10, fall=25, head_tilt=10, jaw=1.0, xeyes=True,
             hip_drop=24, armF=60, armB=40, legF=55, kneeF=80, legB=40, kneeB=75),
        dict(ground=False, lean=0, fall=55, head_tilt=-5, jaw=1.0, xeyes=True,
             hip_drop=30, armF=110, armB=90, legF=70, kneeF=70, legB=60, kneeB=60),
        dict(ground=False, lean=0, fall=86, head_tilt=-10, jaw=0.9, xeyes=True,
             hip_drop=31, armF=150, elbowF=-10, armB=130, legF=80, kneeF=55,
             legB=72, kneeB=40),
        dict(ground=False, lean=0, fall=80, head_tilt=-6, jaw=0.7, xeyes=True,
             hip_drop=31, armF=140, elbowF=-5, armB=125, legF=78, kneeF=50,
             legB=70, kneeB=36),
    ]
    lying = dict(frames[6])
    frames.append(dict(lying, alpha=0.75))
    frames.append(dict(lying, alpha=0.45))
    frames.append(dict(lying, alpha=0.15))
    pose = frames[i]
    if armor != "none" and i >= 1:
        pose["hat_free"] = hat_path[i] if i < len(hat_path) else rest
    return pose


def frame_pose(anim, i, n, armor):
    if anim == "idle":
        return idle_pose(i / n)
    if anim == "walk":
        return walk_pose(i / n)
    if anim == "eat":
        return eat_pose(i / n)
    if anim == "hurt":
        return hurt_pose(i)
    return death_pose(i, armor)


def build_sheet(armor):
    sheet = Image.new("RGBA", (FRAME_W * MAX_FRAMES, FRAME_H * len(ANIMS)), (0, 0, 0, 0))
    for row, (anim, n, _fps, _loop) in enumerate(ANIMS):
        for i in range(n):
            img = render(armor, **frame_pose(anim, i, n, armor))
            sheet.alpha_composite(img, (i * FRAME_W, row * FRAME_H))
    return sheet


def build_headwear(armor):
    cv = Canvas()
    cv.G = T(FRAME_W / 2, FRAME_H / 2 + 20)
    (draw_cone if armor == "cone" else draw_bucket)(cv, (1, 0, 0, 0, 1, 0))
    img = cv.finish()
    return img.crop(img.getbbox())


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.join(here, "..", "..", "plants-vs-zombies", "assets", "zombies")
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else default_out)
    os.makedirs(out, exist_ok=True)
    sheets = {}
    for armor in ("regular", "cone", "bucket"):
        key = "none" if armor == "regular" else armor
        sheets[armor] = build_sheet(key)
        sheets[armor].save(os.path.join(out, f"zombie_{armor}.png"))
        print("wrote", f"zombie_{armor}.png", sheets[armor].size)
    for armor in ("cone", "bucket"):
        build_headwear(armor).save(os.path.join(out, f"headwear_{armor}.png"))
    # Contact sheet on a lawn-green backdrop for quick review.
    w, h = sheets["regular"].size
    prev = Image.new("RGBA", (w, h * 3), (120, 170, 90, 255))
    for k, armor in enumerate(("regular", "cone", "bucket")):
        prev.alpha_composite(sheets[armor], (0, k * h))
    prev.convert("RGB").save(os.path.join(here, "preview.png"))
    print("done ->", out)


if __name__ == "__main__":
    main()
