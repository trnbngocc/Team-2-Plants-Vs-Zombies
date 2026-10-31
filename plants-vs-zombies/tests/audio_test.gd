extends SceneTree
## Lawn Mower and Squash sounds in the running game (windowed, real audio device).
##   Squash: silent when planted / with nothing near / for another row; one cue when a zombie comes within about a cell
##           of its attack range (never restarted every tick); cancelled when the zombie leaves before the jump;
##           the attack itself is unchanged (it still jumps and smashes once).
##   Mower:  one sound per activation, started by the activation, stopped when the run ends, no overlap.
## Run:  Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/audio_test.gd -- <out_dir>

const SQUASH := 4
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


func wait_until(cond: Callable, seconds: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _run() -> void:
	var audio := root.get_node("Audio")
	var session := root.get_node("Session")
	session.begin_match("AudioTester")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(4.2).timeout                  # Start Text intro
	var core: Node = main.get_node("GameController")
	core.add_sun(5000)

	var alerts := []
	var cancels := []
	var smashes := []
	var mowers := []
	core.squash_alert.connect(func(r, c): alerts.append([r, c]))
	core.squash_alert_cancelled.connect(func(r, c): cancels.append([r, c]))
	core.squash_smashed.connect(func(r, c, h): smashes.append(h))
	core.mower_activated.connect(func(r): mowers.append(r))

	# ---------------- Squash: planting it and idling is silent
	check(core.place_plant(1, 3, SQUASH), "Squash planted")
	await create_timer(1.0).timeout
	check(alerts.is_empty() and audio.tracked_count() == 0, "planting Squash plays nothing")
	check(not audio.is_tracked_playing("squash_1_3"), "idle Squash is silent")
	# a zombie in another row, and one far away in its own row: still silent
	core.debug_spawn_enemy(0, 2, 4.0)
	core.debug_spawn_enemy(0, 1, 8.0)
	await create_timer(1.0).timeout
	check(alerts.is_empty() and audio.tracked_count() == 0, "zombies in another row / far away do not trigger it")

	# ---------------- Squash: a zombie comes within about a cell of the attack range
	var sound_started := false
	var alert_count_when_started := 0
	var jumped_before_sound := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000 and smashes.is_empty():
		await process_frame
		if not sound_started and audio.is_tracked_playing("squash_1_3"):
			sound_started = true
			alert_count_when_started = alerts.size()
			var plants: Array = core.get_plants_data()
			for p in plants:
				if int(p["row"]) == 1 and int(p["column"]) == 3 and int(p.get("state", 0)) == 1:
					jumped_before_sound = true
			await shot("squash_alert")
	check(sound_started, "the Squash cue plays when the zombie approaches")
	check(not jumped_before_sound, "the cue starts while Squash is still idle (before the jump)")
	check(alerts.size() == 1 and alerts[0] == [1, 3], "exactly one alert, for the right Squash (%s)" % [alerts])
	check(smashes.size() == 1 and smashes[0] == 1, "Squash then attacked normally and hit the zombie (%s)" % [smashes])
	await create_timer(1.5).timeout
	check(alerts.size() == 1 and audio.tracked_count() == 0, "the cue was not restarted and its voice was released")
	check(cancels.is_empty(), "no cancel when the attack happened")

	# ---------------- Squash: the zombie leaves (dies) before the attack -> the cue is cancelled
	alerts.clear()
	core.place_plant(3, 3, SQUASH)
	core.place_plant(3, 5, JALAPENO)                     # fuse 2 s, burns the whole row
	core.debug_spawn_enemy(0, 3, 5.2)                    # within detection (<= 5.5), outside attack (> 4.5)
	var got_alert := await wait_until(func(): return alerts.size() >= 1, 3.0)
	check(got_alert, "the cue starts for the approaching zombie")
	var cancelled := await wait_until(func(): return cancels.size() >= 1, 8.0)
	check(cancelled, "the zombie left before the attack: the cue is cancelled")
	await process_frame
	check(not audio.is_tracked_playing("squash_3_3") and audio.tracked_count() == 0, "no sound is left playing")
	check(smashes.size() == 1, "Squash did not attack an empty row")

	# ---------------- Lawn mower
	mowers.clear()
	var mower_audio_checks := {"max_players": 0, "played": false}
	core.debug_spawn_enemy(0, 4, 0.5)                    # reaches the mower trigger at once
	var activated := await wait_until(func(): return mowers.size() >= 1, 3.0)
	check(activated, "the mower of row 4 was activated by the zombie")
	var t1 := Time.get_ticks_msec()
	var saw_playing := false
	while Time.get_ticks_msec() - t1 < 4000:
		await process_frame
		if audio.is_tracked_playing("mower_4"):
			saw_playing = true
		if mowers.size() == 1 and saw_playing and Time.get_ticks_msec() - t1 == 400:
			pass
		mower_audio_checks["max_players"] = maxi(mower_audio_checks["max_players"], audio.tracked_count())
		if saw_playing and Time.get_ticks_msec() - t1 > 500 and not mower_audio_checks["played"]:
			mower_audio_checks["played"] = true
			await shot("mower_running")
	check(saw_playing, "the mower sound plays while it runs")
	check(mowers.count(4) == 1, "one activation event for the row-4 mower (%s)" % [mowers])
	check(mower_audio_checks["max_players"] <= 1, "never more than one mower voice (%d)" % mower_audio_checks["max_players"])
	check(audio.tracked_count() == 0 and not audio.is_tracked_playing("mower_4"), "the voice is released when the run ends")
	var mower_gone := true
	for d in core.get_mowers_data():
		if int(d["row"]) == 4 and int(d["state"]) != 2:
			mower_gone = false
	check(mower_gone, "the mower is spent after one use")

	# ---------------- pause keeps the cue paused, and leaving the match leaves nothing behind
	audio.play_tracked("mower_0", "mower")
	audio.set_gameplay_paused(true)
	check((audio._tracked["mower_0"] as AudioStreamPlayer).stream_paused, "pause pauses a tracked effect")
	audio.set_gameplay_paused(false)
	check(not (audio._tracked["mower_0"] as AudioStreamPlayer).stream_paused, "resume continues it")
	audio.play_tracked("mower_0", "mower")               # same key: replaced, not stacked
	check(audio.tracked_count() == 1, "the same key never stacks two voices")
	audio.stop_gameplay_audio()
	check(audio.tracked_count() == 0, "leaving gameplay stops tracked effects")

	print("audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
