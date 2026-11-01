class_name PlantRig
extends Node2D
## plant_rig.gd - the picture and animation of ONE plant (display only; the C++ core owns every rule).
##
## Art: the HD illustrations in assets/references/original_pvz cut into layers by tools/character_art
## (assets/characters/{sunflower,peashooter,jalapeno,squash}/), plus the supplied Wall-nut sprite sheet.
##   Sunflower   stem + head layers   -> idle sway, the head lags behind the stem
##   Peashooter  stem + head layers   -> idle sway, recoil when it fires
##   Wall-nut    3 damage sprites     -> idle breathing, blink, hit reaction
##   Jalapeno    one sprite           -> idle sway, the fuse makes it glow, pulse and shake
##   Squash      frames of the original GIF -> idle, crouch + jump arc, (splat spawned by main_game)
## The rig's origin is the point on the ground the plant stands on.

const DIR := "res://assets/characters/"

# PlantType codes of the core
const PEASHOOTER := 0
const SUNFLOWER := 1
const WALLNUT := 2
const JALAPENO := 3
const SQUASH := 4

# Bullets leave the Peashooter's mouth; main_game draws them this far above the cell centre (lawn px).
const PEA_BULLET_Y := -43.0

const SUN_GROUND := Vector2(232, 520)
const SUN_PIVOT := Vector2(260, 372)
const SUN_STEM := Vector2(121, 340.5)
const SUN_SCALE := 0.165

const PEA_GROUND := Vector2(118, 221)
const PEA_PIVOT := Vector2(116, 112)
const PEA_STEM := Vector2(50, 104)
const PEA_SCALE := 0.38

const JAL_GROUND := Vector2(150, 380)
const JAL_SCALE := 0.27
const JAL_FUSE := 2.0

const WALL_SCALE := 0.82
# Wall-nut eyes (centre x, y, radius) in the three damage sprites, for the blink.
const WALL_EYES := [
	[Vector2(45.3, 39.2), 9.5, Vector2(74.3, 36.5), 8.5],
	[Vector2(36.3, 37.2), 9.5, Vector2(65.3, 34.5), 8.5],
	[Vector2(36.3, 31.2), 9.5, Vector2(65.3, 28.5), 8.5],
]
const WALL_FILES := ["res://assets/plants/wall-nut/wallnut_1.png", "res://assets/plants/wall-nut/wallnut_2.png", "res://assets/plants/wall-nut/wallnut_3.png"]

const SQ_GROUND := Vector2(52, 218)
const SQ_SCALE := 0.98
const SQ_JUMP_FRAMES := [14, 17, 20, 23, 26, 28, 30, 32, 34, 36, 38, 40, 42, 43, 44]
const SQ_SPLAT_FRAMES := [45, 47, 50, 55, 59]
const SQ_JUMP_TIME := 0.5       # the core's jump time (Squash::JUMP_DURATION); the pose follows it

var plant_type := -1
var animating := true
var jump_dx := 0.0              # Squash: horizontal distance to the landing cell (lawn px), set by main_game

var _t := 0.0
var _age := 0.0
var _hit_t := 0.0
var _shoot_t := -1.0
var _sway: Node2D
var _head: Node2D
var _sprite: Sprite2D
var _lids: Node2D
var _next_blink := 2.5
var _blink_t := -1.0
var _wall_state := 0
var _sq_state := 0
var _jump_t := 0.0
var _tex_cache := {}


