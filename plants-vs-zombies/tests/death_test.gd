extends SceneTree
## Zombie death animations in the running game (windowed).
##   ordinary kill (peas): Regular / Conehead / Buckethead lose their head (a flying head; a helmet is attached only if it
##   was still on), Imp too; Lawn Mower kill: stronger throw to the right, an intact helmet stays on the head; Jalapeno
##   and Squash kills and the Gargantuar keep the plain fall; pause freezes the head; nothing is left behind afterwards;
##   the final zombie does not delay Victory.
## Every section runs in a FRESH match: the core starts its waves by itself after ~40 s of its own clock, and a stray wave
## zombie would pollute the counts.
## Run:  Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/death_test.gd -- <out_dir>

const PEA := 0
const WALLNUT := 2
const JALAPENO := 3
const SQUASH := 4

# loaded at run time: zombie_view.gd uses the Audio autoload, which does not exist yet when this script compiles
var ZV: GDScript
var out_dir := ""
var failures := 0
var checks := 0
var main: Node
var core: Node
var ui: Control


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


func new_match(label: String) -> void:
	if main != null:
		main.queue_free()
		await process_frame
		await process_frame
	root.get_node("Session").begin_match("Death_" + label)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(4.2).timeout                  # Start Text intro
	core = main.get_node("GameController")
	ui = main.get_node("Maingame")
	core.add_sun(9000)


func flying_heads() -> Array:
	return main.find_children("FlyingHead", "Node2D", true, false)


func zombies_in_row(row: int) -> int:
	return core.get_zombies_data().filter(func(z): return int(z["row"]) == row).size()


