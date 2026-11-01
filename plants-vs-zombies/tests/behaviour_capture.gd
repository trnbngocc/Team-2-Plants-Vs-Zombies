extends SceneTree
## Windowed behaviour check of presentation features that need a real renderer:
## Squash jump + one-time screen shake (position restored), boss Imp throw + death,
## pause freezing the whole screen, banners, seed-bank states. Saves screenshots.
## Run:
##   Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/behaviour_capture.gd -- <out_dir>

var out_dir := ""
var failures := 0
var checks := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://shots"
	call_deferred("_run")


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func wait(s: float) -> void:
	await create_timer(s).timeout


func frames(n := 3) -> void:
	for i in n:
		await process_frame


func grab() -> Image:
	await frames(2)
	return root.get_viewport().get_texture().get_image()


func shot(name: String) -> Image:
	var img := await grab()
	DirAccess.make_dir_recursive_absolute(out_dir)
	img.save_png(out_dir.path_join(name + ".png"))
	return img


func _run() -> void:
	var session := root.get_node("Session")
	session.begin_match("Tester")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await wait(0.5)
	var core: Node = main.get_node("GameController")
	var ui: Control = main.get_node("Maingame")

	# ---- Start Text: waves must not start until it has finished ----
	check(not core.get_waves_started(), "waves have not started while Start Text is on screen")
	var holder: Node = ui.fx_layer.get_node_or_null("StartText")
	check(holder != null, "Start Text is shown at the start")
	await wait(4.2)
	check(core.get_waves_started(), "waves start after the Start Text finished")
	check(ui.fx_layer.get_node_or_null("StartText") == null, "Start Text is removed afterwards")
	var spawned_at_start: int = core.get_enemies_spawned()

	# ---- seed bank states ----
	core.add_sun(-core.get_sun() + 60)       # 60 Sun: only the 50-Sun packets are affordable
	await shot("b01_seedbank_60_sun")
	check(ui._card_dim[1].visible == false and ui._card_dim[0].visible == true and ui._card_dim[3].visible == true,
		"packets dim exactly when Sun < cost (Sunflower ok, Peashooter + Jalapeno dim)")
	ui._on_seed_card_pressed(4)
	await frames(2)
	check(ui.card_buttons[4].get_node("Selected").visible, "selected packet shows its frame")
	ui._on_seed_card_pressed(1)
	check(not ui.card_buttons[4].get_node("Selected").visible and ui.card_buttons[1].get_node("Selected").visible, "selection moves to the new packet")
	ui.selected_plant_type = -1
	ui._highlight_selected()

	# ---- Shovel: held sprite follows the pointer; removes ONLY the clicked plant; empty cell does nothing ----
	core.add_sun(300)
	core.place_plant(3, 6, 2)
	core.place_plant(3, 7, 2)
	await frames(3)
	var plants_before: int = core.get_plants_data().size()
	var sun_before: int = core.get_sun()
	var spent_before: int = core.get_sun_spent()
	root.warp_mouse(Vector2(700, 420))
	await frames(4)
	ui._on_shovel_pressed()
	await frames(4)
	check(ui._held_shovel.visible and ui._shovel_button.get_node("Selected").visible, "shovel selected: held shovel + slot highlight shown")
	var tip: Vector2 = ui._held_shovel.position + ui._held_shovel.size * Vector2(0.06, 0.94)
	check(tip.distance_to(ui.fx_layer.get_local_mouse_position()) < 3.0, "the blade tip sits on the pointer")
	await shot("b00_shovel_held")
	ui._on_cell_pressed(0, 8)                # empty cell
	await frames(2)
	check(core.get_plants_data().size() == plants_before, "shovel on an empty cell removes nothing")
	check(ui._shovel_active, "shovel stays selected after clicking an empty cell")
	ui._on_cell_pressed(3, 6)                # plant
	core.advance_time(0.1)
	await frames(3)
	var left_cols := []
	for pd in core.get_plants_data():
		if pd["row"] == 3:
			left_cols.append(pd["column"])
	check(core.get_plants_data().size() == plants_before - 1 and left_cols == [7], "only the clicked plant was removed (neighbour stays)")
	check(core.get_sun() == sun_before and core.get_sun_spent() == spent_before, "no refund, score unchanged")
	check(not ui._shovel_active and not ui._held_shovel.visible, "shovel returns to the normal state after removing")
	check(core.get_plants_data().size() == plants_before - 1, "no accidental planting during the shovel click")

	# ---- Squash: jump, impact, shake once, camera restored ----
	core.add_sun(500)
	core.place_plant(1, 3, 4)
	core.debug_spawn_enemy(2, 1, 4.6)
	var origin: Vector2 = ui.position
	core.advance_time(0.3)
	await shot("b02_squash_in_the_air")
	var max_offset := 0.0
	var shakes := [0]
	core.squash_smashed.connect(func(r, c, h): shakes[0] += 1)
	var ticks := 0
	core.advance_time(0.3)                   # impact happens inside this call
	for i in 40:
		await process_frame
		max_offset = maxf(max_offset, (ui.position - origin).length())
		ticks += 1
	check(shakes[0] == 1, "exactly one Squash smash event")
	check(max_offset > 1.0 and max_offset <= 12.0, "screen shakes noticeably but not excessively (max %.1f px)" % max_offset)
	await wait(0.5)
	check(ui.position == origin, "screen position restored exactly after the shake")
	await shot("b03_after_squash")

	# ---- Boss: Jalapeno + Imp throw ----
	core.add_sun(1000)
	core.debug_spawn_enemy(3, 2, 6.0)
	core.place_plant(2, 0, 3)                # Jalapeno
	core.advance_time(2.3)
	await shot("b04_boss_after_jalapeno")
	var kinds := []
	for z in core.get_zombies_data():
		kinds.append(z["kind"])
	check(kinds.count(1) == 1 and kinds.count(2) == 0, "boss survived Jalapeno, no Imp yet")
	core.place_plant(2, 1, 0)                # Peashooter chips the boss below 1000 (Squash would one-shot it from 1100)
	var waited := 0.0
	var imp_seen := false
	while waited < 20.0 and not imp_seen:
		core.advance_time(0.25)
		waited += 0.25
		for z in core.get_zombies_data():
			if z["kind"] == 2:
				imp_seen = true
	await shot("b05_imp_thrown")
	kinds = []
	for z in core.get_zombies_data():
		kinds.append(z["kind"])
	check(kinds.count(2) == 1, "one Imp is on the field")
	var imp_view_found := false
	for v in ui.zombie_views.values():
		if v.kind == 2 and v.puppet != null:
			imp_view_found = true
	check(imp_view_found, "the Imp is drawn with its own rig")
	await wait(0.2)
	await shot("b06_boss_throwing")

	# ---- Pause freezes the whole screen ----
	root.warp_mouse(Vector2(1, 1))           # keep the pointer off the pause-menu buttons (their hover tint is not game motion)
	await frames(4)
	ui._on_pause_pressed()
	await frames(12)                         # let one-frame transitions (overlay, process modes) settle
	check(core.get_state() == 2, "paused")
	var a := await grab()
	await wait(1.2)
	var b := await grab()
	check(a.get_data() == b.get_data(), "paused screen is completely frozen (no timers/animations run)")
	if a.get_data() != b.get_data():
		DirAccess.make_dir_recursive_absolute(out_dir)
		a.save_png(out_dir.path_join("pause_a.png"))
		b.save_png(out_dir.path_join("pause_b.png"))
	await shot("b07_paused")
	ui._on_resume_pressed()
	await frames(3)
	check(core.get_state() == 1, "resumed")
	check(ui._intro_started and ui._waves_begun, "resume does not re-run the intro")
	check(ui.fx_layer.get_node_or_null("StartText") == null, "no Start Text after resume")

	# ---- Boss death: Jalapeno (900) then Squash (1800) through the normal damage path ----
	core.add_sun(1000)
	core.debug_spawn_enemy(3, 4, 5.0)
	core.place_plant(4, 0, 3)
	core.advance_time(2.3)
	var boss_row4 := {}
	for z in core.get_zombies_data():
		if z["kind"] == 1 and z["row"] == 4:
			boss_row4 = z
	check(not boss_row4.is_empty() and boss_row4["health"] == 1100, "second boss survived Jalapeno with 1100 HP")
	await frames(3)                           # let the UI create the boss view before it dies
	var boss_id: int = boss_row4["id"]
	var boss_view = ui.zombie_views.get(boss_id)
	check(boss_view != null, "boss has a view before dying")
	core.place_plant(4, 4, 4)
	core.advance_time(0.5)
	core.advance_time(0.2)
	var boss_dead := true
	for z in core.get_zombies_data():
		if z["id"] == boss_id:
			boss_dead = false
	check(boss_dead, "Jalapeno + Squash (2700 total) kill the 2000-HP Gargantuar")
	await frames(3)
	check(is_instance_valid(boss_view) and boss_view.dying, "boss view plays its death animation")
	await shot("b08_boss_death")
	await wait(0.5)
	await shot("b08b_boss_falling")
	await wait(2.6)           # the Gargantuar's death motion is ~2.3 s
	check(not is_instance_valid(boss_view), "boss view is freed after the death animation")
	await shot("b09_boss_gone")
	print("behaviour: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
