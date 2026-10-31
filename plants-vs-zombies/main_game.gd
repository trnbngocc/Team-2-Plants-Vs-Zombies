extends Control
## main_game.gd - script UI của Quyên, gắn vào Node GỐC của MainGame.tscn.
##
## NGUYÊN TẮC (theo yêu cầu của Ngọc):
##  - UI chỉ HIỂN THỊ dữ liệu lấy từ Core và GỌI hàm của GameController.
##  - KHÔNG tự tính Sun, sát thương, va chạm, thắng/thua trong file này.
##  - Hàm nào Core chưa có thì UI chỉ in cảnh báo, không tự tạo dữ liệu giả.

const DEBUG_LOG := true

# --- Mã số cây (theo tài liệu của Ngọc) ---
const PLANT_PEASHOOTER := 0
const PLANT_SUNFLOWER := 1
const PLANT_WALLNUT := 2
const PLANT_CHILI := 3

# --- Trạng thái game (theo tài liệu của Ngọc) ---
const STATE_SETUP := 0
const STATE_PLAYING := 1
const STATE_PAUSED := 2
const STATE_VICTORY := 3
const STATE_DEFEAT := 4

const BOARD_COLS := 9

# Tên Node của thẻ cây (viết thường, bỏ khoảng trắng và gạch dưới) -> mã số cây
const CARD_NAME_TO_TYPE := {
	"peashooter": PLANT_PEASHOOTER,
	"sunflower": PLANT_SUNFLOWER,
	"wallnut": PLANT_WALLNUT,
	"cherrybomb": PLANT_CHILI,
	"chili": PLANT_CHILI,
	"chilipepper": PLANT_CHILI,
}

# Hình dùng để vẽ cây trên bàn chơi (đổi lại nếu tên file của bạn khác)
const PLANT_TEXTURES := {
	PLANT_PEASHOOTER: "res://assets/pea.png",
	PLANT_SUNFLOWER: "res://assets/sunflower (1).png",
	PLANT_WALLNUT: "res://assets/wallnut (1).png",
	PLANT_CHILI: "res://assets/chilli.png",
}
const SUN_TEXTURE := "res://assets/sưnn.png"

# Zombie: column của Core là cạnh trước liên tục (ô c chiếm [c, c+1)).
# Chân Zombie đặt lùi sau cạnh trước một chút để tay/miệng chạm cây khi ăn.
const ZOMBIE_FEET_BEHIND_FRONT := 16.0
const ZOMBIE_FEET_BELOW_CENTER := 0.36   # tỉ lệ chiều cao hàng

# Peashooter ghép từ các mảnh: chân cây dưới tâm ô; đạn vẽ ngang miệng cây
const PEA_FEET_BELOW_CENTER := 26.0
const PROJECTILE_TEXTURE := "res://assets/projectiles/pea_projectile.png"
const PROJECTILE_SIZE := Vector2(20, 20)

const MENU_SCENE := "res://scenes/menu.tscn"

# Cảnh báo "zombies are coming" phát trước khi Zombie đầu tiên xuất hiện bao nhiêu giây
# (giây của game; phần có tiếng của file dài khoảng 3.4 s)
const ZOMBIE_WARNING_LEAD := 3.0

# Lý do Core từ chối trồng cây (GameController::PlacementResult)
const PLACE_OCCUPIED := 3
const PLACE_NOT_ENOUGH_SUN := 4
# Màu chữ thông báo: lấy từ ô đếm Sun của HUD (sun_display.tscn), thêm đỏ đậm cho cảnh báo
const NOTICE_TEXT := Color(0.2, 0.12, 0.02, 1)
const NOTICE_OUTLINE := Color(1, 0.97, 0.85, 1)
const NOTICE_WARNING := Color(0.62, 0.1, 0.04, 1)
# Thông báo "CANNOT PLANT HERE!": bay lên bao nhiêu px, không lên cao hơn đáy HUD
const CANNOT_PLANT_RISE := 26.0
const CANNOT_PLANT_MIN_Y := 98.0

var game_controller: Node
var selected_plant_type: int = -1

var sun_label: Label
var pause_button: BaseButton
var win_screen: Control
var lose_screen: Control
var pause_overlay: Control

var cells: Array = []
var card_buttons := {}
var entity_layer: Control
var board_field: Control

var plant_views := {}    # "row,col" -> view (mỗi ô tối đa 1 cây)
var zombie_views := {}   # id Zombie (từ Core) -> ZombieView
var bullet_views: Array = []
var sun_views := {}

