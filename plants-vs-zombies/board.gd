extends Control
## board.gd - đặt bãi cỏ (Field = ảnh lawn + 45 ô bấm) vừa khung bên dưới HUD.
##
## Field được thiết kế ở toạ độ tham chiếu (bố cục 1152x648 cũ) và chỉ được
## phóng to/thu nhỏ ĐỀU (cùng tỉ lệ ngang/dọc), nên 45 ô luôn khớp với ô vẽ
## trên ảnh. main_game.gd chép cùng transform này cho lớp vẽ cây/zombie/đạn.
## Chỉ là hiển thị: không đụng tới gameplay.

const HUD_HEIGHT := 96.0     # thanh seed bank ở trên cùng
const KEEP_LEFT := 110.0     # phần sân/nhà giữ lại bên trái bãi cỏ (toạ độ tham chiếu)
const KEEP_RIGHT := 70.0     # khoảng trống bên phải cho Zombie xuất hiện

@onready var field: Control = $Field
@onready var grid: GridContainer = $Field/GridContainer


func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)
	_relayout.call_deferred()


func _relayout() -> void:
	var view := get_viewport_rect().size
	var lawn_pos := grid.position
	var lawn_size := grid.get_combined_minimum_size()
	# Lớn nhất có thể mà bãi cỏ vẫn nằm trọn dưới HUD và đủ chỗ hai bên
	var k := minf((view.y - HUD_HEIGHT) / lawn_size.y,
			view.x / (KEEP_LEFT + lawn_size.x + KEEP_RIGHT))
	# Ưu tiên sát phải (Zombie vào từ phải, nhà bên trái), nhưng không để
	# mép trái ảnh lộ ra trong cửa sổ; phần dư thì chia đều hai bên.
	var left := view.x - (lawn_size.x + KEEP_RIGHT) * k
	var max_left := lawn_pos.x * k
	if left > max_left:
		left = max_left + (left - max_left) * 0.5
	var top := HUD_HEIGHT + (view.y - HUD_HEIGHT - lawn_size.y * k) * 0.5
	field.scale = Vector2(k, k)
	field.position = Vector2(left, top) - lawn_pos * k
