extends SceneTree
## Windowed capture of the Gargantuar's Imp throw: stops the core exactly when the throw starts, then records
## real-time frames (the Gargantuar leaning back, the Imp leaving its shoulder, flying and landing).
## Run:  Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/throw_capture.gd -- <out_dir>

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


func shot(name: String) -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _run() -> void:
	var session := root.get_node("Session")
	session.begin_match("ThrowTester")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(4.0).timeout             # let the Start Text finish
	var core: Node = main.get_node("GameController")
	var ui: Control = main.get_node("Maingame")
	core.begin_waves()
	core.add_sun(2000)
	for c in range(0, 3):
		core.place_plant(2, c, 0)                # Peashooters chip the boss down to 1000
	core.place_plant(2, 3, 3)                    # Jalapeno: 900
	core.debug_spawn_enemy(3, 2, 7.0)
	var thrown := [false]
	core.imp_thrown.connect(func(r, a, b): thrown[0] = true)
	var guard := 0
	while not thrown[0] and guard < 6000:
		core.advance_time(1.0 / 30.0)
		guard += 1
	check(thrown[0], "the Gargantuar threw its Imp")
	for c in range(0, 3):
		core.shovel_plant(2, c)                  # the Imp must survive long enough to be watched walking
	await shot("t0_throw_start")
	for step in [0.2, 0.25, 0.25, 0.3, 0.4, 0.6]:
		await create_timer(step).timeout
		await shot("t_%02d" % int(Time.get_ticks_msec() % 100000 / 10))
	# follow the landed Imp: it should now walk toward the plants
	var imp_pos := Vector2.ZERO
	for step2 in [0.6, 0.6]:
		await create_timer(step2).timeout
		for v in ui.zombie_views.values():
			if v.kind == 2:
				imp_pos = v.global_position
		await shot("imp_walk_%d" % int(Time.get_ticks_msec() % 100000 / 10))
	print("IMP_POS ", imp_pos)
	var imp_views := 0
	var garg_view = null
	for v in ui.zombie_views.values():
		if v.kind == 2:
			imp_views += 1
		if v.kind == 1:
			garg_view = v
	check(imp_views == 1, "one Imp view")
	check(garg_view != null and garg_view.puppet != null and not garg_view.puppet._rider.visible, "the rider Imp left the Gargantuar's shoulder")
	print("throw: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
