class_name ZombieView
extends Node2D
## zombie_view.gd - hình + animation của MỘT Zombie trên bãi cỏ.
##
## Chỉ hiển thị: vị trí, ăn/đi, máu, armor đều lấy từ dữ liệu Core
## (get_zombies_data). Không tự di chuyển, không tự tính sát thương.
##
## Sprite sheet (sinh bởi tools/zombie_art/generate_zombies.py):
##   mỗi hàng là một animation theo thứ tự ANIMS, mỗi cột một frame,
##   frame FRAME_SIZE, gốc chân (pivot) tại PIVOT trong mọi frame.

const FRAME_SIZE := Vector2i(192, 200)
const PIVOT := Vector2(80, 190)
const DRAW_SCALE := 0.66

# Mã armor theo Core: 0 NONE (thường), 1 CONE, 2 BUCKET
const SHEETS := {
	0: "res://assets/zombies/zombie_regular.png",
	1: "res://assets/zombies/zombie_cone.png",
	2: "res://assets/zombies/zombie_bucket.png",
}
const HEADWEAR := {
	1: "res://assets/zombies/headwear_cone.png",
	2: "res://assets/zombies/headwear_bucket.png",
}
# Vị trí (theo pixel frame, so với pivot) của mũ khi còn đội trên đầu
const HEADWEAR_SEAT := Vector2(-8, -130)
# Tâm thanh máu (pixel frame, so với pivot): ngay trên tóc của Zombie không đội mũ
const HEALTH_BAR_POS := Vector2(-12, -152)

# [tên, số frame, fps, lặp]
const ANIMS := [
	["idle", 6, 6.0, true],
	["walk", 8, 8.0, true],
	["eat", 6, 8.0, true],
	["hurt", 4, 12.0, false],
	["death", 10, 10.0, false],
]

const STATE_PLAYING := 1
const STATE_PAUSED := 2

static var _frames_cache := {}

var sprite: AnimatedSprite2D
var armor := -1
var eating := false
var hurting := false
var dying := false
var _last_hp := -1
var _game_state := STATE_PLAYING
var health_bar: HealthBar


## Thanh máu nhỏ trên đầu Zombie (con của ZombieView: đi theo Zombie, bị xoá cùng
## Zombie, nằm trong lớp gameplay nên bị lớp phủ Pause / Thắng / Thua làm tối).
## Chỉ vẽ tỉ lệ HP thân do Core cung cấp; không có giá trị máu riêng.
class HealthBar extends Node2D:
	const SIZE := Vector2(58, 9)          # pixel frame (x DRAW_SCALE trên màn hình)
	const BORDER := Color("2b3c4c")       # viền navy giống nút đá
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
			# giảm nhanh nhưng mượt (đạt ~95% sau 0.25 s)
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
	sprite = AnimatedSprite2D.new()
	sprite.centered = false
	sprite.offset = -PIVOT
	sprite.animation_finished.connect(_on_animation_finished)
	add_child(sprite)
	health_bar = HealthBar.new()
	health_bar.position = HEALTH_BAR_POS
	health_bar.visible = false
	add_child(health_bar)
	scale = Vector2.ONE * DRAW_SCALE


static func frames_for(armor_type: int) -> SpriteFrames:
	if _frames_cache.has(armor_type):
		return _frames_cache[armor_type]
	var sheet: Texture2D = load(SHEETS[armor_type])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in ANIMS.size():
		var a: Array = ANIMS[row]
		frames.add_animation(a[0])
		frames.set_animation_speed(a[0], a[2])
		frames.set_animation_loop(a[0], a[3])
		for i in int(a[1]):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2(i * FRAME_SIZE.x, row * FRAME_SIZE.y), FRAME_SIZE)
			frames.add_frame(a[0], atlas)
	_frames_cache[armor_type] = frames
	return frames


## Cập nhật từ một Dictionary của get_zombies_data() mỗi frame.
func apply_data(d: Dictionary) -> void:
	if dying:
		return
	var a := clampi(int(d.get("armor", 0)), 0, 2)
	if a != armor:
		if armor > 0 and a < armor:
			_drop_headwear(armor)
		_set_armor(a)

	# Máu + armor giảm so với frame trước -> bị trúng đòn.
	var hp := int(d.get("health", 0)) + int(d.get("armor_health", 0))
	if _last_hp >= 0 and hp < _last_hp:
		_start_hurt()
	_last_hp = hp

	# Thanh máu: chỉ hiện khi KHÔNG còn nón / xô; luôn là HP thân lấy từ Core
	var max_hp := int(d.get("max_health", 0))
	var was_visible := health_bar.visible
	health_bar.visible = a == 0 and max_hp > 0
	if max_hp > 0:
		health_bar.set_target(float(d.get("health", 0)) / float(max_hp))
		if health_bar.visible and not was_visible:
			health_bar.snap()   # vừa mất nón/xô: hiện ngay đúng HP thân còn lại

	eating = bool(d.get("eating", false))
	# ONE_ARM_LOST (visual_state 1): tối màu nhẹ để vẫn thấy Zombie yếu đi
	modulate = Color(0.82, 0.86, 0.8) if int(d.get("visual_state", 0)) == 1 else Color.WHITE
	_play_base()


## PLAYING: chạy animation; PAUSED: đứng hình; VICTORY/DEFEAT: idle.
func set_game_state(state: int) -> void:
	_game_state = state
	sprite.speed_scale = 0.0 if state == STATE_PAUSED else 1.0
	_play_base()


## Core đã xoá Zombie (chết): chơi death rồi tự giải phóng.
func die() -> void:
	if dying:
		return
	dying = true
	hurting = false
	health_bar.visible = false
	sprite.speed_scale = 1.0
	sprite.play("death")


func current_animation() -> String:
	return String(sprite.animation)


func _set_armor(a: int) -> void:
	armor = a
	var anim := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.sprite_frames = frames_for(a)
	# Giữ nhịp animation khi đổi hình (ví dụ rơi nón giữa bước đi)
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		sprite.set_frame_and_progress(frame, progress)
	else:
		sprite.play("walk")


func _play_base() -> void:
	if dying or hurting:
		return
	var want := "walk"
	if _game_state != STATE_PLAYING and _game_state != STATE_PAUSED:
		want = "idle"
	elif eating:
		want = "eat"
	if sprite.animation != want or not sprite.is_playing():
		sprite.play(want)


func _start_hurt() -> void:
	if dying:
		return
	hurting = true
	sprite.play("hurt")
	sprite.set_frame_and_progress(0, 0.0)


func _on_animation_finished() -> void:
	if dying:
		queue_free()
	elif hurting:
		hurting = false
		_play_base()


# Nón / xô bị phá: rơi xuống đất rồi mờ dần (chỉ là hiệu ứng hình).
func _drop_headwear(old_armor: int) -> void:
	var parent := get_parent()
	if parent == null or not HEADWEAR.has(old_armor):
		return
	var tex: Texture2D = load(HEADWEAR[old_armor])
	var hat := Sprite2D.new()
	hat.texture = tex
	hat.scale = scale
	hat.z_index = z_index
	hat.position = position + HEADWEAR_SEAT * DRAW_SCALE
	parent.add_child(hat)
	var tw := hat.create_tween()
	tw.set_parallel(true)
	tw.tween_property(hat, "position", position + Vector2(-22, -8), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(hat, "rotation", -1.6, 0.45)
	tw.chain().tween_property(hat, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(hat.queue_free)
