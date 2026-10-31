class_name StoneButton
extends TextureButton
## stone_button.gd - a UI button using one of the extracted stone button images.
##
## The supplied artwork has a single state, so hover / press feedback is only a
## tint (the image itself is untouched). Every press plays the click sound exactly
## once: the sound is connected here, once, and nowhere else.

const HOVER_TINT := Color(1.12, 1.12, 1.15)
const PRESS_TINT := Color(0.82, 0.86, 0.9)


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


func _refresh() -> void:
	if is_pressed():
		self_modulate = PRESS_TINT
	elif is_hovered():
		self_modulate = HOVER_TINT
	else:
		self_modulate = Color.WHITE
