extends SceneTree
## Headless test of session.gd (username validation + the in-memory, session-only leaderboard).
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

	# ---- a result is recorded immediately, once per match ----
	s.begin_match("Alice")
	check(s.add_result(true, 450), "the result is added when the match ends")
	check(not s.add_result(true, 450), "a second call for the same match is ignored")
	check(not s.add_result(false, 0), "a late defeat cannot add a second row")
	check(s.records.size() == 1, "exactly one record")
	check(s.last_result["score"] == 450 and s.last_result["won"], "victory score = Sun spent")
	s.begin_match("Alice")
	check(s.records.size() == 1, "starting another match does not clear or duplicate records")
	check(s.add_result(false, 999), "the next match adds its own record")
	check(s.records.size() == 2 and s.records[1]["score"] == 0, "defeat score is 0 whatever was spent; same name twice is fine")

	# ---- duplicates (case-insensitive, trimmed) ----
	s.begin_match("Zed")
	s.add_result(true, 10)
	check(s.validate_username("alice")["error"] == "Username already exists", "duplicate: lower case")
	check(s.validate_username("ALICE")["error"] == "Username already exists", "duplicate: upper case")
	check(s.validate_username("  aLiCe ")["error"] == "Username already exists", "duplicate: padded + mixed case")
	check(s.validate_username("Alicia")["ok"], "a different name is fine")
	check(s.validate_username(" zed ")["ok"], "the player of this session may play again under the same name")

	# ---- sorting ----
	s = fresh_session()
	for e in [["Alice", true, 450], ["Bob", false, 999], ["Cara", true, 300], ["Dan", true, 700], ["Eve", false, 0], ["Finn", true, 300]]:
		s.begin_match(e[0])
		s.add_result(e[1], e[2])
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
	check(s.sorted_records().size() == 6 and s.records.size() == 6, "sorting does not change or duplicate the records")

	# ---- nothing is read from or written to disk (an old user://leaderboard.json of earlier versions is left alone, unused) ----
	var path := "user://leaderboard.json"
	var mtime := FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
	var s2 := fresh_session()
	s2.begin_match("Disk")
	s2.add_result(true, 5)
	check((FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0) == mtime, "recording a result does not touch any file")
	check(fresh_session().records.is_empty(), "a new process / session never sees earlier records")

	print("session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