static func create(t: int) -> PlantRig:
	var r := PlantRig.new()
	r.setup(t)
	return r


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _sprite_at(parent: Node2D, tex_path: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(tex_path)
	s.centered = false
	s.position = pos
	parent.add_child(s)
	return s


func setup(t: int) -> void:
	plant_type = t
	var shadow := PuppetZombie.Shadow.new()
	shadow.rx = 34.0
	shadow.ry = 8.0
	shadow.position = Vector2(0, -2)
	shadow.z_index = -1
	add_child(shadow)

	_sway = Node2D.new()          # whole-plant motion about the ground point
	add_child(_sway)
	match t:
		SUNFLOWER:
			scale = Vector2.ONE * SUN_SCALE
			shadow.scale = Vector2.ONE / SUN_SCALE
			_sprite_at(_sway, DIR + "sunflower/stem.png", SUN_STEM - SUN_GROUND)
			_head = Node2D.new()
			_head.position = SUN_PIVOT - SUN_GROUND
			_sway.add_child(_head)
			_sprite_at(_head, DIR + "sunflower/head.png", -SUN_PIVOT)
		PEASHOOTER:
			scale = Vector2.ONE * PEA_SCALE
			shadow.scale = Vector2.ONE / PEA_SCALE
			_sprite_at(_sway, DIR + "peashooter/stem.png", PEA_STEM - PEA_GROUND)
			_head = Node2D.new()
			_head.position = PEA_PIVOT - PEA_GROUND
			_sway.add_child(_head)
			_sprite_at(_head, DIR + "peashooter/head.png", -PEA_PIVOT)
		JALAPENO:
			scale = Vector2.ONE * JAL_SCALE
			shadow.scale = Vector2.ONE / JAL_SCALE
			_sprite = _sprite_at(_sway, DIR + "jalapeno/jalapeno.png", -JAL_GROUND)
		WALLNUT:
			scale = Vector2.ONE * WALL_SCALE
			shadow.scale = Vector2.ONE / WALL_SCALE
			shadow.rx = 52.0
			shadow.ry = 11.0
			_sprite = Sprite2D.new()
			_sprite.centered = false
			_sway.add_child(_sprite)
			_lids = Lids.new()
			_lids.visible = false
			_sway.add_child(_lids)
			_set_wall_state(0)
		SQUASH:
			scale = Vector2.ONE * SQ_SCALE
			shadow.scale = Vector2.ONE / SQ_SCALE
			shadow.rx = 40.0
			shadow.ry = 8.0
			_sprite = Sprite2D.new()
			_sprite.centered = false
			_sprite.position = -SQ_GROUND
			_sway.add_child(_sprite)
			_sprite.texture = _tex(DIR + "squash/f00.png")


## Per-frame update from one entry of get_plants_data().
func update_from(d: Dictionary) -> void:
	match plant_type:
		WALLNUT:
			pass          # the damage sprite is picked by main_game through set_damage()
		SQUASH:
			var st := int(d.get("state", 0))
			if st == 1 and _sq_state == 0:
				_jump_t = 0.0
			_sq_state = st


## Wall-nut: 0 healthy, 1 cracked, 2 badly cracked.
func set_damage(state: int) -> void:
	if plant_type == WALLNUT and state != _wall_state:
		_set_wall_state(state)


func hit() -> void:
	_hit_t = 0.22


func play_shoot() -> void:
	_shoot_t = 0.0


func _set_wall_state(s: int) -> void:
	_wall_state = s
	_sprite.texture = _tex(WALL_FILES[s])
	var sz := _sprite.texture.get_size()
	_sprite.position = Vector2(-sz.x * 0.5, -sz.y)
	var eyes: Array = WALL_EYES[s]
	(_lids as Lids).setup(eyes[0] + _sprite.position, eyes[1], eyes[2] + _sprite.position, eyes[3])


func _process(delta: float) -> void:
	if not animating:
		return
	_t += delta
	_age += delta
	_hit_t = maxf(_hit_t - delta, 0.0)
	match plant_type:
		SUNFLOWER:
			_sway.rotation = sin(_t * 1.5) * 0.028
			_head.rotation = sin(_t * 1.5 - 0.7) * 0.05
			_head.position.y = SUN_PIVOT.y - SUN_GROUND.y + sin(_t * 3.0) * 2.5
		PEASHOOTER:
			_sway.rotation = sin(_t * 1.7) * 0.022
			var recoil := 0.0
			var kick := 0.0
			if _shoot_t >= 0.0:
				_shoot_t += delta
				var p := clampf(_shoot_t / 0.32, 0.0, 1.0)
				recoil = sin(p * PI) * 11.0
				kick = sin(p * PI) * 0.1
				if p >= 1.0:
					_shoot_t = -1.0
			_head.rotation = sin(_t * 1.7 - 0.6) * 0.04 - kick
			_head.position = Vector2(PEA_PIVOT.x - PEA_GROUND.x - recoil, PEA_PIVOT.y - PEA_GROUND.y + sin(_t * 3.4) * 1.5)
		JALAPENO:
			_animate_jalapeno()
		WALLNUT:
			_animate_wallnut(delta)
		SQUASH:
			_animate_squash(delta)
	# short white flash when hurt
	if plant_type != JALAPENO:
		modulate = Color(1.5, 1.5, 1.5) if _hit_t > 0.0 else Color.WHITE


func _animate_jalapeno() -> void:
	# The core's fuse is 2 s from planting; the rig counts the same time since it appeared.
	var k := clampf((_age - 0.8) / (JAL_FUSE - 0.8), 0.0, 1.0)
	var rate := 1.6 + 11.0 * k * k
	_sway.rotation = sin(_t * rate) * (0.025 + 0.035 * k)
	var pulse := 1.0 + sin(_t * (6.0 + 22.0 * k)) * 0.035 * k
	_sway.scale = Vector2(pulse, pulse * (1.0 + sin(_t * 1.5) * 0.01))
	_sway.position.x = sin(_t * 41.0) * 3.0 * k
	modulate = Color(1.0 + 0.55 * k, 1.0 - 0.38 * k, 1.0 - 0.38 * k)


func _animate_wallnut(delta: float) -> void:
	var jolt := _hit_t / 0.22
	var br := 1.0 + sin(_t * 1.8) * 0.012
	_sway.scale = Vector2(br * (1.0 + 0.1 * jolt), (2.0 - br) * (1.0 - 0.12 * jolt))
	_sway.rotation = sin(_t * 1.3) * 0.015 + sin(_t * 38.0) * 0.04 * jolt
	_next_blink -= delta
	if _next_blink <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_next_blink = randf_range(2.5, 5.5)
	if _blink_t >= 0.0:
		_blink_t += delta
		_lids.visible = _blink_t < 0.16
		if _blink_t >= 0.16:
			_blink_t = -1.0
			_lids.visible = false


func _animate_squash(delta: float) -> void:
	var frame := 0
	var x_off := 0.0
	if _sq_state == 1:
		_jump_t += delta
		var p := clampf(_jump_t / SQ_JUMP_TIME, 0.0, 1.0)
		frame = SQ_JUMP_FRAMES[mini(int(p * SQ_JUMP_FRAMES.size()), SQ_JUMP_FRAMES.size() - 1)]
		var e := p * p * (3.0 - 2.0 * p)          # ease in/out toward the landing cell
		x_off = jump_dx * e / scale.x
	else:
		_jump_t = 0.0
		frame = 0
	_sprite.texture = _tex(DIR + "squash/f%02d.png" % frame)
	_sprite.position = Vector2(x_off, 0) - SQ_GROUND


## What is left after a Squash lands: the flattened Squash from the original animation, fading away.
static func make_squash_splat() -> Node2D:
	var root := Node2D.new()
	var spr := Sprite2D.new()
	spr.centered = false
	spr.position = -SQ_GROUND
	root.add_child(spr)
	root.scale = Vector2.ONE * SQ_SCALE
	var tw := root.create_tween()
	for f in SQ_SPLAT_FRAMES:
		var path := DIR + "squash/f%02d.png" % f
		tw.tween_callback(func(): spr.texture = load(path))
		tw.tween_interval(0.07)
	tw.tween_interval(0.35)
	tw.tween_property(root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(root.queue_free)
	spr.texture = load(DIR + "squash/f%02d.png" % SQ_SPLAT_FRAMES[0])
	return root


## Eyelids for the Wall-nut blink: two nut-coloured ovals with a dark lash line.
class Lids extends Node2D:
	var a := Vector2.ZERO
	var ra := 9.0
	var b := Vector2.ZERO
	var rb := 8.0

	func setup(pa: Vector2, rad_a: float, pb: Vector2, rad_b: float) -> void:
		a = pa
		ra = rad_a
		b = pb
		rb = rad_b
		queue_redraw()

	func _lid(c: Vector2, r: float) -> void:
		var pts := PackedVector2Array()
		for i in 24:
			var ang := TAU * i / 24.0
			pts.append(c + Vector2(cos(ang) * (r + 1.8), sin(ang) * (r + 2.2)))
		draw_colored_polygon(pts, Color(0.80, 0.62, 0.20))
		draw_arc(c + Vector2(0, 1.0), r * 0.85, deg_to_rad(15), deg_to_rad(165), 12, Color(0.18, 0.12, 0.04), 1.6)

	func _draw() -> void:
		_lid(a, ra)
		_lid(b, rb)
