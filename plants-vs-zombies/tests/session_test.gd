extends SceneTree
## Headless test of session.gd: username validation, one entry per username, restart updates that entry,
## ending the session keeps the name taken, and the in-memory (session-only) leaderboard.
## Run:  Godot --headless --path plants-vs-zombies --script res://tests/session_test.gd

var failures := 0
var checks := 0


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func fresh_session() -> Node:
	return load("res://session.gd").new()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var s := fresh_session()
	check(s.records.is_empty(), "a new session starts with an empty leaderboard")

	# ---- validation ----
	check(not s.validate_username("")["ok"], "empty rejected")
	check(not s.validate_username("   \t ")["ok"], "whitespace-only rejected")
	check(s.validate_username("")["error"] == "Please enter a username", "empty error text")
	var padded: Dictionary = s.validate_username("   Alice  ")
	check(padded["ok"] and padded["name"] == "Alice", "leading/trailing spaces are trimmed")
	check(not s.validate_username("x".repeat(17))["ok"], "17 characters rejected")
	check(s.validate_username("x".repeat(16))["ok"], "16 characters accepted")

	# ---- first match creates the player's entry, once ----
	s.begin_match("Alice")
	check(s.add_result(true, 450), "the first result creates the entry when the match ends")
	check(not s.add_result(true, 450), "a second call for the same match is ignored")
	check(not s.add_result(false, 0), "a late defeat cannot change it")
	check(s.records.size() == 1 and s.records[0]["score"] == 450 and s.records[0]["won"], "one entry: Victory, score = Sun spent")
	var first_id: int = s.last_id

	# ---- RESTART: same name, new match, the SAME entry is updated ----
	s.restart_match()
	check(s.username == "Alice", "restart keeps the username")
	check(s.records.size() == 1, "restart itself creates nothing")
	check(s.add_result(false, 999), "the replay's result is stored")
	check(s.records.size() == 1, "still exactly one entry for Alice")
	check(s.records[0]["won"] == false and s.records[0]["score"] == 0, "the entry now holds the latest result (Defeat, score 0 whatever was spent)")
	check(s.last_id == first_id, "the updated entry is the same one")
	s.restart_match()
	s.add_result(true, 300)
	check(s.records.size() == 1 and s.records[0]["won"] and s.records[0]["score"] == 300, "restarting repeatedly keeps updating it (Victory 300)")

	# ---- BACK ends the session; the name stays taken ----
	s.end_session()
	check(s.username == "" and not s.username_accepted, "end_session clears the current player")
	check(s.records.size() == 1, "the entry stays on the leaderboard")
	check(s.validate_username("Alice")["error"] == "Username already exists", "the old username is rejected")
	check(s.validate_username("alice")["error"] == "Username already exists", "duplicate: lower case")
	check(s.validate_username("ALICE")["error"] == "Username already exists", "duplicate: upper case")
	check(s.validate_username("  aLiCe ")["error"] == "Username already exists", "duplicate: padded + mixed case")
	check(s.validate_username("Bob")["ok"], "a different name is accepted")
	s.begin_match("Bob")
	s.add_result(false, 50)
	check(s.records.size() == 2 and s.records[1]["username"] == "Bob", "the next player gets their own entry")
	check(s.records[0]["username"] == "Alice" and s.records[0]["score"] == 300, "Alice's entry was not touched")

	# ---- sorting (rules unchanged) ----
	s = fresh_session()
	for e in [["Alice", true, 450], ["Bob", false, 999], ["Cara", true, 300], ["Dan", true, 700], ["Eve", false, 0], ["Finn", true, 300]]:
		s.begin_match(e[0])
		s.add_result(e[1], e[2])
		s.end_session()
	var order: Array = []
	for r in s.sorted_records():
		order.append(r["username"])
	check(order == ["Cara", "Finn", "Alice", "Dan", "Bob", "Eve"], "Victory first by ascending Sun spent, then Defeats: %s" % [order])
	var seen_defeat := false
	var defeat_above_victory := false
	for r in s.sorted_records():
		if not r["won"]:
			seen_defeat = true
			check(r["score"] == 0, "defeat score is 0 (%s)" % r["username"])
		elif seen_defeat:
			defeat_above_victory = true
	check(not defeat_above_victory, "no Defeat ranks above a Victory")
	# a replay can change the rank
	s.begin_match("Dan")
	s.restart_match()
	s.add_result(true, 100)
	order = []
	for r in s.sorted_records():
		order.append(r["username"])
	check(order[0] == "Dan" and s.records.size() == 6, "an improved replay moves the same entry up (%s)" % [order])

	# ---- nothing is read from or written to disk (an old user://leaderboard.json is left alone, unused) ----
	var path := "user://leaderboard.json"
	var mtime := FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
	var s2 := fresh_session()
	s2.begin_match("Disk")
	s2.add_result(true, 5)
	check((FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0) == mtime, "recording a result does not touch any file")
	check(fresh_session().records.is_empty(), "a new process / session never sees earlier records")

	print("session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
