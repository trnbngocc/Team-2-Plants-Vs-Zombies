extends Node
## session.gd - autoload Session: player name + leaderboard for this run.
##
## The leaderboard is only kept in memory (`records`), nothing goes to disk, so it starts
## empty every launch. It's an autoload so it survives scene changes.
##
## One username = one leaderboard entry:
##   TICK in menu -> first match ends -> add_result() creates the entry
##   RESTART      -> restart_match(): same name, new match, add_result() updates the same entry
##   BACK         -> end_session(): back to menu, name stays on the board so nobody else can use it
##   menu leaderboard -> view only (VIEW_MENU)
##   menu Quit        -> game closes, records are gone

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
var records: Array = []          # one {username, score, won, id} per player
var last_result := {}            # {username, score, won} of the match that just ended
var last_id := -1                # id of the entry that match created or updated
var _match_has_result := false   # already recorded this match


## Trim spaces at both ends.
static func normalize(raw: String) -> String:
	return raw.strip_edges()


## Check a username. Returns {ok, name, error}.
## Names already on the board count as duplicates (replays use restart_match() instead).
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


## TICK: name is valid, keep it.
func accept_username(name: String) -> void:
	username = normalize(name)
	username_accepted = true


func clear_accepted() -> void:
	username_accepted = false


## New player's first match from the menu.
func begin_match(name: String) -> void:
	username = normalize(name)
	_match_has_result = false
	last_result = {}
	last_id = -1
	view_mode = VIEW_NONE


## RESTART: same player plays again, result updates their entry.
func restart_match() -> void:
	_match_has_result = false
	last_result = {}
	last_id = -1
	view_mode = VIEW_NONE


## BACK: session over. Entry stays on the board so the name is still taken.
func end_session() -> void:
	username = ""
	username_accepted = false
	last_result = {}
	last_id = -1
	_match_has_result = false
	view_mode = VIEW_NONE


## Score: win = Sun spent in the match, loss = 0.
static func score_for(won: bool, sun_spent: int) -> int:
	return maxi(sun_spent, 0) if won else 0


## Match ended: save the result (once per match, returns true if it was saved).
## First match adds a new entry, later ones (after RESTART) overwrite it.
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
	rec["id"] = records.size()      # insert order, used for ties and highlighting
	records.append(rec)
	last_id = int(rec["id"])
	return true


## Sort: wins first, less Sun spent ranks higher, ties keep insert order.
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
