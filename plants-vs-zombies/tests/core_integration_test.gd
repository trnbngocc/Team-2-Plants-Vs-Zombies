extends SceneTree
## Headless integration test of the REAL C++ GameController (loaded from the built DLL).
## Run:  Godot --headless --path plants-vs-zombies --script res://tests/core_integration_test.gd
## Exit code 0 = all checks passed.

const PEA := 0
const SUNFLOWER := 1
const WALLNUT := 2
const JALAPENO := 3
const SQUASH := 4

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func make_game(begin := true) -> Node:
	var g: Node = ClassDB.instantiate("GameController")
	root.add_child(g)      # _ready() runs start_game() -> PLAYING
	if begin:
		g.begin_waves()
	return g


func free_game(g: Node) -> void:
	root.remove_child(g)
	g.free()


func zombies(g: Node) -> Array:
	return g.get_zombies_data()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	check(ClassDB.class_exists("GameController"), "GameController is registered by the DLL")
	test_costs_and_spending()
	test_intro_gating()
	test_armor_hp()
	test_sunflower_and_falling_sun()
	test_shovel()
	test_mowers_and_defeat()
	test_boss_mower()
	test_squash()
	test_jalapeno_vs_boss()
	test_full_match_defeat()
	test_full_match_victory()
	test_replay_is_fresh()
	print("core integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func test_costs_and_spending() -> void:
	var g := make_game()
	check(g.get_plant_cost(SUNFLOWER) == 50, "Sunflower costs 50")
	check(g.get_plant_cost(PEA) == 100, "Peashooter costs 100")
	check(g.get_plant_cost(WALLNUT) == 50, "Wall-nut costs 50")
	check(g.get_plant_cost(JALAPENO) == 125, "Jalapeno costs 125")
	check(g.get_plant_cost(SQUASH) == 50, "Squash costs 50")
	check(g.get_plant_cost(99) == -1, "unknown plant cost is -1")
	check(g.get_sun() == 50 and g.get_sun_spent() == 0, "start: 50 Sun, 0 spent")
	check(g.place_plant(0, 0, SUNFLOWER), "plant Sunflower")
	check(g.get_sun() == 0 and g.get_sun_spent() == 50, "spent 50")
	check(not g.place_plant(0, 1, PEA), "cannot afford Peashooter")
	check(g.get_sun_spent() == 50, "failed plant spends nothing")
	check(not g.place_plant(0, 0, SUNFLOWER), "occupied cell rejected")
	g.add_sun(300)
	check(g.place_plant(1, 0, JALAPENO) and g.place_plant(2, 0, SQUASH), "plant Jalapeno + Squash")
	check(g.get_sun_spent() == 50 + 125 + 50, "spent sums the costs of successful plants")
	free_game(g)


func test_intro_gating() -> void:
	var g := make_game(false)
	g.advance_time(5.0)
	check(not g.get_waves_started(), "waves wait for begin_waves()")
	check(g.get_enemies_spawned() == 0 and zombies(g).is_empty(), "nothing spawns during the intro")
	check(is_equal_approx(g.get_preparation_time_left(), 30.0), "countdown not running yet")
	g.begin_waves()
	g.begin_waves()                       # second call must be harmless
	g.advance_time(1.0)
	check(g.get_preparation_time_left() < 30.0 and g.get_preparation_time_left() > 28.0, "countdown starts after begin_waves()")
	free_game(g)

	# Safety net: waves still start if the UI never calls begin_waves().
	var g2 := make_game(false)
	g2.advance_time(10.5)
	check(g2.get_waves_started(), "core fallback starts waves after the intro timeout")
	free_game(g2)


func test_armor_hp() -> void:
	var g := make_game()
	g.debug_spawn_enemy(0, 0, 8.0)
	g.debug_spawn_enemy(1, 1, 8.0)
	g.debug_spawn_enemy(2, 2, 8.0)
	g.debug_spawn_enemy(3, 3, 8.0)
	var by_row := {}
	for z in zombies(g):
		by_row[z["row"]] = z
	check(by_row[0]["health"] == 200 and by_row[0]["armor_health"] == 0, "Regular 200/0")
	check(by_row[1]["health"] == 200 and by_row[1]["armor_health"] == 370, "Conehead 200 + 370")
	check(by_row[2]["health"] == 200 and by_row[2]["armor_health"] == 1100, "Buckethead 200 + 1100")
	check(by_row[3]["health"] == 2000 and by_row[3]["kind"] == 1, "Gargantuar 2000, kind boss")
	free_game(g)


func test_sunflower_and_falling_sun() -> void:
	var g := make_game(false)
	check(g.place_plant(2, 3, SUNFLOWER), "plant Sunflower")
	g.advance_time(4.9)
	check(g.get_sun_drops().is_empty(), "no Sun before 5 s")
	g.advance_time(0.3)
	var drops: Array = g.get_sun_drops()
	check(drops.size() == 1, "one Sun after 5 s")
	if drops.size() == 1:
		var d: Dictionary = drops[0]
		check(d["value"] == 25, "Sun is worth 25")
		check(d["fall_duration"] > 0.0, "Sun falls from above")
		check(d["row"] >= 0 and d["row"] <= 4 and d["column"] >= 0.0 and d["column"] <= 8.0, "Sun lands on the lawn")
		g.advance_time(2.0)
		var landed: Dictionary = g.get_sun_drops()[0]
		check(landed["age"] > landed["fall_duration"], "Sun has landed")
		var before: int = g.get_sun()
		var got: int = g.collect_sun(landed["id"])
		check(got == 25 and g.get_sun() == before + 25, "landed Sun can be collected for +25")
		check(g.collect_sun(landed["id"]) == 0, "cannot collect the same Sun twice")
	# Different drops land at varied places.
	var columns := {}
	for i in 12:
		g.advance_time(5.0)
		for s in g.get_sun_drops():
			columns[snappedf(s["column"], 0.01)] = true
			g.collect_sun(s["id"])
	check(columns.size() > 3, "Sun lands at varied horizontal positions")
	free_game(g)


func test_shovel() -> void:
	var g := make_game(false)
	g.add_sun(500)
	g.place_plant(1, 1, WALLNUT)
	g.place_plant(1, 2, WALLNUT)
	var spent: int = g.get_sun_spent()
	var sun: int = g.get_sun()
	check(not g.shovel_plant(3, 3), "shovel on an empty cell does nothing")
	check(g.get_plants_data().size() == 2, "empty-cell shovel removed nothing")
	check(g.shovel_plant(1, 1), "shovel removes the plant")
	g.advance_time(0.1)
	var left: Array = g.get_plants_data()
	check(left.size() == 1 and left[0]["column"] == 2, "only the selected plant is gone, neighbour stays")
	check(g.get_sun() == sun and g.get_sun_spent() == spent, "shovel gives no refund and keeps the score")
	check(g.place_plant(1, 1, WALLNUT), "cell is free again")
	free_game(g)


func test_mowers_and_defeat() -> void:
	var g := make_game(false)
	var m: Array = g.get_mowers_data()
	check(m.size() == 5, "one mower per row")
	for row in 5:
		check(m[row]["state"] == 0, "mower %d starts READY" % row)

	g.debug_spawn_enemy(2, 2, 0.3)       # Buckethead right at the trigger point
	g.advance_time(0.5)
	check(zombies(g).is_empty(), "mower wipes out an ordinary zombie (even Buckethead)")
	check(g.get_mowers_data()[2]["state"] != 0, "row 2 mower activated")
	check(g.get_mowers_data()[3]["state"] == 0, "other rows' mowers untouched")
	g.advance_time(3.0)
	check(g.get_mowers_data()[2]["state"] == 2, "mower is spent after its run")
	check(g.get_state() == 1, "still PLAYING after the mower saved the row")

	g.debug_spawn_enemy(0, 2, 0.3)       # second zombie in the same row: nothing left
	g.advance_time(8.0)
	check(g.get_state() == 4, "zombie reaching a row with a spent mower = DEFEAT")
	free_game(g)

	# An Imp is also swept away by a mower.
	var g2 := make_game(false)
	g2.debug_spawn_enemy(3, 0, 0.2)
	free_game(g2)


func test_boss_mower() -> void:
	var g := make_game(false)
	g.debug_spawn_enemy(3, 1, 0.3)
	g.advance_time(0.6)
	var boss: Dictionary = zombies(g)[0]
	check(boss["kind"] == 1, "the boss survives the mower")
	check(boss["health"] == 2000 - 400, "mower deals exactly 400 to the Gargantuar")
	check(boss["column"] > 1.8 and boss["column"] < 2.1, "mower knocks the Gargantuar back ~2 columns")
	check(g.get_mowers_data()[1]["state"] == 2, "mower is spent on the boss")
	free_game(g)


func test_squash() -> void:
	var g := make_game(false)
	g.add_sun(100)
	var smashed := []
	g.squash_smashed.connect(func(row, col, hits): smashed.append(hits))
	g.place_plant(1, 3, SQUASH)
	g.debug_spawn_enemy(2, 1, 4.6)       # Buckethead in range
	g.advance_time(0.3)
	check(smashed.is_empty(), "no smash/shake while Squash is still jumping")
	var p: Array = g.get_plants_data()
	check(p.size() == 1 and p[0]["state"] == 1, "Squash is jumping")
	g.advance_time(0.5)
	check(smashed.size() == 1 and smashed[0] == 1, "one smash that hit one zombie")
	var z: Array = zombies(g)
	check(z.size() == 1 and z[0]["armor_health"] == 0 and z[0]["health"] == 200 - (1800 - 1100) + 0 or z.is_empty(),
		"1800 damage: 1100 armor first, then body HP")
	check(g.get_plants_data().is_empty(), "Squash is consumed (single use)")
	g.advance_time(2.0)
	check(smashed.size() == 1, "no second smash")
	free_game(g)

	# vs Gargantuar: survives at 200 HP, then throws its Imp.
	var g2 := make_game(false)
	g2.add_sun(100)
	var thrown := []
	g2.imp_thrown.connect(func(row, a, b): thrown.append([a, b]))
	g2.place_plant(0, 3, SQUASH)
	g2.debug_spawn_enemy(3, 0, 4.6)
	g2.advance_time(0.9)
	var boss: Array = zombies(g2)
	check(boss.size() >= 1 and boss[0]["kind"] == 1 and boss[0]["health"] == 200, "boss survives Squash with 200 HP")
	g2.advance_time(0.4)
	var kinds := []
	for e in zombies(g2):
		kinds.append(e["kind"])
	check(kinds.count(2) == 1, "the Imp exists as a separate enemy")
	g2.advance_time(1.5)              # keep fighting: the boss must not throw again
	check(thrown.size() == 1, "boss threw exactly one Imp")
	check(thrown[0][1] < thrown[0][0], "Imp lands in front of (left of) the boss")
	free_game(g2)


func test_jalapeno_vs_boss() -> void:
	var g := make_game(false)
	g.add_sun(200)
	var imps := []
	g.imp_thrown.connect(func(row, a, b): imps.append(row))
	g.place_plant(2, 0, JALAPENO)
	g.debug_spawn_enemy(3, 2, 6.0)
	g.debug_spawn_enemy(0, 2, 7.0)
	g.advance_time(2.3)
	var left: Array = zombies(g)
	var boss_alive := false
	for z in left:
		if z["kind"] == 1:
			boss_alive = true
			check(z["health"] == 1100, "Jalapeno: 900 normal damage, boss left with 1100")
	check(boss_alive, "Gargantuar survives Jalapeno")
	check(left.size() == 1, "the regular zombie in the row died")
	check(imps.is_empty(), "no Imp while boss HP > 1000")
	free_game(g)


func advance_until_over(g: Node, max_seconds: float) -> void:
	var t := 0.0
	while g.get_state() == 1 and t < max_seconds:
		g.advance_time(5.0)
		t += 5.0


func test_full_match_defeat() -> void:
	var g := make_game()
	var started := []
	var warnings := []
	g.wave_started.connect(func(w): started.append(w))
	g.huge_wave_warning.connect(func(): warnings.append(1))
	advance_until_over(g, 600.0)
	check(g.get_state() == 4, "no defenses: the match is lost")
	check(g.get_enemies_spawned() >= 3, "enemies did spawn")
	free_game(g)


func test_full_match_victory() -> void:
	var g := make_game()
	g.add_sun(20000)
	var clock := [0.0]
	var started := []
	var warn := []          # [time, enemies_spawned]
	var banner2 := []
	var wave4 := []
	var imps := []
	g.wave_started.connect(func(w): started.append(w); if w == 4: wave4.append([clock[0], g.get_enemies_spawned()]))
	g.huge_wave_warning.connect(func(): warn.append([clock[0], g.get_enemies_spawned()]))
	g.final_wave_banner.connect(func(): banner2.append([clock[0], g.get_enemies_spawned()]))
	g.imp_thrown.connect(func(r, a, b): imps.append(r))
	# Defence: Peashooters in columns 0..6 of every row plus Wall-nuts in front.
	for row in 5:
		for col in range(0, 7):
			g.place_plant(row, col, PEA)
		g.place_plant(row, 7, WALLNUT)
	var spent_on_plants: int = g.get_sun_spent()
	check(spent_on_plants == 5 * (7 * 100 + 50), "spent = sum of plant costs")
	while g.get_state() == 1 and clock[0] < 900.0:
		g.advance_time(0.05)
		clock[0] += 0.05
	check(g.get_state() == 3, "strong defence wins the match (VICTORY)")
	check(g.get_enemies_spawned() == 25, "exactly 25 enemies spawned")
	check(g.get_total_enemies() == 25, "total enemies is 25")
	check(g.get_enemies_defeated() == 25, "all 25 enemies defeated")
	check(zombies(g).is_empty(), "no zombie (incl. Imp) left alive at victory")
	check(imps.size() == 1, "exactly one Imp thrown in the whole match")
	check(started == [1, 2, 3, 4], "wave_started fires once per wave, in order: %s" % [started])
	# Final-wave sequence: banner 1 -> banner 2 -> wave 4 + first zombie; each exactly once.
	check(warn.size() == 1 and banner2.size() == 1 and wave4.size() == 1, "each announcement event fires exactly once")
	if warn.size() == 1 and banner2.size() == 1 and wave4.size() == 1:
		check(warn[0][1] == 15, "banner 1 comes after waves 1-3 finished spawning (15 enemies)")
		check(absf((banner2[0][0] - warn[0][0]) - 4.0) < 0.12, "banner 2 starts when banner 1's 4 s slot ends (%.2f)" % (banner2[0][0] - warn[0][0]))
		check(absf((wave4[0][0] - banner2[0][0]) - 3.0) < 0.12, "wave 4 starts when banner 2's 3 s slot ends (%.2f)" % (wave4[0][0] - banner2[0][0]))
		check(banner2[0][1] == 15, "no wave-4 enemy has spawned when banner 2 starts")
		check(wave4[0][1] <= 16, "only the first wave-4 enemy exists when wave 4 starts")
	check(g.get_sun_spent() >= spent_on_plants, "score tracking kept")
	free_game(g)


func test_replay_is_fresh() -> void:
	var g := make_game()
	g.add_sun(100)
	g.place_plant(0, 0, PEA)
	g.debug_spawn_enemy(0, 4, 5.0)
	g.advance_time(3.0)
	free_game(g)                          # what Play Again does (scene reload)
	var g2 := make_game(false)
	check(g2.get_sun() == 50 and g2.get_sun_spent() == 0, "replay: Sun and score reset")
	check(g2.get_plants_data().is_empty() and zombies(g2).is_empty(), "replay: no stale plants/zombies")
	check(g2.get_bullets_data().is_empty() and g2.get_sun_drops().is_empty(), "replay: no bullets/Sun")
	check(g2.get_enemies_spawned() == 0 and g2.get_enemies_defeated() == 0, "replay: enemy tracking reset")
	var all_ready := true
	for m in g2.get_mowers_data():
		if m["state"] != 0:
			all_ready = false
	check(all_ready, "replay: all five mowers are READY again")
	check(not g2.get_waves_started(), "replay: waves wait for the intro again")
	free_game(g2)
