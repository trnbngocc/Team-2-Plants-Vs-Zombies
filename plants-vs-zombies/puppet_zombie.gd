class_name PuppetZombie
extends Node2D
## puppet_zombie.gd - cut-out ("skeletal") rigs for every zombie, built from the HD character art in
## assets/characters/ (cut out of assets/references/original_pvz by tools/character_art/*.py).
##
##   Regular / Conehead / Buckethead   zombie/{head,body,feet}.png + cone_N / bucket_N accessories (N = damage state)
##   Gargantuar                        gargantuar/{feet,body,head,pole,hand,grip,imp_rider}.png
##   Imp                               imp/{upper,leg,shoe}.png
##
## Each part sits at its position inside the original full-size picture, so with every joint at rest the
## character looks exactly like the reference. Joints are Node2D pivots (hips, neck, pole grip ...); the
## procedural animations below only rotate / nudge parts about those pivots by small amounts.
## Nothing here changes gameplay: position, HP, armor and state all come from the C++ core via ZombieView.

signal death_finished
signal imp_released          # the Gargantuar let go of the Imp (ZombieView starts the Imp's flight)

const KIND_ORDINARY := 0
const KIND_GARGANTUAR := 1
const KIND_IMP := 2

const DIR := "res://assets/characters/"

# ---- ordinary zombie (pixels of the half-size zombie_pose picture, 369 x 607) ----
const Z_GROUND := Vector2(243, 607)
const Z_HIPS := Vector2(190, 330)
const Z_NECK := Vector2(150, 160)
const Z_FEET_PIVOT := Vector2(243, 500)
const Z_PARTS := {
	"head": Vector2(0, 0),
	"body": Vector2(57, 103),
	"feet": Vector2(116.5, 487.5),
}
const Z_ARMOR_SEAT := {   # accessory top-left in the same coordinates; armor code 1 = cone, 2 = bucket
	1: Vector2(-14.0, -134.0),
	2: Vector2(-20.0, -64.5),
}
const Z_ARMOR_SCALE := {1: 1.3, 2: 1.0}   # the cone art is scaled up to the regular zombie's head (reference proportions)
const ARMOR_NAMES := {1: "cone", 2: "bucket"}

# ---- Gargantuar (pixels of the 0.6x Gargantuar picture, 350 x 345) ----
const G_GROUND := Vector2(240, 343)
const G_HIPS := Vector2(240, 270)
const G_NECK := Vector2(150, 168)
const G_GRIP := Vector2(240, 257)
const G_PARTS := {
	"feet": Vector2(154.2, 282.0),
	"body": Vector2(0, 0),
	"head": Vector2(100.8, 55.8),
	"pole": Vector2(0, 150.0),
	"hand": Vector2(105.0, 231.6),
	"grip": Vector2(230.4, 235.2),
	"imp_rider": Vector2(259.8, 2.4),
}
const G_THROW_RELEASE := 0.45      # seconds into the throw animation when the Imp leaves the shoulder

# ---- Imp ----
const IMP_UPPER_SIZE := Vector2(78, 74)

var kind := KIND_ORDINARY
var anim := "walk"
var _t := 0.0
var _dying := false
var _hurt_left := 0.0
var _speed := 1.0                  # 0 while paused

var _ground: Node2D                # origin = the point between the feet on the ground; whole-body motions
var _upper: Node2D                 # everything above the hips
var _feet: Node2D
var _head: Node2D                  # head joint (pivot at the neck)
var _pole: Node2D                  # Gargantuar pole joint (pivot at the grip)
var _rider: Node2D                 # Imp riding the Gargantuar
var _arm_l: Node2D                 # Imp arms (front / back)
var _arm_r: Node2D
var _leg_back: Node2D
var _leg_front: Node2D
var _armor_sprite: Sprite2D
var _armor_type := 0
var _armor_state := 0
var _released := false
var _tex_cache := {}


static func has_rig(_k: int) -> bool:
	return true


func _tex(rel: String) -> Texture2D:
	if not _tex_cache.has(rel):
		_tex_cache[rel] = load(DIR + rel)
	return _tex_cache[rel]


