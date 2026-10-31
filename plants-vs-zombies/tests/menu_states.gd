extends SceneTree
## Captures the menu with a button hovered, pressed and disabled (visual check of the interaction states).
## Run: Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/menu_states.gd -- <out_dir>
var out_dir := ""

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[0] if a.size() > 0 else "user://shots"
	call_deferred("_run")

func frames(n := 4) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await frames(3)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))

func mouse(c: Control, pressed = null) -> void:
	var pos: Vector2 = c.get_global_rect().get_center()
	if pressed == null:
		var mv := InputEventMouseMotion.new()
		mv.position = pos
		mv.global_position = pos
		Input.parse_input_event(mv)
	else:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(ev)
	await frames(3)

func _run() -> void:
	change_scene_to_file("res://scenes/menu.tscn")
	await frames(8)
	var m := current_scene
	var tick: TextureButton = m.tick_button
	var play: TextureButton = m.play_button
	var quit_b: TextureButton = m.quit_button
	await shot("normal")
	await mouse(quit_b)
	await shot("hover_quit")
	await mouse(tick)
	await shot("hover_tick")
	await mouse(tick, true)
	await shot("pressed_tick")
	await mouse(tick, false)
	await mouse(play)
	await shot("hover_play")
	for b in [tick, play, quit_b]:
		b.disabled = true
		b._refresh()
	await mouse(m.leaderboard_button)
	await shot("disabled_all")
	print("menu_states done")
	quit(0)
