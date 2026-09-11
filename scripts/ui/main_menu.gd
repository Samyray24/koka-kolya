class_name MainMenu
extends Control

# MainMenu — Высокотехнологичный киберпанк интерфейс «Кока-Коля» (v1.0.0 Gold Master)
# Включает:
# - Процедурный анимированный неоновый фон CyberpunkMenuBackground
# - Фоновый синтвейв-саундтрек с плавным затуханием и виджетом переключения
# - Интерактивный правый терминал (Тактический КПК): живой селектор районов, цели, досье агента
# - Неоновые кнопки с анимациями смещения, подсветки и процедурными звуковыми эффектами
# - Модальное окно карты Краснограда и меню расширенных настроек

@onready var btn_play: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnPlay")
@onready var btn_districts: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnDistricts")
@onready var btn_settings: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnSettings")
@onready var btn_guide: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnGuide")
@onready var btn_testhub: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnTestHub")
@onready var btn_quit: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnQuit")
@onready var settings_menu: Node = get_node_or_null("SettingsMenu")
@onready var game_title: Label = get_node_or_null("MarginContainer/VBoxContainer/GameTitle")
@onready var sub_title: Label = get_node_or_null("MarginContainer/VBoxContainer/SubTitle")

var district_modal: Control = null
var music_player: AudioStreamPlayer = null
var btn_music_toggle: Button = null
var btn_fullscreen_toggle: Button = null
var top_bar: HBoxContainer = null

# Правый тактический терминал
var terminal_panel: PanelContainer = null
var term_district_title: Label = null
var term_threat_badge: Label = null
var term_desc: Label = null
var term_objectives_vbox: VBoxContainer = null
var term_launch_btn: Button = null
var selected_district_idx: int = 0
var district_tab_buttons: Array[Button] = []

var glitch_timer: float = 0.0

