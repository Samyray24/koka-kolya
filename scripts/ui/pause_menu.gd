class_name PauseMenu
extends Control

# PauseMenu — Тактический киберпанк оверлей паузы «Кока-Коля» (v1.0.0 Gold Master)
# Отображает текущий район, состояние агента, баланс кредитов и активные цели миссии.
# Поддерживает быстрое сохранение/загрузку, выбор района и расширенные настройки.

@onready var panel_container: PanelContainer = get_node_or_null("Center/Panel")
@onready var title_label: Label = get_node_or_null("Center/Panel/Margin/VBox/Title")
@onready var subtitle_label: Label = get_node_or_null("Center/Panel/Margin/VBox/SubTitle")
@onready var btn_resume: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnResume")
@onready var btn_districts: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnDistricts")
@onready var btn_settings: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnSettings")
@onready var btn_save: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnSave")
@onready var btn_load: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnLoad")
@onready var btn_testhub: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnTestHub")
@onready var btn_mainmenu: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnMainMenu")
@onready var status_label: Label = get_node_or_null("Center/Panel/Margin/VBox/StatusLabel")
@onready var settings_menu: Node = get_node_or_null("SettingsMenu")

var is_paused: bool = false
var district_modal: Control = null
var tactical_card: PanelContainer = null
var tac_district_label: Label = null
var tac_stats_label: Label = null
var tac_objective_label: Label = null

const DISTRICT_LIST: Array[Dictionary] = [
	{
		"id": "old_district",
		"icon": "🏙️",
		"name": "Старый Район (Трущобы)",
		"desc": "Конспиративный гараж Коли, улицы трущоб и Складской терминал №4.",
		"danger": "★☆☆",
		"scene": "res://scenes/levels/old_district.tscn"
	},
	{
		"id": "city_highway",
		"icon": "🏎️",
		"name": "Скоростное Шоссе и Блокпост",
		"desc": "Скоростная 4-полосная автомагистраль, КПП №2 Синдиката и вещательная медиа-башня.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/city_highway.tscn"
	},
	{
		"id": "neon_boulevard",
		"icon": "🌆",
		"name": "Неоновый Бульвар (Даунтаун)",
		"desc": "Небоскрёбы, двухуровневая эстакада, автоматы с колой и Неон-Плаза.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/neon_boulevard.tscn"
	},
	{
		"id": "red_line_plant",
		"icon": "🏭",
		"name": "Завод «Красная Линия»",
		"desc": "Огромный заводской комплекс по розливу синтетической газировки.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/red_line_plant.tscn"
	},
	{
		"id": "logistics_hub",
		"icon": "📦",
		"name": "Логистический Хаб MERIDIAN",
		"desc": "Складской терминал MERIDIAN с контейнерами, кранами и патрулями.",
		"danger": "★★★",
		"scene": "res://scenes/levels/logistics_hub.tscn"
	},
	{
		"id": "underground_metro",
		"icon": "🚇",
		"name": "Подземный Метрополитен",
		"desc": "Станция «Проспект Революции», туннели, пути и схрон Сопротивления.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/underground_metro.tscn"
	},
	{
		"id": "citadel_penthouse",
		"icon": "👑",
		"name": "Пентхаус Цитадели (Штаб MERIDIAN)",
		"desc": "Вершина цитадели MERIDIAN: серверная, панорамная площадка и главный мейнфрейм.",
		"danger": "★★★",
		"scene": "res://scenes/levels/citadel_penthouse.tscn"
	},
	{
		"id": "garage",
		"icon": "🛠️",
		"name": "Гараж Коли (Испытательный Полигон)",
		"desc": "Стенд физики, настройка управляемости фургона и полигон инструментов.",
		"danger": "☆☆☆",
		"scene": "res://scenes/testlabs/foundation_graybox.tscn"
	}
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_style_panel()
	_build_tactical_status_card()
	_setup_buttons()
	_build_district_modal()

func _style_panel() -> void:
	if not panel_container:
		return
	panel_container.custom_minimum_size = Vector2(500, 580)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.9, 1.0, 0.9)
	style.shadow_color = Color(0.05, 0.6, 0.9, 0.35)
	style.shadow_size = 14
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel_container.add_theme_stylebox_override("panel", style)