## A Sprite2D whose top-left is `top_left` in rig coordinates, expressed relative to a joint at `pivot`.
func _sprite(parent: Node2D, rel: String, top_left: Vector2, pivot: Vector2, z := 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(rel)
	s.centered = false
	s.position = top_left - pivot
	s.z_index = z
	parent.add_child(s)
	return s


func _joint(parent: Node2D, at: Vector2, relative_to := Vector2.ZERO, z := 0) -> Node2D:
	var j := Node2D.new()
	j.position = at - relative_to
	j.z_index = z
	parent.add_child(j)
	return j


## Soft oval contact shadow on the lawn.
class Shadow extends Node2D:
	var rx := 60.0
	var ry := 12.0

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.28))
		var inner := PackedVector2Array()
		for i in 28:
			var a2 := TAU * i / 28.0
			inner.append(Vector2(cos(a2) * rx * 0.62, sin(a2) * ry * 0.6))
		draw_colored_polygon(inner, Color(0, 0, 0, 0.18))


func setup(k: int) -> void:
	kind = k
	_ground = Node2D.new()
	add_child(_ground)
	var shadow := Shadow.new()
	match kind:
		KIND_GARGANTUAR:
			shadow.rx = 120.0
			shadow.ry = 20.0
			shadow.position = Vector2(-10, -4)
		KIND_IMP:
			shadow.rx = 34.0
			shadow.ry = 7.0
		_:
			shadow.rx = 78.0
			shadow.ry = 15.0
			shadow.position = Vector2(-4, -4)
	shadow.z_index = -1
	_ground.add_child(shadow)
	match kind:
		KIND_GARGANTUAR:
			_build_gargantuar()
		KIND_IMP:
			_build_imp()
		_:
			_build_zombie()


# ====================================================================== Regular / Conehead / Buckethead
func _build_zombie() -> void:
	# `rig` holds the parts in picture coordinates; shifting it by -ground puts the feet on the origin.
	var rig := Node2D.new()
	rig.position = -Z_GROUND
	_ground.add_child(rig)

	_feet = _joint(rig, Z_FEET_PIVOT, Vector2.ZERO, 0)
	_sprite(_feet, "zombie/feet.png", Z_PARTS["feet"], Z_FEET_PIVOT, 0)

	_upper = _joint(rig, Z_HIPS, Vector2.ZERO, 1)
	_sprite(_upper, "zombie/body.png", Z_PARTS["body"], Z_HIPS, 0)

	_head = _joint(_upper, Z_NECK, Z_HIPS, 2)
	_sprite(_head, "zombie/head.png", Z_PARTS["head"], Z_NECK, 0)
	_armor_sprite = Sprite2D.new()
	_armor_sprite.centered = false
	_armor_sprite.z_index = 1
	_armor_sprite.visible = false
	_head.add_child(_armor_sprite)


# ---- armor: the cone / bucket cut from the HD Conehead / Buckethead art, 3 damage states ----
## armor_type: 0 none, 1 cone, 2 bucket (core code); hp / max_hp: the armor's remaining / initial HP.
func set_armor(armor_type: int, hp: int, max_hp: int) -> void:
	if _armor_sprite == null:
		return
	if armor_type == 0 or hp <= 0:
		if _armor_type != 0:
			_drop_armor()
		_armor_type = 0
		_armor_state = 0
		_armor_sprite.visible = false
		return
	var frac := float(hp) / float(maxi(max_hp, 1))
	var state := 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
	if armor_type != _armor_type or state != _armor_state:
		_armor_type = armor_type
		_armor_state = state
		_armor_sprite.texture = _tex("zombie/%s_%d.png" % [ARMOR_NAMES[armor_type], state])
		_armor_sprite.scale = Vector2.ONE * float(Z_ARMOR_SCALE[armor_type])
		_armor_sprite.position = Z_ARMOR_SEAT[armor_type] - Z_NECK
		_armor_sprite.visible = true


