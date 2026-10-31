# Zombie sprites ("Lilac Shambler" family)

Original art made entirely by `generate_zombies.py`, which draws polygons,
ellipses and capsules on a small 2D rig with Pillow. No screenshot, game sprite
or other image is used as a source, traced or sampled. Re-run it to regenerate
the art:

```
python tools/zombie_art/generate_zombies.py      # writes plants-vs-zombies/assets/zombies/
```

`preview.png` (this folder) is a contact sheet of all three sheets on a green
backdrop. It is kept out of the Godot project on purpose.

## Characters

| Sheet | Core `armor` | Look |
|---|---|---|
| `zombie_regular.png` | 0 NONE | Lilac-grey skin, one bulging red-rimmed eye and one droopy eye, gold tooth and underbite fangs, stitched forehead scar, three wiry hairs, torn mustard cardigan over a teal/cream striped shirt (red and blue mismatched buttons), patched plum trousers, red sneaker plus a broken boot with a toe poking out |
| `zombie_cone.png` | 1 CONE | Same zombie wearing an orange traffic cone with two white reflective bands, a square base flange and a chipped tip |
| `zombie_bucket.png` | 2 BUCKET | Same zombie wearing an upside-down galvanised bucket with embossed rings, rust patches, a dent, a rivet and a loose wire handle; the rim sits low over the eyes |

`headwear_cone.png` and `headwear_bucket.png` are the props that fall off
when Core reports the armor broke.

## Sheet layout

- Frame: **192 × 200 px**, transparent background.
- Pivot: **(80, 190)** in every frame. This is the ground point under the hips; the zombie faces left.
- One row per animation and one column per frame, read left to right. Unused cells are empty.
- Sheet size: 1920 × 1000.

| Row | Animation | Frames | FPS | Loop |
|---|---|---|---|---|
| 0 | `idle`  | 6  | 6  | yes |
| 1 | `walk`  | 8  | 8  | yes |
| 2 | `eat`   | 6  | 8  | yes |
| 3 | `hurt`  | 4  | 12 | no  |
| 4 | `death` | 10 | 10 | no; the last 3 frames fade out |

In game the frames are drawn at scale 0.66 (`ZombieView.DRAW_SCALE`).
`plants-vs-zombies/zombie_view.gd` holds these values as constants; keep the two in sync.
