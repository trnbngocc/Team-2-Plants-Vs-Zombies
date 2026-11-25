class_name StoneButton
extends TextureButton
## stone_button.gd - button using one of the stone button images.
##
## The image only has one state so hover / press is just a tint.
## Click sound is connected here so it plays once per press.

const HOVER_TINT := Color(1.12, 1.12, 1.15)
const PRESS_TINT := Color(0.82, 0.86, 0.9)
const DISABLED_TINT := Color(0.6, 0.65, 0.7, 0.85)


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	mouse_entered.connect(_refresh)
	mouse_exited.connect(_refresh)
	button_down.connect(_refresh)
	button_up.connect(_refresh)


func _on_pressed() -> void:
	Audio.play_sfx("click")


## Callers that toggle `disabled` call this afterwards.
func _refresh() -> void:
	if disabled:
		self_modulate = DISABLED_TINT
	elif is_pressed():
		self_modulate = PRESS_TINT
	elif is_hovered():
		self_modulate = HOVER_TINT
	else:
		self_modulate = Color.WHITE