## The armor flies off the head, tumbles and fades (visual only).
func _drop_armor() -> void:
	var nm: String = ARMOR_NAMES.get(_armor_type, "")
	if nm == "" or _armor_sprite == null:
		return
	var s := Sprite2D.new()
	s.texture = _tex("zombie/%s_3.png" % nm)
	s.centered = false
	s.top_level = true
	s.z_index = 8
	s.global_position = _armor_sprite.global_position
	s.global_rotation = _armor_sprite.global_rotation
	s.scale = global_scale * float(Z_ARMOR_SCALE.get(_armor_type, 1.0))
	add_child(s)
	var dir := -1.0 if randf() < 0.5 else 1.0
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "global_position", s.global_position + Vector2(dir * 30.0, 70.0) * global_scale.x, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "rotation", s.rotation + dir * 1.6, 0.5)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(s.queue_free)


# ====================================================================== Gargantuar
func _build_gargantuar() -> void:
	var rig := Node2D.new()
	rig.position = -G_GROUND
	_ground.add_child(rig)

	_feet = _joint(rig, G_PARTS["feet"] + Vector2(90, 5), Vector2.ZERO, 0)
	_sprite(_feet, "gargantuar/feet.png", G_PARTS["feet"], G_PARTS["feet"] + Vector2(90, 5), 0)

	_upper = _joint(rig, G_HIPS, Vector2.ZERO, 1)
	_sprite(_upper, "gargantuar/body.png", G_PARTS["body"], G_HIPS, 0)

	_head = _joint(_upper, G_NECK, G_HIPS, 2)
	_sprite(_head, "gargantuar/head.png", G_PARTS["head"], G_NECK, 0)

	_pole = _joint(_upper, G_GRIP, G_HIPS, 3)
	_sprite(_pole, "gargantuar/pole.png", G_PARTS["pole"], G_GRIP, 0)
	# the hands are drawn over the pole (it passes behind them)
	var hand := _joint(_upper, Vector2.ZERO, G_HIPS, 4)
	_sprite(hand, "gargantuar/hand.png", G_PARTS["hand"], Vector2.ZERO, 0)
	_sprite(hand, "gargantuar/grip.png", G_PARTS["grip"], Vector2.ZERO, 1)

	_rider = _joint(_upper, Vector2.ZERO, G_HIPS, 5)
	_sprite(_rider, "gargantuar/imp_rider.png", G_PARTS["imp_rider"], Vector2.ZERO, 0)


## Where the Imp sits (for the flight start), relative to the ground point, in rig pixels.
func rider_offset() -> Vector2:
	return G_PARTS["imp_rider"] + Vector2(40, 36) - G_GROUND


# ====================================================================== Imp
# Layers (assets/characters/imp, built by tools/character_art/imp_parts.py): head (cut from the reference), shirt body,
# arms, legs, shoes. Pixel layout, origin = ground between the feet.
const IMP_HIP_BACK := Vector2(-5, -33)
const IMP_HIP_FRONT := Vector2(8, -33)
const IMP_WAIST := Vector2(0, -30)
const IMP_NECK := Vector2(6, -62)
const IMP_SHOULDER_FRONT := Vector2(-6, -62)
const IMP_SHOULDER_BACK := Vector2(12, -62)


func _imp_leg(hip: Vector2, z: int) -> Node2D:
	var j := _joint(_ground, hip, Vector2.ZERO, z)
	var leg := Sprite2D.new()
	leg.texture = _tex("imp/leg.png")
	leg.centered = false
	leg.position = Vector2(-5.5, 0)
	j.add_child(leg)
	var shoe := Sprite2D.new()
	shoe.texture = _tex("imp/shoe.png")
	shoe.centered = false
	shoe.position = Vector2(-16, 22)
	j.add_child(shoe)
	return j


