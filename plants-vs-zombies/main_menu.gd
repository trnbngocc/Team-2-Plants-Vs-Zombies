extends Control
## main_menu.gd - Main Menu: background, username box + TICK, PLAY, QUIT (image buttons) and LEADERBOARD (all image buttons).
##
## The three primary buttons use the supplied stone artwork (assets/ui/buttons/{tick,play,quit}.png):
##   * TICK (round, beside the username box) confirms the name. Only a mouse click on it does: the box's
##     text_submitted signal (keyboard Enter) is deliberately not connected, so Enter confirms nothing.
##     Validation: trimmed, non-empty, at most Session.MAX_NAME_LENGTH, not on the leaderboard
##     (case-insensitive; duplicate => exactly "Username already exists"). A valid name is stored in Session
##     and a green "Username accepted" message is shown.
##   * PLAY starts the game, but only once a name has been confirmed with TICK; otherwise it stays here and
##     shows a message. Editing the name withdraws the confirmation.
##   * QUIT closes the application without saving anything (it is not a finished match).
## LEADERBOARD (image button, same family) opens the existing leaderboard screen read-only.

const GAME_SCENE := "res://scenes/main.tscn"
const LEADERBOARD_SCENE := "res://scenes/leaderboard.tscn"

const OK_COLOR := Color("1f7a2c")
const ERR_COLOR := Color("d12a1f")
const TICK_SIZE := Vector2(68, 65)         # keeps the 160:152 artwork proportions

var name_edit: LineEdit
var tick_button: TextureButton
var play_button: TextureButton
var quit_button: TextureButton
var leaderboard_button: TextureButton
var status_label: Label     # error ("Username already exists") or confirmation message
var _busy := false          # leaving the menu: every button ignores further clicks


func _ready() -> void:
	Audio.stop_gameplay_audio()
	Audio.play_music("menu")
	Session.end_session()             # the menu means no player session is active
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
	# NOTE: text_submitted (the keyboard Enter key) is intentionally NOT connected.
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


# LEADERBOARD: an image button of the same family, in the row next to PLAY and QUIT (it needs a wider face for its label).
func _build_leaderboard_button() -> void:
	leaderboard_button = StoneUI.make_image_button("leaderboard", Vector2(184, 80))
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	var buttons: Control = $Buttons
	buttons.add_child(leaderboard_button)
	buttons.offset_left = -300.0       # the row was laid out for PLAY + QUIT only
	buttons.offset_right = 300.0


func _show_status(text: String, ok: bool) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", OK_COLOR if ok else ERR_COLOR)


# PLAY looks dimmed until a username has been confirmed; it stays clickable so it can explain why it waits.
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


## TICK: validate; if valid, accept + store the name and show the confirmation. Does NOT start the game.
func _on_tick_pressed() -> void:
	if _busy:
		return
	var result: Dictionary = Session.validate_username(name_edit.text)
	if not result["ok"]:
		Session.clear_accepted()
		StoneUI.style_line_edit(name_edit)
		_show_status(result["error"], false)      # exactly "Username already exists" for a duplicate
		_refresh_play_state()
		name_edit.grab_focus()
		return
	var accepted: String = result["name"]
	Session.accept_username(accepted)
	name_edit.text = accepted                     # show the trimmed name that was accepted
	StoneUI.style_line_edit(name_edit, true)
	_show_status("Username accepted: " + accepted, true)
	_refresh_play_state()


## PLAY: starts the match, only with a name confirmed by TICK.
func _on_play_pressed() -> void:
	if _busy:
		return
	if not Session.username_accepted:
		_show_status("Confirm your username with the tick first", false)
		return
	_busy = true                                  # repeated clicks cannot start the game twice
	_lock_buttons()
	Session.begin_match(Session.username)
	Audio.play_music("gameplay")   # starts with the 30 s preparation phase
	get_tree().change_scene_to_file(GAME_SCENE)


## LEADERBOARD: read-only view of the saved records.
func _on_leaderboard_pressed() -> void:
	if _busy:
		return
	_busy = true
	_lock_buttons()
	Session.view_mode = Session.VIEW_MENU
	get_tree().change_scene_to_file(LEADERBOARD_SCENE)


## QUIT: close the whole application. Nothing is saved: the menu is not a finished match.
func _on_quit_pressed() -> void:
	if _busy:
		return
	_busy = true
	_lock_buttons()
	Audio.quit_game()   # lets the click finish, stops audio, then exits


func _lock_buttons() -> void:
	for b in [tick_button, play_button, quit_button]:
		b.disabled = true
		b._refresh()
	leaderboard_button.disabled = true
	leaderboard_button._refresh()
	name_edit.editable = false
