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
const PLANT_JALAPENO := 3
const PLANT_SQUASH := 4

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
	"jalapeno": PLANT_JALAPENO,
	"squash": PLANT_SQUASH,
}

# Seed Bank icons (small transparent copies of the HD art; see tools/character_art/build_all.py)
const PLANT_ICONS := {
	PLANT_PEASHOOTER: "res://assets/characters/icons/peashooter.png",
	PLANT_SUNFLOWER: "res://assets/characters/icons/sunflower.png",
	PLANT_WALLNUT: "res://assets/characters/icons/wallnut.png",
	PLANT_JALAPENO: "res://assets/characters/icons/jalapeno.png",
	PLANT_SQUASH: "res://assets/characters/icons/squash.png",
}
# Plants stand on the ground this far below the cell centre; the plant view is 72x72 with the centre at 36.
const PLANT_GROUND_Y := 66.0

# Lawn mower: cắt thân máy cắt cỏ từ sprite sheet lawn_mover_all.png
# Lawn mower: body + engine + two wheels, cut from assets/env/lawn_mower/lawn_mover_all.png (tools/character_art/mower_parts.py).
# Positions are pixels of the assembled 130x110 picture; the wheels spin as the mower rolls.
const MOWER_DIR := "res://assets/characters/mower/"
# Size from assets/references/original_pvz/full_lawn_grid_mower.jpg: the mower is ~0.86 of a cell wide and ~0.58 of a row
# tall (70 x 59 px on an 82 x 101 px cell), its wheels rest ~4 px above the row's lower edge and its front touches the
# lawn's left edge. In this 87 x 110 cell that is ~75 x 64 px: scale 0.75 of the 100 x 82 px rig. Display only.
const MOWER_SCALE := 0.75
const MOWER_DRAW_OFFSET := Vector2(-20, 59)     # from the core's (row, column) point to the rig's ground point
const MOWER_BODY_POS := Vector2(10, 6)
const MOWER_ENGINE_POS := Vector2(40, 28)
const MOWER_WHEEL_BACK := Vector2(35, 75)       # wheel centres
const MOWER_WHEEL_FRONT := Vector2(81, 73)
const MOWER_GROUND := Vector2(58, 100)          # the point of the rig that sits on the lawn
const MOWER_WHEEL_SPIN := 12.0                  # radians of wheel rotation per lawn column travelled
const SHOVEL_TEXTURE := "res://assets/env/shovel/Shovel.jpg"                 # the supplied shovel slot (HUD button)
const SHOVEL_HELD_TEXTURE := "res://assets/env/shovel/shovel_cutout.png"     # the shovel alone, follows the pointer
const SHOVEL_HELD_SIZE := Vector2(64, 65)
const SHOVEL_HELD_TIP := Vector2(0.06, 0.94)     # blade tip inside the picture (fraction): placed on the pointer

# Start Text ("Ready... Set... PLANT!"): cắt ba dòng từ Start_Text.png (bỏ dòng chú thích trên cùng)
const START_TEXT_TEXTURE := "res://assets/ui/Start_Text.png"
const START_TEXT_REGIONS := [Rect2(8, 22, 296, 104), Rect2(70, 126, 175, 82), Rect2(4, 214, 302, 124)]
const START_STEP := 0.75          # giây giữa hai dòng
const START_END_HOLD := 0.8       # giữ dòng cuối trước khi bắt đầu wave
const START_SAFETY_SECONDS := 4.5 # dù animation / âm thanh lỗi, wave vẫn bắt đầu

# Rung màn hình khi Squash đập trúng
const SHAKE_AMPLITUDE := 7.0
const SHAKE_DURATION := 0.28

const SUN_TEXTURE := "res://assets/sưnn.png"

# Zombie: column của Core là cạnh trước liên tục (ô c chiếm [c, c+1)).
# Chân Zombie đặt lùi sau cạnh trước một chút để tay/miệng chạm cây khi ăn.
const ZOMBIE_FEET_BEHIND_FRONT := 16.0
const ZOMBIE_FEET_BELOW_CENTER := 0.36   # tỉ lệ chiều cao hàng

# Peashooter ghép từ các mảnh: chân cây dưới tâm ô; đạn vẽ ngang miệng cây
# The Pea from the "Pea" block of assets/projectiles/Projectiles.png (extracted to projectiles/pea/pea.png, 24x24).
const PROJECTILE_TEXTURE := "res://assets/projectiles/pea/pea.png"
const PROJECTILE_SIZE := Vector2(30, 30)      # 24 px source drawn at 1.25x, proportions unchanged

const MENU_SCENE := "res://scenes/menu.tscn"
const IMPACT_FACE_OFFSET := 20.0   # how far in front of the zombie's feet point the splat lands (its face / chest)
const LEADERBOARD_SCENE := "res://scenes/leaderboard.tscn"
const GAME_OVER_ART := "res://assets/ui/Game Over Screen.png"

