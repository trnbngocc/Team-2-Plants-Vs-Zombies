extends SceneTree
## Real-time check of the final-wave announcement sequence in the running game (windowed):
##   banner "A huge wave..." -> it ends -> banner "Final Wave" -> it ends -> wave-4 zombies spawn.
## Every frame it samples which banners are on screen and the core's enemy count, then checks
## they never overlap, appear once each, and that no wave-4 zombie exists while a banner is up.
## Also checks pause / resume in the middle of a banner.
## Run:
##   Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/final_wave_sequence_test.gd -- <out_dir>

const PEA := 0
const WALLNUT := 2

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
	await process_frame
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func banners(ui: Control) -> Array:
	var found := []
	for c in ui.fx_layer.get_children():
		# Godot renames a second node with the same name ("@TextureRect@5"), so identify banners by texture.
		if c is TextureRect and not c.is_queued_for_deletion() and c.texture != null 				and "wave_text" in c.texture.resource_path:
			found.append(c)
	return found


func _run() -> void:
	var session := root.get_node("Session")
	session.begin_match("SeqTester")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	var core: Node = main.get_node("GameController")
	var ui: Control = main.get_node("Maingame")
	await create_timer(4.6).timeout             # Start Text intro finishes, waves begin
	check(core.get_waves_started(), "waves started after the intro")

	# Strong defence so the match survives until wave 3 ends; fast-forward the core to just that point.
	core.add_sun(20000)
	for row in 5:
		for col in range(0, 7):
			core.place_plant(row, col, PEA)
		core.place_plant(row, 7, WALLNUT)
	var events := []        # [name, ms]
	core.huge_wave_warning.connect(func(): events.append(["banner1_signal", Time.get_ticks_msec()]))
	core.final_wave_banner.connect(func(): events.append(["banner2_signal", Time.get_ticks_msec()]))
	core.wave_started.connect(func(w): if w == 4: events.append(["wave4_signal", Time.get_ticks_msec()]))
	var guard := 0
	while core.get_enemies_spawned() < 15 and core.get_state() == 1 and guard < 4000:
		core.advance_time(0.25)
		guard += 1
	# Step frame by frame near the event so the UI banner starts when the core event fires (no overshoot).
	guard = 0
	while events.is_empty() and core.get_state() == 1 and guard < 2000:
		core.advance_time(1.0 / 60.0)
		guard += 1
	check(events.size() == 1 and events[0][0] == "banner1_signal", "fast-forwarded to the start of the final-wave sequence")
	var spawned_before: int = core.get_enemies_spawned()
	check(spawned_before == 15, "15 enemies from waves 1-3 have spawned when banner 1 starts (got %d)" % spawned_before)

	# ---- observe in real time ----
	var timeline := []      # per-frame: [ms, n_banners, texture_path, enemies_spawned]
	var paused_done := false
	var t_end := Time.get_ticks_msec() + 12000
	var shot1 := false
	var shot2 := false
	while Time.get_ticks_msec() < t_end:
		await process_frame
		var bs := banners(ui)
		var tex_path := ""
		if bs.size() > 0:
			tex_path = (bs[0] as TextureRect).texture.resource_path
		timeline.append([Time.get_ticks_msec(), bs.size(), tex_path, core.get_enemies_spawned()])
		if bs.size() > 1:
			check(false, "two banners on screen at once")
		var elapsed: int = Time.get_ticks_msec() - int(events[0][1])
		# pause in the middle of banner 1
		if not paused_done and elapsed > 1500 and bs.size() == 1:
			paused_done = true
			ui._on_pause_pressed()
			await create_timer(0.3).timeout
			var b := banners(ui)[0] as TextureRect
			var snap_alpha := b.modulate.a
			var snap_scale := b.scale
			var snap_events := events.size()
			await shot("seq_1_banner1_paused")
			await create_timer(1.5).timeout
			var b2 := banners(ui)[0] as TextureRect
			check(is_equal_approx(b2.modulate.a, snap_alpha) and b2.scale == snap_scale, "banner 1 is frozen while paused")
			check(events.size() == snap_events, "no sequence event fires while paused")
			ui._on_resume_pressed()
			t_end += 1800
		if not shot1 and elapsed > 800 and bs.size() == 1 and not paused_done:
			shot1 = true
			await shot("seq_0_banner1")
		if events.size() >= 2 and not shot2 and bs.size() == 1 and "final_wave" in tex_path and Time.get_ticks_msec() - events[1][1] > 700:
			shot2 = true
			await shot("seq_2_banner2")
		if events.size() >= 3 and Time.get_ticks_msec() - events[2][1] > 1500:
			break

	check(events.size() == 3, "all three sequence events fired (got %d)" % events.size())
	if events.size() == 3:
		check(events[0][0] == "banner1_signal" and events[1][0] == "banner2_signal" and events[2][0] == "wave4_signal", "events are in the required order")
	# Banner intervals from the per-frame samples.
	var b1_first := -1
	var b1_last := -1
	var b2_first := -1
	var b2_last := -1
	var wave4_first_spawn := -1
	for s in timeline:
		if "huge_wave" in s[2]:
			if b1_first < 0:
				b1_first = s[0]
			b1_last = s[0]
		if "final_wave" in s[2]:
			if b2_first < 0:
				b2_first = s[0]
			b2_last = s[0]
		if s[3] > 15 and wave4_first_spawn < 0:
			wave4_first_spawn = s[0]
	check(b1_first >= 0 and b2_first >= 0, "both banners were displayed")
	check(b1_last < b2_first, "banner 1 is completely gone before banner 2 appears (no overlap)")
	check(b2_last < wave4_first_spawn, "banner 2 is completely gone before the first wave-4 zombie spawns")
	check(wave4_first_spawn >= 0, "wave-4 zombies do spawn after the sequence")
	var shown_b1 := 0
	var shown_b2 := 0
	var prev1 := false
	var prev2 := false
	for s in timeline:
		var is1: bool = "huge_wave" in s[2]
		var is2: bool = "final_wave" in s[2]
		if is1 and not prev1:
			shown_b1 += 1
		if is2 and not prev2:
			shown_b2 += 1
		prev1 = is1
		prev2 = is2
	check(shown_b1 == 1 and shown_b2 == 1, "each banner is displayed exactly once (%d, %d)" % [shown_b1, shown_b2])
	await create_timer(1.0).timeout
	check(banners(ui).is_empty(), "no banner is left on screen afterwards")
	print("sequence: %d checks, %d failures | banner1 %.2fs, gap %.2fs, banner2 %.2fs, gap to spawn %.2fs" % [checks, failures,
		(b1_last - b1_first) / 1000.0, (b2_first - b1_last) / 1000.0, (b2_last - b2_first) / 1000.0, (wave4_first_spawn - b2_last) / 1000.0])
	quit(1 if failures > 0 else 0)
