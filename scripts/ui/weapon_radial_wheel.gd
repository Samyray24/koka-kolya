class_name WeaponRadialWheel
extends CanvasLayer

# WeaponRadialWheel — Круговое меню выбора оружия и расходников в режиме замедленного времени (Bullet Time)
# Активируется по зажатию клавиши [Q].
# Поддерживает выбор 8 слотов (оружие, хакерский тул, ледяная Кола).

signal weapon_selected(slot_idx: int, slot_name: String)
signal wheel_opened()
signal wheel_closed()

var is_wheel_open: bool = false
var selected_index: int = 0
var previous_time_scale: float = 1.0

var player_ref: CharacterBody3D = null
var inventory_ref: Node = null

# UI ноды
var wheel_root: Control = null
var center_panel: PanelContainer = null
var title_label: Label = null
var desc_label: Label = null
var sector_buttons: Array[PanelContainer] = []
var sector_labels: Array[Label] = []

const SLOTS: Array[Dictionary] = [
	{
		"id": "blaster",
		"tool_slot": 5, # ToolSlot.BLASTER
		"title": "Плазменный Бластер",
		"icon": "💥",
		"desc": "Высокоточный плазменный пистолет. Эффективен против легкой охраны.",
		"color": Color(0.2, 0.9, 1.0)
	},
	{
		"id": "repeater",
		"tool_slot": 6, # ToolSlot.REPEATER
		"title": "Штурмовой Репитер",
		"icon": "⚡",
		"desc": "Скорострельный автоматический карабин. Подавляет скопления врагов.",
		"color": Color(1.0, 0.4, 0.2)
	},
	{
		"id": "crossbow",
		"tool_slot": 7, # ToolSlot.CROSSBOW
		"title": "Энергетический Арбалет",
		"icon": "🏹",
		"desc": "Бесшумное оружие дальнего боя. Пробивает энергощиты Синдиката.",
		"color": Color(0.8, 0.3, 1.0)
	},
	{
		"id": "axe",
		"tool_slot": 4, # ToolSlot.AXE
		"title": "Тактический Топор",
		"icon": "🪓",
		"desc": "Тяжелый топор из легированной стали для крушения преград и ближнего боя.",
		"color": Color(1.0, 0.7, 0.1)
	},
	{
		"id": "baton",
		"tool_slot": 1, # ToolSlot.BATON
		"title": "Шокер-Дубинка",
		"icon": "⚡",
		"desc": "Оглушает патрульных охраны электрическим разрядом без поднятия тревоги.",
		"color": Color(0.3, 1.0, 0.6)
	},
	{
		"id": "hack",
		"tool_slot": 3, # ToolSlot.HACK
		"title": "Кибер-Взломщик",
		"icon": "💻",
		"desc": "Взламывает камеры наблюдения, терминалы ворот и сбрасывает розыск.",
		"color": Color(0.2, 1.0, 0.85)
	},
	{
		"id": "cola",
		"tool_slot": -1, # Расходник
		"title": "Ледяная «Кока-Коля»",
		"icon": "🥤",
		"desc": "Банка ледяной газировки! Мгновенно восстанавливает +50 HP и дает бодрость.",
		"color": Color(1.0, 0.2, 0.3)
	},
	{
		"id": "grabber",
		"tool_slot": 0, # ToolSlot.GRABBER
		"title": "Физический Захват / Руки",
		"icon": "✋",
		"desc": "Манипулятор гравизахвата. Переноска ящиков, бросок бочек и погрузка в фургон.",
		"color": Color(0.9, 0.9, 0.9)
	}
]

func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func setup(player: CharacterBody3D, inventory: Node) -> void:
	player_ref = player
	inventory_ref = inventory