func _build_tactical_status_card() -> void:
	var vbox: VBoxContainer = get_node_or_null("Center/Panel/Margin/VBox")
	if not vbox:
		return

	if title_label:
		title_label.text = "ПАУЗА // ТАКТИЧЕСКИЙ КПК"
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))

	if subtitle_label:
		subtitle_label.text = "СИСТЕМА: КРАСНОГРАД OS // РЕЖИМ ОЖИДАНИЯ"
		subtitle_label.add_theme_font_size_override("font_size", 11)
		subtitle_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))

	# Карточка тактического статуса
	tactical_card = PanelContainer.new()
	tactical_card.name = "TacticalStatusCard"
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.05, 0.1, 0.16, 0.9)
	c_style.border_width_left = 2
	c_style.border_color = Color(0.2, 0.7, 0.9, 0.6)
	c_style.corner_radius_top_left = 4
	c_style.corner_radius_top_right = 4
	c_style.corner_radius_bottom_left = 4
	c_style.corner_radius_bottom_right = 4
	tactical_card.add_theme_stylebox_override("panel", c_style)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_bottom", 8)
	tactical_card.add_child(m)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	m.add_child(cv)

	tac_district_label = Label.new()
	tac_district_label.text = "📍 РАЙОН: СТАРЫЙ РАЙОН"
	tac_district_label.add_theme_font_size_override("font_size", 13)
	tac_district_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	cv.add_child(tac_district_label)

	tac_stats_label = Label.new()
	tac_stats_label.text = "❤️ Здоровье: 100 HP   |   💰 Баланс: 250 КР."
	tac_stats_label.add_theme_font_size_override("font_size", 11)
	tac_stats_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	cv.add_child(tac_stats_label)

	tac_objective_label = Label.new()
	tac_objective_label.text = "🎯 ЦЕЛЬ: Загрузить 3 ящика «Кока-Коля» в кузов"
	tac_objective_label.add_theme_font_size_override("font_size", 11)
	tac_objective_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5))
	cv.add_child(tac_objective_label)

	# Вставляем карточку после разделителя (индекс 3)
	vbox.add_child(tactical_card)
	vbox.move_child(tactical_card, 3)