const DISTRICT_LIST: Array[Dictionary] = [
	{
		"id": "old_district",
		"icon": "🏙️",
		"name": "Старый Район & Терминал №4",
		"desc": "Конспиративный гараж Коли, улицы трущоб и Складской терминал №4 Синдиката MERIDIAN.",
		"danger": "★☆☆ (НИЗКАЯ ОПАСНОСТЬ)",
		"danger_color": Color(0.2, 0.95, 0.4),
		"objectives": [
			"Загрузить 3 ящика «Кока-Коля» в фургон [E]",
			"Доехать до Складского терминала №4",
			"Похитить рецептурный чип из хранилища",
			"Вернуться в гараж и защитить формулу"
		],
		"scene": "res://scenes/levels/old_district.tscn"
	},
	{
		"id": "city_highway",
		"icon": "🏎️",
		"name": "Скоростное Шоссе & КПП №2",
		"desc": "Скоростная 4-полосная автомагистраль, блокпост патрулей, таран на фургоне и медиа-телебашня.",
		"danger": "★★☆ (СРЕДНЯЯ ОПАСНОСТЬ)",
		"danger_color": Color(1.0, 0.75, 0.2),
		"objectives": [
			"Прорвать охранный заслон КПП №2 на таран",
			"Оторваться от скоростных патрулей Синдиката",
			"Взломать терминал телебашни Краснограда",
			"Запустить вещание подпольного радио"
		],
		"scene": "res://scenes/levels/city_highway.tscn"
	},
	{
		"id": "neon_boulevard",
		"icon": "🌆",
		"name": "Неоновый Бульвар (Даунтаун)",
		"desc": "Сердце мегаполиса: небоскрёбы, двухуровневая эстакада, автоматы с колой и площадь Неон-Плаза.",
		"danger": "★★☆ (СРЕДНЯЯ ОПАСНОСТЬ)",
		"danger_color": Color(0.2, 0.85, 1.0),
		"objectives": [
			"Доставить партию свежей колы на Неон-Плаза",
			"Активировать автоматы раздачи для горожан",
			"Уйти от сканирующих дронов-охотников"
		],
		"scene": "res://scenes/levels/neon_boulevard.tscn"
	},
	{
		"id": "red_line_plant",
		"icon": "🏭",
		"name": "Завод «Красная Линия»",
		"desc": "Гигантский заводской комплекс: автоматика розлива, конвейеры, камеры наблюдения и сиропная башня.",
		"danger": "★★☆ (СРЕДНЯЯ ОПАСНОСТЬ)",
		"danger_color": Color(1.0, 0.45, 0.2),
		"objectives": [
			"Синтезировать концентрат на верстаке",
			"Отключить камеры охраны через терминал",
			"Запустить конвейер розлива настоящей колы"
		],
		"scene": "res://scenes/levels/red_line_plant.tscn"
	},
	{
		"id": "logistics_hub",
		"icon": "📦",
		"name": "Логистический Хаб MERIDIAN",
		"desc": "Грузовой распределительный терминал: контейнерные площадки, охранные турели и фуры снабжения.",
		"danger": "★★★ (ВЫСОКАЯ ОПАСНОСТЬ)",
		"danger_color": Color(1.0, 0.3, 0.3),
		"objectives": [
			"Проникнуть на охраняемую грузовую рампу",
			"Перехватить партию ингредиентов сиропа",
			"Эвакуировать груз на фургоне под обстрелом"
		],
		"scene": "res://scenes/levels/logistics_hub.tscn"
	},
	{
		"id": "underground_metro",
		"icon": "🚇",
		"name": "Подземный Метрополитен",
		"desc": "Станция «Проспект Революции», заброшенные тоннели, стрелки путей и партизанский схрон.",
		"danger": "★★☆ (СРЕДНЯЯ ОПАСНОСТЬ)",
		"danger_color": Color(0.4, 0.9, 1.0),
		"objectives": [
			"Исследовать станцию «Проспект Революции»",
			"Найти тайник связного Сопротивления",
			"Подключить партизанский модем к магистрали"
		],
		"scene": "res://scenes/levels/underground_metro.tscn"
	},
	{
		"id": "citadel_penthouse",
		"icon": "👑",
		"name": "Пентхаус Цитадели (Штаб MERIDIAN)",
		"desc": "Вершина Цитадели: серверный зал мейнфрейма, вертолетная площадка и элитные кибер-стражи.",
		"danger": "★★★ (ЭКСТРЕМАЛЬНАЯ)",
		"danger_color": Color(1.0, 0.15, 0.4),
		"objectives": [
			"Взломать главный сервер Синдиката",
			"Стереть монопольные патенты корпорации",
			"Освободить Красноград от диктата сиропа"
		],
		"scene": "res://scenes/levels/citadel_penthouse.tscn"
	},
	{
		"id": "garage",
		"icon": "🛠️",
		"name": "Гараж Коли (Испытательный Полигон)",
		"desc": "Тренировочный полигон: стенды физики, тест оружия, стрельбище и дрифт-зона фургона.",
		"danger": "☆☆☆ (ТРЕНИРОВКА)",
		"danger_color": Color(0.7, 0.8, 0.9),
		"objectives": [
			"Отработать физический захват предметов",
			"Протестировать все 9 видов оружия и тулов",
			"Проверить нитро-ускорение и ручник фургона"
		],
		"scene": "res://scenes/testlabs/foundation_graybox.tscn"
	}
]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_setup_background()
	_setup_music()
	_setup_top_bar()
	_setup_main_buttons()
	_build_tactical_terminal()
	_build_district_modal()
	_setup_settings_integration()
	_select_district(0)

func _process(delta: float) -> void:
	glitch_timer += delta
	if glitch_timer >= 4.0:
		glitch_timer = 0.0
		_trigger_title_glitch()

func _setup_background() -> void:
	# Проверяем наличие фонового контроллера, если нет — добавляем процедурный
	var bg = get_node_or_null("CyberpunkBackground")
	if not bg:
		var bg_script = load("res://scripts/ui/cyberpunk_menu_background.gd")
		if bg_script:
			var new_bg = bg_script.new()
			new_bg.name = "CyberpunkBackground"
			add_child(new_bg)
			move_child(new_bg, 0)

func _setup_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MenuMusicPlayer"
	music_player.bus = "Master"
	add_child(music_player)

	var track_path := "res://assets/audio/radio/synthwave_neon_run.wav"
	if ResourceLoader.exists(track_path):
		var stream = load(track_path)
		if stream:
			music_player.stream = stream
			music_player.volume_db = -12.0
			if DisplayServer.get_name() != "headless":
				music_player.play()

