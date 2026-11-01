extends SceneTree
## Visual check driver: runs the real game scene in a window, drives it through the
## C++ core and saves screenshots. Not an assertion test - the PNGs are inspected by eye.
## Run (windowed, not --headless):
##   Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/visual_capture.gd -- <out_dir>

var out_dir := ""
var game: Node
var ui: Control


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://shots"
	call_deferred("_run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	DirAccess.make_dir_recursive_absolute(out_dir)
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	var session := root.get_node("Session")
	session.begin_match("Tester")

	var scene: PackedScene = load("res://scenes/main.tscn")
	var main := scene.instantiate()
	root.add_child(main)
	await wait(0.6)
	game = main.get_node("GameController")
	ui = main.get_node("Maingame")

	await shot("01_intro_start")
	await wait(1.0)
	await shot("02_start_text_ready")
	await wait(1.6)
	await shot("03_start_text_plant")
	await wait(2.5)
	print("waves started: ", game.get_waves_started())

	# Plants: one of each type + extra Sun to show the affordable state first.
	game.add_sun(1000)
	game.place_plant(0, 1, 1)   # Sunflower
	game.place_plant(1, 1, 0)   # Peashooter
	game.place_plant(2, 1, 2)   # Wall-nut
	game.place_plant(3, 1, 3)   # Jalapeno (fuse running)
	game.place_plant(4, 1, 4)   # Squash
	await wait(0.4)
	await shot("04_five_plants_seedbank")

	# Insufficient Sun state.
	game.add_sun(-1000 + 0)
	await wait(0.2)
	await shot("05_seedbank_after_spend")

	# Enemies on the lawn.
	game.debug_spawn_enemy(0, 0, 8.0)
	game.debug_spawn_enemy(1, 1, 7.0)
	game.debug_spawn_enemy(2, 2, 6.0)
	game.debug_spawn_enemy(3, 3, 8.0)
	game.debug_spawn_enemy(0, 4, 4.0)
	await wait(0.8)
	await shot("06_zombies_and_boss")

	# Announcements (the core fires them once; here we call the UI handlers to see the art).
	ui._on_huge_wave_warning()
	await wait(0.9)
	await shot("07_huge_wave_banner")
	await wait(4.5)
	ui._on_final_wave_banner()
	await wait(0.9)
	await shot("08_final_wave_banner")
	await wait(3.5)

	# Squash impact + Jalapeno fire (real core events).
	game.advance_time(1.2)
	await wait(0.1)
	await shot("09_after_effects")

	# Lawn alignment overlay: draw a marker at each cell centre through the UI's own mapping.
	var layer: Control = ui.entity_layer
	for row in 5:
		for col in 9:
			var dot := ColorRect.new()
			dot.color = Color(1, 0, 0, 0.9)
			dot.size = Vector2(6, 6)
			dot.position = ui._cell_center(float(row), float(col)) - dot.size * 0.5
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.z_index = 20
			layer.add_child(dot)
	await wait(0.2)
	await shot("10_cell_centres")
	quit(0)