func _setup_buttons() -> void:
	var buttons := [btn_resume, btn_districts, btn_settings, btn_save, btn_load, btn_testhub, btn_mainmenu]
	var labels := [
		"[ ESC ]  ▶  ПРОДОЛЖИТЬ ИГРУ",
		"[ M ]    🗺️  ВЫБОР РАЙОНА (КАРТА ГОРОДА)",
		"[ O ]    ⚙️  НАСТРОЙКИ И УПРАВЛЕНИЕ",
		"[ F5 ]   💾  БЫСТРОЕ СОХРАНЕНИЕ",
		"[ F9 ]   📂  БЫСТРАЯ ЗАГРУЗКА",
		"[ H ]    🧪  TEST HUB / СТЕНДЫ",
		"[ Q ]    🏠  В ГЛАВНОЕ МЕНЮ"
	]

	for i in range(buttons.size()):
		var b: Button = buttons[i]
		if not b:
			continue
		b.text = labels[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_apply_cyber_button_styling(b, i == 0)

	if btn_resume:
		btn_resume.pressed.connect(resume_game)
	if btn_districts:
		btn_districts.pressed.connect(_on_districts_pressed)
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_save:
		btn_save.pressed.connect(_on_save_pressed)
	if btn_load:
		btn_load.pressed.connect(_on_load_pressed)
	if btn_testhub:
		btn_testhub.pressed.connect(_on_testhub_pressed)
	if btn_mainmenu:
		btn_mainmenu.pressed.connect(_on_mainmenu_pressed)

func _apply_cyber_button_styling(btn: Button, is_primary: bool = false) -> void:
	var base_bg := Color(0.06, 0.12, 0.2, 0.92) if is_primary else Color(0.04, 0.08, 0.13, 0.88)
	var border_col := Color(1.0, 0.85, 0.25, 0.9) if is_primary else Color(0.2, 0.38, 0.52, 0.6)
	
	var norm_style := StyleBoxFlat.new()
	norm_style.bg_color = base_bg
	norm_style.border_width_left = 3 if is_primary else 2
	norm_style.border_width_top = 1
	norm_style.border_width_right = 1
	norm_style.border_width_bottom = 1
	norm_style.border_color = border_col
	norm_style.corner_radius_top_left = 4
	norm_style.corner_radius_top_right = 4
	norm_style.corner_radius_bottom_left = 4
	norm_style.corner_radius_bottom_right = 4
	norm_style.content_margin_left = 14
	norm_style.content_margin_right = 14
	btn.add_theme_stylebox_override("normal", norm_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.08, 0.2, 0.32, 0.96)
	hover_style.border_width_left = 4
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(0.2, 0.95, 1.0, 1.0)
	hover_style.shadow_color = Color(0.1, 0.8, 1.0, 0.4)
	hover_style.shadow_size = 4
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	hover_style.content_margin_left = 18
	hover_style.content_margin_right = 14
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	btn.mouse_entered.connect(func() -> void:
		_play_sfx("ui_hover", -10.0, randf_range(0.96, 1.05))
		var tw := create_tween()
		tw.tween_property(btn, "position:x", 6.0, 0.1).as_relative()
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "position:x", -6.0, 0.1).as_relative()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_cancel"):
		if district_modal and district_modal.visible:
			district_modal.visible = false
			return
		if settings_menu and settings_menu.visible:
			settings_menu.close_menu()
			return
		toggle_pause()
	elif is_paused:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_M:
					_on_districts_pressed()
				KEY_O:
					_on_settings_pressed()
				KEY_F5:
					_quick_save()
				KEY_F9:
					_quick_load()
				KEY_H:
					_on_testhub_pressed()
				KEY_Q:
					_on_mainmenu_pressed()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_quick_save()
		elif event.keycode == KEY_F9:
			_quick_load()

func toggle_pause() -> void:
	set_paused(not is_paused)

func set_paused(paused: bool) -> void:
	is_paused = paused
	visible = is_paused
	get_tree().paused = is_paused

	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_tactical_status()
		if btn_resume:
			btn_resume.grab_focus()
		_play_sfx("ui_click", -4.0)
	else:
		if settings_menu:
			settings_menu.visible = false
		if district_modal:
			district_modal.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_tactical_status() -> void:
	var dist_name := "Старый Район & Терминал №4"
	var credits := 250
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var d_id: String = str(gm.get("current_district"))
		for d in DISTRICT_LIST:
			if d["id"] == d_id:
				dist_name = "%s %s" % [d["icon"], d["name"]]
				break
		credits = int(gm.get("credits"))

	if tac_district_label:
		tac_district_label.text = "📍 %s" % dist_name.to_upper()

	var hp := 100
	var player = get_tree().get_first_node_in_group("player")
	if not player and has_node("/root/OldDistrict/Player"):
		player = get_node("/root/OldDistrict/Player")
	if player and "health" in player:
		hp = int(player.get("health"))

	if tac_stats_label:
		tac_stats_label.text = "❤️ Здоровье: %d HP   |   💰 Кредиты: %d КР." % [hp, credits]

	if tac_objective_label:
		var obj_text := "Загрузить 3 ящика «Кока-Коля» в фургон"
		var mm = get_tree().get_first_node_in_group("mission_manager")
		if not mm and has_node("/root/OldDistrict/MissionManager"):
			mm = get_node("/root/OldDistrict/MissionManager")
		if mm and "current_objective_title" in mm:
			obj_text = str(mm.get("current_objective_title"))
		tac_objective_label.text = "🎯 ЦЕЛЬ: %s" % obj_text

func resume_game() -> void:
	_play_sfx("ui_click", -4.0)
	set_paused(false)

func _on_districts_pressed() -> void:
	_play_sfx("ui_click")
	if district_modal:
		district_modal.visible = true

func _build_district_modal() -> void:
	district_modal = Control.new()
	district_modal.name = "DistrictSelectModal"
	district_modal.anchors_preset = Control.PRESET_FULL_RECT
	district_modal.visible = false
	add_child(district_modal)

	var dimmer := ColorRect.new()
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.color = Color(0.02, 0.03, 0.06, 0.92)
	district_modal.add_child(dimmer)

	var frame := PanelContainer.new()
	frame.anchors_preset = Control.PRESET_CENTER
	frame.offset_left = -480.0
	frame.offset_right = 480.0
	frame.offset_top = -280.0
	frame.offset_bottom = 280.0
	var f_style := StyleBoxFlat.new()
	f_style.bg_color = Color(0.04, 0.08, 0.14, 0.95)
	f_style.border_width_left = 2
	f_style.border_width_top = 2
	f_style.border_width_right = 2
	f_style.border_width_bottom = 2
	f_style.border_color = Color(0.2, 0.95, 1.0, 0.9)
	f_style.shadow_size = 14
	f_style.shadow_color = Color(0.1, 0.8, 1.0, 0.35)
	f_style.corner_radius_top_left = 6
	f_style.corner_radius_top_right = 6
	f_style.corner_radius_bottom_left = 6
	f_style.corner_radius_bottom_right = 6
	frame.add_theme_stylebox_override("panel", f_style)
	district_modal.add_child(frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	frame.add_child(main_vbox)

	var top_bar := HBoxContainer.new()
	main_vbox.add_child(top_bar)

	var title := Label.new()
	title.text = " 🗺️ КАРТА КРАСНОГРАДА // ПЕРЕХОД В РАЙОН"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = " [X] Закрыть "
	close_btn.pressed.connect(func() -> void:
		_play_sfx("ui_click")
		district_modal.visible = false
	)
	top_bar.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for dist in DISTRICT_LIST:
		var item_panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Color(0.06, 0.1, 0.16, 0.85)
		p_style.border_width_left = 2
		p_style.border_color = Color(0.2, 0.8, 1.0, 0.7)
		p_style.corner_radius_top_left = 4
		p_style.corner_radius_top_right = 4
		p_style.corner_radius_bottom_left = 4
		p_style.corner_radius_bottom_right = 4
		item_panel.add_theme_stylebox_override("panel", p_style)
		list.add_child(item_panel)

		var hbox := HBoxContainer.new()
		item_panel.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var d_title := Label.new()
		d_title.text = "%s %s  [Опасность: %s]" % [dist["icon"], dist["name"], dist["danger"]]
		d_title.add_theme_font_size_override("font_size", 14)
		d_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		info_vbox.add_child(d_title)

		var d_desc := Label.new()
		d_desc.text = dist["desc"]
		d_desc.add_theme_font_size_override("font_size", 11)
		d_desc.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
		info_vbox.add_child(d_desc)

		var travel_btn := Button.new()
		travel_btn.text = " ПЕРЕЙТИ В РАЙОН ▶ "
		var target_id: String = dist["id"]
		var target_scene: String = dist["scene"]
		travel_btn.pressed.connect(func() -> void:
			_play_sfx("ui_click")
			district_modal.visible = false
			resume_game()
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm and gm.has_method("change_district"):
				gm.call("change_district", target_id, true)
			else:
				get_tree().change_scene_to_file(target_scene)
		)
		travel_btn.mouse_entered.connect(func() -> void:
			_play_sfx("ui_hover", -12.0)
		)
		hbox.add_child(travel_btn)

func _on_settings_pressed() -> void:
	_play_sfx("ui_click")
	if settings_menu:
		settings_menu.open_menu(0)

func _on_save_pressed() -> void:
	_quick_save()

func _on_load_pressed() -> void:
	_quick_load()

func _quick_save() -> void:
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		var success: bool = sm.call("save_game", 0)
		if success:
			_set_status("✔ ИГРА УСПЕШНО СОХРАНЕНА В СЛОТ #0!", Color(0.3, 1.0, 0.4))
			_play_sfx("hint", -2.0)
		else:
			_set_status("✖ ОШИБКА СОХРАНЕНИЯ!", Color(1.0, 0.3, 0.3))

func _quick_load() -> void:
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		var data: Dictionary = sm.call("load_game", 0)
		if not data.is_empty():
			_set_status("✔ СОХРАНЕНИЕ УСПЕШНО ЗАГРУЖЕНО!", Color(0.3, 0.8, 1.0))
			_play_sfx("hint", -2.0)
			resume_game()
		else:
			_set_status("✖ ФАЙЛ СОХРАНЕНИЯ НЕ НАЙДЕН!", Color(1.0, 0.8, 0.2))

func _on_testhub_pressed() -> void:
	_play_sfx("ui_click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")

func _on_mainmenu_pressed() -> void:
	_play_sfx("ui_click")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _set_status(text: String, color: Color) -> void:
	if status_label:
		status_label.text = text
		status_label.modulate = color

func _play_sfx(sound_name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", sound_name, vol, pitch)
