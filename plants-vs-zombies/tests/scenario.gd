extends SceneTree
## One user-flow scenario per process (so a REAL application quit can be observed
## by tools/run_scenarios.ps1). Input is injected through Godot's input system (real mouse clicks on the
## on-screen buttons, real keyboard events), not by calling the handlers.
##
## Run:  Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/scenario.gd -- <mode> <out_dir>
## The leaderboard is in memory only; each mode is a fresh process seeded with Alice (Victory 450) and Bob (Defeat).
## Modes: menu_quit | menu_board | username | match_victory | match_defeat | match_two | match_two_rev | back_only | fresh_start
## Prints "SCENARIO <mode>: N checks, M failures" and, for modes that quit, never returns (the process exits).

const PEA := 0
const WALLNUT := 2

var mode := ""
var out_dir := ""
var failures := 0
var checks := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else ""
	out_dir = args[1] if args.size() > 1 else "user://shots"
	call_deferred("_run")


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL [%s]: %s" % [mode, what])


func frames(n := 4) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	await frames(3)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [mode, name]))


## A genuine mouse click at the centre of an on-screen control.
func click(c) -> void:
	if c == null or not is_instance_valid(c):
		return                      # the scene already changed: a repeated click has nothing left to hit
	check(c.is_visible_in_tree(), "the button to click is visible")
	var pos: Vector2 = c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	Input.parse_input_event(mv)
	await frames(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(ev)
		await frames(1)
	await frames(2)


func press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(1)
	await frames(2)


func type_text(le: LineEdit, text: String) -> void:
	le.grab_focus()
	le.text = text
	le.text_changed.emit(text)
	await frames(2)


func goto(path: String) -> void:
	change_scene_to_file(path)
	await frames(6)


func finish() -> void:
	print("SCENARIO %s: %d checks, %d failures" % [mode, checks, failures])
	quit(1 if failures > 0 else 0)




# An old user://leaderboard.json from earlier versions is never read or written any more: its timestamp must not change.
const OLD_FILE := "user://leaderboard.json"
var _old_mtime := 0


func disk_untouched() -> bool:
	return (FileAccess.get_modified_time(OLD_FILE) if FileAccess.file_exists(OLD_FILE) else 0) == _old_mtime


func snap() -> String:
	return JSON.stringify(root.get_node("Session").records)


func seed_board() -> void:
	var s: Node = root.get_node("Session")
	s.records = [
		{"username": "Alice", "score": 450, "won": true, "id": 0},
		{"username": "Bob", "score": 0, "won": false, "id": 1},
	]


func _run() -> void:
	_old_mtime = FileAccess.get_modified_time(OLD_FILE) if FileAccess.file_exists(OLD_FILE) else 0
	if mode != "fresh_start":
		seed_board()
	match mode:
		"menu_quit":
			await scenario_menu_quit()
		"menu_board":
			await scenario_menu_board()
		"username":
			await scenario_username()
		"match_victory":
			await scenario_match(["victory"])
		"match_defeat":
			await scenario_match(["defeat"])
		"match_two":
			await scenario_match(["defeat", "victory"])
		"match_two_rev":
			await scenario_match(["victory", "defeat"])
		"back_only":
			await scenario_back_only()
		"fresh_start":
			await scenario_fresh_start()
		_:
			printerr("unknown mode " + mode)
			quit(2)


# ---------------------------------------------------------------------------- A: menu Quit
func scenario_menu_quit() -> void:
	await goto("res://scenes/menu.tscn")
	var menu := current_scene
	await shot("menu")
	await click(menu.quit_button)
	await click(menu.quit_button)     # a second click must be harmless
	await create_timer(4.0).timeout   # the application must close by itself shortly after the click
	print("SCENARIO menu_quit: STILL RUNNING (the Quit button did not close the application)")
	printerr("FAIL [menu_quit]: application did not exit")
	quit(1)


# ---------------------------------------------------------------------------- B: leaderboard from the menu
func scenario_menu_board() -> void:
	await goto("res://scenes/menu.tscn")
	var menu := current_scene
	var before := snap()
	var session: Node = root.get_node("Session")
	var saved: int = session.records.size()
	check(menu.leaderboard_button is TextureButton and menu.leaderboard_button.texture_normal.resource_path.ends_with("buttons/leaderboard.png"), "the menu has the image LEADERBOARD button")
	await shot("menu_with_leaderboard_button")
	await click(menu.leaderboard_button)
	await frames(6)
	check(current_scene.name == "Leaderboard", "LEADERBOARD opens the leaderboard screen")
	check(session.view_mode == session.VIEW_MENU, "it is the menu view")
	var rows: Node = current_scene.find_child("Rows", true, false)
	check(rows != null and rows.get_child_count() == saved, "it lists the %d session records" % saved)
	check(current_scene.find_child("Quit", true, false) == null and current_scene.find_child("PlayAgain", true, false) == null, "no Quit / Play Again, only BACK")
	var back: Control = current_scene.find_child("Back", true, false)
	check(back is TextureButton and back.texture_normal.resource_path.ends_with("buttons/back.png"), "BACK is the image button")
	await shot("menu_leaderboard")
	check(snap() == before, "opening the leaderboard changes nothing")
	await click(back)
	await click(back)
	await frames(6)
	check(current_scene.name == "MainMenu", "BACK returns to the main menu")
	check(snap() == before and session.records.size() == saved, "no record was created or changed")
	finish()


# ---------------------------------------------------------------------------- C: username confirmation
func scenario_username() -> void:
	await goto("res://scenes/menu.tscn")
	var menu := current_scene
	var session: Node = root.get_node("Session")
	check(menu.tick_button != null and menu.tick_button.texture_normal.resource_path.ends_with("buttons/tick.png"), "the menu has the image TICK button")
	check(menu.play_button.texture_normal.resource_path.ends_with("buttons/play.png") and menu.quit_button.texture_normal.resource_path.ends_with("buttons/quit.png"), "PLAY and QUIT use the supplied artwork")
	# --- PLAY is blocked before a name is confirmed
	await type_text(menu.name_edit, "EarlyBird")
	await click(menu.play_button)
	check(current_scene == menu and menu.status_label.text == "Confirm your username with the tick first", "PLAY without a confirmed name stays on the menu with a message")
	await shot("menu")
	# --- the physical Enter key does nothing
	await type_text(menu.name_edit, "KeyPlayer")
	await press_key(KEY_ENTER)
	await press_key(KEY_KP_ENTER)
	await frames(10)
	check(current_scene == menu, "the keyboard Enter key does not start the game")
	check(not session.username_accepted and menu.status_label.text == "", "the keyboard Enter key does not accept the name")
	await click(menu.play_button)
	check(current_scene == menu, "PLAY still blocked after the Enter key")
	# --- empty
	await type_text(menu.name_edit, "   ")
	await click(menu.tick_button)
	check(menu.status_label.text == "Please enter a username" and current_scene == menu, "an empty name is rejected")
	check(not session.validate_username("x".repeat(17))["ok"], "17 characters are rejected")
	# --- duplicate (case-insensitive, trimmed)
	await type_text(menu.name_edit, "  aLiCe ")
	await click(menu.tick_button)
	check(menu.status_label.text == "Username already exists", "a duplicate shows exactly: Username already exists")
	check(not session.username_accepted and current_scene == menu, "a duplicate is not accepted")
	await shot("duplicate")
	# --- valid name: accepted only by the mouse click; editing withdraws it; then PLAY starts the game
	await type_text(menu.name_edit, "  NewPlayer  ")
	await press_key(KEY_ENTER)
	check(current_scene == menu and not session.username_accepted, "still nothing after the Enter key")
	await click(menu.tick_button)
	await click(menu.tick_button)               # a second click is harmless
	check(session.username_accepted and session.username == "NewPlayer", "the click accepts and stores the trimmed username")
	check(menu.status_label.text == "Username accepted: NewPlayer", "visible confirmation")
	check(current_scene == menu, "TICK alone does not start the game")
	await shot("accepted")
	await type_text(menu.name_edit, "NewPlayer2")
	check(not session.username_accepted, "editing the name withdraws the confirmation")
	await click(menu.play_button)
	check(current_scene == menu, "PLAY is blocked again until TICK is clicked")
	await click(menu.tick_button)
	var play: Control = menu.play_button
	await click(play)
	await click(play)                           # extra clicks must not start the game twice
	await create_timer(1.6).timeout
	await frames(8)
	check(current_scene.has_node("GameController"), "gameplay starts after TICK then PLAY")
	finish()


# ---------------------------------------------------------------------------- D / E / F: complete matches
func play_match(kind: String, name: String) -> void:
	var core: Node = current_scene.get_node("GameController")
	await frames(4)
	core.begin_waves()
	if kind == "victory":
		core.add_sun(20000)
		for row in 5:
			for col in range(0, 7):
				core.place_plant(row, col, PEA)
			core.place_plant(row, 7, WALLNUT)
		var t := 0.0
		while core.get_state() == 1 and t < 900.0:
			core.advance_time(5.0)
			t += 5.0
			await process_frame
		check(core.get_state() == 3, "%s: the match is won" % name)
	else:
		core.debug_spawn_enemy(0, 2, 0.3)
		core.advance_time(5.0)
		core.debug_spawn_enemy(0, 2, 0.3)
		core.advance_time(10.0)
		check(core.get_state() == 4, "%s: the match is lost" % name)
	await frames(8)


func enter_menu_and_play(name: String) -> void:
	var menu := current_scene
	await type_text(menu.name_edit, name)
	await click(menu.tick_button)
	await click(menu.play_button)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and not (current_scene != null and current_scene.has_node("GameController")):
		await frames(2)                                  # wait for the game scene instead of guessing a delay
	await frames(8)


func hero_entries(session: Node) -> Array:
	var found := []
	for r in session.records:
		if r["username"] == "Hero":
			found.append(r)
	return found


# Register Hero, play one match per entry of `kinds`, RESTARTing between them. The leaderboard must keep exactly ONE
# Hero entry, holding the latest result. Then BACK ends the session: "Hero" is taken, another name is accepted.
func scenario_match(kinds: Array) -> void:
	var session: Node = root.get_node("Session")
	var seed_count: int = session.records.size()
	await goto("res://scenes/menu.tscn")
	await enter_menu_and_play("Hero")                        # type + TICK + PLAY, like a player
	check(current_scene.has_node("GameController"), "the game started from TICK then PLAY")
	for i in kinds.size():
		var kind: String = kinds[i]
		await play_match(kind, "match %d" % (i + 1))
		var entries := hero_entries(session)
		check(session.records.size() == seed_count + 1 and entries.size() == 1, "exactly one Hero entry exists after match %d (%d)" % [i + 1, entries.size()])
		check(entries[0]["won"] == (kind == "victory") and entries[0]["score"] == (3750 if kind == "victory" else 0), "the entry holds this match's result (%s)" % kind)
		await frames(10)
		check(session.records.size() == seed_count + 1, "waiting on the result screen adds nothing")
		var ui: Control = current_scene.get_node("Maingame")
		var nxt: Control = ui._next_buttons[0] if kind == "victory" else ui._next_buttons[1]
		check(nxt is TextureButton and nxt.texture_normal.resource_path.ends_with("buttons/next.png"), "NEXT is the image button")
		await shot("%s_result_%d" % [kind, i + 1])
		await click(nxt)
		await click(nxt)
		await frames(8)
		check(current_scene.name == "Leaderboard" and session.view_mode == session.VIEW_POST_MATCH, "NEXT opens the leaderboard (no new match)")
		var lb := current_scene
		check(lb.find_child("Restart", true, false) != null and lb.find_child("Back", true, false) != null, "RESTART and BACK are visible")
		check(lb.find_child("PlayAgain", true, false) == null and lb.find_child("Quit", true, false) == null, "no Play Again / Quit")
		var rows: Node = lb.find_child("Rows", true, false)
		check(rows.get_child_count() == seed_count + 1, "the board lists %d entries" % (seed_count + 1))
		await shot("leaderboard_%d" % (i + 1))
		if i < kinds.size() - 1:
			var restart: Control = lb.find_child("Restart", true, false)
			await click(restart)
			await click(restart)                             # a second click is harmless
			await frames(8)
			await create_timer(0.5).timeout
			check(current_scene.has_node("GameController") and session.username == "Hero", "RESTART: a new match with the same username")
			check(session.records.size() == seed_count + 1 and hero_entries(session).size() == 1, "RESTART created no entry")
			var core: Node = current_scene.get_node("GameController")
			check(core.get_state() != 3 and core.get_state() != 4 and core.get_sun_spent() == 0, "the whole gameplay state is fresh (no result, nothing spent)")
	# BACK: the player's session ends, the name stays taken
	var back: Control = current_scene.find_child("Back", true, false)
	await click(back)
	await click(back)
	await frames(8)
	check(current_scene.name == "MainMenu", "BACK returns to the main menu")
	check(session.username == "" and session.records.size() == seed_count + 1, "the session ended; the entry stays on the board")
	var menu := current_scene
	await type_text(menu.name_edit, "Hero")
	await click(menu.tick_button)
	check(menu.status_label.text == "Username already exists" and not session.username_accepted, "the old username is rejected: Username already exists")
	await click(menu.play_button)
	check(current_scene == menu, "no new game can start with the old username")
	await type_text(menu.name_edit, " hERO ")
	await click(menu.tick_button)
	check(menu.status_label.text == "Username already exists", "also rejected case-insensitively")
	await shot("old_name_rejected")
	await type_text(menu.name_edit, "Hero2")
	await click(menu.tick_button)
	check(session.username_accepted and session.username == "Hero2", "a different username is accepted")
	await click(menu.play_button)
	await create_timer(1.2).timeout
	await frames(8)
	check(current_scene.has_node("GameController") and session.records.size() == seed_count + 1, "the new player starts a new game; no entry yet")
	print("RECORDS " + JSON.stringify(session.sorted_records()))
	check(disk_untouched(), "nothing was written to disk")
	finish()


# After a finished match: NEXT, BACK, menu leaderboard, BACK, menu Quit. The record exists in memory, the process then ends.
func scenario_back_only() -> void:
	var session: Node = root.get_node("Session")
	var seed_count: int = session.records.size()
	await goto("res://scenes/menu.tscn")
	await enter_menu_and_play("Hero")
	await play_match("defeat", "match")
	var ui: Control = current_scene.get_node("Maingame")
	await click(ui._next_buttons[1])
	await frames(8)
	await click(current_scene.find_child("Back", true, false))
	await frames(8)
	check(current_scene.name == "MainMenu" and session.records.size() == seed_count + 1, "BACK returns to the menu, the result stays (one record)")
	await click(current_scene.leaderboard_button)
	await frames(6)
	check(session.view_mode == session.VIEW_MENU and current_scene.find_child("Rows", true, false).get_child_count() == seed_count + 1, "menu leaderboard shows the result once")
	await click(current_scene.find_child("Back", true, false))
	await frames(6)
	check(session.records.size() == seed_count + 1, "still exactly one new record")
	check(disk_untouched(), "nothing on disk")
	await click(current_scene.quit_button)
	await create_timer(4.0).timeout
	printerr("FAIL [back_only]: application did not exit")
	quit(1)


# A fresh launch: the leaderboard is empty (the previous process's records are gone).
func scenario_fresh_start() -> void:
	var session: Node = root.get_node("Session")
	check(session.records.is_empty(), "a fresh launch starts with an empty leaderboard")
	await goto("res://scenes/menu.tscn")
	await click(current_scene.leaderboard_button)
	await frames(6)
	var rows: Node = current_scene.find_child("Rows", true, false)
	check(rows.get_child_count() == 1 and rows.get_child(0) is Label, "the leaderboard screen shows 'No results yet'")
	check(session.validate_username("Hero")["ok"], "a name used in an earlier run is free again")
	print("BOARD_COUNT %d" % session.records.size())
	finish()