# Thông báo wave (cắt sẵn, mỗi ảnh là một dòng chữ riêng, không phải sprite sheet)
# A_huge_wave_is_approaching.png has an opaque black background; the _transparent copy is the same
# artwork with the black keyed out (the original file is left untouched).
const HUGE_WAVE_TEXTURE := "res://assets/ui/huge_wave_text.png"      # tight, transparent crop of A_huge_wave_is_approaching.png
const FINAL_WAVE_TEXTURE := "res://assets/ui/final_wave_text.png"    # lettering-only crop of final-wave.png
const HUGE_WAVE_SCALE := 1.9
const FINAL_WAVE_SCALE := 3.7
# Each banner has a time slot in the core's final-wave sequence (WaveManager::HUGE_WAVE_BANNER_SECONDS = 4.0,
# FINAL_WAVE_BANNER_SECONDS = 3.0). in + hold + out must fit inside the slot so the banners never overlap
# and the wave-4 zombies only start after the second one is gone.
const BANNER_IN := 0.45
const BANNER_OUT := 0.5
const HUGE_WAVE_HOLD := 2.7
const FINAL_WAVE_HOLD := 1.7
const BANNER_Y := 0.40

# Seed Bank: thẻ cây cắt từ SeedPackets.png (thẻ xanh trống ở góc trên trái)
const SEED_PACKET_TEXTURE := "res://assets/ui/seed_packet/SeedPackets.png"
const SEED_PACKET_REGION := Rect2(0, 0, 104, 144)
const SEED_PACKET_SIZE := Vector2(56, 79)
const PLANT_NAMES := {
	PLANT_PEASHOOTER: "Peashooter",
	PLANT_SUNFLOWER: "Sunflower",
	PLANT_WALLNUT: "Wall-nut",
	PLANT_JALAPENO: "Jalapeno",
	PLANT_SQUASH: "Squash",
}

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

var mower_views := {}        # hàng -> Node2D (MOWER rig)
var _zombie_columns := {}    # row -> [column of each live zombie] (to place the pea splat on the zombie that was hit)
var impact_count := 0        # number of pea splats created (tests)
var _pending_imp_throws: Array = []   # imp_thrown events waiting for the Imp's view to appear
var fx_layer: Control        # lớp hiệu ứng toàn màn hình (Start Text, thông báo wave, thanh máu boss); dừng khi Pause
var _card_cost := {}         # loại cây -> giá Sun (lấy từ Core)
var _card_dim := {}          # loại cây -> ColorRect phủ tối khi thiếu Sun
var _card_cost_label := {}   # loại cây -> Label giá
var _huge_wave_shown := false
var _final_wave_shown := false
var _result_recorded := false
var _next_buttons: Array = []
var _score_labels := {}      # màn hình -> Label điểm
var _boss_bar: Control
var _boss_fill: ProgressBar
var _boss_label: Label
var _shovel_button: TextureButton
var _held_shovel: TextureRect
var _shovel_active := false
var _intro_started := false   # Start Text chỉ chạy đúng một lần mỗi ván (pause / resume không chạy lại)
var _waves_begun := false
var _shake_tween: Tween
var _shake_origin := Vector2.ZERO
var _shake_origin_set := false


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
	# Màn hình thắng / thua: chỉ có nút Next -> Leaderboard (chỉ có Back)
	_setup_end_screens()
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
	if game_controller.has_signal("jalapeno_exploded"):
		game_controller.jalapeno_exploded.connect(_on_jalapeno_exploded)
	if game_controller.has_signal("squash_smashed"):
		game_controller.squash_smashed.connect(_on_squash_smashed)
	if game_controller.has_signal("squash_alert"):
		game_controller.squash_alert.connect(_on_squash_alert)
	if game_controller.has_signal("squash_alert_cancelled"):
		game_controller.squash_alert_cancelled.connect(_on_squash_alert_cancelled)
	if game_controller.has_signal("mower_activated"):
		game_controller.mower_activated.connect(_on_mower_activated)
	Audio.stop_all_tracked()      # nothing from an earlier match may still be sounding
	if game_controller.has_signal("plant_shoveled"):
		game_controller.plant_shoveled.connect(_on_plant_shoveled)
	if game_controller.has_signal("huge_wave_warning"):
		game_controller.huge_wave_warning.connect(_on_huge_wave_warning)
	if game_controller.has_signal("imp_thrown"):
		game_controller.imp_thrown.connect(_on_imp_thrown)
	if game_controller.has_signal("final_wave_banner"):
		game_controller.final_wave_banner.connect(_on_final_wave_banner)
	if game_controller.has_signal("wave_started"):
		game_controller.wave_started.connect(_on_wave_started)

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

	# Lớp hiệu ứng toàn màn hình: nằm trên bãi cỏ / HUD nhưng dưới OverlayLayer (Pause / Thắng / Thua).
	fx_layer = Control.new()
	fx_layer.name = "FxLayer"
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.z_index = 30
	add_child(fx_layer)

	_make_shovel_button()
	_build_seed_packets()

	var s = _core("get_state")
	print("[UI] state luc bat dau = ", s, "  (0 SETUP, 1 PLAYING, 2 PAUSED, 3 VICTORY, 4 DEFEAT)")

	# Wave / đếm ngược chỉ bắt đầu sau khi Start Text chạy xong (Core cũng có timeout dự phòng).
	_start_intro.call_deferred()


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
	_sync_mowers()
	_update_card_states()
	_move_held_shovel()


# ====================== START TEXT ======================

