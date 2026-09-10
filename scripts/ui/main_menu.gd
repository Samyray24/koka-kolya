extends Control

# Main Menu Controller for «Кока-Коля» (v1.0.0 Gold Master)

@onready var btn_play: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnPlay")
@onready var btn_districts: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnDistricts")
@onready var btn_settings: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnSettings")
@onready var btn_guide: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnGuide")
@onready var btn_testhub: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnTestHub")
@onready var btn_quit: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnQuit")
@onready var settings_menu: Node = get_node_or_null("SettingsMenu")

var district_modal: Control = null

const DISTRICT_LIST: Array[Dictionary] = [
	{
		"id": "old_district",
		"name": "Старый Район (Трущобы)",
		"desc": "Конспиративный гараж Коли, улицы трущоб и Складской терминал №4.",
		"danger": "★☆☆",
		"scene": "res://scenes/levels/old_district.tscn"
	},
	{
		"id": "city_highway",
		"name": "Скоростное Шоссе и Блокпост",
		"desc": "Скоростная 4-полосная автомагистраль, КПП №2 Синдиката и вещательная медиа-башня.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/city_highway.tscn"
	},
	{
		"id": "neon_boulevard",
		"name": "Неоновый Бульвар (Даунтаун)",
		"desc": "Небоскрёбы, двухуровневая эстакада, автоматы с колой и Неон-Плаза.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/neon_boulevard.tscn"
	},
	{
		"id": "red_line_plant",
		"name": "Завод Красной Линии",
		"desc": "Огромный заводской комплекс по розливу синтетической газировки.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/red_line_plant.tscn"
	},
	{
		"id": "logistics_hub",
		"name": "Логистический Хаб",
		"desc": "Складской терминал MERIDIAN с контейнерами, кранами и патрулями.",
		"danger": "★★★",
		"scene": "res://scenes/levels/logistics_hub.tscn"
	},
	{
		"id": "underground_metro",
		"name": "Подземный Метрополитен",
		"desc": "Станция «Проспект Революции», туннели, пути и схрон Сопротивления.",
		"danger": "★★☆",
		"scene": "res://scenes/levels/underground_metro.tscn"
	},
	{
		"id": "citadel_penthouse",
		"name": "Пентхаус Цитадели (Штаб Синдиката)",
		"desc": "Вершина цитадели MERIDIAN: серверная, панорамная вертолетная площадка и главный мейнфрейм.",
		"danger": "★★★",
		"scene": "res://scenes/levels/citadel_penthouse.tscn"
	},
	{
		"id": "garage",
		"name": "Гараж Коли (Испытательный Полигон)",
		"desc": "Стенд физики, настройка управляемости фургона и полигон инструментов.",
		"danger": "☆☆☆",
		"scene": "res://scenes/testlabs/foundation_graybox.tscn"
	}
]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
		_hook_btn(btn_play)
		btn_play.grab_focus()
	if btn_districts:
		btn_districts.pressed.connect(_on_districts_pressed)
		_hook_btn(btn_districts)
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
		_hook_btn(btn_settings)
	if btn_guide:
		btn_guide.pressed.connect(_on_guide_pressed)
		_hook_btn(btn_guide)
	if btn_testhub:
		btn_testhub.pressed.connect(_on_testhub_pressed)
		_hook_btn(btn_testhub)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
		_hook_btn(btn_quit)

	_build_district_modal()

func _hook_btn(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void:
		_play_sfx("ui_hover", -12.0)
	)

func _play_sfx(sound_name: String, vol: float = 0.0) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", sound_name, vol)

func _on_play_pressed() -> void:
	_play_sfx("ui_click")
	print("[MENU] Launching First Playable (Old District: Mission 1)...")
	get_tree().change_scene_to_file("res://scenes/levels/old_district.tscn")

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
	dimmer.color = Color(0.02, 0.03, 0.06, 0.9)
	district_modal.add_child(dimmer)

	var frame := PanelContainer.new()
	frame.anchors_preset = Control.PRESET_CENTER
	frame.offset_left = -480.0
	frame.offset_right = 480.0
	frame.offset_top = -280.0
	frame.offset_bottom = 280.0
	district_modal.add_child(frame)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	frame.add_child(main_vbox)

	var top_bar := HBoxContainer.new()
	main_vbox.add_child(top_bar)

	var title := Label.new()
	title.text = " 🗺️ КАРТА КРАСНОГРАДА // ВЫБОР РАЙОНА ДЛЯ СТАРТА"
	title.add_theme_font_size_override("font_size", 17)
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
		list.add_child(item_panel)

		var hbox := HBoxContainer.new()
		item_panel.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var d_title := Label.new()
		d_title.text = "%s  [Опасность: %s]" % [dist["name"], dist["danger"]]
		d_title.add_theme_font_size_override("font_size", 15)
		d_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
		info_vbox.add_child(d_title)

		var d_desc := Label.new()
		d_desc.text = dist["desc"]
		d_desc.add_theme_font_size_override("font_size", 12)
		d_desc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
		info_vbox.add_child(d_desc)

		var travel_btn := Button.new()
		travel_btn.text = " ВЪЕХАТЬ В РАЙОН ▶ "
		var target_id: String = dist["id"]
		var target_scene: String = dist["scene"]
		travel_btn.pressed.connect(func() -> void:
			_play_sfx("ui_click")
			district_modal.visible = false
			print("[MENU] Traveling to district: %s (%s)..." % [target_id, target_scene])
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm and gm.has_method("change_district"):
				gm.call("change_district", target_id, true)
			else:
				get_tree().change_scene_to_file(target_scene)
		)
		_hook_btn(travel_btn)
		hbox.add_child(travel_btn)

func _on_settings_pressed() -> void:
	_play_sfx("ui_click")
	if settings_menu:
		settings_menu.open_menu(0) # 0: Графика

func _on_guide_pressed() -> void:
	_play_sfx("ui_click")
	if settings_menu:
		settings_menu.open_menu(2) # 2: Управление / Клавиши

func _on_testhub_pressed() -> void:
	_play_sfx("ui_click")
	print("[MENU] Opening Test Hub...")
	get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")

func _on_quit_pressed() -> void:
	_play_sfx("ui_click")
	print("[MENU] Quitting application...")
	get_tree().quit()