func _setup_top_bar() -> void:
	top_bar = HBoxContainer.new()
	top_bar.name = "TopNavBar"
	top_bar.anchors_preset = Control.PRESET_TOP_WIDE
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 48.0
	top_bar.offset_top = 16.0
	top_bar.offset_right = -48.0
	top_bar.offset_bottom = 54.0
	top_bar.add_theme_constant_override("separation", 16)
	top_bar.mouse_filter = MOUSE_FILTER_IGNORE
	top_bar.z_index = 2
	add_child(top_bar)

	var status_badge := Label.new()
	status_badge.text = "● СЕТЬ: КРАСНОГРАД OS v2.6 // СОПРОТИВЛЕНИЕ: ОНЛАЙН"
	status_badge.add_theme_font_size_override("font_size", 12)
	status_badge.add_theme_color_override("font_color", Color(0.2, 0.95, 0.5, 0.9))
	status_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(status_badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	# Кнопка переключения музыки
	btn_music_toggle = Button.new()
	btn_music_toggle.name = "BtnMusicToggle"
	btn_music_toggle.text = " 🎵 МУЗЫКА: ВКЛ "
	btn_music_toggle.custom_minimum_size = Vector2(130, 32)
	btn_music_toggle.add_theme_font_size_override("font_size", 11)
	_style_pill_button(btn_music_toggle, Color(0.2, 0.8, 1.0))
	btn_music_toggle.pressed.connect(_toggle_music)
	top_bar.add_child(btn_music_toggle)

	# Кнопка полного экрана
	btn_fullscreen_toggle = Button.new()
	btn_fullscreen_toggle.name = "BtnFullscreenToggle"
	btn_fullscreen_toggle.text = " ⛶ ЭКРАН "
	btn_fullscreen_toggle.custom_minimum_size = Vector2(90, 32)
	btn_fullscreen_toggle.add_theme_font_size_override("font_size", 11)
	_style_pill_button(btn_fullscreen_toggle, Color(1.0, 0.85, 0.3))
	btn_fullscreen_toggle.pressed.connect(_toggle_fullscreen)
	top_bar.add_child(btn_fullscreen_toggle)

func _setup_main_buttons() -> void:
	if game_title:
		game_title.text = "КОКА-КОЛЯ"
		game_title.add_theme_font_size_override("font_size", 52)
		game_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		game_title.add_theme_color_override("font_shadow_color", Color(0.9, 0.1, 0.3, 0.8))
		game_title.add_theme_constant_override("shadow_offset_x", 3)
		game_title.add_theme_constant_override("shadow_offset_y", 3)

	if sub_title:
		sub_title.text = "⚡ КРАСНОГРАД 2026 // РЕЙД ЗА НАСТОЯЩИМ ВКУСОМ"
		sub_title.add_theme_font_size_override("font_size", 13)
		sub_title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))

	var buttons: Array[Button] = [btn_play, btn_districts, btn_settings, btn_guide, btn_testhub, btn_quit]
	var btn_labels := [
		"[ 01 ] ▶ НАЧАТЬ КАМПАНИЮ (СТАРЫЙ РАЙОН)",
		"[ 02 ] 🗺️ КАРТА РАЙОНОВ КРАСНОГРАДА",
		"[ 03 ] ⚙️ РАСШИРЕННЫЕ НАСТРОЙКИ",
		"[ 04 ] 📖 РУКОВОДСТВО ОПЕРАТИВНИКА",
		"[ 05 ] 🧪 ТЕСТОВЫЙ ПОЛИГОН (LABS)",
		"[ 06 ] 🚪 ВЫХОД В СИСТЕМУ"
	]

	for i in range(buttons.size()):
		var b: Button = buttons[i]
		if not b:
			continue
		b.text = btn_labels[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_apply_cyber_button_styling(b, i == 0)

	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
		btn_play.grab_focus()
	if btn_districts:
		btn_districts.pressed.connect(_on_districts_pressed)
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_guide:
		btn_guide.pressed.connect(_on_guide_pressed)
	if btn_testhub:
		btn_testhub.pressed.connect(_on_testhub_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)

func _apply_cyber_button_styling(btn: Button, is_primary: bool = false) -> void:
	var base_bg := Color(0.06, 0.12, 0.2, 0.92) if is_primary else Color(0.035, 0.07, 0.12, 0.88)
	var border_col := Color(1.0, 0.85, 0.25, 0.9) if is_primary else Color(0.18, 0.38, 0.55, 0.6)
	
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
	norm_style.content_margin_left = 16
	norm_style.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", norm_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.08, 0.22, 0.35, 0.96)
	hover_style.border_width_left = 4
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(0.2, 0.95, 1.0, 1.0)
	hover_style.shadow_color = Color(0.1, 0.8, 1.0, 0.4)
	hover_style.shadow_size = 6
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	hover_style.content_margin_left = 22
	hover_style.content_margin_right = 16
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	btn.mouse_entered.connect(func() -> void:
		_play_sfx("ui_hover", -8.0, randf_range(0.96, 1.05))
		var tw := create_tween()
		tw.tween_property(btn, "position:x", 8.0, 0.12).as_relative()
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "position:x", -8.0, 0.12).as_relative()
	)