func _build_imp() -> void:
	_leg_back = _imp_leg(IMP_HIP_BACK, 0)
	_upper = _joint(_ground, IMP_WAIST, Vector2.ZERO, 1)

	# arm behind the body, body, head, arm in front
	_arm_r = _joint(_upper, IMP_SHOULDER_BACK, IMP_WAIST, -1)
	_sprite(_arm_r, "imp/arm.png", Vector2(-5.5, 0), Vector2.ZERO, 0)

	var body := Sprite2D.new()
	body.texture = _tex("imp/body.png")
	body.centered = false
	body.position = Vector2(-20, -40)       # body spans y -70..-26 relative to the ground
	_upper.add_child(body)

	_head = _joint(_upper, IMP_NECK, IMP_WAIST, 2)
	var head := Sprite2D.new()
	head.texture = _tex("imp/head.png")
	head.centered = false
	head.position = Vector2(-36, -58)       # chin overlaps the shirt collar
	_head.add_child(head)

	_arm_l = _joint(_upper, IMP_SHOULDER_FRONT, IMP_WAIST, 3)
	_sprite(_arm_l, "imp/arm.png", Vector2(-5.5, 0), Vector2.ZERO, 0)

	_leg_front = _imp_leg(IMP_HIP_FRONT, 2)


# ====================================================================== animation state
func set_anim(name: String) -> void:
	if _dying:
		return
	if name != anim:
		anim = name
		_t = 0.0
		if name == "throw":
			_released = false


func flash() -> void:
	_hurt_left = 0.18


func set_paused(paused: bool) -> void:
	_speed = 0.0 if paused else 1.0


## Play the death motion once, then emit death_finished.
func die() -> void:
	if _dying:
		return
	_dying = true
	anim = "death"
	_t = 0.0
	if _armor_sprite:
		_armor_sprite.visible = false
	var tw := create_tween()
	match kind:
		KIND_GARGANTUAR:
			# a long heavy fall forward (to the left), head lagging behind
			tw.tween_property(_ground, "rotation", -1.35, 1.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_head, "rotation", -0.35, 1.0)
			tw.tween_interval(0.35)
			tw.tween_property(self, "modulate:a", 0.0, 0.6)
		KIND_IMP:
			tw.tween_property(_ground, "rotation", -1.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.25)
			tw.tween_property(self, "modulate:a", 0.0, 0.4)
		_:
			# zombie slumps forward; the head drops a little further
			tw.tween_property(_ground, "rotation", -1.42, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(_head, "rotation", -0.55, 0.8)
			tw.tween_interval(0.25)
			tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): death_finished.emit())


func _process(delta: float) -> void:
	if _ground == null or _dying:
		return
	var dt := delta * _speed
	_t += dt
	_hurt_left = maxf(_hurt_left - dt, 0.0)
	match kind:
		KIND_GARGANTUAR:
			_animate_gargantuar()
		KIND_IMP:
			_animate_imp()
		_:
			_animate_zombie()
	# white flash while hurt
	modulate = Color(1.6, 1.6, 1.6) if _hurt_left > 0.0 else Color.WHITE


func _animate_zombie() -> void:
	var feet_x := 0.0
	var feet_rot := 0.0
	var bob := 0.0
	var sway := 0.0
	var head_rot := 0.0
	match anim:
		"walk":
			var w := _t * 5.2
			feet_x = sin(w) * 6.0
			feet_rot = sin(w) * 0.03
			bob = absf(sin(w)) * 4.0
			sway = sin(w * 0.5) * 0.03
			head_rot = sin(w + 0.9) * 0.05
		"eat":
			# lean in and bite, over and over
			var w2 := _t * 8.0
			var k := 0.5 + 0.5 * sin(w2)
			sway = -0.10 * k
			head_rot = -0.16 * k + 0.04
			bob = 2.0 * k
		"idle":
			sway = sin(_t * 1.6) * 0.012
			head_rot = sin(_t * 1.3 + 0.5) * 0.02
			bob = sin(_t * 2.0) * 1.2
	_feet.position.x = Z_FEET_PIVOT.x + feet_x
	_feet.rotation = feet_rot
	_upper.position = Z_HIPS + Vector2(0, -bob)
	_upper.rotation = sway
	_head.rotation = head_rot


