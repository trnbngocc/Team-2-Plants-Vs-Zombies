extends Node
## session.gd - autoload "Session": the player's name and the leaderboard of THIS run of the application.
##
## The leaderboard lives only in memory (`records`): nothing is written to or read from disk, so every launch starts
## with an empty one and quitting discards it. It survives scene changes (menu <-> match <-> leaderboard) because
## this autoload lives for the whole run.
##
## ONE USERNAME = ONE LEADERBOARD ENTRY = ONE PLAYER SESSION:
##   register a name (menu TICK) -> first match ends -> add_result() creates the entry (immediately, once per match)
##   RESTART (post-match leaderboard) -> restart_match(): same name, a brand-new match; when it ends add_result()
##                                    UPDATES that same entry with the latest result (never a second row)
##   BACK                -> end_session(): back to the menu, the name stays registered (its entry stays on the board)
##                          so nobody can start a new session with it; the next player needs a different name
##   menu leaderboard    -> read-only view (view_mode = VIEW_MENU)
##   menu Quit           -> the application exits; the records disappear with the process

const MAX_NAME_LENGTH := 16

const ERROR_EMPTY := "Please enter a username"
const ERROR_TOO_LONG := "Username is too long (max %d characters)"
const ERROR_DUPLICATE := "Username already exists"

const VIEW_NONE := 0
const VIEW_MENU := 1          # leaderboard opened from the main menu
const VIEW_POST_MATCH := 2    # leaderboard shown after a finished match

var view_mode := VIEW_NONE

var username := ""               # the player of the current / last match
var username_accepted := false   # true once the menu's TICK confirmed a valid username
var records: Array = []          # one {username, score, won, id} per player, in the order the players first finished
var last_result := {}            # {username, score, won} of the match that just ended
var last_id := -1                # id of the entry that match created or updated
var _match_has_result := false   # this match already produced its record


## Trim whitespace at both ends. Everything else is kept as typed.
static func normalize(raw: String) -> String:
	return raw.strip_edges()


## Validate a raw username. Returns {ok: bool, name: String, error: String}.
## A name that already has an entry on the board is a duplicate, whoever asks (a replay uses restart_match(), which
## never goes through here).
func validate_username(raw: String) -> Dictionary:
	var name := normalize(raw)
	if name.is_empty():
		return {"ok": false, "name": name, "error": ERROR_EMPTY}
	if name.length() > MAX_NAME_LENGTH:
		return {"ok": false, "name": name, "error": ERROR_TOO_LONG % MAX_NAME_LENGTH}
	if username_exists(name):
		return {"ok": false, "name": name, "error": ERROR_DUPLICATE}
	return {"ok": true, "name": name, "error": ""}


## Case-insensitive: "Bob", "bob" and " BOB " are the same player.
func username_exists(name: String) -> bool:
	var wanted := normalize(name).to_lower()
	for r in records:
		if String(r.get("username", "")).strip_edges().to_lower() == wanted:
			return true
	return false


## Menu TICK: the username was validated; keep it for this session.
func accept_username(name: String) -> void:
	username = normalize(name)
	username_accepted = true


func clear_accepted() -> void:
	username_accepted = false


## Start a new player's first match from the main menu. Earlier entries stay on the leaderboard.
func begin_match(name: String) -> void:
	username = normalize(name)
	_match_has_result = false
	last_result = {}
	last_id = -1
	view_mode = VIEW_NONE


## RESTART: the same player replays. Same username, a fresh match; its result updates the player's existing entry.
func restart_match() -> void:
	_match_has_result = false
	last_result = {}
	last_id = -1
	view_mode = VIEW_NONE


## BACK to the menu: the player's session is over. Their entry stays on the board, which keeps the name taken.
func end_session() -> void:
	username = ""
	username_accepted = false
	last_result = {}
	last_id = -1
	_match_has_result = false
	view_mode = VIEW_NONE


## Score rules: Victory = Sun actually spent in the match; Defeat = 0.
static func score_for(won: bool, sun_spent: int) -> int:
	return maxi(sun_spent, 0) if won else 0


## The match is over: record it. Once per match; true only for the call that stored it. The first match of a player
## creates their entry; later matches (after RESTART) replace that entry's result with the latest one.
func add_result(won: bool, sun_spent: int) -> bool:
	if _match_has_result:
		return false
	_match_has_result = true
	var name := username if not username.is_empty() else "Player"
	last_result = {"username": name, "score": score_for(won, sun_spent), "won": won}
	for r in records:
		if String(r["username"]).to_lower() == name.to_lower():
			r["score"] = last_result["score"]
			r["won"] = last_result["won"]
			last_id = int(r["id"])
			return true
	var rec := last_result.duplicate()
	rec["id"] = records.size()      # insertion order (ties); identifies the row for highlighting
	records.append(rec)
	last_id = int(rec["id"])
	return true


## Leaderboard order: every Victory above every Defeat; among Victories the lower
## Sun spent ranks higher; ties keep the order they were recorded in.
func sorted_records() -> Array:
	var rows: Array = []
	for i in records.size():
		var r: Dictionary = records[i].duplicate()
		r["_i"] = i
		rows.append(r)
	rows.sort_custom(_rank_before)
	for r in rows:
		r.erase("_i")
	return rows


static func _rank_before(a: Dictionary, b: Dictionary) -> bool:
	var aw := bool(a.get("won", false))
	var bw := bool(b.get("won", false))
	if aw != bw:
		return aw                      # Victory first
	if aw and int(a["score"]) != int(b["score"]):
		return int(a["score"]) < int(b["score"])   # lower Sun spent first
	return int(a["_i"]) < int(b["_i"])