func _style_pill_button(btn: Button, accent_col: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.14, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = accent_col
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_color_override("font_color", accent_col)

	btn.mouse_entered.connect(func() -> void:
		_play_sfx("ui_hover", -12.0)
	)

func _build_tactical_terminal() -> void:
	terminal_panel = PanelContainer.new()
	terminal_panel.name = "TacticalTerminalPanel"
	terminal_panel.anchors_preset = Control.PRESET_FULL_RECT
	terminal_panel.anchor_left = 0.44
	terminal_panel.anchor_right = 1.0
	terminal_panel.anchor_top = 0.09
	terminal_panel.anchor_bottom = 0.93
	terminal_panel.offset_left = 10.0
	terminal_panel.offset_right = -48.0
	terminal_panel.offset_top = 0.0
	terminal_panel.offset_bottom = 0.0
	terminal_panel.grow_horizontal = GROW_DIRECTION_BOTH
	terminal_panel.grow_vertical = GROW_DIRECTION_BOTH

	var term_style := StyleBoxFlat.new()
	term_style.bg_color = Color(0.03, 0.06, 0.1, 0.9)
	term_style.border_width_left = 2
	term_style.border_width_top = 2
	term_style.border_width_right = 2
	term_style.border_width_bottom = 2
	term_style.border_color = Color(0.2, 0.85, 1.0, 0.8)
	term_style.shadow_color = Color(0.05, 0.5, 0.8, 0.25)
	term_style.shadow_size = 12
	term_style.corner_radius_top_left = 6
	term_style.corner_radius_top_right = 6
	term_style.corner_radius_bottom_left = 6
	term_style.corner_radius_bottom_right = 6
	terminal_panel.add_theme_stylebox_override("panel", term_style)
	terminal_panel.z_index = 0
	terminal_panel.z_as_relative = false
	add_child(terminal_panel)
	move_child(terminal_panel, 1)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	terminal_panel.add_child(margin)

	var vbox_all := VBoxContainer.new()
	vbox_all.add_theme_constant_override("separation", 10)
	margin.add_child(vbox_all)

	# 1. Заголовок терминала
	var header_hbox := HBoxContainer.new()
	vbox_all.add_child(header_hbox)

	var h_title := Label.new()
	h_title.text = "📡 ГОЛОГРАФИЧЕСКИЙ ТЕРМИНАЛ // КАРТА ОПЕРАЦИЙ"
	h_title.add_theme_font_size_override("font_size", 14)
	h_title.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	header_hbox.add_child(h_title)

	var h_spacer := Control.new()
	h_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header_hbox.add_child(h_spacer)

	var h_status := Label.new()
	h_status.text = "КАНАЛ: ЗАШИФРОВАН [AES-256]"
	h_status.add_theme_font_size_override("font_size", 10)
	h_status.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
	header_hbox.add_child(h_status)

	var sep1 := HSeparator.new()
	vbox_all.add_child(sep1)

	# 2. Селектор районов (горизонтальная прокрутка или плитки)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.custom_minimum_size = Vector2(0, 42)
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox_all.add_child(tabs_scroll)

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 8)
	tabs_scroll.add_child(tabs_hbox)

	district_tab_buttons.clear()
	for i in range(DISTRICT_LIST.size()):
		var d: Dictionary = DISTRICT_LIST[i]
		var btn := Button.new()
		btn.text = "%s %s" % [d["icon"], d["name"].split(" ")[0]]
		btn.custom_minimum_size = Vector2(105, 36)
		btn.add_theme_font_size_override("font_size", 11)
		_style_pill_button(btn, Color(0.3, 0.7, 0.9))
		btn.pressed.connect(func() -> void:
			_select_district(i)
		)
		tabs_hbox.add_child(btn)
		district_tab_buttons.append(btn)

	# 3. Карточка выбранного района
	var card_panel := PanelContainer.new()
	card_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.08, 0.14, 0.92)
	card_style.border_width_left = 2
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.2, 0.6, 0.8, 0.5)
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_panel.add_theme_stylebox_override("panel", card_style)
	vbox_all.add_child(card_panel)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 16)
	card_margin.add_theme_constant_override("margin_top", 12)
	card_margin.add_theme_constant_override("margin_right", 16)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	card_panel.add_child(card_margin)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card_margin.add_child(card_vbox)

	# Шапка района
	var d_header := HBoxContainer.new()
	card_vbox.add_child(d_header)

	term_district_title = Label.new()
	term_district_title.text = "СТАРЫЙ РАЙОН"
	term_district_title.add_theme_font_size_override("font_size", 16)
	term_district_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	d_header.add_child(term_district_title)

	var d_sp := Control.new()
	d_sp.size_flags_horizontal = SIZE_EXPAND_FILL
	d_header.add_child(d_sp)

	term_threat_badge = Label.new()
	term_threat_badge.text = "★☆☆ (НИЗКАЯ ОПАСНОСТЬ)"
	term_threat_badge.add_theme_font_size_override("font_size", 12)
	d_header.add_child(term_threat_badge)

	# Описание
	term_desc = Label.new()
	term_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	term_desc.add_theme_font_size_override("font_size", 12)
	term_desc.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))
	card_vbox.add_child(term_desc)

	# Список задач
	var obj_hdr := Label.new()
	obj_hdr.text = "ТАКТИЧЕСКИЕ ЦЕЛИ ОПЕРАЦИИ:"
	obj_hdr.add_theme_font_size_override("font_size", 11)
	obj_hdr.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	card_vbox.add_child(obj_hdr)

	term_objectives_vbox = VBoxContainer.new()
	term_objectives_vbox.add_theme_constant_override("separation", 3)
	card_vbox.add_child(term_objectives_vbox)

	var bottom_h := HBoxContainer.new()
	bottom_h.add_theme_constant_override("separation", 12)
	card_vbox.add_child(bottom_h)

	var b_sp := Control.new()
	b_sp.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom_h.add_child(b_sp)

	term_launch_btn = Button.new()
	term_launch_btn.text = " ВЫСАДИТЬСЯ В РАЙОН ▶ "
	term_launch_btn.custom_minimum_size = Vector2(240, 44)
	term_launch_btn.add_theme_font_size_override("font_size", 13)
	_apply_cyber_button_styling(term_launch_btn, true)
	term_launch_btn.pressed.connect(_on_term_launch_pressed)
	bottom_h.add_child(term_launch_btn)

	# 4. Досье агента внизу терминала
	var dossier_box := PanelContainer.new()
	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.02, 0.04, 0.08, 0.8)
	d_style.border_width_left = 1
	d_style.border_width_top = 1
	d_style.border_width_right = 1
	d_style.border_width_bottom = 1
	d_style.border_color = Color(0.15, 0.3, 0.45, 0.5)
	d_style.corner_radius_top_left = 4
	d_style.corner_radius_top_right = 4
	d_style.corner_radius_bottom_left = 4
	d_style.corner_radius_bottom_right = 4
	dossier_box.add_theme_stylebox_override("panel", d_style)
	vbox_all.add_child(dossier_box)

	var dos_m := MarginContainer.new()
	dos_m.add_theme_constant_override("margin_left", 12)
	dos_m.add_theme_constant_override("margin_top", 8)
	dos_m.add_theme_constant_override("margin_right", 12)
	dos_m.add_theme_constant_override("margin_bottom", 8)
	dossier_box.add_child(dos_m)

	var dos_v := VBoxContainer.new()
	dos_v.add_theme_constant_override("separation", 2)
	dos_m.add_child(dos_v)

	var d_line1 := Label.new()
	d_line1.text = "👤 ОПЕРАТИВНИК: НИКОЛАЙ (КОЛЯ) // СПЕЦИАЛИСТ ПО ДОСТАВКЕ СОПРОТИВЛЕНИЯ"
	d_line1.add_theme_font_size_override("font_size", 11)
	d_line1.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	dos_v.add_child(d_line1)

	var d_line2 := Label.new()
	d_line2.text = "🚚 СНАРЯЖЕНИЕ: ФУРГОН RED REBEL (НИТРО + ТАРАН)  •  ХОТБАР 9 СЛОТОВ (ЗАХВАТ, ДУБИНКА, ВЗЛОМ...)"
	d_line2.add_theme_font_size_override("font_size", 10)
	d_line2.add_theme_color_override("font_color", Color(0.65, 0.78, 0.9))
	dos_v.add_child(d_line2)

