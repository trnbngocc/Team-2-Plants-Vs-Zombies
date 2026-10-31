extends Control
## main_menu.gd - Main Menu: background, Play (▶) and Quit.
## Play loads a fresh game scene (new GameController = fresh Sun, waves, timers).

const GAME_SCENE := "res://scenes/main.tscn"


func _ready() -> void:
	Audio.stop_gameplay_audio()
	Audio.play_music("menu")
	$Buttons/Play.pressed.connect(_on_play_pressed)
	$Buttons/Quit.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	_lock_buttons()
	Audio.play_music("gameplay")   # starts with the 30 s preparation phase
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quit_pressed() -> void:
	_lock_buttons()
	Audio.quit_game()   # lets the click finish, stops audio, then exits


# A second click while the scene is changing / closing must not act twice.
func _lock_buttons() -> void:
	$Buttons/Play.disabled = true
	$Buttons/Quit.disabled = true