var _warned := {}
var _dumped := {}
var _tex_cache := {}
var _last_state := -99
var _zombie_warning_played := false   # "zombies are coming": đúng 1 lần mỗi ván (ván mới = scene mới)
var _leaving := false    # đã bấm Quit: không xử lý thêm lần nữa
var _notice: VBoxContainer   # thông báo trồng cây đang hiện (tối đa một)
var _notice_tween: Tween


func _ready() -> void:
	print("[UI] main_game.gd dang chay")
	game_controller = get_node_or_null("../GameController")
	if game_controller == null:
		push_error("[UI] Khong tim thay ../GameController. MainGame phai nam canh GameController trong main.tscn")
		return

	# Tìm Node theo TÊN (không dùng đường dẫn cứng nên không sợ sai cấu trúc scene)
	sun_label = _find_in("sun_display", "Label") as Label
	pause_button = _find_in("pause_button", "BaseButton") as BaseButton
	win_screen = find_child("win_screen", true, false) as Control
	lose_screen = find_child("lose_screen", true, false) as Control
	pause_overlay = find_child("pause_overlay", true, false) as Control

	for pair in [["sun_label", sun_label], ["pause_button", pause_button], ["win_screen", win_screen], ["lose_screen", lose_screen], ["pause_overlay", pause_overlay]]:
		if pair[1] == null:
			push_warning("[UI] Khong tim thay: " + pair[0] + " (kiem tra ten Node trong MainGame.tscn)")

	_connect_seed_cards()
	_connect_board_cells()

	if pause_button:
		pause_button.pressed.connect(_on_pause_pressed)
	# Màn hình thắng / thua: Play Again (ván mới hoàn toàn) và Quit (thoát hẳn game)
	for screen in [win_screen, lose_screen]:
		if screen:
			screen.visible = false
			_connect_named_button(screen, "PlayAgain", _on_play_again_pressed)
			_connect_named_button(screen, "Quit", _on_end_screen_quit_pressed)
	# Màn hình Pause: Resume (chơi tiếp) và Quit -> về Main Menu
	if pause_overlay:
		pause_overlay.visible = false
		_connect_named_button(pause_overlay, "Resume", _on_resume_pressed)
		_connect_named_button(pause_overlay, "Quit", _on_pause_quit_pressed)

	# Sự kiện chỉ để trình bày (âm thanh / hoạt ảnh), Core phát khi chúng thật sự xảy ra
	if game_controller.has_signal("projectile_fired"):
		game_controller.projectile_fired.connect(_on_projectile_fired)
	if game_controller.has_signal("projectile_hit"):
		game_controller.projectile_hit.connect(_on_projectile_hit)
	if game_controller.has_signal("plant_placed"):
		game_controller.plant_placed.connect(_on_plant_placed)
	if game_controller.has_signal("placement_rejected"):
		game_controller.placement_rejected.connect(_on_placement_rejected)
	if game_controller.has_signal("chili_exploded"):
		game_controller.chili_exploded.connect(_on_chili_exploded)

	# Nhạc nền duy nhất của trận: chạy từ lúc chuẩn bị, qua cả lúc vào trận (không khởi động lại)
	Audio.play_music("gameplay")

	# Lớp chứa cây/zombie/đạn/Sun: nằm trên Board, dưới HUD, không chặn chuột.
	# Các lớp phủ Pause / Thắng / Thua ở OverlayLayer (CanvasLayer riêng, vẽ trên cùng),
	# nên mọi thứ ở đây -- kể cả Zombie có z_index cao -- đều bị phủ tối đồng đều.
	entity_layer = Control.new()
	entity_layer.name = "EntityLayer"
	entity_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(entity_layer)
	var hud := find_child("hud", false, false)
	if hud:
		move_child(entity_layer, hud.get_index())
	# Bãi cỏ được board.gd co giãn đều theo cửa sổ; lớp vẽ đi theo cùng transform
	board_field = find_child("Field", true, false) as Control
	if board_field == null:
		push_warning("[UI] Khong thay Node Field trong board.tscn")

	var s = _core("get_state")
	print("[UI] state luc bat dau = ", s, "  (0 SETUP, 1 PLAYING, 2 PAUSED, 3 VICTORY, 4 DEFEAT)")
	# Nếu state vẫn là 0 (SETUP) khi chạy, hỏi Ngọc ai chịu trách nhiệm gọi start_game().
	# Nếu Ngọc bảo UI gọi thì bỏ dấu # ở dòng dưới:
	# _core("start_game")