func _select_district(idx: int) -> void:
	if idx < 0 or idx >= DISTRICT_LIST.size():
		return
	selected_district_idx = idx
	var data: Dictionary = DISTRICT_LIST[idx]

	if term_district_title:
		term_district_title.text = "%s %s" % [data["icon"], data["name"].to_upper()]
	if term_threat_badge:
		term_threat_badge.text = data["danger"]
		term_threat_badge.add_theme_color_override("font_color", data["danger_color"])
	if term_desc:
		term_desc.text = data["desc"]

	if term_objectives_vbox:
		for c in term_objectives_vbox.get_children():
			c.queue_free()
		var objs: Array = data["objectives"]
		for obj_text in objs:
			var l := Label.new()
			l.text = "  ▶ %s" % obj_text
			l.add_theme_font_size_override("font_size", 11)
			l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
			term_objectives_vbox.add_child(l)

	# Подсветка активной вкладки
	for i in range(district_tab_buttons.size()):
		var b: Button = district_tab_buttons[i]
		if i == selected_district_idx:
			b.modulate = Color(1.0, 0.85, 0.2)
		else:
			b.modulate = Color(0.8, 0.9, 1.0)

	_play_sfx("ui_hover", -14.0)

func _on_term_launch_pressed() -> void:
	var data: Dictionary = DISTRICT_LIST[selected_district_idx]
	_launch_district(data["id"], data["scene"])