# "Ready... Set... PLANT!" + âm thanh, chạy đúng một lần. Core chỉ bắt đầu đếm
# wave khi begin_waves() được gọi; timer an toàn bên dưới đảm bảo luôn được gọi
# kể cả khi hình / âm thanh không nạp được.
func _start_intro() -> void:
	if _intro_started:
		return
	_intro_started = true
	var safety := get_tree().create_timer(START_SAFETY_SECONDS)
	safety.timeout.connect(_begin_waves_once)

	var sheet := _tex(START_TEXT_TEXTURE)
	if sheet == null:
		_begin_waves_once()
		return
	Audio.play_sfx("start")

	var holder := Control.new()
	holder.name = "StartText"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.add_child(holder)

	var tw := holder.create_tween()
	for i in START_TEXT_REGIONS.size():
		var region: Rect2 = START_TEXT_REGIONS[i]
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = region
		var rect := TextureRect.new()
		rect.texture = atlas
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.size = region.size * 1.3
		rect.pivot_offset = rect.size * 0.5
		rect.visible = false
		holder.add_child(rect)
		tw.tween_callback(_show_start_line.bind(rect))
		tw.tween_interval(START_STEP if i < START_TEXT_REGIONS.size() - 1 else START_END_HOLD)
		if i < START_TEXT_REGIONS.size() - 1:
			tw.tween_callback(rect.hide)
	tw.tween_callback(_begin_waves_once)
	tw.tween_callback(holder.queue_free)


# Hiện một dòng ở giữa màn hình và nảy lên (bounce).
func _show_start_line(rect: TextureRect) -> void:
	var view := get_viewport_rect().size
	rect.position = (view - rect.size) * 0.5
	rect.visible = true
	rect.scale = Vector2(0.4, 0.4)
	var tw := rect.create_tween()
	tw.tween_property(rect, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _begin_waves_once() -> void:
	if _waves_begun:
		return
	_waves_begun = true
	_core("begin_waves")


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
	_set_shovel_active(false)
	selected_plant_type = plant_type
	print("[UI] Da chon cay loai ", plant_type)
	_highlight_selected()


func _on_cell_pressed(row: int, col: int) -> void:
	# Xẻng đang chọn: chỉ gỡ cây ở đúng ô này (ô trống thì không làm gì), không trồng cây.
	if _shovel_active:
		var removed = _core("shovel_plant", [row, col])
		if removed == true:
			_set_shovel_active(false)
		return
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


# Thắng / Thua -> Next: mở Leaderboard (chỉ có nút Back). Chỉ xử lý một lần.
func _on_next_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	for b in _next_buttons:
		b.disabled = true
		b._refresh()
	Audio.stop_gameplay_audio()
	Session.view_mode = Session.VIEW_POST_MATCH
	get_tree().change_scene_to_file(LEADERBOARD_SCENE)


func _on_sun_clicked(id) -> void:
	# id lấy từ Core, UI không tự tạo id
	var value = _core("collect_sun", [id])
	if value != null and int(value) > 0:
		Audio.play_sfx("sun")


# Core vừa bắn một viên đạn (chỉ Peashooter bắn): chỉ hoạt ảnh bắn, KHÔNG phát âm thanh.
func _on_projectile_fired(row: int, column: float) -> void:
	var v = plant_views.get(_cell_key(row, floori(column)))
	if v != null and is_instance_valid(v):
		var pea := v.get_node_or_null("Rig") as PlantRig
		if pea and pea.plant_type == PlantRig.PEASHOOTER:
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
# Also the ONLY place that creates the green impact splat: the core emits this signal on a real collision only,
# so there is no splat for a missed or otherwise removed pea.
func _on_projectile_hit(row: int, column: float) -> void:
	Audio.play_sfx("pea_hit")
	if entity_layer == null:
		return
	var at := _cell_center(float(row), column) + Vector2(0, PlantRig.PEA_BULLET_Y)
	# put the splat on the zombie that was hit (its face / chest), not on the empty grass in front of it
	var best := -1.0
	for zc in _zombie_columns.get(row, []):
		if best < 0.0 or absf(zc - column) < absf(best - column):
			best = zc
	if best >= 0.0 and absf(best - column) <= 0.8:
		at.x = _zombie_feet(row, best).x - IMPACT_FACE_OFFSET
	PeaImpact.spawn(entity_layer, at)
	impact_count += 1


# ====================== XẺNG ======================

func _make_shovel_button() -> void:
	_shovel_button = TextureButton.new()
	_shovel_button.name = "ShovelButton"
	_shovel_button.texture_normal = _tex(SHOVEL_TEXTURE)
	_shovel_button.ignore_texture_size = true
	_shovel_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_shovel_button.custom_minimum_size = Vector2(60, 60)
	_shovel_button.size = Vector2(60, 60)
	_shovel_button.position = Vector2(930, 18)
	_shovel_button.tooltip_text = "Shovel"
	_shovel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_shovel_button.pressed.connect(_on_shovel_pressed)
	_shovel_button.z_index = 12   # above every zombie (their z_index is 1..5), which can enter from beyond the lawn
	add_child(_shovel_button)

	# Gold frame while the shovel is selected.
	var frame := Panel.new()
	frame.name = "Selected"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 0.4, 0.12)
	sb.border_color = Color(1, 0.9, 0.1, 1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", sb)
	frame.visible = false
	_shovel_button.add_child(frame)

	# The shovel alone follows the pointer while selected (tip of the blade on the pointer).
	_held_shovel = TextureRect.new()
	_held_shovel.name = "HeldShovel"
	_held_shovel.texture = _tex(SHOVEL_HELD_TEXTURE)
	_held_shovel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_shovel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_held_shovel.size = SHOVEL_HELD_SIZE
	_held_shovel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_shovel.z_index = 40
	_held_shovel.visible = false
	fx_layer.add_child(_held_shovel)


func _on_shovel_pressed() -> void:
	Audio.play_sfx("click")
	selected_plant_type = -1
	_highlight_selected()
	_set_shovel_active(not _shovel_active)


func _set_shovel_active(active: bool) -> void:
	_shovel_active = active
	if _shovel_button:
		(_shovel_button.get_node("Selected") as Control).visible = active
	if _held_shovel:
		_held_shovel.visible = active
		if active:
			_move_held_shovel()


# Keep the held shovel under the pointer (blade tip on the pointer).
func _move_held_shovel() -> void:
	if _held_shovel == null or not _held_shovel.visible:
		return
	_held_shovel.position = fx_layer.get_local_mouse_position() - SHOVEL_HELD_SIZE * SHOVEL_HELD_TIP


func _on_plant_shoveled(_row: int, _column: int) -> void:
	Audio.play_sfx("planting")


# ====================== SQUASH / RUNG MÀN HÌNH ======================


# Squash sound: played when a zombie comes within about a cell of the attack range (core signal squash_alert),
# never when the plant is planted or selected. One voice per Squash cell; cancelled if the zombie leaves first.
func _squash_key(row: int, column: int) -> String:
	return "squash_%d_%d" % [row, column]


func _on_squash_alert(row: int, column: int) -> void:
	Audio.play_tracked(_squash_key(row, column), "squash")


func _on_squash_alert_cancelled(row: int, column: int) -> void:
	Audio.stop_tracked(_squash_key(row, column), 0.1)


# Lawn mower sound: starts with the mower's activation, one voice per row, stopped when its run ends (_sync_mowers).
func _on_mower_activated(row: int) -> void:
	Audio.play_tracked("mower_%d" % row, "mower")


# Core xác nhận Squash vừa hạ cánh: chỉ rung màn hình khi đập trúng Zombie (âm thanh đã phát lúc Zombie tới gần).
func _on_squash_smashed(row: int, column: float, hit_count: int) -> void:
	_note_death_event("squash", row, column)
	if hit_count > 0:
		_shake()


# Rung ngắn, biên độ nhỏ, rồi trả Control gốc về đúng vị trí ban đầu.
# Chỉ dịch hình (position của Control gốc); va chạm / logic nằm ở Core nên không bị ảnh hưởng.
func _shake() -> void:
	if not _shake_origin_set:
		_shake_origin = position
		_shake_origin_set = true
	if _shake_tween:
		_shake_tween.kill()
	position = _shake_origin
	_shake_tween = create_tween()
	var steps := 6
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_AMPLITUDE * falloff
		_shake_tween.tween_property(self, "position", _shake_origin + offset, SHAKE_DURATION / steps)
	_shake_tween.tween_property(self, "position", _shake_origin, 0.02)


# Jalapeno vừa nổ (sau ngòi 2 giây của Core): âm thanh + lửa chạy ngang cả hàng.
func _on_jalapeno_exploded(row: int, column: int) -> void:
	_note_death_event("burn", row, float(column))
	Audio.play_sfx("jalapeno")
	var fire := JalapenoFire.new()
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
			_record_result(state == STATE_VICTORY)
			_clear_transient_fx()
	if win_screen:
		win_screen.visible = (state == STATE_VICTORY)
	if lose_screen:
		lose_screen.visible = (state == STATE_DEFEAT)
	if pause_button:
		pause_button.disabled = state != STATE_PLAYING
		pause_button.modulate.a = 1.0 if state == STATE_PLAYING else 0.5
	if pause_overlay:
		pause_overlay.visible = (state == STATE_PAUSED)
	# Tạm dừng: đứng hình mọi hoạt ảnh trên sân (zombie, cây, hiệu ứng lửa) và các thông báo
	var frozen := Node.PROCESS_MODE_DISABLED if state == STATE_PAUSED else Node.PROCESS_MODE_INHERIT
	if entity_layer:
		entity_layer.process_mode = frozen
	if fx_layer:
		fx_layer.process_mode = frozen


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
	var hp := Label.new()
	hp.name = "Hp"
	hp.position = Vector2(14, 60)
	hp.add_theme_font_size_override("font_size", 13)
	hp.add_theme_color_override("font_color", Color("fff3d6"))
	hp.add_theme_color_override("font_outline_color", Color("2b1d0e"))
	hp.add_theme_constant_override("outline_size", 5)
	hp.z_index = 3
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp)
	return root