func _process(_delta: float) -> void:
	if game_controller == null:
		return
	_update_sun_label()
	_update_zombie_warning()
	_update_state_ui()
	_follow_board_field()
	_sync_plants()
	_sync_zombies()
	_sync_bullets()
	_sync_sun_drops()


# ====================== GỌI CORE AN TOÀN ======================

func _core(method: String, args: Array = []) -> Variant:
	if not game_controller.has_method(method):
		if not _warned.has(method):
			_warned[method] = true
			push_warning("[UI] Core chua co ham '" + method + "' -> bao Ngoc de mo them API")
		return null
	return game_controller.callv(method, args)


func _as_list(data) -> Array:
	if data is Array:
		return data
	if data is Dictionary:
		return data.values()
	return []


func _debug_dump(source: String, list: Array) -> void:
	if DEBUG_LOG and not list.is_empty() and not _dumped.has(source):
		_dumped[source] = true
		print("[UI][DEBUG] ", source, " mau dau tien: ", list[0])


# ====================== TÌM NODE & NỐI NÚT ======================

func _find_in(container_name: String, node_type: String) -> Node:
	var container := find_child(container_name, true, false)
	if container == null:
		push_warning("[UI] Khong thay Node ten: " + container_name)
		return null
	var found := container.find_children("*", node_type, true, false)
	if found.is_empty():
		push_warning("[UI] Khong thay " + node_type + " ben trong " + container_name)
		return null
	return found[0]


func _connect_seed_cards() -> void:
	var bank := find_child("seed_bank", true, false)
	if bank == null:
		push_warning("[UI] Khong thay Node seed_bank")
		return
	for b in bank.find_children("*", "Button", true, false):
		var key := String(b.name).to_lower().replace(" ", "").replace("_", "")
		if CARD_NAME_TO_TYPE.has(key):
			var plant_type: int = CARD_NAME_TO_TYPE[key]
			b.pressed.connect(_on_seed_card_pressed.bind(plant_type))
			card_buttons[plant_type] = b
			print("[UI] Noi the cay: ", b.name, " -> loai ", plant_type)
		else:
			push_warning("[UI] The cay khong nhan ra ten: " + String(b.name) + " (doi ten Node thanh Peashooter/Sunflower/WallNut/CherryBomb)")


func _connect_board_cells() -> void:
	var grids := find_children("*", "GridContainer", true, false)
	if grids.is_empty():
		push_warning("[UI] Khong thay GridContainer cua board")
		return
	cells = grids[0].get_children()
	if cells.size() != 45:
		push_warning("[UI] Board co " + str(cells.size()) + " o, can dung 45 o (5 hang x 9 cot)")
	for i in cells.size():
		var row := floori(i / float(BOARD_COLS))
		var col := i % BOARD_COLS
		cells[i].pressed.connect(_on_cell_pressed.bind(row, col))


# ====================== SỰ KIỆN NGƯỜI CHƠI ======================

func _on_seed_card_pressed(plant_type: int) -> void:
	# Chọn thẻ cây = bấm nút UI: luôn có tiếng click (kể cả khi chưa đủ Sun)
	Audio.play_sfx("click")
	selected_plant_type = plant_type
	print("[UI] Da chon cay loai ", plant_type)
	_highlight_selected()


func _on_cell_pressed(row: int, col: int) -> void:
	if selected_plant_type == -1:
		return
	# UI KHÔNG tự trừ Sun. Core xử lý và trả true/false.
	var ok = _core("place_plant", [row, col, selected_plant_type])
	print("[UI] place_plant(", row, ", ", col, ", ", selected_plant_type, ") -> ", ok)
	if ok == true:
		selected_plant_type = -1
		_highlight_selected()


func _connect_named_button(root: Node, button_name: String, handler: Callable) -> void:
	var b := root.find_child(button_name, true, false) as BaseButton
	if b == null:
		push_warning("[UI] Khong thay nut " + button_name + " trong " + String(root.name))
	elif not b.pressed.is_connected(handler):
		b.pressed.connect(handler)


func _on_pause_pressed() -> void:
	var s = _core("get_state")
	if s != null and int(s) == STATE_PAUSED:
		_on_resume_pressed()
	elif s != null and int(s) == STATE_PLAYING:
		_core("pause_game")
		Audio.set_gameplay_paused(true)