func _trigger_title_glitch() -> void:
	if not game_title:
		return
	var orig_pos := game_title.position
	var tw := create_tween()
	tw.tween_property(game_title, "position:x", orig_pos.x + randf_range(-4, 4), 0.05)
	tw.parallel().tween_property(game_title, "modulate", Color(0.2, 0.95, 1.0), 0.05)
	tw.tween_property(game_title, "position:x", orig_pos.x, 0.06)
	tw.parallel().tween_property(game_title, "modulate", Color(1.0, 1.0, 1.0), 0.06)

func _toggle_music() -> void:
	if not music_player:
		return
	if music_player.playing:
		music_player.stop()
		if btn_music_toggle:
			btn_music_toggle.text = " 🔇 МУЗЫКА: ВЫКЛ "
			btn_music_toggle.modulate = Color(0.6, 0.6, 0.6)
	else:
		music_player.volume_db = -12.0
		music_player.play()
		if btn_music_toggle:
			btn_music_toggle.text = " 🎵 МУЗЫКА: ВКЛ "
			btn_music_toggle.modulate = Color(0.3, 0.9, 1.0)
	_play_sfx("ui_click")

func _toggle_fullscreen() -> void:
	_play_sfx("ui_click")
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
		if btn_fullscreen_toggle:
			btn_fullscreen_toggle.text = " ⛶ ЭКРАН "
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)
		if btn_fullscreen_toggle:
			btn_fullscreen_toggle.text = " 🗗 ОКОННЫЙ "