## Advance the core in small steps (like the real game) until `cond` holds or `seconds` of real time pass.
func run_until(cond: Callable, seconds: float, step := 1.0 / 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		core.advance_time(step)
		await process_frame
		if cond.call():
			return true
	return cond.call()


func wait_head(seconds := 1.0) -> Node2D:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		var h := flying_heads()
		if not h.is_empty():
			return h[0]
		await process_frame
	return null


func no_head_for(frames: int) -> bool:
	for i in frames:
		await process_frame
		if not flying_heads().is_empty():
			return false
	return true


func settle() -> void:
	await create_timer(1.6).timeout


func shooters(row: int, n: int) -> void:
	for c in n:
		core.place_plant(row, c, PEA)


func _run() -> void:
	ZV = load("res://zombie_view.gd")

	# ================= 1. ordinary kills (peas): Regular, Conehead, Buckethead
	await new_match("peas")
	shooters(0, 3)
	core.debug_spawn_enemy(0, 0, 5.0)
	check(await run_until(func(): return zombies_in_row(0) == 0, 40.0), "the Regular zombie was shot dead")
	var head := await wait_head()
	check(head != null, "ordinary kill: a flying head appears")
	if head != null:
		check(head.get_child_count() == 1, "Regular: head only, no helmet (%d children)" % head.get_child_count())
		var x0 := head.global_position.x
		await create_timer(0.3).timeout
		await shot("regular_head_mid")
		check(is_instance_valid(head) and head.global_position.x < x0 - 3.0, "the head moves forward (to the left)")
		check(flying_heads().size() == 1, "exactly one flying head (no duplicate effect)")
	await settle()
	check(flying_heads().is_empty(), "the head is gone after the animation")
	check(ui.entity_layer.get_children().filter(func(n): return n.get_script() == ZV).is_empty(), "the zombie view was freed")
	check(ui.zombie_views.is_empty(), "no zombie views are tracked")

	shooters(1, 6)
	core.debug_spawn_enemy(1, 1, 6.5)
	await run_until(func(): return zombies_in_row(1) == 0, 40.0)
	head = await wait_head()
	check(head != null and head.get_child_count() == 1, "Conehead: its cone broke earlier, so the head carries no helmet")
	await settle()
	check(flying_heads().is_empty(), "Conehead: head removed afterwards")

	await new_match("bucket")                        # a fresh clock: the long Buckethead fight must finish before any wave
	shooters(2, 6)
	core.debug_spawn_enemy(2, 2, 7.5)
	await run_until(func(): return zombies_in_row(2) == 0, 60.0)
	head = await wait_head()
	check(head != null and head.get_child_count() == 1, "Buckethead: no helmet left to drop on its head")
	await settle()
	check(flying_heads().is_empty(), "Buckethead: head removed afterwards")

	# ================= 2. Lawn Mower kills: stronger throw to the right, an intact helmet stays on the head
	await new_match("mower")
	core.debug_spawn_enemy(1, 3, 1.2)                # Conehead, armor intact, walks into the mower (seen on screen first)
	check(await run_until(func(): return zombies_in_row(3) == 0, 30.0), "the mower killed the Conehead")
	head = await wait_head()
	check(head != null, "mower kill: a flying head appears")
	if head != null:
		check(head.get_child_count() == 2, "mower kill on an intact Conehead: the cone stays on the flying head (%d children)" % head.get_child_count())
		var mx0 := head.global_position.x
		await create_timer(0.35).timeout
		await shot("mower_head_mid")
		check(is_instance_valid(head) and head.global_position.x > mx0 + 15.0, "mower kill: the head is thrown to the right")
		check(flying_heads().size() == 1, "one flying head only")
	await settle()
	check(flying_heads().is_empty(), "mower kill: nothing left behind")
	core.debug_spawn_enemy(2, 4, 1.2)                # Buckethead, armor intact
	await run_until(func(): return zombies_in_row(4) == 0, 30.0)
	head = await wait_head()
	check(head != null and head.get_child_count() == 2, "mower kill on an intact Buckethead: the bucket stays on the head")
	await settle()
	check(flying_heads().is_empty(), "mower kill (bucket): nothing left behind")

	# ================= 3. Jalapeno and Squash kills keep the plain fall
	await new_match("burn")
	core.place_plant(0, 4, JALAPENO)
	core.debug_spawn_enemy(0, 0, 6.5)
	check(await run_until(func(): return zombies_in_row(0) == 0, 15.0), "the Jalapeno killed the zombie")
	check(await no_head_for(60), "Jalapeno kill: no flying head (existing animation)")
	await settle()
	core.place_plant(4, 3, SQUASH)
	core.debug_spawn_enemy(0, 4, 4.2)
	check(await run_until(func(): return zombies_in_row(4) == 0, 15.0), "the Squash killed the zombie")
	check(await no_head_for(60), "Squash kill: no flying head (existing animation)")
	await settle()

	# ================= 4. Imp, Gargantuar, pause, clean-up
	await new_match("units")
	var baseline_tweens := get_processed_tweens().size()
	var imp = ZV.new()
	ui.entity_layer.add_child(imp)
	imp.position = Vector2(700, 300)
	imp.apply_data({"kind": 2, "row": 2, "column": 5.0, "armor": 0, "health": 100, "max_health": 100})
	var reg = ZV.new()
	ui.entity_layer.add_child(reg)
	reg.position = Vector2(500, 300)
	reg.apply_data({"kind": 0, "row": 2, "column": 3.0, "armor": 0, "health": 200, "max_health": 200})
	await process_frame
	imp.die("")
	reg.die("")
	await process_frame
	var heads := flying_heads()
	check(heads.size() == 2, "Imp and Regular each lose their head (%d)" % heads.size())
	if heads.size() == 2:
		var sizes := heads.map(func(h): return (h.get_child(0) as Sprite2D).texture.get_size().x * h.scale.x)
		check(minf(sizes[0], sizes[1]) < maxf(sizes[0], sizes[1]) * 0.9, "the Imp's head is drawn smaller than the Regular's (%s px)" % [sizes])
	await shot("imp_and_regular")
	await settle()
	check(flying_heads().is_empty(), "Imp / Regular heads cleaned up")
	var garg = ZV.new()
	ui.entity_layer.add_child(garg)
	garg.position = Vector2(600, 300)
	garg.apply_data({"kind": 1, "row": 2, "column": 4.0, "armor": 0, "health": 2000, "max_health": 2000})
	await process_frame
	garg.die("")
	check(await no_head_for(20), "Gargantuar keeps its head (heavy fall only)")
	check(garg.puppet._head.visible, "the Gargantuar's head stays on its body")
	await settle()

	shooters(3, 3)
	core.debug_spawn_enemy(0, 3, 4.0)
	await run_until(func(): return zombies_in_row(3) == 0, 40.0)
	head = await wait_head()
	check(head != null, "a head to pause")
	if head != null:
		core.pause_game()
		await process_frame
		await process_frame
		var p0 := head.global_position
		var r0 := head.rotation
		await create_timer(0.5).timeout
		check(head.global_position.is_equal_approx(p0) and is_equal_approx(head.rotation, r0), "pause: the flying head does not move")
		await shot("paused_head")
		core.resume_game()
		await create_timer(0.2).timeout
		check(not (is_instance_valid(head) and head.global_position.is_equal_approx(p0)), "resume: the head continues")
	await settle()
	check(flying_heads().is_empty(), "after pause / resume the head is cleaned up")
	check(ui.zombie_views.is_empty(), "no zombie views are tracked")
	check(get_processed_tweens().size() <= baseline_tweens + 3, "no stray tweens remain (%d vs baseline %d)" % [get_processed_tweens().size(), baseline_tweens])

	# ================= 5. the final zombie does not delay Victory
	await new_match("victory")
	core.begin_waves()
	for row in 5:
		for col in range(0, 7):
			core.place_plant(row, col, PEA)
		core.place_plant(row, 7, WALLNUT)
	var t := 0.0
	while core.get_state() == 1 and t < 900.0:
		core.advance_time(5.0)
		t += 5.0
		await process_frame
	check(core.get_state() == 3, "Victory reached (state %d, zombies left %d)" % [core.get_state(), core.get_zombies_data().size()])
	var t_win := Time.get_ticks_msec()
	await process_frame
	await process_frame
	await create_timer(0.4).timeout
	check(ui._next_buttons.size() > 0 and ui._next_buttons[0].is_visible_in_tree(), "the Victory screen with NEXT is up right away (%d ms)" % (Time.get_ticks_msec() - t_win))
	await shot("victory_after_deaths")
	await create_timer(1.6).timeout
	check(flying_heads().is_empty(), "no flying heads linger after Victory")

	print("death: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
