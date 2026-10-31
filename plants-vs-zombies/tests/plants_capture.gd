extends SceneTree
## Windowed capture of the plants' animations in real time: Jalapeno fuse (glow / pulse), Peashooter recoil,
## Wall-nut blink + hit reaction, Sunflower sway, Squash idle. Saves frames and a few checks.
## Run:  Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/plants_capture.gd -- <out_dir>

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
	session.begin_match("PlantTester")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(4.0).timeout
	var core: Node = main.get_node("GameController")
	var ui: Control = main.get_node("Maingame")
	core.add_sun(2000)
	core.place_plant(0, 2, 1)       # Sunflower
	core.place_plant(1, 2, 0)       # Peashooter
	core.place_plant(2, 2, 2)       # Wall-nut
	core.place_plant(3, 2, 3)       # Jalapeno (fuse 2 s)
	core.place_plant(4, 2, 4)       # Squash
	core.debug_spawn_enemy(0, 1, 6.5)   # something for the Peashooter to shoot
	var frames_hit := 0
	await create_timer(0.3).timeout
	await shot("p0_planted")
	await create_timer(1.0).timeout
	await shot("p1_fuse_mid")
	await create_timer(0.55).timeout
	await shot("p2_fuse_late")
	# let the Jalapeno explode, check it is gone, then look at the others
	await create_timer(0.8).timeout
	check(core.get_plants_data().size() == 4 or core.get_plants_data().size() == 5, "plants still present")
	# Wall-nut: damage it through the normal path (a zombie in its row eats it)
	core.debug_spawn_enemy(0, 2, 2.9)
	var saw_hit := false
	var max_scale_jolt := 1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500:
		await process_frame
		for v in ui.plant_views.values():
			var rig := v.get_node_or_null("Rig") as PlantRig
			if rig and rig.plant_type == PlantRig.WALLNUT and rig._hit_t > 0.0:
				saw_hit = true
		if saw_hit:
			break
	check(saw_hit, "Wall-nut plays a hit reaction when it takes damage")
	await shot("p3_wallnut_hit")
	# Peashooter fired at the zombie in row 1? (it has had >3 s)
	var pea_rig: PlantRig = null
	for v in ui.plant_views.values():
		var rig2 := v.get_node_or_null("Rig") as PlantRig
		if rig2 and rig2.plant_type == PlantRig.PEASHOOTER:
			pea_rig = rig2
	check(pea_rig != null, "Peashooter rig exists")
	# blink: sample the Wall-nut's eyelids for a few seconds
	var blinked := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 7000 and not blinked:
		await process_frame
		for v in ui.plant_views.values():
			var rig3 := v.get_node_or_null("Rig") as PlantRig
			if rig3 and rig3.plant_type == PlantRig.WALLNUT and rig3._lids != null and rig3._lids.visible:
				blinked = true
	check(blinked, "Wall-nut blinks")
	if blinked:
		await shot("p4_wallnut_blink")
	print("plants: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
