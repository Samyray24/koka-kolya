class_name CyberpunkHotbar
extends Control

# CyberpunkHotbar — Стильный киберпанк-хотбар снаряжения игрока (Слоты 1-9)
# Размещен по центру внизу экрана с адаптивными якорями, гарантирующими корректное
# отображение на любых разрешениях без наложений и обрезаний.

signal slot_clicked(slot_idx: int)

const SLOT_DATA: Array[Dictionary] = [
	{"num": "1", "icon": "✋", "name": "Руки", "desc": "Физический захват"},
	{"num": "2", "icon": "⚡", "name": "Дубинка", "desc": "Электрошок"},
	{"num": "3", "icon": "🧼", "name": "Пена", "desc": "Пенный распылитель"},
	{"num": "4", "icon": "💻", "name": "Взлом", "desc": "Кибер-дека"},
	{"num": "5", "icon": "🪓", "name": "Топор", "desc": "Тактический топор"},
	{"num": "6", "icon": "💥", "name": "Бластер", "desc": "Плазменный бластер"},
	{"num": "7", "icon": "🔫", "name": "Репитер", "desc": "Импульсный репитер"},
	{"num": "8", "icon": "🏹", "name": "Арбалет", "desc": "Энергетический арбалет"},
	{"num": "9", "icon": "🗡️", "name": "Кинжал", "desc": "Боевой кинжал"}
]

var active_slot_idx: int = 0
var slot_panels: Array[PanelContainer] = []
var slot_numbers: Array[Label] = []
var slot_icons: Array[Label] = []
var slot_names: Array[Label] = []

var inventory_ref: Node = null

func _ready() -> void:
	name = "CyberpunkHotbar"
	mouse_filter = MOUSE_FILTER_IGNORE
	
	# Адаптивное позиционирование по центру внизу экрана
	anchors_preset = PRESET_CENTER_BOTTOM
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -380.0
	offset_right = 380.0
	offset_top = -86.0
	offset_bottom = -14.0
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BEGIN
	
	_build_ui()
	set_active_slot(0)

func setup(inv_mgr: Node) -> void:
	inventory_ref = inv_mgr
	if inventory_ref and inventory_ref.has_signal("slot_changed"):
		if not inventory_ref.is_connected("slot_changed", Callable(self, "_on_slot_changed")):
			inventory_ref.connect("slot_changed", Callable(self, "_on_slot_changed"))
		if "active_slot" in inventory_ref:
			set_active_slot(int(inventory_ref.get("active_slot")))

func _build_ui() -> void:
	# Очистка предыдущих нод, если есть
	for c in get_children():
		c.queue_free()
	slot_panels.clear()
	slot_numbers.clear()
	slot_icons.clear()
	slot_names.clear()

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxRoot"
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# 1. Горизонтальная линейка 9 слотов
	var hbox := HBoxContainer.new()
	hbox.name = "SlotsHBox"
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	hbox.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(hbox)

	for i in range(SLOT_DATA.size()):
		var data: Dictionary = SLOT_DATA[i]
		var panel := _create_slot_panel(i, data)
		hbox.add_child(panel)
		slot_panels.append(panel)

	# 2. Подсказка горячих клавиш под слотами
	var hint_lbl := Label.new()
	hint_lbl.name = "HotbarHint"
	hint_lbl.text = "[1-9] Быстрый выбор  •  [Колесо мыши] Смена слота  •  [Q] Селектор оружия"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.75))
	hint_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint_lbl.add_theme_constant_override("shadow_offset_x", 1)
	hint_lbl.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(hint_lbl)

func _create_slot_panel(idx: int, data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Slot_%d" % (idx + 1)
	panel.custom_minimum_size = Vector2(76, 44)
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.mouse_filter = MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var v_content := VBoxContainer.new()
	v_content.mouse_filter = MOUSE_FILTER_IGNORE
	v_content.add_theme_constant_override("separation", 1)
	margin.add_child(v_content)

	# Верхняя строка: номер слота + иконка
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = MOUSE_FILTER_IGNORE
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 4)
	v_content.add_child(top_row)

	var num_lbl := Label.new()
	num_lbl.text = "[%s]" % data["num"]
	num_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	num_lbl.add_theme_font_size_override("font_size", 11)
	num_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 0.9))
	top_row.add_child(num_lbl)
	slot_numbers.append(num_lbl)

	var icon_lbl := Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	icon_lbl.add_theme_font_size_override("font_size", 12)
	top_row.add_child(icon_lbl)
	slot_icons.append(icon_lbl)

	# Нижняя строка: краткое название тула
	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 0.9))
	v_content.add_child(name_lbl)
	slot_names.append(name_lbl)

	# Обработка клика мыши
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_panel_clicked(idx)
	)

	return panel

func _on_panel_clicked(idx: int) -> void:
	if inventory_ref and inventory_ref.has_method("select_slot"):
		inventory_ref.call("select_slot", idx)
	else:
		set_active_slot(idx)
	slot_clicked.emit(idx)

func _on_slot_changed(slot_idx: int, _slot_name: String) -> void:
	set_active_slot(slot_idx)

func set_active_slot(idx: int) -> void:
	active_slot_idx = clampi(idx, 0, SLOT_DATA.size() - 1)

	for i in range(slot_panels.size()):
		var p: PanelContainer = slot_panels[i]
		var is_active := (i == active_slot_idx)
		
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4

		if is_active:
			# Яркий неоновый стиль для активного слота
			style.bg_color = Color(0.08, 0.18, 0.28, 0.94)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.2, 0.95, 1.0, 1.0) # Неоновый циан
			style.shadow_color = Color(0.1, 0.8, 1.0, 0.45)
			style.shadow_size = 4
			
			if i < slot_numbers.size():
				slot_numbers[i].add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0)) # Золотой номер
			if i < slot_names.size():
				slot_names[i].add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		else:
			# Спокойный киберпанк стиль для неактивных слотов
			style.bg_color = Color(0.04, 0.07, 0.12, 0.82)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.2, 0.32, 0.44, 0.5)
			style.shadow_size = 0
			
			if i < slot_numbers.size():
				slot_numbers[i].add_theme_color_override("font_color", Color(0.35, 0.65, 0.85, 0.8))
			if i < slot_names.size():
				slot_names[i].add_theme_color_override("font_color", Color(0.7, 0.78, 0.86, 0.75))

		p.add_theme_stylebox_override("panel", style)
