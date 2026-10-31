class_name PeaImpact
extends Node2D
## pea_impact.gd - the green splat that appears where a Pea hits a zombie.
##
## Frames come from the "Pea" block of assets/projectiles/Projectiles.png (extracted to
## assets/projectiles/pea/): splat_1..3 are the splat growing, splat_4 is the flattened side splash and
## dot_1..3 are the little droplets that fly off. The effect plays once (~0.4 s) and frees itself.
## It is created only from the core's "projectile_hit" signal, i.e. on a real collision.

const DIR := "res://assets/projectiles/pea/"
const FRAME_TIME := 0.055
const SCALE := 1.5
const LIFE := 0.42

var _t := 0.0
var _splat: Sprite2D
var _drops: Array = []        # [Sprite2D, velocity Vector2]
var _frames: Array = []


static func spawn(parent: Node, at: Vector2, z := 9) -> PeaImpact:
	var e := PeaImpact.new()
	e.position = at
	e.z_index = z
	parent.add_child(e)
	return e


func _init() -> void:
	scale = Vector2.ONE * SCALE


func _ready() -> void:
	for n in ["splat_1", "splat_2", "splat_3", "splat_4"]:
		_frames.append(load(DIR + n + ".png"))
	_splat = Sprite2D.new()
	_splat.texture = _frames[0]
	add_child(_splat)
	var dirs := [Vector2(-1.0, -0.9), Vector2(0.4, -1.2), Vector2(1.0, -0.4)]
	for i in 3:
		var d := Sprite2D.new()
		d.texture = load(DIR + "dot_%d.png" % (i + 1))
		d.visible = false
		add_child(d)
		_drops.append([d, (dirs[i] as Vector2).normalized() * (46.0 + 14.0 * i)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	# splat grows through frames 1..3, then settles into the side splash and fades
	var idx := mini(int(_t / FRAME_TIME), 3)
	_splat.texture = _frames[idx]
	var fade_start := LIFE * 0.55
	_splat.modulate.a = 1.0 if _t < fade_start else 1.0 - (_t - fade_start) / (LIFE - fade_start)
	# droplets fly out under a little gravity
	for d in _drops:
		var s: Sprite2D = d[0]
		s.visible = _t > 0.03
		var tt := maxf(_t - 0.03, 0.0)
		s.position = (d[1] as Vector2) * tt + Vector2(0, 90.0) * tt * tt
		s.modulate.a = clampf(1.0 - tt / (LIFE - 0.03), 0.0, 1.0)