func _on_resume_pressed() -> void:
	var s = _core("get_state")
	if s != null and int(s) == STATE_PAUSED:
		_core("resume_game")   # Core tiếp tục đúng trạng thái cũ (vị trí, máu, đạn, timer, wave)
		Audio.set_gameplay_paused(false)


# Pause -> Quit: bỏ ván đang chơi, về Main Menu (không thoát game).
func _on_pause_quit_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.stop_gameplay_audio()
	get_tree().change_scene_to_file(MENU_SCENE)


# Thắng / Thua -> Play Again: nạp lại toàn bộ scene = ván mới hoàn toàn
# (GameController mới: Sun, wave, timer, cây, zombie, đạn; UI mới: cờ cảnh báo
# zombie, thông báo...). Nhạc gameplay chạy lại từ đầu trong _ready() của ván mới.
func _on_play_again_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.stop_gameplay_audio()
	get_tree().reload_current_scene()


# Thắng / Thua -> Quit: đóng hẳn ứng dụng (không quay lại Menu).
func _on_end_screen_quit_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	Audio.quit_game()


func _on_sun_clicked(id) -> void:
	# id lấy từ Core, UI không tự tạo id
	var value = _core("collect_sun", [id])
	if value != null and int(value) > 0:
		Audio.play_sfx("sun")


# Core vừa bắn một viên đạn (chỉ Peashooter bắn): chỉ hoạt ảnh bắn, KHÔNG phát âm thanh.
func _on_projectile_fired(row: int, column: float) -> void:
	var v = plant_views.get(_cell_key(row, floori(column)))
	if v != null and is_instance_valid(v):
		var pea := v.get_node_or_null("Peashooter") as PeashooterView
		if pea:
			pea.play_shoot()


# Core xác nhận đã trồng cây thành công (đã trừ Sun): đúng một tiếng "planting".
func _on_plant_placed(_row: int, _column: int) -> void:
	Audio.play_sfx("planting")


# Core từ chối trồng cây, kèm lý do thật. Chỉ hai lý do có thông báo:
# ô đã có cây, và thiếu Sun (Core kiểm tra "ô đã có cây" trước, nên một lần
# bấm sai chỉ có một lý do -> không bao giờ hiện cả hai thông báo).
func _on_placement_rejected(row: int, column: int, reason: int, cost: int = 0) -> void:
	if reason == PLACE_OCCUPIED:
		_show_notice(row, column, "CANNOT PLANT HERE!", "", NOTICE_TEXT)
	elif reason == PLACE_NOT_ENOUGH_SUN:
		_show_notice(row, column, "NOT ENOUGH SUN!", "NEED %d SUN" % cost, NOTICE_WARNING)


# Thông báo cạnh ô vừa bấm: bay lên nhẹ rồi mờ dần (~1.2 s) và tự xoá.
# Chỉ có tối đa một thông báo: bấm sai liên tục thì làm mới / thay thông báo đang hiện.
# Kiểu chữ theo ô đếm Sun của HUD (font mặc định của game, viền kem); thông báo
# thiếu Sun dùng chữ đỏ đậm cùng hệ để phân biệt.
func _show_notice(row: int, column: int, title: String, detail: String, title_color: Color) -> void:
	var i := row * BOARD_COLS + column
	if i < 0 or i >= cells.size():
		return
	if _notice_tween:
		_notice_tween.kill()
	if _notice == null or not is_instance_valid(_notice) or _notice.is_queued_for_deletion():
		_notice = VBoxContainer.new()
		_notice.name = "PlacementNotice"
		_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_notice.add_theme_constant_override("separation", -2)
		_notice.z_index = 20   # trên cây / zombie / hiệu ứng (lớp phủ Pause vẫn ở trên)
		for part in [["Title", 22], ["Detail", 16]]:
			var l := Label.new()
			l.name = part[0]
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_color_override("font_outline_color", NOTICE_OUTLINE)
			l.add_theme_constant_override("outline_size", 7)
			l.add_theme_font_size_override("font_size", part[1])
			_notice.add_child(l)
		add_child(_notice)
	var title_label: Label = _notice.get_node("Title")
	var detail_label: Label = _notice.get_node("Detail")
	title_label.text = title
	title_label.add_theme_color_override("font_color", title_color)
	detail_label.text = detail
	detail_label.visible = detail != ""
	detail_label.add_theme_color_override("font_color", NOTICE_TEXT)
	var label := _notice
	label.reset_size()
	var cell_rect: Rect2 = (cells[i] as Control).get_global_rect()
	var view := get_viewport_rect().size
	var start := Vector2(cell_rect.get_center().x - label.size.x * 0.5, cell_rect.get_center().y - label.size.y * 0.5)
	# trong cửa sổ, và không đè lên thanh Seed Bank / HUD ở trên
	start.x = clampf(start.x, 4.0, view.x - label.size.x - 4.0)
	start.y = clampf(start.y, CANNOT_PLANT_MIN_Y + CANNOT_PLANT_RISE, view.y - label.size.y - 4.0)
	label.position = start
	label.modulate.a = 1.0
	_notice_tween = label.create_tween()
	_notice_tween.set_parallel(true)
	_notice_tween.tween_property(label, "position:y", start.y - CANNOT_PLANT_RISE, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_notice_tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.6)
	_notice_tween.chain().tween_callback(label.queue_free)


