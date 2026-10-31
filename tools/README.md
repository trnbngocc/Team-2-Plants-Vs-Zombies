# Asset tools

Every processed asset in `plants-vs-zombies/assets/` is produced by a script in
this folder from a supplied source file. The source files are never modified.

| Tool | Source → output |
|---|---|
| `zombie_art/generate_zombies.py` | (procedural, original art) → `assets/zombies/*.png`. See `zombie_art/README.md` |
| `lawn_art/make_lawn.py` | `grid.jpg` → `assets/lawn/lawn_game.jpg`. See `lawn_art/README.md` |
| `ui_art/prepare_ui_assets.py` | `assets/ui/buttons.jpg` → `assets/ui/buttons/*.png`; `assets/projectiles/shoot.jpg` → `assets/projectiles/pea_projectile.png` |
| `ui_art/make_menu_background.py` | `assets/menu.jpg` → `assets/ui/menu_background.jpg` |
| `peashooter/build_peashooter.py` | `assets/plants/peashooter/168191.png` → `parts/*.png`, `layout.json`, `peashooter_layout.gd`, `peashooter/mockup.png` |
| `audio/fmp4_to_adts.py` + `audio/convert_music.m` | `assets/audio/{menu,gameplay_music}.m4a` → `.ogg` |

## Buttons

`buttons.jpg` is 1199 × 661, a JPG with a white background. Its buttons have one
state each, with no hover or pressed versions. Four were extracted (three are used); their regions are
x0, y0, x1, y1 in `buttons.jpg`:

| File | Region | Used for |
|---|---|---|
| `quit.png` (318 × 139) | 34, 20, 352, 159 | Quit: menu (exit app), pause (back to menu), Victory / Game Over (exit app) |
| `pause.png` (338 × 139) | 37, 502, 376, 641 | HUD Pause |
| `play.png` (166 × 139) | 420, 502, 586, 641 | Play (menu) and Resume (pause) |
| `restart.png` (166 × 138) | 220, 178, 386, 317 | not used any more (Play Again was removed) |

To make the background transparent, near-white pixels connected to the crop
border are cleared. The dark outline stops that fill, so the button art itself is
not changed. Hover and pressed feedback is only a tint applied in Godot
(`stone_button.gd`).

## Projectile

`shoot.jpg` is 98 × 110 and shows a green sphere on white. The white background
is removed, the image is cropped to the sphere (85 × 85), and an anti-aliased
circular alpha mask is applied.

## Menu background

`menu.jpg` is 1200 × 758. As requested, only the publisher badge in the
bottom-right corner (ellipse 1060, 606 – 1214, 772) is removed. It is filled by
diffusion from the surrounding background. The game title artwork is kept.

## Peashooter

`168191.png` is 463 × 325 RGBA. It is an exploded parts sheet with label text
baked in. Each part is cut by its own alpha mask, so the label text is never
included. There are 22 parts:

- the head;
- two mouth tubes: the narrow one is the resting pose, the wide flared one is the firing pose;
- open and closed eye overlays;
- 7 crest leaves;
- 2 stem pieces;
- 8 base leaves.

The sheet gives no assembly positions. Loose pieces were pulled back toward
their group centre, plus a few hand nudges. The user approved the result
(`peashooter/mockup.png`).

## Audio

Mappings follow the supplied file names. The clips were measured with MATLAB
(duration, onset, envelope) but not listened to. Godot plays MP3 and OGG; the
`.m4a` files are fragmented MP4 (DASH) AAC, which neither Godot nor MATLAB opens.
`fmp4_to_adts.py` repackages the AAC frames, then MATLAB decodes them and writes
OGG copies.

| Event | File | Starts at |
|---|---|---|
| UI button click (stone buttons and Seed Bank plant cards) | `button_click.mp3` | 0.72 s |
| Successful plant placement (`plant_placed` signal) | `planting.mp3` (supplied later; 0.8 s, mono) | 0.00 s |
| Peashooter projectile hits a zombie (`projectile_hit` signal; nothing on launch or miss) | `peashooter.mp3` | 0.89 s |
| Zombie eating (loop while any zombie eats) | `zombie_eating.mp3` | 1.20 s |
| Victory | `win.mp3` | 0.13 s |
| Chili explosion | `chilli_explosion.mp3` | 0.13 s |
| Sun collected | `sun_collect.mp3` | 0.03 s |
| Defeat | `lose.mp3` | 0.37 s |
| Once per game, 3 s (game time) before the first zombie spawns | `The zombies are coming Plants vs Zombies Sound Effect.mp3` | 1.10 s |
| Main Menu music | `menu.ogg` (from `menu.m4a`, 86 s) | 0 |
| Gameplay music: from Play, through preparation and battle | `gameplay_music.ogg` (from `gameplay_music.m4a`, 147 s) | 0 |

The "Starts at" offsets skip leading silence when the clip is played; the files
themselves are not trimmed. `choose_plant.m4a` is not used, as requested.
