class_name ZombieView
extends Node2D
## zombie_view.gd - the picture of ONE zombie on the lawn.
##
## Display only: position, health, armor, eating / throwing all come from the C++ core
## (get_zombies_data). The body is a PuppetZombie rig built from the supplied
## Regular_Zombies.png / zombie_Gargantuar.png parts: Regular, Conehead (visible cone with
## 3 damage states) and Buckethead (visible bucket, 3 damage states) are distinct looks.

const STATE_PLAYING := 1
const STATE_PAUSED := 2

# Draw scale per kind (core code 0 ordinary, 1 Gargantuar, 2 Imp). Rig pixels -> screen pixels.
const PUPPET_SCALE := {0: 0.25, 1: 0.55, 2: 0.6}
# Health-bar position above the head, in rig pixels (the node is scaled by PUPPET_SCALE).
const BAR_POS := {0: Vector2(0, -625), 1: Vector2(0, -400), 2: Vector2(0, -135)}

var puppet: PuppetZombie
signal imp_released

# Flight of a freshly thrown Imp: it leaves the Gargantuar at `_flight_delay` and lands on its real position.
var _flight_t := -1.0
var _flight_from := Vector2.ZERO       # start offset relative to the landing point (lawn pixels)
var _flight_delay := 0.45
const FLIGHT_TIME := 0.8
const FLIGHT_ARC := 90.0
var kind := -1
var armor := -1
var eating := false
var dying := false
var last_row := -1          # last data seen from the core (used to explain a death: see main_game._death_cause)
var last_col := -1.0
var _action := 0
var _last_hp := -1
var _game_state := STATE_PLAYING
var health_bar: HealthBar


## Small bar over the head: body HP only (the Gargantuar has its own big bar in main_game.gd).
class HealthBar extends Node2D:
	const SIZE := Vector2(58, 9)
	const BORDER := Color("2b3c4c")
	const EMPTY := Color(0.16, 0.12, 0.12, 0.9)
	const FILL := Color(0.86, 0.2, 0.15)
	const SHINE := Color(1.0, 0.55, 0.45)
	var target := 1.0
	var shown := 1.0

	func set_target(fraction: float) -> void:
		target = clampf(fraction, 0.0, 1.0)

	func snap() -> void:
		shown = target
		queue_redraw()

	func _process(delta: float) -> void:
		if absf(shown - target) > 0.001:
			shown = lerpf(shown, target, 1.0 - exp(-12.0 * delta))
			if absf(shown - target) <= 0.001:
				shown = target
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(-SIZE * 0.5, SIZE)
		draw_rect(r.grow(2.0), BORDER)
		draw_rect(r, EMPTY)
		if shown > 0.0:
			var f := Rect2(r.position, Vector2(r.size.x * shown, r.size.y))
			draw_rect(f, FILL)
			draw_rect(Rect2(f.position, Vector2(f.size.x, 2.0)), SHINE)


func _init() -> void:
	health_bar = HealthBar.new()
	health_bar.visible = false
	add_child(health_bar)


func _ensure_puppet(k: int) -> void:
	if puppet != null:
		return
	kind = k
	puppet = PuppetZombie.new()
	puppet.setup(k)
	add_child(puppet)
	scale = Vector2.ONE * float(PUPPET_SCALE.get(k, 0.8))
	health_bar.position = BAR_POS.get(k, Vector2(0, -170))
	health_bar.scale = Vector2(2.2, 2.2) if k == 0 else Vector2(1.6, 1.6)
	if k == 1:
		puppet.imp_released.connect(func(): imp_released.emit())


## Update from one Dictionary of get_zombies_data() every frame.
func apply_data(d: Dictionary) -> void:
	if dying:
		return
	_ensure_puppet(clampi(int(d.get("kind", 0)), 0, 2))
	last_row = int(d.get("row", last_row))
	last_col = float(d.get("column", last_col))
	_action = int(d.get("action", 0))

	var a := clampi(int(d.get("armor", 0)), 0, 2)
	armor = a
	puppet.set_armor(a, int(d.get("armor_health", 0)), int(d.get("armor_max", 0)))

	# Body HP + armor dropped since the last frame -> got hit.
	var hp := int(d.get("health", 0)) + int(d.get("armor_health", 0))
	if _last_hp >= 0 and hp < _last_hp:
		puppet.flash()
	_last_hp = hp

	# Health bar: only once the helmet is gone (Conehead / Buckethead) and never for the boss.
	var max_hp := int(d.get("max_health", 0))
	var was_visible := health_bar.visible
	health_bar.visible = a == 0 and max_hp > 0 and kind != 1
	if max_hp > 0:
		health_bar.set_target(float(d.get("health", 0)) / float(max_hp))
		if health_bar.visible and not was_visible:
			health_bar.snap()

	eating = bool(d.get("eating", false))
	# ONE_ARM_LOST (visual_state 1): slightly darker so a weakened zombie is recognisable.
	modulate = Color(0.82, 0.86, 0.8) if int(d.get("visual_state", 0)) == 1 else Color.WHITE
	_play_base()


## PLAYING: animate; PAUSED: freeze; VICTORY / DEFEAT: idle.
func set_game_state(state: int) -> void:
	_game_state = state
	if puppet:
		puppet.set_paused(state == STATE_PAUSED)
	_play_base()


## Core removed the zombie (it died): play the death motion, then free this view.
## cause: "" ordinary damage, "mower", "burn" (Jalapeno), "squash" - see PuppetZombie.die().
func die(cause := "") -> void:
	if dying:
		return
	dying = true
	health_bar.visible = false
	if puppet == null:
		queue_free()
		return
	if kind == 1:
		Audio.play_sfx("gargantuar_death")
	puppet.set_paused(false)
	puppet.death_finished.connect(queue_free)
	puppet.die(cause)


func current_animation() -> String:
	return puppet.anim if puppet else ""


func _play_base() -> void:
	if dying or puppet == null:
		return
	var want := "walk"
	if _game_state != STATE_PLAYING and _game_state != STATE_PAUSED:
		want = "idle"
	elif _action == 1:
		want = "throw"
	elif eating:
		want = "eat"
	puppet.set_anim(want)


## The Imp was thrown: hide it for the wind-up, then fly it from `from_offset` (relative to where it lands).
func start_flight(from_offset: Vector2, delay: float) -> void:
	_flight_from = from_offset
	_flight_delay = delay
	_flight_t = 0.0
	if puppet:
		puppet.visible = false


func _process(delta: float) -> void:
	if _flight_t < 0.0 or puppet == null:
		return
	if _game_state == STATE_PAUSED:
		return
	_flight_t += delta
	if _flight_t < _flight_delay:
		puppet.visible = false
		return
	var p := clampf((_flight_t - _flight_delay) / FLIGHT_TIME, 0.0, 1.0)
	puppet.visible = true
	var s := scale.x if scale.x != 0.0 else 1.0
	var lift := Vector2(0, -FLIGHT_ARC * sin(p * PI))
	puppet.position = ((_flight_from * (1.0 - p)) + lift) / s
	puppet.rotation = -TAU * (1.0 - p)      # tumbles once in the air
	if p >= 1.0:
		puppet.position = Vector2.ZERO
		_flight_t = -1.0