func _make_bullet_view() -> Control:
	# Chỉ là hình: vị trí / va chạm vẫn hoàn toàn do Core quyết định
	var root := TextureRect.new()
	root.texture = _tex(PROJECTILE_TEXTURE)
	root.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.stretch_mode = TextureRect.STRETCH_SCALE
	root.size = PROJECTILE_SIZE
	root.z_index = 6                          # above the plants and zombies of its lane
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
			v.set_meta("row", row)
			v.set_meta("col", col)
			var rig := PlantRig.create(t)
			rig.name = "Rig"
			rig.position = Vector2(v.size.x * 0.5, PLANT_GROUND_Y)
			v.add_child(rig)
			v.move_child(rig, 0)   # the HP label stays on top
			v.set_meta("max_hp", int(d.get("health", 1)))
			v.set_meta("last_hp", int(d.get("health", 1)))
			entity_layer.add_child(v)
			plant_views[key] = v
		var rig_node := v.get_node("Rig") as PlantRig
		var hp_now := int(d.get("health", 0))
		var max_hp := maxi(int(v.get_meta("max_hp", hp_now)), 1)
		# HP numbers only while a plant is damaged (they are not part of the original look)
		var hp_label := v.get_node("Hp") as Label
		hp_label.text = str(hp_now)
		hp_label.visible = hp_now < max_hp
		if hp_now < int(v.get_meta("last_hp", hp_now)):
			rig_node.hit()
		v.set_meta("last_hp", hp_now)
		if t == PLANT_WALLNUT:
			var frac := float(hp_now) / float(max_hp)
			rig_node.set_damage(0 if frac > 0.66 else (1 if frac > 0.33 else 2))
		rig_node.animating = not paused
		rig_node.update_from(d)
		v.position = _cell_center(float(row), float(col)) - v.size * 0.5
		# Squash: the jump pose follows the core's state; the plant glides to the landing cell (display only).
		if t == PLANT_SQUASH:
			if int(d.get("state", 0)) == 1:
				var landing := _cell_center(float(row), float(d.get("target_column", col)))
				rig_node.jump_dx = landing.x - _cell_center(float(row), float(col)).x
				v.set_meta("landing", landing)
				v.set_meta("jumping", true)
			else:
				rig_node.jump_dx = 0.0
			v.z_index = 20 if int(d.get("state", 0)) == 1 else 0   # airborne: in front of the zombies
	for key in plant_views.keys():
		if not alive.has(key):
			var gone: Control = plant_views[key]
			# A Squash that vanished mid-jump has just landed: leave the flattened Squash behind.
			if bool(gone.get_meta("jumping", false)) and int(gone.get_meta("type", -1)) == PLANT_SQUASH:
				var splat := PlantRig.make_squash_splat()
				splat.position = (gone.get_meta("landing") as Vector2) + Vector2(0, PLANT_GROUND_Y - 36.0)
				splat.z_index = 2
				entity_layer.add_child(splat)
			elif int(gone.get_meta("type", -1)) == PLANT_SQUASH:
				Audio.stop_tracked(_squash_key(int(gone.get_meta("row", -1)), int(gone.get_meta("col", -1))), 0.1)   # removed before attacking
			gone.queue_free()
			plant_views.erase(key)