# Core xác nhận một viên đạn đã trúng Zombie (mỗi viên tối đa 1 lần): âm thanh trúng đạn.
func _on_projectile_hit(_row: int, _column: float) -> void:
	Audio.play_sfx("pea_hit")


# Chili Pepper vừa nổ (sau ngòi 2 giây của Core): âm thanh + lửa chạy ngang cả hàng.
func _on_chili_exploded(row: int, column: int) -> void:
	Audio.play_sfx("chili")
	var fire := ChiliFire.new()
	var feet := _zombie_feet(row, 0.5)
	fire.setup(_cell_center(float(row), -0.5).x, _cell_center(float(row), 8.5).x,
		_cell_center(float(row), float(column)).x, feet.y)
	fire.z_index = 6   # trên mọi Zombie / cây
	entity_layer.add_child(fire)


func _highlight_selected() -> void:
	# Thẻ cây là vùng bấm trong suốt trên ảnh seed_bank.jpg: bật khung "Selected" của thẻ được chọn
	for t in card_buttons.keys():
		var frame: Control = card_buttons[t].get_node_or_null("Selected")
		if frame:
			frame.visible = (t == selected_plant_type)
		else:
			card_buttons[t].modulate = Color(1, 1, 0.5) if t == selected_plant_type else Color.WHITE


# ====================== CẬP NHẬT HUD ======================

func _update_sun_label() -> void:
	var sun = _core("get_sun")
	if sun != null and sun_label:
		# Ảnh Seed Bank đã có biểu tượng Sun, nhãn chỉ ghi con số
		sun_label.text = str(sun)


# "Zombies are coming": đúng MỘT lần mỗi ván, ngay trước khi Zombie đầu tiên xuất hiện.
# Zombie đầu tiên được WaveManager spawn đúng lúc hết thời gian chuẩn bị, nên cảnh báo
# phát khi thời gian chuẩn bị (của Core, dừng khi Pause) còn ZOMBIE_WARNING_LEAD giây.
# Dự phòng: nếu vì lý do nào đó wave đã bắt đầu mà chưa cảnh báo thì phát ngay (vẫn 1 lần).
func _update_zombie_warning() -> void:
	if _zombie_warning_played:
		return
	var prep = _core("get_preparation_time_left")
	var wave = _core("get_wave")
	var first_zombie_due := prep != null and float(prep) <= ZOMBIE_WARNING_LEAD
	if first_zombie_due or (wave != null and int(wave) >= 1):
		_zombie_warning_played = true
		Audio.play_sfx("incoming")


func _update_state_ui() -> void:
	var s = _core("get_state")
	if s == null:
		return
	var state := int(s)
	if state != _last_state:
		_last_state = state
		print("[UI] state doi thanh ", state)
		# Thắng / thua: dừng âm thanh trận, phát âm thanh kết thúc đúng một lần
		if state == STATE_VICTORY or state == STATE_DEFEAT:
			Audio.stop_gameplay_audio()
			Audio.play_sfx("win" if state == STATE_VICTORY else "lose")
	if win_screen:
		win_screen.visible = (state == STATE_VICTORY)
	if lose_screen:
		lose_screen.visible = (state == STATE_DEFEAT)
	if pause_button:
		pause_button.disabled = state != STATE_PLAYING
		pause_button.modulate.a = 1.0 if state == STATE_PLAYING else 0.5
	if pause_overlay:
		pause_overlay.visible = (state == STATE_PAUSED)
	# Tạm dừng: đứng hình mọi hoạt ảnh trên sân (zombie, cây, hiệu ứng lửa)
	if entity_layer:
		entity_layer.process_mode = Node.PROCESS_MODE_DISABLED if state == STATE_PAUSED else Node.PROCESS_MODE_INHERIT


