@tool
class_name StoneTitle
extends Control
## stone_title.gd - big pixel-block title ("VICTORY", "GAME OVER", "PAUSED")
## drawn in the visual language of the supplied stone buttons:
## pale stone face, a lighter top edge, a thick darker bottom slab and a dark
## navy outline, built from square "pixels" like the buttons' lettering.
## Colours are sampled from assets/ui/buttons/*.png.

const FACE := Color("9fbbd0")
const HIGHLIGHT := Color("b8daf5")
const SLAB := Color("3c5b77")
const OUTLINE := Color("2b3c4c")

# 5x7 pixel glyphs (only the letters the game needs).
const GLYPHS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"G": ["01111", "10000", "10000", "10011", "10001", "10001", "01111"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	" ": ["000", "000", "000", "000", "000", "000", "000"],
}

@export var text := "VICTORY":
	set(v):
		text = v.to_upper()
		queue_redraw()
@export var pixel := 10.0:   # size of one glyph pixel
	set(v):
		pixel = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _text_size() -> Vector2:
	var cols := 0
	for ch in text:
		cols += (GLYPHS.get(ch, GLYPHS[" "])[0] as String).length() + 1
	return Vector2(maxi(cols - 1, 0), 7) * pixel + Vector2(0, pixel * 0.6)


func _draw() -> void:
	var cells: Array[Vector2i] = []
	var col := 0
	for ch in text:
		var g: Array = GLYPHS.get(ch, GLYPHS[" "])
		for y in 7:
			var row: String = g[y]
			for x in row.length():
				if row[x] == "1":
					cells.append(Vector2i(col + x, y))
		col += (g[0] as String).length() + 1
	var origin := (size - _text_size()) * 0.5
	var p := pixel
	var slab := p * 0.6          # thickness of the darker bottom slab
	var ol := maxf(2.0, p * 0.28)   # outline width
	# outline (behind everything, covers face + slab)
	for c in cells:
		draw_rect(Rect2(origin + Vector2(c) * p - Vector2(ol, ol), Vector2(p, p + slab) + Vector2(ol, ol) * 2), OUTLINE)
	# bottom slab, then the face, then the top highlight
	for c in cells:
		draw_rect(Rect2(origin + Vector2(c) * p + Vector2(0, slab), Vector2(p, p)), SLAB)
	for c in cells:
		draw_rect(Rect2(origin + Vector2(c) * p, Vector2(p, p)), FACE)
	var filled := {}
	for c in cells:
		filled[c] = true
	for c in cells:
		if not filled.has(c + Vector2i(0, -1)):
			draw_rect(Rect2(origin + Vector2(c) * p, Vector2(p, maxf(2.0, p * 0.25))), HIGHLIGHT)
