extends Control
## main_menu.gd - main menu: username box + TICK, PLAY, QUIT, LEADERBOARD.
##
##   * TICK checks the name. Only clicking it works, Enter does nothing.
##     Name is trimmed, can't be empty, max Session.MAX_NAME_LENGTH and can't already be
##     on the leaderboard (case-insensitive). If it's ok it gets saved in Session.
##   * PLAY only works after the name is confirmed, otherwise it shows a message.
##     Changing the name means you have to TICK again.
##   * QUIT closes the game.
##   * LEADERBOARD opens the leaderboard (view only).

const GAME_SCENE := "res://scenes/main.tscn"
const LEADERBOARD_SCENE := "res://scenes/leaderboard.tscn"

const OK_COLOR := Color("1f7a2c")
const ERR_COLOR := Color("d12a1f")
const TICK_SIZE := Vector2(68, 65)         # same ratio as the 160x152 image

var name_edit: LineEdit
var tick_button: TextureButton
var play_button: TextureButton
var quit_button: TextureButton
var leaderboard_button: TextureButton
var status_label: Label     # error or "accepted" message
var _busy := false          # leaving the menu: ignore any more clicks


func _ready() -> void:
	Audio.stop_gameplay_audio()
	Audio.play_music("menu")
	Session.end_session()             # no active player while in the menu
	Session.view_mode = Session.VIEW_NONE
	play_button = $Buttons/Play
	quit_button = $Buttons/Quit
	_build_username_box()
	_build_leaderboard_button()
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_refresh_play_state()


# Username box with the TICK button right beside it, and the message line under both.
func _build_username_box() -> void:
	var box := VBoxContainer.new()
	box.name = "UsernameBox"
	box.anchor_left = 0.66
	box.anchor_right = 0.66
	box.anchor_top = 0.628
	box.anchor_bottom = 0.628
	box.offset_left = -200.0
	box.offset_right = 200.0
	box.offset_top = 0.0
	box.offset_bottom = 96.0
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)

	name_edit = LineEdit.new()
	name_edit.name = "Username"
	name_edit.placeholder_text = "Your username"
	name_edit.max_length = Session.MAX_NAME_LENGTH
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(250, 54)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	StoneUI.style_line_edit(name_edit)
	name_edit.text_changed.connect(_on_text_changed)
	# Enter (text_submitted) isn't connected on purpose.
	row.add_child(name_edit)

	tick_button = StoneUI.make_image_button("tick", TICK_SIZE)
	tick_button.pressed.connect(_on_tick_pressed)
	row.add_child(tick_button)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_outline_color", Color("fff3d6"))
	status_label.add_theme_constant_override("outline_size", 6)
	box.add_child(status_label)

	name_edit.grab_focus.call_deferred()


# LEADERBOARD button next to PLAY and QUIT (a bit wider for the text).
func _build_leaderboard_button() -> void:
	leaderboard_button = StoneUI.make_image_button("leaderboard", Vector2(184, 80))
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	var buttons: Control = $Buttons
	buttons.add_child(leaderboard_button)
	buttons.offset_left = -300.0       # row was originally just PLAY + QUIT
	buttons.offset_right = 300.0


func _show_status(text: String, ok: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", OK_COLOR if ok else ERR_COLOR)


# PLAY is dimmed until a name is confirmed, but still clickable so it can show why.
func _refresh_play_state() -> void:
	play_button.self_modulate = Color.WHITE if Session.username_accepted else StoneButton.DISABLED_TINT


# Editing the name clears the message and any earlier confirmation.
func _on_text_changed(_t: String) -> void:
	if _busy:
		return
	Session.clear_accepted()
	status_label.text = ""
	StoneUI.style_line_edit(name_edit)
	_refresh_play_state()


## TICK: check the name, save it and show a message if ok. Doesn't start the game.
func _on_tick_pressed() -> void:
	if _busy:
		return
	var result: Dictionary = Session.validate_username(name_edit.text)
	if not result["ok"]:
		Session.clear_accepted()
		StoneUI.style_line_edit(name_edit)
		_show_status(result["error"], false)      # "Username already exists" for duplicates
		_refresh_play_state()
		name_edit.grab_focus()
		return
	var accepted: String = result["name"]
	Session.accept_username(accepted)
	name_edit.text = accepted                     # show the trimmed name
	StoneUI.style_line_edit(name_edit, true)
	_show_status("Username accepted: " + accepted, true)
	_refresh_play_state()


## PLAY: start the match (needs a confirmed name).
func _on_play_pressed() -> void:
	if _busy:
		return
	if not Session.username_accepted:
		_show_status("Confirm your username with the tick first", false)
		return
	_busy = true                                  # avoid starting twice on double click
	_lock_buttons()
	Session.begin_match(Session.username)
	Audio.play_music("gameplay")   # starts with the 30 s prep phase
	get_tree().change_scene_to_file(GAME_SCENE)


## LEADERBOARD: view only.
func _on_leaderboard_pressed() -> void:
	if _busy:
		return
	_busy = true
	_lock_buttons()
	Session.view_mode = Session.VIEW_MENU
	get_tree().change_scene_to_file(LEADERBOARD_SCENE)


## QUIT: close the game, nothing to save.
func _on_quit_pressed() -> void:
	if _busy:
		return
	_busy = true
	_lock_buttons()
	Audio.quit_game()   # let the click finish, stop audio, then quit


func _lock_buttons() -> void:
	for b in [tick_button, play_button, quit_button]:
		b.disabled = true
		b._refresh()
	leaderboard_button.disabled = true
	leaderboard_button._refresh()
	name_edit.editable = false