# Điểm chân Zombie (toạ độ lớp vẽ) từ (row, column liên tục) của Core.
func _zombie_feet(row: int, column: float) -> Vector2:
	var front := _cell_center(float(row), column - 0.5)
	var row_h := 110.0
	var r := row * BOARD_COLS
	if r >= 0 and r < cells.size():
		row_h = (cells[r] as Control).size.y
	return Vector2(front.x + ZOMBIE_FEET_BEHIND_FRONT, front.y + row_h * ZOMBIE_FEET_BELOW_CENTER)


# Core: the Gargantuar threw its Imp (row, from_column, to_column). The Imp's own view appears on the same
# frame; the flight is purely visual (the Imp is already a real enemy standing on its landing column).
func _on_imp_thrown(row: int, _from_column: float, _to_column: float) -> void:
	_pending_imp_throws.append({"row": row})


func _start_imp_flight(imp_view: ZombieView, info: Dictionary) -> void:
	for gv in zombie_views.values():
		var g := gv as ZombieView
		if g != null and is_instance_valid(g) and g.kind == 1 and g.puppet != null:
			var rider_world: Vector2 = g.position + g.scale * g.puppet.rider_offset()
			imp_view.start_flight(rider_world - imp_view.position, PuppetZombie.G_THROW_RELEASE)
			return


# ---- why did a zombie die? (only to pick the death animation; the core is never asked to change) ----
# The core reports a Jalapeno blast and a Squash smash as signals, in the same update that removes the zombies they kill,
# and Lawn Mower runs are in get_mowers_data(). So a death is "burn" / "squash" when such an event happened a moment ago in
# the zombie's row (Squash: within its smash radius of the landing column), "mower" when a running mower's hit window
# covers the zombie's last column, and an ordinary kill (a pea) otherwise: Peashooter is the only other thing that kills.
# A mix-up between two kills in the very same instant only changes which animation plays.
const DEATH_EVENT_FRAMES := 4
const SQUASH_RADIUS := 0.8          # Squash::SMASH_RADIUS in src/squash.hpp
const MOWER_HIT_BEHIND := 1.0       # LawnMower::HIT_BEHIND / HIT_AHEAD in src/lawn_mower.hpp
const MOWER_HIT_AHEAD := 0.8
const MOWER_MARGIN := 0.35          # the mower covers ~0.12 column per frame; the zombie's column is one frame old
var _death_events: Array = []       # {"type", "row", "col", "frame"}
var _mower_prev := {}               # row -> {"col", "state"} as of the previous frame


func _note_death_event(type: String, row: int, col: float) -> void:
	var f := Engine.get_process_frames()
	_death_events = _death_events.filter(func(e): return f - int(e["frame"]) <= DEATH_EVENT_FRAMES * 3)
	_death_events.append({"type": type, "row": row, "col": col, "frame": f})


