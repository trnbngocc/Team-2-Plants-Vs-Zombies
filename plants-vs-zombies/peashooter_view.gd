class_name PeashooterView
extends Node2D
## peashooter_view.gd - Peashooter assembled from the supplied part images.
##
## Parts and their assembled positions come from tools/peashooter/build_peashooter.py
## (assets/plants/peashooter/parts/*.png + peashooter_layout.gd). Only presentation:
##   idle  - gentle head sway / bob, crest and leaf flutter, eye blink
##   shoot - head recoil + flared mouth tube; started by play_shoot(), which the UI
##           calls on GameController's "projectile_fired" signal (the real shot).
## The node origin is the plant's feet.

const Layout := preload("res://assets/plants/peashooter/peashooter_layout.gd")
const PARTS_DIR := "res://assets/plants/peashooter/parts/"
const DRAW_SCALE := 0.52
const NECK := Vector2(77, 78)          # canvas px: where the stem meets the head (sway pivot)
const SHOOT_TIME := 0.22
const HEAD_PARTS := ["crest_leaf_a", "crest_leaf_b", "crest_leaf_c", "crest_leaf_d", "crest_leaf_e",
	"crest_leaf_f", "crest_leaf_g", "head", "mouth", "mouth_alt", "eyes_open", "eyes_closed"]

static var _tex := {}

var _head: Node2D
var _sprites := {}
var _t := 0.0
var _shoot_left := 0.0
var _blink_left := 0.0
var _next_blink := 2.0
var animating := true


func _init() -> void:
	scale = Vector2.ONE * DRAW_SCALE
	_t = randf() * 10.0               # neighbours do not sway in sync
	_next_blink = randf_range(1.5, 4.0)
	# Layering by child order only (Layout.PARTS is sorted by depth); no z_index,
	# so zombies keep drawing over plants exactly as before.
	_head = Node2D.new()
	_head.position = NECK - Layout.FEET
	for part in Layout.PARTS:
		var s := Sprite2D.new()
		s.texture = _texture(part)
		var centre: Vector2 = Layout.PARTS[part]["centre"]
		if part in HEAD_PARTS:
			s.position = centre - NECK
			_head.add_child(s)
		else:
			s.position = centre - Layout.FEET
			add_child(s)
		_sprites[part] = s
	add_child(_head)   # head (with crest, mouth, eyes) above stem and leaves
	_sprites["mouth"].visible = false        # flared tube: only while firing
	_sprites["eyes_open"].visible = false    # head already has open eyes drawn
	_sprites["eyes_closed"].visible = false  # shown briefly to blink


static func _texture(part: String) -> Texture2D:
	if not _tex.has(part):
		_tex[part] = load(PARTS_DIR + part + ".png")
	return _tex[part]


## Mouth tip relative to the feet, in this node's parent coordinates.
static func mouth_offset() -> Vector2:
	var m: Vector2 = Layout.PARTS["mouth_alt"]["centre"]
	return (m + Vector2(14, 0) - Layout.FEET) * DRAW_SCALE


func play_shoot() -> void:
	_shoot_left = SHOOT_TIME


func _process(delta: float) -> void:
	if not animating:
		return
	_t += delta
	# idle: head sways around the neck and bobs a little
	var sway := sin(_t * 2.1) * 2.2
	var bob := sin(_t * 4.2) * 0.9
	var recoil := 0.0
	if _shoot_left > 0.0:
		_shoot_left -= delta
		var k := clampf(_shoot_left / SHOOT_TIME, 0.0, 1.0)
		recoil = sin(k * PI) * 5.0               # back and forward again
		_sprites["mouth"].visible = k > 0.45
		_sprites["mouth_alt"].visible = k <= 0.45
	else:
		_sprites["mouth"].visible = false
		_sprites["mouth_alt"].visible = true
	_head.position = NECK - Layout.FEET + Vector2(-recoil, bob)
	_head.rotation = deg_to_rad(sway - recoil * 0.6)
	# crest leaves flutter, base leaves breathe
	var i := 0
	for leaf in ["crest_leaf_a", "crest_leaf_b", "crest_leaf_c", "crest_leaf_d", "crest_leaf_e", "crest_leaf_f", "crest_leaf_g"]:
		_sprites[leaf].rotation = deg_to_rad(sin(_t * 3.0 + i * 0.9) * 7.0)
		i += 1
	_sprites["leaf_left"].rotation = deg_to_rad(sin(_t * 1.7) * 3.0)
	_sprites["leaf_right"].rotation = deg_to_rad(-sin(_t * 1.7 + 0.5) * 3.0)
	_sprites["leaf_pair"].scale = Vector2(1.0, 1.0 + sin(_t * 2.1) * 0.025)
	# blink with the supplied closed-eye piece
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_sprites["eyes_closed"].visible = false
			_next_blink = randf_range(2.5, 5.0)
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_left = 0.12
			_sprites["eyes_closed"].visible = true
