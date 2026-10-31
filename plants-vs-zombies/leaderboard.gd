extends Control
## leaderboard.gd - persistent local leaderboard + BACK.
##
## Shows Username, Score and Result (Victory / Defeat) from Session.sorted_records() - this run's results, held in memory:
## every Victory above every Defeat, lower Sun spent first among Victories.
## Opening or leaving this screen only READS the records (the match result was added once when the match ended).
##
## One screen, one button, two entry modes (Session.view_mode): BACK returns to the main menu and saves nothing.
##   VIEW_MENU        opened from the main menu
##   VIEW_POST_MATCH  opened by NEXT after a finished match - the newest result is highlighted

const MENU_SCENE := "res://scenes/menu.tscn"
const BG := "res://assets/ui/menu_background.jpg"

const COL_RANK := 56.0
const COL_NAME := 250.0
const COL_SCORE := 120.0
const COL_RESULT := 140.0

var _leaving := false
var _buttons: Array = []


func _ready() -> void:
	Audio.stop_gameplay_audio()
	Audio.play_music("menu")
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.texture = load(BG) if ResourceLoader.exists(BG) else null
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.06, 0.1, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("9fbbd0")
	sb.border_color = Color("2b3c4c")
	sb.set_border_width_all(5)
	sb.border_width_bottom = 12
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "LEADERBOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("2b3c4c"))
	box.add_child(title)

	box.add_child(_row(["#", "Username", "Score", "Result"], true, false))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(COL_RANK + COL_NAME + COL_SCORE + COL_RESULT + 30, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)

	var post_match: bool = Session.view_mode == Session.VIEW_POST_MATCH
	var data: Array = Session.sorted_records()
	if data.is_empty():
		var empty := Label.new()
		empty.text = "No results yet"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("2b3c4c"))
		rows.add_child(empty)
	var newest: int = int(Session.records[-1]["id"]) if post_match and not Session.records.is_empty() else -1
	for i in data.size():
		var r: Dictionary = data[i]
		var is_mine: bool = int(r.get("id", -2)) == newest
		rows.add_child(_row([
			str(i + 1), String(r["username"]), str(int(r["score"])),
			"Victory" if bool(r["won"]) else "Defeat",
		], false, is_mine, bool(r["won"])))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)

	# BACK is the only navigation, in both modes: it returns to the main menu and never saves anything.
	var back := StoneUI.make_image_button("back", Vector2(184, 80))
	back.name = "Back"
	back.pressed.connect(_on_back)
	buttons.add_child(back)
	_buttons = [back]


func _row(cells: Array, header: bool, mine: bool, won := false) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if header:
		sb.bg_color = Color("3c5b77")
	elif mine:
		sb.bg_color = Color("ffe9a6")
	else:
		sb.bg_color = Color("c9dceb")
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	panel.add_child(h)
	var widths := [COL_RANK, COL_NAME, COL_SCORE, COL_RESULT]
	for i in cells.size():
		var l := Label.new()
		l.text = String(cells[i])
		l.custom_minimum_size = Vector2(widths[i], 0)
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 20)
		var color := Color("e8f2ff") if header else Color("1d2a36")
		if not header and i == 3:
			color = Color("1f6b2a") if won else Color("a3201a")
		l.add_theme_color_override("font_color", color)
		h.add_child(l)
	return panel


func _lock() -> bool:
	if _leaving:
		return false
	_leaving = true
	for b in _buttons:
		b.disabled = true
	return true


# BACK (menu view and post-match view alike): navigation only. Pending results stay in Session, nothing is saved.
func _on_back() -> void:
	if not _lock():
		return
	Session.view_mode = Session.VIEW_NONE
	get_tree().change_scene_to_file(MENU_SCENE)