# ====================== TOẠ ĐỘ Ô (LẤY TỪ CHÍNH 45 Ô BUTTON) ======================

# Lớp vẽ (EntityLayer) dùng đúng transform của Field trong board: toạ độ dưới đây
# đều là toạ độ cục bộ của lớp vẽ, nên cây/zombie/đạn/Sun co giãn cùng bãi cỏ.
func _follow_board_field() -> void:
	if board_field == null:
		return
	entity_layer.scale = board_field.get_global_transform().get_scale()
	entity_layer.global_position = board_field.global_position


# Ô trên ảnh grid.jpg vẽ tay nên rộng/cao không đều: số nguyên = tâm ô đó, số lẻ
# (zombie, đạn) nội suy tuyến tính giữa tâm hai ô kề nhau, ngoài lưới thì ngoại suy.
func _cell_center(row: float, col: float) -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	if cells.size() < BOARD_COLS * 2:
		return _center_of(cells[0])
	var xs: Array = []
	for c in BOARD_COLS:
		xs.append(_center_of(cells[c]).x)
	var ys: Array = []
	for r in cells.size() / BOARD_COLS:
		ys.append(_center_of(cells[r * BOARD_COLS]).y)
	return Vector2(_lerp_centers(xs, col), _lerp_centers(ys, row))


func _center_of(cell: Control) -> Vector2:
	var global_center := cell.get_global_transform() * (cell.size * 0.5)
	return entity_layer.get_global_transform().affine_inverse() * global_center


func _lerp_centers(centers: Array, v: float) -> float:
	var i := clampi(floori(v), 0, centers.size() - 2)
	return lerpf(centers[i], centers[i + 1], v - i)


# ====================== VẼ CÂY / ZOMBIE / ĐẠN / SUN ======================

func _ensure_views(views: Array, count: int, maker: Callable) -> void:
	while views.size() < count:
		var v: Control = maker.call()
		entity_layer.add_child(v)
		views.append(v)
	while views.size() > count:
		var old = views.pop_back()
		old.queue_free()


func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	else:
		push_warning("[UI] Khong thay hinh: " + path)
	_tex_cache[path] = t
	return t


func _make_plant_view() -> Control:
	var root := Control.new()
	root.size = Vector2(72, 72)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := TextureRect.new()
	tex.name = "Tex"
	tex.size = root.size
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tex)
	var hp := Label.new()
	hp.name = "Hp"
	hp.position = Vector2(0, 52)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp)
	return root


func _make_bullet_view() -> Control:
	# Chỉ là hình: vị trí / va chạm vẫn hoàn toàn do Core quyết định
	var root := TextureRect.new()
	root.texture = _tex(PROJECTILE_TEXTURE)
	root.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.size = PROJECTILE_SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root


func _make_sun_view(id) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = _tex(SUN_TEXTURE)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.size = Vector2(56, 56)
	b.pressed.connect(_on_sun_clicked.bind(id))
	entity_layer.add_child(b)
	return b


func _cell_key(row: int, col: int) -> String:
	return "%d,%d" % [row, col]


func _sync_plants() -> void:
	var list := _as_list(_core("get_plants_data"))
	_debug_dump("get_plants_data", list)
	var s = _core("get_state")
	var paused := s != null and int(s) == STATE_PAUSED
	var alive := {}
	for d in list:
		if not (d is Dictionary):
			continue
		var row := int(d.get("row", 0))
		var col := int(d.get("column", 0))
		var t := int(d.get("type", d.get("plant_type", -1)))
		var key := _cell_key(row, col)
		alive[key] = true
		var v: Control = plant_views.get(key)
		# Ô có cây khác loại (cây cũ chết, trồng cây mới) -> tạo lại hình
		if v != null and int(v.get_meta("type", -2)) != t:
			v.queue_free()
			v = null
		if v == null:
			v = _make_plant_view()
			v.set_meta("type", t)
			if t == PLANT_PEASHOOTER:
				var pea := PeashooterView.new()
				pea.name = "Peashooter"
				pea.position = Vector2(v.size.x * 0.5, v.size.y * 0.5 + PEA_FEET_BELOW_CENTER)
				v.add_child(pea)
				v.move_child(pea, 0)   # nhãn máu vẫn nằm trên
			else:
				(v.get_node("Tex") as TextureRect).texture = _tex(PLANT_TEXTURES.get(t, ""))
			entity_layer.add_child(v)
			plant_views[key] = v
		(v.get_node("Hp") as Label).text = str(d.get("health", ""))
		v.position = _cell_center(float(row), float(col)) - v.size * 0.5
		var pea_view := v.get_node_or_null("Peashooter") as PeashooterView
		if pea_view:
			pea_view.animating = not paused
	for key in plant_views.keys():
		if not alive.has(key):
			plant_views[key].queue_free()
			plant_views.erase(key)


