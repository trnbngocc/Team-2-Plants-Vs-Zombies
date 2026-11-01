class_name StoneUI
extends RefCounted
## stone_ui.gd - Godot-built UI controls in the palette of the supplied stone buttons
## (stone_button.gd / stone_title.gd). Used where no button artwork exists: the
## Next / Play Again / Quit buttons of the result screens and leaderboard, and the
## username box in the main menu.

const FACE := Color("9fbbd0")
const HIGHLIGHT := Color("b8daf5")
const PRESSED := Color("86a3b9")
const DISABLED := Color("8097a8")
const SLAB := Color("3c5b77")
const OUTLINE := Color("2b3c4c")
const INK := Color("1d2a36")


static func _box(bg: Color, bottom: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = OUTLINE
	sb.set_border_width_all(4)
	sb.border_width_bottom = bottom
	sb.set_corner_radius_all(6)
	sb.content_margin_top = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb


## A stone-style text button. Plays the shared click sound once per press.
static func make_button(text: String, min_size := Vector2(210, 68), font_size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", OUTLINE)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("5d7184"))
	b.add_theme_stylebox_override("normal", _box(FACE, 12))
	b.add_theme_stylebox_override("hover", _box(HIGHLIGHT, 12))
	b.add_theme_stylebox_override("pressed", _box(PRESSED, 6))
	b.add_theme_stylebox_override("disabled", _box(DISABLED, 12))
	b.pressed.connect(func(): Audio.play_sfx("click"))
	return b


## An image button from the supplied stone artwork (assets/ui/buttons/<name>.png), shown at `size` (aspect kept).
static func make_image_button(name: String, size: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.set_script(load("res://stone_button.gd"))
	b.texture_normal = load("res://assets/ui/buttons/%s.png" % name)
	b.custom_minimum_size = size
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.name = name.capitalize()
	return b


## Text box with the same stone look (username input).
static func style_line_edit(le: LineEdit, accepted := false) -> void:
	le.add_theme_font_size_override("font_size", 26)
	le.add_theme_color_override("font_color", INK)
	le.add_theme_color_override("font_placeholder_color", Color("5d7184"))
	le.add_theme_color_override("caret_color", OUTLINE)
	var normal := _box(Color("dcebf7") if not accepted else Color("e3f6e4"), 8)
	if accepted:
		normal.border_color = Color("2f9a3d")
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var focus := _box(Color("f4fbff"), 8)
	focus.border_color = Color("e0a526") if not accepted else Color("2f9a3d")
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
