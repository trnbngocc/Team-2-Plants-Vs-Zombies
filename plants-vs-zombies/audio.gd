extends Node
## audio.gd - autoload "Audio": the ONE place that plays music and sound effects.
##
## Lives for the whole session (survives scene changes / Play Again), so there is
## never more than one music player. Scenes only call the functions below; they
## never create their own AudioStreamPlayers.
##
## Several supplied clips start with up to ~1.2 s of silence; START trims that at
## playback time (the files themselves are untouched).

const MUSIC := {
	"menu": "res://assets/audio/menu.ogg",                # converted from menu.m4a
	"gameplay": "res://assets/audio/gameplay_music.ogg",  # converted from gameplay_music.m4a
}
const SFX := {
	"click": "res://assets/audio/button_click.mp3",
	"pea_hit": "res://assets/audio/peashooter.mp3",   # Peashooter projectile hits a zombie
	"sun": "res://assets/audio/sun_collect.mp3",
	"jalapeno": "res://assets/audio/jalapeno_explosion.mp3",
	"incoming": "res://assets/audio/The zombies are coming Plants vs Zombies Sound Effect.mp3",
	"win": "res://assets/audio/win.mp3",
	"lose": "res://assets/audio/lose.mp3",
	"eating": "res://assets/audio/zombie_eating.mp3",
	"squash": "res://assets/audio/squash.mp3",              # Squash notices a zombie (preparation cue)
	"mower": "res://assets/audio/lawn_mower.mp3",           # Lawn Mower running
	"gargantuar_death": "res://assets/audio/gargantuar_death.mp3",
	"start": "res://assets/audio/plants-vs-zombies-ready-set-plant.mp3",   # Start Text "Ready, Set, Plant!"
}
# Sound for a successful plant placement (supplied as planting.mp3; 0.8 s, audible
# from 0.00 s). The first of these files that exists is used.
const PLANTING_CANDIDATES := [
	"res://assets/audio/planting.wav",
	"res://assets/audio/planting.ogg",
	"res://assets/audio/planting.mp3",
]
# Measured start of the audible part of each clip, in seconds.
const START := {
	"click": 0.72, "pea_hit": 0.89, "sun": 0.03, "jalapeno": 0.13, "incoming": 1.10,
	"win": 0.13, "lose": 0.37, "eating": 1.20, "planting": 0.0, "squash": 0.12, "mower": 0.6,
}
const SFX_VOICES := 8
# Per-source volume (dB) of the "tracked" effects: one voice per source (a mower, a Squash), see play_tracked().
const TRACKED_DB := {"squash": -2.0, "mower": -6.0}

var _music: AudioStreamPlayer
var _music_name := ""
var _eating: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_sfx := {}   # voice -> name of the clip it is playing
var _streams := {}
var _paused := false
var _tracked := {}      # key -> AudioStreamPlayer of an effect that follows one object (mower row, Squash cell)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Closing the window goes through quit_game() so audio is stopped first.
	get_tree().set_auto_accept_quit(false)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -6.0
	add_child(_music)
	_eating = AudioStreamPlayer.new()
	_eating.volume_db = -4.0
	add_child(_eating)
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Exit the application cleanly: the audio server removes stopped streams on its
## own thread, so stop everything and give it a moment before quitting
## (quitting mid-playback leaks the playback objects at shutdown).
## The click that triggered the quit is allowed to finish first.
var suppress_quit := false      # tests: do everything quit_game() does except ending the process
var quit_requests := 0


func quit_game() -> void:
	quit_requests += 1
	stop_music()
	_eating.stop()
	stop_all_tracked()
	await get_tree().create_timer(0.15).timeout
	for p in _voices:
		p.stop()
	await get_tree().create_timer(0.1).timeout
	if suppress_quit:
		return
	get_tree().quit()


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null
	_eating.stop()
	_eating.stream = null
	for p in _voices:
		p.stop()
		p.stream = null
	_streams.clear()