# Điểm chân Zombie (toạ độ lớp vẽ) từ (row, column liên tục) của Core.
func _zombie_feet(row: int, column: float) -> Vector2:
	var front := _cell_center(float(row), column - 0.5)
	var row_h := 110.0
	var r := row * BOARD_COLS
	if r >= 0 and r < cells.size():
		row_h = (cells[r] as Control).size.y
	return Vector2(front.x + ZOMBIE_FEET_BEHIND_FRONT, front.y + row_h * ZOMBIE_FEET_BELOW_CENTER)


func _sync_zombies() -> void:
	var list := _as_list(_core("get_zombies_data"))
	_debug_dump("get_zombies_data", list)
	var s = _core("get_state")
	var state := int(s) if s != null else STATE_PLAYING
	var alive := {}
	var any_eating := false
	for d in list:
		if not (d is Dictionary) or not d.has("id"):
			continue
		var id := int(d["id"])
		alive[id] = true
		any_eating = any_eating or bool(d.get("eating", false))
		var v: ZombieView = zombie_views.get(id)
		if v == null:
			v = ZombieView.new()
			entity_layer.add_child(v)
			zombie_views[id] = v
		# UI chỉ quyết định "dữ liệu này thì vẽ hình gì", không tự tính sát thương
		var row := int(d.get("row", 0))
		v.z_index = 1 + row   # hàng dưới vẽ đè hàng trên, Zombie đè cây cùng hàng
		v.position = _zombie_feet(row, float(d.get("column", 0)))
		v.apply_data(d)
		v.set_game_state(state)
	# Tiếng ăn: một vòng lặp liên tục khi còn ít nhất một Zombie đang ăn (không phát lại mỗi frame)
	if state == STATE_PLAYING or state == STATE_PAUSED:
		Audio.set_eating(any_eating)
	# Zombie biến khỏi dữ liệu Core = đã chết -> chơi death rồi tự xoá
	for id in zombie_views.keys():
		if not alive.has(id):
			var dead: ZombieView = zombie_views[id]
			zombie_views.erase(id)
			if is_instance_valid(dead):
				dead.die()


func _sync_bullets() -> void:
	var list := _as_list(_core("get_bullets_data"))
	_debug_dump("get_bullets_data", list)
	_ensure_views(bullet_views, list.size(), _make_bullet_view)
	for i in list.size():
		var d = list[i]
		var v: Control = bullet_views[i]
		if not (d is Dictionary):
			v.visible = false
			continue
		v.visible = true
		# Đạn chỉ do Peashooter bắn: vẽ ngang miệng cây (chỉ dịch hình theo chiều dọc;
		# cột / va chạm vẫn là của Core)
		var mouth_y := PEA_FEET_BELOW_CENTER + PeashooterView.mouth_offset().y
		v.position = _cell_center(float(d.get("row", 0)), float(d.get("column", 0))) \
			+ Vector2(0, mouth_y) - v.size * 0.5


func _sync_sun_drops() -> void:
	var list := _as_list(_core("get_sun_drops"))
	_debug_dump("get_sun_drops", list)
	var alive := {}
	for d in list:
		if not (d is Dictionary):
			continue
		var id = d.get("id", -1)
		alive[id] = true
		if not sun_views.has(id):
			sun_views[id] = _make_sun_view(id)
		var v: TextureButton = sun_views[id]
		v.position = _cell_center(float(d.get("row", 0)), float(d.get("column", 0))) - v.size * 0.5
	for id in sun_views.keys():
		if not alive.has(id):
			sun_views[id].queue_free()
			sun_views.erase(id)