func _death_cause(v: ZombieView) -> String:
	if v.kind == 1:
		return ""                    # the Gargantuar keeps its heavy fall whatever killed it (PuppetZombie ignores the cause)
	var f := Engine.get_process_frames()
	for e in _death_events:
		if f - int(e["frame"]) > DEATH_EVENT_FRAMES or int(e["row"]) != v.last_row:
			continue
		if e["type"] == "burn":
			return "burn"
		if e["type"] == "squash" and absf(v.last_col - float(e["col"])) <= SQUASH_RADIUS + 0.35:
			return "squash"
	var now := {}
	for m in _as_list(_core("get_mowers_data")):
		if m is Dictionary:
			now[int(m.get("row", -1))] = {"col": float(m.get("column", 0)), "state": int(m.get("state", 0))}
	for src in [_mower_prev, now]:
		var m = src.get(v.last_row)
		if m != null and int(m["state"]) == 1 \
				and v.last_col >= float(m["col"]) - MOWER_HIT_BEHIND - MOWER_MARGIN \
				and v.last_col <= float(m["col"]) + MOWER_HIT_AHEAD + MOWER_MARGIN:
			return "mower"
	return ""


func _sync_zombies() -> void:
	var list := _as_list(_core("get_zombies_data"))
	_debug_dump("get_zombies_data", list)
	var s = _core("get_state")
	var state := int(s) if s != null else STATE_PLAYING
	var alive := {}
	var any_eating := false
	_update_boss_bar(list)
	_zombie_columns.clear()
	for zd in list:
		if zd is Dictionary:
			var zr := int(zd.get("row", 0))
			if not _zombie_columns.has(zr):
				_zombie_columns[zr] = []
			_zombie_columns[zr].append(float(zd.get("column", 0)))
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
			# A new Imp that the Gargantuar just threw: fly it in from the Gargantuar's back.
			if int(d.get("kind", 0)) == 2 and not _pending_imp_throws.is_empty():
				v.set_meta("throw", _pending_imp_throws.pop_front())
		# UI chỉ quyết định "dữ liệu này thì vẽ hình gì", không tự tính sát thương
		var row := int(d.get("row", 0))
		v.z_index = 1 + row   # hàng dưới vẽ đè hàng trên, Zombie đè cây cùng hàng
		v.position = _zombie_feet(row, float(d.get("column", 0)))
		v.apply_data(d)
		v.set_game_state(state)
		if v.has_meta("throw"):
			_start_imp_flight(v, v.get_meta("throw"))
			v.remove_meta("throw")
	# Tiếng ăn: một vòng lặp liên tục khi còn ít nhất một Zombie đang ăn (không phát lại mỗi frame)
	if state == STATE_PLAYING or state == STATE_PAUSED:
		Audio.set_eating(any_eating)
	# Zombie biến khỏi dữ liệu Core = đã chết -> chơi death rồi tự xoá
	for id in zombie_views.keys():
		if not alive.has(id):
			var dead: ZombieView = zombie_views[id]
			zombie_views.erase(id)
			if is_instance_valid(dead):
				dead.die(_death_cause(dead))


# Mỗi hàng một máy cắt cỏ: nằm chờ ở mép trái, lao qua hàng khi được kích hoạt, rồi biến mất (đã dùng).
func _sync_mowers() -> void:
	var list := _as_list(_core("get_mowers_data"))
	for d in list:
		if not (d is Dictionary):
			continue
		var row := int(d.get("row", 0))
		var used := int(d.get("state", 0)) == 2
		var v: Node2D = mower_views.get(row)
		if used:
			Audio.stop_tracked("mower_%d" % row, 0.25)    # the run is over: let the sound die away
			if v != null:
				v.queue_free()
				mower_views.erase(row)
			continue
		if v == null:
			v = _make_mower_view()
			entity_layer.add_child(v)
			mower_views[row] = v
		var col := float(d.get("column", -0.7))
		v.position = _cell_center(float(row), col) + MOWER_DRAW_OFFSET
		(v.get_node("WheelB") as Node2D).rotation = col * MOWER_WHEEL_SPIN
		(v.get_node("WheelF") as Node2D).rotation = col * MOWER_WHEEL_SPIN
	_mower_prev.clear()
	for d in list:
		if d is Dictionary:
			_mower_prev[int(d.get("row", -1))] = {"col": float(d.get("column", 0)), "state": int(d.get("state", 0))}


func _make_mower_view() -> Node2D:
	var root := Node2D.new()
	root.name = "Mower"
	root.scale = Vector2.ONE * MOWER_SCALE
	root.z_index = 2
	var parts := [
		["WheelB", "wheel.png", MOWER_WHEEL_BACK, true],
		["Body", "body.png", MOWER_BODY_POS, false],
		["Engine", "engine.png", MOWER_ENGINE_POS, false],
		["WheelF", "wheel.png", MOWER_WHEEL_FRONT, true],
	]
	for p in parts:
		var s := Sprite2D.new()
		s.name = p[0]
		s.texture = _tex(MOWER_DIR + p[1])
		s.centered = p[3]
		s.position = (p[2] as Vector2) - MOWER_GROUND
		root.add_child(s)
	return root


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
		var mouth_y := PlantRig.PEA_BULLET_Y
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
		# Sun rơi từ trên cao xuống bãi cỏ trong fall_duration giây (Core cấp age / fall_duration).
		var fall := float(d.get("fall_duration", 0.0))
		if fall > 0.0:
			var t := clampf(float(d.get("age", 0.0)) / fall, 0.0, 1.0)
			v.position.y -= (1.0 - t) * (1.0 - t) * 260.0   # ease-out: nhanh rồi chậm dần khi chạm cỏ
	for id in sun_views.keys():
		if not alive.has(id):
			sun_views[id].queue_free()
			sun_views.erase(id)


# ====================== MÀN HÌNH THẮNG / THUA ======================