func _animate_imp() -> void:
	var bob := 0.0
	var swing := 0.0
	var lean := 0.0
	var head_rot := 0.0
	var arm_f := 0.0
	var arm_b := 0.0
	match anim:
		"walk":
			var w := _t * 9.0
			swing = sin(w)
			bob = absf(sin(w)) * 3.5
			lean = sin(w * 0.5) * 0.04
			head_rot = sin(w + 0.8) * 0.06
			arm_f = -swing * 0.65 + 0.15
			arm_b = swing * 0.65 + 0.15
		"eat":
			# lunge forward and chomp, arms reaching toward the plant
			var w2 := _t * 11.0
			var k := 0.5 + 0.5 * sin(w2)
			lean = 0.12 * k
			bob = 1.5 * k
			head_rot = 0.2 * k - 0.04
			arm_f = 1.25 + 0.25 * sin(w2 + 1.0)
			arm_b = 1.1 + 0.25 * sin(w2)
		"idle":
			bob = sin(_t * 2.4) * 1.0
			head_rot = sin(_t * 1.8) * 0.03
			arm_f = 0.08 + sin(_t * 2.0) * 0.04
			arm_b = 0.08 - sin(_t * 2.0) * 0.04
	_upper.position = IMP_WAIST + Vector2(0, -bob)
	_upper.rotation = lean
	_head.rotation = head_rot
	_arm_l.rotation = arm_f
	_arm_r.rotation = arm_b
	_leg_back.rotation = swing * 0.55
	_leg_front.rotation = -swing * 0.55


func _animate_gargantuar() -> void:
	var feet_x := 0.0
	var bob := 0.0
	var sway := 0.0
	var head_rot := 0.0
	var pole_rot := 0.0
	var rider_shift := Vector2.ZERO
	match anim:
		"walk":
			var w := _t * 2.6
			feet_x = sin(w) * 5.0
			bob = absf(sin(w)) * 3.5
			sway = sin(w) * 0.012
			head_rot = sin(w + 1.0) * 0.03
			pole_rot = sin(w) * 0.03 - 0.02
			rider_shift = Vector2(0, -absf(sin(w)) * 1.5)
		"eat":
			# wind the pole up, hold, slam it down, recover
			var c := fposmod(_t / 1.5, 1.0)
			if c < 0.55:
				var p := c / 0.55
				pole_rot = 0.9 * sin(p * PI * 0.5)
				sway = 0.025 * p
				head_rot = 0.04 * p
			elif c < 0.65:
				pole_rot = 0.9
			elif c < 0.72:
				var p2 := (c - 0.65) / 0.07
				pole_rot = lerpf(0.9, -0.06, p2)
				sway = lerpf(0.025, -0.035, p2)
				head_rot = lerpf(0.04, -0.07, p2)
				bob = -3.0 * p2
			else:
				var p3 := (c - 0.72) / 0.28
				pole_rot = lerpf(-0.06, 0.0, p3)
				sway = lerpf(-0.035, 0.0, p3)
				head_rot = lerpf(-0.07, 0.0, p3)
		"throw":
			# lean back, then let go of the Imp
			var p4 := clampf(_t / G_THROW_RELEASE, 0.0, 1.0)
			sway = 0.055 * sin(p4 * PI * 0.5) * (1.0 if _t < G_THROW_RELEASE else clampf(1.0 - (_t - G_THROW_RELEASE) / 0.4, 0.0, 1.0))
			head_rot = -0.05 * p4
			pole_rot = 0.12 * p4
			rider_shift = Vector2(4.0, -3.0) * p4
			if _t >= G_THROW_RELEASE and not _released:
				_released = true
				if _rider:
					_rider.visible = false
				imp_released.emit()
		"idle":
			bob = sin(_t * 1.5) * 1.4
			sway = sin(_t * 1.1) * 0.006
			head_rot = sin(_t * 1.2 + 0.6) * 0.02
	var feet_base: Vector2 = G_PARTS["feet"] + Vector2(90, 5)
	_feet.position.x = feet_base.x + feet_x
	_upper.position = G_HIPS + Vector2(0, -bob)
	_upper.rotation = sway
	_head.rotation = head_rot
	_pole.rotation = pole_rot
	if _rider and not _released:
		_rider.position = -G_HIPS + rider_shift