func _stream(path: String, loop: bool) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	else:
		push_warning("[Audio] missing file: " + path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = loop
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = loop
	_streams[path] = s
	return s


## Start a music track (looping). Calling it again for the track that is
## already playing does nothing, so it never restarts or doubles up.
func play_music(track: String) -> void:
	if _music_name == track and _music.playing:
		return
	var s := _stream(MUSIC.get(track, ""), true)
	_music.stop()
	_music_name = track
	_music.stream_paused = false
	if s != null:
		_music.stream = s
		_music.play()


func stop_music() -> void:
	_music.stop()
	_music_name = ""


func music_track() -> String:
	return _music_name if _music.playing else ""


func _sfx_path(name: String) -> String:
	if name == "planting":
		for p in PLANTING_CANDIDATES:
			if ResourceLoader.exists(p):
				return p
		return PLANTING_CANDIDATES[0]   # missing -> _stream() warns once, plays nothing
	return SFX.get(name, "")


func play_sfx(name: String) -> void:
	var s := _stream(_sfx_path(name), false)
	if s == null:
		return
	var voice: AudioStreamPlayer = null
	for p in _voices:
		if not p.playing:
			voice = p
			break
	if voice == null:
		voice = _voices[0]   # all busy: reuse the oldest slot
		_voices.push_back(_voices.pop_front())
	voice.stream = s
	voice.stream_paused = false
	_voice_sfx[voice] = name
	voice.play(START.get(name, 0.0))


## An effect that belongs to ONE object (a running mower, a Squash that noticed a zombie). Starting it again for the
## same key restarts that key's voice instead of stacking a second one, and the voice is released when the clip ends
## or stop_tracked() is called.
func play_tracked(key: String, name: String) -> void:
	var s := _stream(_sfx_path(name), false)
	if s == null:
		return
	stop_tracked(key, 0.0)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = TRACKED_DB.get(name, 0.0)
	p.stream_paused = _paused
	add_child(p)
	_tracked[key] = p
	p.finished.connect(_release_tracked.bind(key, p))
	p.play(START.get(name, 0.0))


func is_tracked_playing(key: String) -> bool:
	return _tracked.has(key) and is_instance_valid(_tracked[key]) and (_tracked[key] as AudioStreamPlayer).playing


func tracked_count() -> int:
	return _tracked.size()


## Stop a tracked effect, fading it out over `fade` seconds (0 = immediately).
func stop_tracked(key: String, fade := 0.12) -> void:
	if not _tracked.has(key):
		return
	var p: AudioStreamPlayer = _tracked[key]
	_tracked.erase(key)
	if not is_instance_valid(p):
		return
	if fade <= 0.0 or not p.playing:
		p.stop()
		p.queue_free()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		p.stop()
		p.queue_free())


func stop_all_tracked() -> void:
	for k in _tracked.keys():
		stop_tracked(k, 0.0)


func _release_tracked(key: String, p: AudioStreamPlayer) -> void:
	if _tracked.get(key) == p:
		_tracked.erase(key)
	if is_instance_valid(p):
		p.queue_free()


## Continuous eating loop while at least one zombie is eating; not restarted per frame.
func set_eating(active: bool) -> void:
	if active and not _eating.playing:
		var s := _stream(SFX["eating"], true)
		if s != null:
			(s as AudioStreamMP3).loop_offset = START["eating"]
			_eating.stream = s
			_eating.play(START["eating"])
			_eating.stream_paused = _paused
	elif not active and _eating.playing:
		_eating.stop()


## Pause / resume the gameplay audio (music keeps its exact position).
func set_gameplay_paused(paused: bool) -> void:
	_paused = paused
	_music.stream_paused = paused
	_eating.stream_paused = paused
	for k in _tracked:
		if is_instance_valid(_tracked[k]):
			(_tracked[k] as AudioStreamPlayer).stream_paused = paused
	for p in _voices:
		if _voice_sfx.get(p, "") != "click":
			p.stream_paused = paused


## Leaving gameplay (quit to menu, victory, defeat): silence everything gameplay-related.
## A UI click that is still sounding is left alone (it belongs to the button just pressed).
func stop_gameplay_audio() -> void:
	_paused = false
	stop_music()
	_eating.stop()
	stop_all_tracked()
	for p in _voices:
		p.stream_paused = false
		if _voice_sfx.get(p, "") != "click":
			p.stop()
