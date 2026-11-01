"""Seed Bank icons (the Imp is built by imp_parts.py)."""
from PIL import ImageDraw

from charlib import *

def icon(src, name, w):
    im = load_rgba(os.path.join(REFS, src))
    save(scaled(im, w / im.width), f'icons/{name}.png')


icon('Sunflower.webp', 'sunflower', 150)
icon('Peashooter.webp', 'peashooter', 120)
icon('Jalapeno.webp', 'jalapeno', 90)
icon('Squash.webp', 'squash', 120)
# the Wall-nut has no HD reference: its icon is the supplied sheet's healthy nut (see tools/plant_art)
wn = Image.open(os.path.join(ASSETS, 'plants', 'wall-nut', 'wallnut_1.png')).convert('RGBA')
save(wn, 'icons/wallnut.png')