func _build_ui() -> void:
	wheel_root = Control.new()
	wheel_root.name = "WheelRoot"
	wheel_root.anchors_preset = Control.PRESET_FULL_RECT
	wheel_root.visible = false
	add_child(wheel_root)

	# Затемнение фона
	var dim := ColorRect.new()
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.color = Color(0.01, 0.03, 0.06, 0.72)
	wheel_root.add_child(dim)

	# Центральная информационная панель
	center_panel = PanelContainer.new()
	center_panel.name = "CenterPanel"
	center_panel.anchors_preset = Control.PRESET_CENTER
	center_panel.anchor_left = 0.5
	center_panel.anchor_right = 0.5
	center_panel.anchor_top = 0.5
	center_panel.anchor_bottom = 0.5
	center_panel.offset_left = -170.0
	center_panel.offset_right = 170.0
	center_panel.offset_top = -80.0
	center_panel.offset_bottom = 80.0
	wheel_root.add_child(center_panel)

	var cvbox := VBoxContainer.new()
	center_panel.add_child(cvbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "СЕЛЕКТОР ОРУЖИЯ"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	cvbox.add_child(title_label)

	desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = "Удерживайте [Q] и выберите слот мышью."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	cvbox.add_child(desc_label)

	# Секторы кругового меню (радиус ~220px)
	sector_buttons.clear()
	sector_labels.clear()
	var radius: float = 230.0
	var count: int = SLOTS.size()

	for i in range(count):
		var slot: Dictionary = SLOTS[i]
		var angle_rad: float = (float(i) / float(count)) * TAU - (PI * 0.5)

		var btn := PanelContainer.new()
		btn.name = "SlotButton_%d" % i
		btn.anchors_preset = Control.PRESET_CENTER
		btn.anchor_left = 0.5
		btn.anchor_right = 0.5
		btn.anchor_top = 0.5
		btn.anchor_bottom = 0.5

		var offset_x := cos(angle_rad) * radius
		var offset_y := sin(angle_rad) * radius

		btn.offset_left = offset_x - 90.0
		btn.offset_right = offset_x + 90.0
		btn.offset_top = offset_y - 28.0
		btn.offset_bottom = offset_y + 28.0
		wheel_root.add_child(btn)

		var lbl := Label.new()
		lbl.text = "%s %s" % [slot["icon"], slot["title"]]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", slot["color"])
		btn.add_child(lbl)

		sector_buttons.append(btn)
		sector_labels.append(lbl)

func open_wheel() -> void:
	if is_wheel_open:
		return
	is_wheel_open = true
	wheel_root.visible = true

	# Замедление времени Bullet Time
	previous_time_scale = Engine.time_scale
	Engine.time_scale = 0.15

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "slow_motion_enter")

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	wheel_opened.emit()
	_update_selection()

func close_wheel() -> void:
	if not is_wheel_open:
		return
	is_wheel_open = false
	wheel_root.visible = false

	# Возврат нормального времени
	Engine.time_scale = 1.0

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "slow_motion_exit")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_apply_selection()
	wheel_closed.emit()

func _apply_selection() -> void:
	if selected_index < 0 or selected_index >= SLOTS.size():
		return
	var slot: Dictionary = SLOTS[selected_index]
	var tool_id: int = slot["tool_slot"]

	if slot["id"] == "cola":
		# Выпита банка Кока-Коли!
		if player_ref and player_ref.has_method("heal"):
			player_ref.call("heal", 50.0)
		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "cola_drink")
		LogManager.info("[РАСХОДНИК]: Коля выпил банку ледяной колы! Здоровье восстановлено (+50 HP).", "PLAYER")
	else:
		if inventory_ref and inventory_ref.has_method("select_slot"):
			inventory_ref.call("select_slot", tool_id)
		LogManager.info("[ОРУЖИЕ]: Экипирован слот: %s" % slot["title"], "PLAYER")

	weapon_selected.emit(selected_index, slot["title"])

func _process(_delta: float) -> void:
	if not is_wheel_open:
		return
	_update_selection()

func _update_selection() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var center := vp_size * 0.5
	var mouse_pos := get_viewport().get_mouse_position()

	var diff := mouse_pos - center
	if diff.length_squared() > 1600.0: # Дистанция > 40px от центра
		var angle := atan2(diff.y, diff.x)
		var norm_angle := fposmod(angle + (PI * 0.5) + (TAU / 16.0), TAU)
		selected_index = clampi(int((norm_angle / TAU) * 8.0), 0, 7)

	for i in range(sector_buttons.size()):
		var is_sel := (i == selected_index)
		var btn := sector_buttons[i]
		var lbl := sector_labels[i]
		if is_sel:
			btn.modulate = Color(1.3, 1.3, 1.3, 1.0)
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
		else:
			btn.modulate = Color(0.7, 0.7, 0.7, 0.8)
			lbl.add_theme_color_override("font_color", SLOTS[i]["color"])

	if selected_index >= 0 and selected_index < SLOTS.size():
		var sel_slot: Dictionary = SLOTS[selected_index]
		title_label.text = "%s %s" % [sel_slot["icon"], sel_slot["title"]]
		title_label.modulate = sel_slot["color"]
		desc_label.text = sel_slot["desc"]