func _setup_end_screens() -> void:
	for screen in [win_screen, lose_screen]:
		if screen == null:
			continue
		screen.visible = false
		var old_buttons: Node = screen.find_child("Buttons", true, false)
		if old_buttons:
			old_buttons.queue_free()   # Play Again / Quit chuyển sang Leaderboard
		var is_win: bool = screen == win_screen
		if not is_win:
			# Dùng đúng ảnh Game Over có sẵn thay cho chữ vẽ tay
			var title := screen.find_child("Title", true, false) as Control
			if title:
				title.visible = false
			var art := TextureRect.new()
			art.name = "GameOverArt"
			art.texture = _tex(GAME_OVER_ART)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.anchor_left = 0.5
			art.anchor_right = 0.5
			art.anchor_top = 0.47
			art.anchor_bottom = 0.47
			art.offset_left = -200.0
			art.offset_right = 200.0
			art.offset_top = -166.0
			art.offset_bottom = 166.0
			screen.add_child(art)

		var score := Label.new()
		score.name = "Score"
		score.text = "Score: 0"
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score.mouse_filter = Control.MOUSE_FILTER_IGNORE
		score.add_theme_font_size_override("font_size", 30)
		score.add_theme_color_override("font_color", Color("e8f2ff"))
		score.add_theme_color_override("font_outline_color", Color("2b3c4c"))
		score.add_theme_constant_override("outline_size", 8)
		score.anchor_left = 0.5
		score.anchor_right = 0.5
		score.anchor_top = 0.73 if not is_win else 0.60
		score.anchor_bottom = score.anchor_top
		score.offset_left = -240.0
		score.offset_right = 240.0
		score.offset_top = -20.0
		score.offset_bottom = 20.0
		screen.add_child(score)
		_score_labels[screen] = score

		var next := StoneUI.make_image_button("next", Vector2(184, 80))
		next.anchor_left = 0.5
		next.anchor_right = 0.5
		next.anchor_top = 0.86
		next.anchor_bottom = 0.86
		next.offset_left = -92.0
		next.offset_right = 92.0
		next.offset_top = -40.0
		next.offset_bottom = 40.0
		next.pressed.connect(_on_next_pressed)
		screen.add_child(next)
		_next_buttons.append(next)


# Lưu kết quả đúng MỘT lần (Session cũng chặn lưu lần thứ hai) và hiện điểm.
func _record_result(won: bool) -> void:
	if _result_recorded:
		return
	_result_recorded = true
	var spent = _core("get_sun_spent")
	# Not saved yet: it becomes a leaderboard record only when Quit is clicked on the post-match leaderboard.
	Session.add_result(won, int(spent) if spent != null else 0)
	var score := int(Session.last_result.get("score", 0))
	var screen: Control = win_screen if won else lose_screen
	if _score_labels.has(screen):
		var label: Label = _score_labels[screen]
		label.text = ("Score: %d  (Sun spent)" % score) if won else "Score: 0"


# ====================== THÔNG BÁO WAVE ======================

# "A huge wave of zombies is approaching": đúng một lần, ngay trước wave cuối (Core phát tín hiệu).
func _on_huge_wave_warning() -> void:
	if _huge_wave_shown:
		return
	_huge_wave_shown = true
	_show_announcement(HUGE_WAVE_TEXTURE, HUGE_WAVE_SCALE, HUGE_WAVE_HOLD, BANNER_Y)


# "Final Wave": đúng một lần, phát ngay khi banner "A huge wave..." hết slot của nó (Core phát
# final_wave_banner). Zombie wave cuối chỉ bắt đầu sau khi banner này cũng hết slot.
func _on_final_wave_banner() -> void:
	if _final_wave_shown:
		return
	_final_wave_shown = true
	_show_announcement(FINAL_WAVE_TEXTURE, FINAL_WAVE_SCALE, FINAL_WAVE_HOLD, BANNER_Y)


# wave_started không còn tạo banner (banner nằm trước wave 4); chỉ giữ để mở rộng sau.
func _on_wave_started(_wave: int) -> void:
	pass


# Banner chữ: lớn dần vào, giữ `hold` giây, mờ dần rồi tự xoá. Không chặn chuột / Seed Bank.
# Nằm trong fx_layer nên đứng hình khi Pause.
func _show_announcement(path: String, scale_factor: float, hold: float, y_fraction: float) -> void:
	var tex := _tex(path)
	if tex == null or fx_layer == null:
		return
	var rect := TextureRect.new()
	rect.name = "Announcement"
	rect.set_meta("announcement", true)
	rect.texture = tex
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = tex.get_size() * scale_factor
	var view := get_viewport_rect().size
	rect.position = Vector2((view.x - rect.size.x) * 0.5, view.y * y_fraction - rect.size.y * 0.5)
	rect.pivot_offset = rect.size * 0.5
	rect.scale = Vector2(0.3, 0.3)
	rect.modulate.a = 0.0
	fx_layer.add_child(rect)
	var tw := rect.create_tween()
	tw.set_parallel(true)
	tw.tween_property(rect, "scale", Vector2.ONE, BANNER_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "modulate:a", 1.0, 0.25)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(rect, "modulate:a", 0.0, BANNER_OUT)
	tw.chain().tween_callback(rect.queue_free)


# Dọn Start Text / banner wave còn dở khi trận kết thúc (không che màn hình Thắng / Thua).
func _clear_transient_fx() -> void:
	if fx_layer == null:
		return
	for c in fx_layer.get_children():
		# Godot renames a second node with the same name, so the banners are tagged with meta instead of by name.
		if c.name == "StartText" or c.has_meta("announcement"):
			c.queue_free()
	if _boss_bar:
		_boss_bar.visible = false


