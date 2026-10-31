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
	"chili": "res://assets/audio/chilli_explosion.mp3",
	"incoming": "res://assets/audio/The zombies are coming Plants vs Zombies Sound Effect.mp3",
	"win": "res://assets/audio/win.mp3",
	"lose": "res://assets/audio/lose.mp3",
	"eating": "res://assets/audio/zombie_eating.mp3",
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
	"click": 0.72, "pea_hit": 0.89, "sun": 0.03, "chili": 0.13, "incoming": 1.10,
	"win": 0.13, "lose": 0.37, "eating": 1.20, "planting": 0.0,
}
const SFX_VOICES := 8

var _music: AudioStreamPlayer
var _music_name := ""
var _eating: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_sfx := {}   # voice -> name of the clip it is playing
var _streams := {}
var _paused := false


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
func quit_game() -> void:
	stop_music()
	_eating.stop()
	await get_tree().create_timer(0.15).timeout
	for p in _voices:
		p.stop()
	await get_tree().create_timer(0.1).timeout
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
	for p in _voices:
		if _voice_sfx.get(p, "") != "click":
			p.stream_paused = paused


## Leaving gameplay (quit to menu, victory, defeat): silence everything gameplay-related.
## A UI click that is still sounding is left alone (it belongs to the button just pressed).
func stop_gameplay_audio() -> void:
	_paused = false
	stop_music()
	_eating.stop()
	for p in _voices:
		p.stream_paused = false
		if _voice_sfx.get(p, "") != "click":
			p.stop()
