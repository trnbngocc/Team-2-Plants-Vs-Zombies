extends SceneTree
## Pea projectile + impact effect, in the running game (windowed).
##   1. a pea that MISSES (its target dies mid-flight) leaves no splat
##   2. several peas hitting zombies in different rows each make exactly one splat, on the zombie, then it frees itself
##   3. the traveling pea uses the extracted sprite, undistorted
## Run:  Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/projectile_test.gd -- <out_dir>

const PEA := 0
const JALAPENO := 3

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


func impacts(ui: Control) -> Array:
	var found := []
	for c in ui.entity_layer.get_children():
		if c is PeaImpact and not c.is_queued_for_deletion():
			found.append(c)
	return found


func _run() -> void:
	var session := root.get_node("Session")
	session.begin_match("PeaTester")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(4.2).timeout                  # Start Text intro
	var core: Node = main.get_node("GameController")
	var ui: Control = main.get_node("Maingame")
	core.add_sun(3000)

	# ---------------- 3. the traveling sprite
	core.place_plant(0, 0, PEA)
	core.debug_spawn_enemy(0, 0, 8.4)
	var hits := [0]
	core.projectile_hit.connect(func(r, c): hits[0] += 1)
	var fired := [0]
	core.projectile_fired.connect(func(r, c): fired[0] += 1)
	var seen_sprite := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000 and not seen_sprite:
		core.advance_time(1.0 / 20.0)
		await process_frame
		for v in ui.bullet_views:
			if v.visible and v is TextureRect:
				var tr := v as TextureRect
				if tr.texture != null and tr.texture.resource_path.ends_with("projectiles/pea/pea.png"):
					seen_sprite = true
					var tsz := tr.texture.get_size()
					check(is_equal_approx(tr.size.x / tr.size.y, tsz.x / tsz.y), "the pea keeps its aspect ratio (%.2f)" % (tr.size.x / tr.size.y))
					await shot("pea_in_flight")
					break
	check(seen_sprite, "the traveling projectile is the extracted green pea sprite")
	# let this first pea land
	t0 = Time.get_ticks_msec()
	while hits[0] == 0 and Time.get_ticks_msec() - t0 < 6000:
		core.advance_time(1.0 / 30.0)
		await process_frame
	check(hits[0] == 1 and ui.impact_count == 1, "one real collision -> one splat (hits=%d, splats=%d)" % [hits[0], ui.impact_count])
	await process_frame
	check(impacts(ui).size() == 1, "the splat is on screen right after the hit")
	await shot("pea_impact")
	await create_timer(0.7).timeout
	check(impacts(ui).is_empty(), "the splat frees itself after its animation")

	# ---------------- 1. a miss: the target dies while the pea is still flying
	core.add_sun(3000)
	core.shovel_plant(0, 0)                           # stop the row-0 Peashooter so only this test row shoots
	for i in 40:                                      # let its last peas land / leave
		core.advance_time(1.0 / 20.0)
		await process_frame
	var splats_before: int = ui.impact_count
	var hits_before: int = hits[0]
	core.place_plant(3, 0, PEA)
	core.place_plant(3, 1, JALAPENO)                  # fuse 2 s: kills the zombie after the pea has been fired (1.4 s)
	core.debug_spawn_enemy(0, 3, 8.8)
	var fired_before: int = fired[0]
	var miss_fired := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		core.advance_time(1.0 / 20.0)
		await process_frame
		if fired[0] > fired_before:
			miss_fired = true
		if miss_fired and core.get_bullets_data().is_empty() and core.get_zombies_data().filter(func(z): return z["row"] == 3).is_empty():
			break
	check(miss_fired, "the Peashooter fired at the zombie")
	check(hits[0] == hits_before and ui.impact_count == splats_before, "a pea that missed made no hit and no splat (hits +%d, splats +%d)" % [hits[0] - hits_before, ui.impact_count - splats_before])

	# ---------------- 2. several peas at once
	hits_before = hits[0]
	splats_before = ui.impact_count
	for row in [1, 2, 4]:
		core.place_plant(row, 0, PEA)
		core.debug_spawn_enemy(0, row, 7.0 + 0.4 * row)
	var max_active := 0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000 and hits[0] - hits_before < 3:
		core.advance_time(1.0 / 30.0)
		await process_frame
		max_active = maxi(max_active, ui.bullet_views.filter(func(v): return v.visible).size())
	check(hits[0] - hits_before == 3, "three peas, three hits (%d)" % (hits[0] - hits_before))
	check(ui.impact_count - splats_before == 3, "exactly one splat per hit (%d)" % (ui.impact_count - splats_before))
	await shot("pea_impacts_many")
	await create_timer(0.8).timeout
	check(impacts(ui).is_empty(), "every splat freed itself")
	print("projectile: %d checks, %d failures (max simultaneous peas %d)" % [checks, failures, max_active])
	quit(1 if failures > 0 else 0)