# ====================== THANH MÁU BOSS ======================

# Thanh máu riêng của Gargantuar ở giữa phía trên màn hình (khác thanh nhỏ của Zombie thường).
func _update_boss_bar(list: Array) -> void:
	var boss = null
	for d in list:
		if d is Dictionary and int(d.get("kind", 0)) == 1:
			boss = d
			break
	if boss == null:
		if _boss_bar:
			_boss_bar.visible = false
		return
	if _boss_bar == null:
		_make_boss_bar()
	_boss_bar.visible = true
	var max_hp := maxi(int(boss.get("max_health", 1)), 1)
	var hp := clampi(int(boss.get("health", 0)), 0, max_hp)
	_boss_fill.max_value = max_hp
	_boss_fill.value = hp
	_boss_label.text = "GARGANTUAR   %d / %d" % [hp, max_hp]


func _make_boss_bar() -> void:
	_boss_bar = Control.new()
	_boss_bar.name = "BossBar"
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# In the empty part of the Seed Bank strip: clearly visible, never over the lawn.
	_boss_bar.position = Vector2(400, 22)
	_boss_bar.size = Vector2(380, 40)
	fx_layer.add_child(_boss_bar)

	_boss_fill = ProgressBar.new()
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_fill.show_percentage = false
	_boss_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.07, 0.07, 0.92)
	back.border_color = Color("2b3c4c")
	back.set_border_width_all(3)
	back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.1, 0.08)
	fill.set_corner_radius_all(3)
	_boss_fill.add_theme_stylebox_override("background", back)
	_boss_fill.add_theme_stylebox_override("fill", fill)
	_boss_bar.add_child(_boss_fill)

	_boss_label = Label.new()
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_label.add_theme_font_size_override("font_size", 18)
	_boss_label.add_theme_color_override("font_color", Color("fff2d6"))
	_boss_label.add_theme_color_override("font_outline_color", Color("2b1010"))
	_boss_label.add_theme_constant_override("outline_size", 6)
	_boss_bar.add_child(_boss_label)


# ====================== SEED BANK ======================

# Mỗi thẻ: nền thẻ cắt từ SeedPackets.png + hình cây + tên + giá Sun.
# Trạng thái: chọn (khung vàng có sẵn), thiếu Sun (phủ tối + giá đỏ). Chưa có cơ chế hồi
# chiêu trong Core nên không vẽ hồi chiêu.
func _build_seed_packets() -> void:
	var sheet := _tex(SEED_PACKET_TEXTURE)
	for t in card_buttons.keys():
		var b: Button = card_buttons[t]
		b.size = SEED_PACKET_SIZE
		b.position.y = 9.0
		b.tooltip_text = PLANT_NAMES.get(t, "")
		var cost = _core("get_plant_cost", [t])
		_card_cost[t] = int(cost) if cost != null else 0

		var bg := TextureRect.new()
		bg.name = "PacketArt"
		if sheet != null:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = SEED_PACKET_REGION
			bg.texture = atlas
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(bg)

		var icon := TextureRect.new()
		icon.name = "PlantIcon"
		var icon_tex := _tex(PLANT_ICONS.get(t, ""))
		icon.texture = icon_tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(6, 11)
		icon.size = Vector2(44, 30)
		b.add_child(icon)

		var name_label := Label.new()
		name_label.name = "PlantName"
		name_label.text = PLANT_NAMES.get(t, "")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.position = Vector2(-3, 43)
		name_label.size = Vector2(SEED_PACKET_SIZE.x + 6, 12)
		name_label.clip_text = false
		name_label.add_theme_font_size_override("font_size", 8 if String(name_label.text).length() <= 8 else 7)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_color_override("font_outline_color", Color("1f3a12"))
		name_label.add_theme_constant_override("outline_size", 4)
		b.add_child(name_label)

		var cost_label := Label.new()
		cost_label.name = "Cost"
		cost_label.text = str(_card_cost[t])
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_label.position = Vector2(5, 57)
		cost_label.size = Vector2(30, 18)
		cost_label.add_theme_font_size_override("font_size", 14)
		cost_label.add_theme_color_override("font_color", Color("2a1a05"))
		b.add_child(cost_label)
		_card_cost_label[t] = cost_label

		var dim := ColorRect.new()
		dim.name = "Dim"
		dim.color = Color(0.05, 0.05, 0.08, 0.55)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.visible = false
		b.add_child(dim)
		_card_dim[t] = dim

		# Khung "Selected" của scene luôn nằm trên cùng
		var sel := b.get_node_or_null("Selected")
		if sel:
			b.move_child(sel, b.get_child_count() - 1)


# Thiếu Sun: phủ tối thẻ và đổi giá sang đỏ (vẫn bấm được để nhận thông báo "NOT ENOUGH SUN").
func _update_card_states() -> void:
	var sun = _core("get_sun")
	if sun == null:
		return
	for t in _card_cost.keys():
		var poor: bool = int(sun) < int(_card_cost[t])
		if _card_dim.has(t):
			(_card_dim[t] as ColorRect).visible = poor
		if _card_cost_label.has(t):
			(_card_cost_label[t] as Label).add_theme_color_override("font_color", Color("b3150d") if poor else Color("2a1a05"))
