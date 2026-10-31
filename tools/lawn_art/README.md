# In-game lawn background

`make_lawn.py` builds `plants-vs-zombies/assets/lawn/lawn_game.jpg` from
`plants-vs-zombies/grid.jpg`. The source file is never modified.

| | Size | Notes |
|---|---|---|
| `grid.jpg` (source) | 886 × 514 (aspect 1.724) | Lawn at x 213–853, y 61–494 (640 × 433 source px) |
| `lawn_game.jpg` | 2252 × 1508 | Source upscaled ×2 (Lanczos), plus a 240 px (= 120 source px) soft margin on every side |

The original picture area is not cropped; it is only upscaled. The margin is
edge-extended, blurred and darkened toward the outside. It only shows when the
window's shape exposes space beyond the original picture.

## Painted cell edges

Measured on `grid.jpg` from the light/dark checker, in source px:

- Columns: 213, 290, 350, 425, 492, 563, 632, 695, 767, 853
- Rows: 61, 154, 234, 327, 401, 494

`board.tscn` places the 45 cell buttons at these edges × 1.275, the reference
scale used by the old 1152×648 layout. Each edge is rounded to a whole pixel
because `GridContainer` truncates fractional child positions; the rounding error
is at most 0.4 source px.

## Layout

`board.gd` scales the `Field` node (lawn image plus cells) uniformly at
runtime. The scale is the largest that keeps all 9 × 5 cells below the 96 px
HUD, with 110 reference px of yard on the left and 70 on the right for zombie
spawns. `main_game.gd` gives its entity layer the same transform, so plants,
zombies, bullets and sun scale and stay aligned with the cells.
