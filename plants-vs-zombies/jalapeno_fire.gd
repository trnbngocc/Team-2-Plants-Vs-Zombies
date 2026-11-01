class_name JalapenoFire
extends Node2D
## jalapeno_fire.gd - visual-only row of fire for the Jalapeno explosion.
##
## Created by main_game.gd when GameController emits "jalapeno_exploded" (the real
## explosion, after the existing 2 s fuse). Damage, targeting and timing all stay
## in C++; this only draws: the blaze bursts from the jalapeno, races to both ends of
## the row, burns for a moment, then dies down into smoke and frees itself.

const SPREAD_TIME := 0.35
const BURN_TIME := 0.45
const FADE_TIME := 0.5
const STEP := 11.0            # spacing between flame tongues
const FLAME_HEIGHT := 70.0

var x_from := 0.0             # row ends and the jalapeno's position, in parent coordinates
var x_to := 0.0
var origin_x := 0.0
var _t := 0.0


func setup(row_left: float, row_right: float, jalapeno_x: float, ground_y: float) -> void:
	x_from = row_left
	x_to = row_right
	origin_x = jalapeno_x
	position = Vector2(0, ground_y)


func _process(delta: float) -> void:
	_t += delta
	if _t >= SPREAD_TIME + BURN_TIME + FADE_TIME:
		queue_free()
		return
	queue_redraw()


func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


func _draw() -> void:
	var spread := clampf(_t / SPREAD_TIME, 0.0, 1.0)
	spread = 1.0 - pow(1.0 - spread, 2.0)                # ease out
	var left := lerpf(origin_x, x_from, spread)
	var right := lerpf(origin_x, x_to, spread)
	var fade := clampf((_t - SPREAD_TIME - BURN_TIME) / FADE_TIME, 0.0, 1.0)
	var life := 1.0 - fade
	# glow on the ground along the burning span
	draw_rect(Rect2(left, -14.0, right - left, 20.0), Color(1.0, 0.45, 0.05, 0.35 * life))
	var n := int((x_to - x_from) / STEP) + 1
	for i in n:
		var x := x_from + i * STEP
		if x < left - 1.0 or x > right + 1.0:
			continue
		var r := _hash(i)
		# tongues near the advancing front are still growing
		var front := minf(absf(x - left), absf(x - right))
		var grow := clampf(front / 40.0, 0.25, 1.0) if spread < 1.0 else 1.0
		var flicker := 0.7 + 0.3 * sin(_t * 18.0 + r * 40.0)
		var h := FLAME_HEIGHT * (0.55 + 0.45 * r) * flicker * grow * life
		if h < 2.0:
			continue
		var w := STEP * 1.25
		var lean := sin(_t * 9.0 + r * 20.0) * 4.0
		_tongue(x, w, h, lean, Color(0.85, 0.12, 0.02, 0.85 * life))
		_tongue(x, w * 0.72, h * 0.72, lean * 0.8, Color(1.0, 0.5, 0.05, 0.9 * life))
		_tongue(x, w * 0.42, h * 0.42, lean * 0.6, Color(1.0, 0.92, 0.45, 0.95 * life))
		# embers and, while dying down, smoke puffs
		var ey := -fmod(_t * 90.0 + r * 120.0, 110.0)
		draw_circle(Vector2(x + lean + (r - 0.5) * 10.0, ey), 1.6, Color(1.0, 0.8, 0.3, 0.8 * life * (1.0 + ey / 110.0)))
		if fade > 0.0 and i % 3 == 0:
			draw_circle(Vector2(x, -h - 10.0 - fade * 30.0), 6.0 + fade * 10.0 * r, Color(0.25, 0.22, 0.22, 0.35 * fade * life * 2.0))


func _tongue(x: float, w: float, h: float, lean: float, col: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(x - w * 0.5, 0.0),
		Vector2(x - w * 0.55 + lean * 0.3, -h * 0.35),
		Vector2(x - w * 0.25 + lean * 0.7, -h * 0.75),
		Vector2(x + lean, -h),
		Vector2(x + w * 0.3 + lean * 0.6, -h * 0.6),
		Vector2(x + w * 0.55 + lean * 0.2, -h * 0.3),
		Vector2(x + w * 0.5, 0.0),
	])
	draw_colored_polygon(pts, col)