func _play_sfx(sound_name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", sound_name, vol, pitch)

func _on_play_pressed() -> void:
	_launch_district("old_district", "res://scenes/levels/old_district.tscn")

func _launch_district(target_id: String, target_scene: String) -> void:
	_play_sfx("ui_click")
	_fade_out_music(func() -> void:
		print("[MENU] Traveling to district: %s (%s)..." % [target_id, target_scene])
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("change_district"):
			gm.call("change_district", target_id, true)
		else:
			get_tree().change_scene_to_file(target_scene)
	)

func _fade_out_music(callback: Callable) -> void:
	if music_player and music_player.playing:
		var tw := create_tween()
		tw.tween_property(music_player, "volume_db", -50.0, 0.45)
		tw.tween_callback(callback)
	else:
		callback.call()

func _on_districts_pressed() -> void:
	_play_sfx("ui_click")
	if settings_menu:
		settings_menu.visible = false
	if not district_modal:
		_build_district_modal()
	_open_modal(district_modal)

func _build_district_modal() -> void:
	if district_modal:
		return
	district_modal = Control.new()
	district_modal.name = "DistrictSelectModal"
	district_modal.anchors_preset = Control.PRESET_FULL_RECT
	district_modal.visible = false
	district_modal.z_index = 100
	district_modal.z_as_relative = false
	add_child(district_modal)

	var dimmer := ColorRect.new()
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.color = Color(0.02, 0.03, 0.06, 0.92)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_play_sfx("ui_click")
			district_modal.visible = false
			_on_modal_closed()
	)
	district_modal.add_child(dimmer)

	var frame := PanelContainer.new()
	frame.anchors_preset = Control.PRESET_CENTER
	frame.offset_left = -480.0
	frame.offset_right = 480.0
	frame.offset_top = -290.0
	frame.offset_bottom = 290.0
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

	var modal_top_bar := HBoxContainer.new()
	main_vbox.add_child(modal_top_bar)

	var title := Label.new()
	title.text = " 🗺️ КАРТА КРАСНОГРАДА // ВЫБОР РАЙОНА ДЛЯ СТАРТА"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	modal_top_bar.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_top_bar.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = " [X] Закрыть "
	close_btn.pressed.connect(func() -> void:
		_play_sfx("ui_click")
		district_modal.visible = false
		_on_modal_closed()
	)
	modal_top_bar.add_child(close_btn)

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
		p_style.border_color = dist["danger_color"]
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
		d_title.text = "%s %s  [%s]" % [dist["icon"], dist["name"], dist["danger"]]
		d_title.add_theme_font_size_override("font_size", 14)
		d_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		info_vbox.add_child(d_title)

		var d_desc := Label.new()
		d_desc.text = dist["desc"]
		d_desc.add_theme_font_size_override("font_size", 11)
		d_desc.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
		info_vbox.add_child(d_desc)

		var travel_btn := Button.new()
		travel_btn.text = " ВЪЕХАТЬ В РАЙОН ▶ "
		var target_id: String = dist["id"]
		var target_scene: String = dist["scene"]
		travel_btn.pressed.connect(func() -> void:
			district_modal.visible = false
			_on_modal_closed()
			_launch_district(target_id, target_scene)
		)
		travel_btn.mouse_entered.connect(func() -> void:
			_play_sfx("ui_hover", -12.0)
		)
		hbox.add_child(travel_btn)

func _setup_settings_integration() -> void:
	if settings_menu:
		settings_menu.z_index = 100
		settings_menu.z_as_relative = false
		if settings_menu.has_signal("closed"):
			settings_menu.closed.connect(_on_modal_closed)
		settings_menu.visibility_changed.connect(func() -> void:
			if not settings_menu.visible and (district_modal == null or not district_modal.visible):
				_on_modal_closed()
		)

func _on_modal_closed() -> void:
	if terminal_panel:
		terminal_panel.visible = true
	if top_bar:
		top_bar.visible = true

func _open_modal(modal: Control) -> void:
	if terminal_panel:
		terminal_panel.visible = false
	if top_bar:
		top_bar.visible = false
	modal.z_index = 100
	modal.z_as_relative = false
	modal.move_to_front()
	modal.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if district_modal and district_modal.visible:
			district_modal.visible = false
			_on_modal_closed()
			_play_sfx("ui_click")
			get_viewport().set_input_as_handled()
			return
		if settings_menu and settings_menu.visible:
			settings_menu.close_menu()
			_on_modal_closed()
			get_viewport().set_input_as_handled()
			return

func _on_settings_pressed() -> void:
	_play_sfx("ui_click")
	if district_modal:
		district_modal.visible = false
	if terminal_panel:
		terminal_panel.visible = false
	if top_bar:
		top_bar.visible = false
	if settings_menu:
		settings_menu.z_index = 100
		settings_menu.z_as_relative = false
		settings_menu.move_to_front()
		settings_menu.open_menu(0)

func _on_guide_pressed() -> void:
	_play_sfx("ui_click")
	if district_modal:
		district_modal.visible = false
	if terminal_panel:
		terminal_panel.visible = false
	if top_bar:
		top_bar.visible = false
	if settings_menu:
		settings_menu.z_index = 100
		settings_menu.z_as_relative = false
		settings_menu.move_to_front()
		settings_menu.open_menu(2)

func _on_testhub_pressed() -> void:
	_play_sfx("ui_click")
	_fade_out_music(func() -> void:
		print("[MENU] Opening Test Hub...")
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
	)

func _on_quit_pressed() -> void:
	_play_sfx("ui_click")
	print("[MENU] Quitting application...")
	get_tree().quit()
