extends CanvasLayer

# CyberdeckManager — Кибер-КПК, Навигационный 3D-Компас и Радио-Виджет «Кока-Коля»
# Полноэкранный киберпанк-интерфейс [Tab / M], GPS-карта 7 районов, прокачка за кредиты,
# навигационный компас реального времени и анимированный музыкальный эквалайзер.

signal pda_opened()
signal pda_closed()
signal upgrade_purchased(upgrade_id: String)
signal contract_started(contract: Dictionary)
signal contract_completed(contract: Dictionary)

var is_pda_open: bool = false
var current_tab: int = 0
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var active_contract: Dictionary = {}

# База купленных улучшений (сохраняется в профиле игрока)
var purchased_upgrades: Dictionary = {
	"van_armor": false,
	"van_nitro": false,
	"van_engine": false,
	"player_suit": false,
	"drone_combat": false
}

# Каталог улучшений
const UPGRADE_CATALOG: Dictionary = {
	"van_armor": {
		"title": "Титановое Усиление Шасси",
		"desc": "Увеличивает прочность кузова фургона на +50% и снижает урон от столкновений.",
		"cost": 300,
		"category": "Транспорт"
	},
	"van_nitro": {
		"title": "Форсированный Сиропный Инжектор",
		"desc": "Увеличивает объем бака нитро на +50% и ускоряет его автоматическую регенерацию.",
		"cost": 350,
		"category": "Транспорт"
	},
	"van_engine": {
		"title": "Турбо-Компрессор «Гипердрайв»",
		"desc": "Повышает крутящий момент мотора на +30%, обеспечивая резкий старт и ускорение.",
		"cost": 400,
		"category": "Транспорт"
	},
	"player_suit": {
		"title": "Тактический Нано-Костюм Коли",
		"desc": "Повышает максимальный запас здоровья Коли до 150 HP и ускоряет спринт.",
		"cost": 250,
		"category": "Персонаж"
	},
	"drone_combat": {
		"title": "Фазовый Коллиматор BUBBLE",
		"desc": "Увеличивает дальность лазерной турели дрона на +50% и удваивает урон по турелям корпорации.",
		"cost": 300,
		"category": "Дрон"
	}
}

# 7 Районов Краснограда
const DISTRICT_INTEL: Array[Dictionary] = [
	{
		"id": "old_district",
		"name": "Старый Район (Трущобы)",
		"desc": "Колыбель восстания. Узкие неоновые улочки, конспиративный гараж Коли и подпольный бар Сопротивления.",
		"danger": "★☆☆",
		"reward": "250 КР"
	},
	{
		"id": "red_line_plant",
		"name": "Завод Красной Линии",
		"desc": "Огромный промышленный комплекс по розливу синтетической колы. Конвейеры, бочки и патрули охраны.",
		"danger": "★★☆",
		"reward": "400 КР"
	},
	{
		"id": "city_highway",
		"name": "Скоростное Шоссе и Блокпост",
		"desc": "Четырехполосная автомагистраль через реку. Укрепленный КПП №2 корпорации и главная вещательная телебашня.",
		"danger": "★★☆",
		"reward": "500 КР"
	},
	{
		"id": "neon_boulevard",
		"name": "Неоновый Бульвар (Даунтаун)",
		"desc": "Сияющие небоскребы, двухуровневая эстакада, гигантские голо-билборды и центральная Неон-Плаза.",
		"danger": "★★☆",
		"reward": "450 КР"
	},
	{
		"id": "logistics_hub",
		"name": "Логистический Хаб",
		"desc": "Закрытый складской терминал MERIDIAN с контейнерным лабиринтом, портальными кранами и лазерной сеткой.",
		"danger": "★★★",
		"reward": "600 КР"
	},
	{
		"id": "underground_metro",
		"name": "Подземный Метрополитен",
		"desc": "Заброшенная станция «Проспект Революции». Тоннели, состав поезда, тайный сервер данных и схрон повстанцев.",
		"danger": "★★☆",
		"reward": "550 КР"
	},
	{
		"id": "garage",
		"name": "Гараж Коли (Испытательный Полигон)",
		"desc": "База для калибровки физики, тестирования инструментов, дрона BUBBLE и настройки фургона.",
		"danger": "☆☆☆",
		"reward": "0 КР"
	}
]

# Кодекс и Досье
const CODEX_ENTRIES: Array[Dictionary] = [
	{
		"title": "Николай «Коля» Сиропов",
		"tag": "Главный Герой / Водитель-Бунтарь",
		"text": "Бывший лучший курьер корпорации MERIDIAN, уволенный за отказ разбавлять натуральную газировку техническим дейтерием. Отлично водит прокачанный красный фургон, метко стреляет и знает каждый закоулок Краснограда."
	},
	{
		"title": "Александра «Саша V» Воронова",
		"tag": "Координатор / Кибер-Хакер",
		"text": "Мозг подземного движения «Свободный Красноград». Взламывает системы видеонаблюдения, снабжает Колю разведданными по рации и ведет эфир пиратских радиостанций."
	},
	{
		"title": "Корпорация MERIDIAN",
		"tag": "Антагонисты / Монополия Синтетики",
		"text": "Транснациональный синдикат, захвативший контроль над чистой водой и напитками Краснограда. Использует автоматизированных дронов, ЧОП в тяжелой броне и налоги на сахар для подавления населения."
	},
	{
		"title": "Секретная Формула «Кока-Коля»",
		"tag": "Артефакт / Концентрат Свободы",
		"text": "Натуральный рецепт газировки на основе экстракта орехов колы, карамели и родниковой воды. Не вызывает привыкания, восстанавливает здоровье и дает невероятный прилив сил и драйва."
	},
	{
		"title": "Дрон BUBBLE v2.4",
		"tag": "Автономный Напарник",
		"text": "Служебный дрон-уборщик, перепрошитый Сашей V. Оборудован сканером уязвимостей, лазерным резаком и генератором защитных мыльных пузырей."
	}
]

# Ссылки на элементы UI
var pda_root: Control = null
var tab_container: TabContainer = null
var credits_label: Label = null

# Навигационный Компас
var compass_container: PanelContainer = null
var compass_heading_label: Label = null
var compass_poi_label: Label = null

# Радио-баннер
var radio_banner: PanelContainer = null
var radio_station_label: Label = null
var radio_track_label: Label = null
var radio_bars_label: Label = null
var radio_banner_timer: float = 0.0

var pda_overlay: Control:
	get: return pda_root

var banner_title: Label:
	get: return radio_station_label

var banner_track: Label:
	get: return radio_track_label

var active_tab_idx: int:
	get: return tab_container.current_tab if tab_container else current_tab

var credits: int:
	get:
		var gm: Node = get_node_or_null("/root/GameManager")
		return int(gm.get("credits")) if gm else 500
	set(val):
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			gm.set("credits", val)

func switch_tab(idx: int) -> void:
	if tab_container and idx >= 0 and idx < tab_container.get_tab_count():
		tab_container.current_tab = idx
		current_tab = idx

func purchase_upgrade(up_id: String) -> bool:
	if not UPGRADE_CATALOG.has(up_id):
		return false
	if purchased_upgrades.get(up_id, false):
		return false
	var up: Dictionary = UPGRADE_CATALOG[up_id]
	var cost: int = up["cost"]
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var cur_cr: int = int(gm.get("credits"))
		if cur_cr < cost:
			_play_sfx("alarm")
			return false
		gm.call("add_credits", -cost)
		if credits_label:
			credits_label.text = "Баланс: %d КР  " % int(gm.get("credits"))
	purchased_upgrades[up_id] = true
	_play_sfx("upgrade_purchase")
	upgrade_purchased.emit(up_id)
	_apply_upgrades_to_active_entities()
	return true

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	LogManager.info("CyberdeckManager (КПК и Навигация) инициализирован.", "CORE")

func _build_ui() -> void:
	# 1. Верхний навигационный компас
	_build_compass_ui()

	# 2. Анимированный баннер радио
	_build_radio_banner_ui()

	# 3. Главное модальное окно Кибер-КПК
	_build_pda_ui()

func _build_compass_ui() -> void:
	compass_container = PanelContainer.new()
	compass_container.name = "HUDCompass"
	compass_container.anchors_preset = Control.PRESET_CENTER_TOP
	compass_container.anchor_left = 0.5
	compass_container.anchor_right = 0.5
	compass_container.anchor_top = 0.0
	compass_container.anchor_bottom = 0.0
	compass_container.offset_left = -260.0
	compass_container.offset_right = 260.0
	compass_container.offset_top = 10.0
	compass_container.offset_bottom = 58.0
	add_child(compass_container)

	var vbox := VBoxContainer.new()
	compass_container.add_child(vbox)

	compass_heading_label = Label.new()
	compass_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_heading_label.text = "180° [ ЮГ ]"
	compass_heading_label.add_theme_font_size_override("font_size", 14)
	compass_heading_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	vbox.add_child(compass_heading_label)

	compass_poi_label = Label.new()
	compass_poi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_poi_label.text = "🎯 Задание: Поиск... | 🚗 Фургон: Поиск..."
	compass_poi_label.add_theme_font_size_override("font_size", 11)
	compass_poi_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(compass_poi_label)

func _build_radio_banner_ui() -> void:
	radio_banner = PanelContainer.new()
	radio_banner.name = "RadioBanner"
	radio_banner.anchors_preset = Control.PRESET_TOP_RIGHT
	radio_banner.anchor_left = 1.0
	radio_banner.anchor_right = 1.0
	radio_banner.anchor_top = 0.0
	radio_banner.anchor_bottom = 0.0
	radio_banner.offset_left = -340.0
	radio_banner.offset_right = -20.0
	radio_banner.offset_top = 14.0
	radio_banner.offset_bottom = 80.0
	radio_banner.visible = false
	add_child(radio_banner)

	var vbox := VBoxContainer.new()
	radio_banner.add_child(vbox)

	radio_station_label = Label.new()
	radio_station_label.text = "📻 РАДИО КРАСНОГРАД — 98.4 FM"
	radio_station_label.add_theme_font_size_override("font_size", 13)
	radio_station_label.add_theme_color_override("font_color", Color(0.1, 0.9, 1.0))
	vbox.add_child(radio_station_label)

	radio_track_label = Label.new()
	radio_track_label.text = "▶ Эфир: Synthwave Neon Run"
	radio_track_label.add_theme_font_size_override("font_size", 11)
	radio_track_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(radio_track_label)

	radio_bars_label = Label.new()
	radio_bars_label.text = "ılı.lıllılı.ıllı.ılı.lı"
	radio_bars_label.add_theme_font_size_override("font_size", 12)
	radio_bars_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	vbox.add_child(radio_bars_label)

func _build_pda_ui() -> void:
	pda_root = Control.new()
	pda_root.name = "CyberPDARoot"
	pda_root.anchors_preset = Control.PRESET_FULL_RECT
	pda_root.visible = false
	add_child(pda_root)

	var dim_bg := ColorRect.new()
	dim_bg.anchors_preset = Control.PRESET_FULL_RECT
	dim_bg.color = Color(0.02, 0.04, 0.08, 0.85)
	pda_root.add_child(dim_bg)

	var frame := PanelContainer.new()
	frame.anchors_preset = Control.PRESET_CENTER
	frame.offset_left = -520.0
	frame.offset_right = 520.0
	frame.offset_top = -320.0
	frame.offset_bottom = 320.0
	pda_root.add_child(frame)

	var main_vbox := VBoxContainer.new()
	frame.add_child(main_vbox)

	var top_bar := HBoxContainer.new()
	main_vbox.add_child(top_bar)

	var pda_title := Label.new()
	pda_title.text = " ⚡ КИБЕР-КПК КОЛИ // CYBERDECK OS v4.2"
	pda_title.add_theme_font_size_override("font_size", 18)
	pda_title.add_theme_color_override("font_color", Color(0.1, 0.9, 1.0))
	top_bar.add_child(pda_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	credits_label = Label.new()
	var init_credits: int = 250
	if has_node("/root/GameManager"):
		init_credits = int(get_node("/root/GameManager").get("credits"))
	credits_label.text = "Баланс: %d КР  " % init_credits
	credits_label.add_theme_font_size_override("font_size", 16)
	credits_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	top_bar.add_child(credits_label)

	var close_btn := Button.new()
	close_btn.text = " [X] Закрыть [Tab/M] "
	close_btn.pressed.connect(close_pda)
	top_bar.add_child(close_btn)

	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)

	_build_map_tab()
	_build_quests_tab()
	_build_upgrades_tab()
	_build_codex_tab()

func _build_map_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Карта"
	tab_container.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var header := Label.new()
	header.text = "\n  ОТКРЫТЫЕ РАЙОНЫ КРАСНОГРАДА (ВЫБЕРИТЕ ТОЧКУ ДЛЯ ПЕРЕХОДА):\n"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	list.add_child(header)

	var current_dist := "old_district"
	if has_node("/root/GameManager"):
		current_dist = str(get_node("/root/GameManager").get("current_district"))

	for d in DISTRICT_INTEL:
		var item_panel := PanelContainer.new()
		list.add_child(item_panel)

		var hbox := HBoxContainer.new()
		item_panel.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var is_cur: bool = (current_dist == d["id"])
		var title := Label.new()
		title.text = "%s %s" % [d["name"], " [ВЫ ЗДЕСЬ]" if is_cur else ""]
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4) if is_cur else Color(1.0, 1.0, 1.0))
		info_vbox.add_child(title)

		var desc := Label.new()
		desc.text = "%s\nОпасность: %s | Награда за район: %s" % [d["desc"], d["danger"], d["reward"]]
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(desc)

		var travel_btn := Button.new()
		travel_btn.text = "Перейти в район" if not is_cur else "Текущий район"
		travel_btn.disabled = is_cur
		var target_id: String = d["id"]
		travel_btn.pressed.connect(func() -> void:
			_on_fast_travel_pressed(target_id)
		)
		hbox.add_child(travel_btn)

func _build_quests_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Задания"
	tab_container.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var cur_dist := "old_district"
	if has_node("/root/GameManager"):
		cur_dist = str(get_node("/root/GameManager").get("current_district"))

	var q_title := Label.new()
	q_title.text = "\n  ТЕКУЩЕЕ АКТИВНОЕ ЗАДАНИЕ РАЙОНА [%s]:\n" % cur_dist.to_upper()
	q_title.add_theme_font_size_override("font_size", 15)
	q_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	list.add_child(q_title)

	var q_box := PanelContainer.new()
	list.add_child(q_box)

	var q_vbox := VBoxContainer.new()
	q_box.add_child(q_vbox)

	var q_name := Label.new()
	q_name.text = "Миссия Сопротивления: «Операция Кока-Коля»"
	q_name.add_theme_font_size_override("font_size", 16)
	q_name.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	q_vbox.add_child(q_name)

	var obj1 := Label.new()
	obj1.text = "  [✓] Проникнуть в район и завести двигатель фургона доставки"
	obj1.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	q_vbox.add_child(obj1)

	var obj2 := Label.new()
	obj2.text = "  [✓] Просканировать дроном BUBBLE ключевые точки интереса"
	obj2.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	q_vbox.add_child(obj2)

	var obj3 := Label.new()
	obj3.text = "  [ ] Завершить доставку натурального концентрата и взломать систему связи"
	obj3.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	q_vbox.add_child(obj3)

	# Диспетчер «Красноград Экспресс»
	var disp_title := Label.new()
	disp_title.text = "\n  📦 СЛУЖБА СРОЧНОЙ ДОСТАВКИ «КРАСНОГРАД ЭКСПРЕСС»:\n"
	disp_title.add_theme_font_size_override("font_size", 14)
	disp_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	list.add_child(disp_title)

	var disp_panel := PanelContainer.new()
	list.add_child(disp_panel)

	var disp_vbox := VBoxContainer.new()
	disp_panel.add_child(disp_vbox)

	var contract_info := Label.new()
	contract_info.name = "ContractInfoLabel"
	if active_contract.is_empty():
		contract_info.text = "Свободных контрактов в работе нет. Запросите рейс у диспетчера."
		contract_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	else:
		contract_info.text = "АКТИВНЫЙ РЕЙС: %s\n%s\nМаршрут: %s → %s | Награда: %d КР" % [
			active_contract["cargo"], active_contract["desc"], active_contract["from_name"], active_contract["to_name"], active_contract["reward"]
		]
		contract_info.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	contract_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contract_info.add_theme_font_size_override("font_size", 12)
	disp_vbox.add_child(contract_info)

	var btn_hbox := HBoxContainer.new()
	disp_vbox.add_child(btn_hbox)

	var new_contract_btn := Button.new()
	new_contract_btn.text = " [📦] ВЗЯТЬ СРОЧНЫЙ КОНТРАКТ ДОСТАВКИ "
	new_contract_btn.pressed.connect(func() -> void:
		var c := generate_random_contract()
		contract_info.text = "АКТИВНЫЙ РЕЙС: %s\n%s\nМаршрут: %s → %s | Награда: %d КР" % [
			c["cargo"], c["desc"], c["from_name"], c["to_name"], c["reward"]
		]
		contract_info.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	)
	btn_hbox.add_child(new_contract_btn)

	var complete_btn := Button.new()
	complete_btn.text = " [✓] СДАТЬ ГРУЗ (ЗАВЕРШИТЬ) "
	complete_btn.pressed.connect(func() -> void:
		if complete_active_contract():
			contract_info.text = "Груз успешно доставлен! Заказ закрыт, награда начислена."
			contract_info.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	)
	btn_hbox.add_child(complete_btn)

	var completed_count := 0
	if has_node("/root/GameManager"):
		var cm = get_node("/root/GameManager").get("completed_missions")
		if cm is Array:
			completed_count = cm.size()

	var arch_title := Label.new()
	arch_title.text = "\n  АРХИВ ЗАВЕРШЕННЫХ ОПЕРАЦИЙ (%d):\n" % completed_count
	arch_title.add_theme_font_size_override("font_size", 14)
	list.add_child(arch_title)

	if has_node("/root/GameManager"):
		var cm = get_node("/root/GameManager").get("completed_missions")
		if cm is Array and not cm.is_empty():
			for m in cm:
				var l := Label.new()
				l.text = "  ★ Завершена миссия: %s (+500 КР, +25 Репутация)" % str(m)
				l.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
				list.add_child(l)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "  Пока нет архивных миссий. Выполняйте задачи в районах города!"
			empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			list.add_child(empty_lbl)

func _build_upgrades_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Мастерская"
	tab_container.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var header := Label.new()
	header.text = "\n  УЛУЧШЕНИЕ ФУРГОНА, ЭКЗО-КОСТЮМА И ДРОНА ЗА КРЕДИТЫ:\n"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	list.add_child(header)

	for up_id: String in UPGRADE_CATALOG:
		var up: Dictionary = UPGRADE_CATALOG[up_id]
		var is_bought: bool = purchased_upgrades.get(up_id, false)

		var up_panel := PanelContainer.new()
		list.add_child(up_panel)

		var hbox := HBoxContainer.new()
		up_panel.add_child(hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_vbox)

		var title := Label.new()
		title.text = "[%s] %s" % [up["category"], up["title"]]
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0) if not is_bought else Color(0.4, 1.0, 0.4))
		info_vbox.add_child(title)

		var desc := Label.new()
		desc.text = "%s\nСтоимость: %d КР" % [up["desc"], up["cost"]]
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(desc)

		var buy_btn := Button.new()
		buy_btn.text = " УСТАНОВЛЕНО [✓] " if is_bought else " КУПИТЬ (%d КР) " % up["cost"]
		buy_btn.disabled = is_bought
		var id_capture: String = up_id
		buy_btn.pressed.connect(func() -> void:
			_purchase_upgrade(id_capture, buy_btn)
		)
		hbox.add_child(buy_btn)

func _build_codex_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Кодекс"
	tab_container.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var header := Label.new()
	header.text = "\n  АРХИВ ДАННЫХ И ДОСЬЕ СОПРОТИВЛЕНИЯ:\n"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	list.add_child(header)

	for c in CODEX_ENTRIES:
		var card := PanelContainer.new()
		list.add_child(card)

		var cvbox := VBoxContainer.new()
		card.add_child(cvbox)

		var title := Label.new()
		title.text = "📁 %s [%s]" % [c["title"], c["tag"]]
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
		cvbox.add_child(title)

		var body := Label.new()
		body.text = c["text"] + "\n"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 12)
		body.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		cvbox.add_child(body)

func _purchase_upgrade(up_id: String, btn: Button) -> void:
	if not UPGRADE_CATALOG.has(up_id):
		return
	var up: Dictionary = UPGRADE_CATALOG[up_id]
	var cost: int = up["cost"]

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var cur_cr: int = int(gm.get("credits"))
		if cur_cr < cost:
			_play_sfx("alarm")
			LogManager.warn("Недостаточно кредитов для покупки %s (Требуется: %d КР)" % [up["title"], cost], "ECONOMY")
			return
		gm.call("add_credits", -cost)
		if credits_label:
			credits_label.text = "Баланс: %d КР  " % int(gm.get("credits"))

	purchased_upgrades[up_id] = true
	btn.text = " УСТАНОВЛЕНО [✓] "
	btn.disabled = true

	_play_sfx("upgrade_purchase")
	LogManager.info("[АПГРЕЙД]: Приобретено улучшение «%s»" % up["title"], "CYBERDECK")
	upgrade_purchased.emit(up_id)
	_apply_upgrades_to_active_entities()

func _apply_upgrades_to_active_entities() -> void:
	var van = get_tree().get_first_node_in_group("vehicle")
	if is_instance_valid(van) and van.has_method("apply_cyberdeck_upgrades"):
		van.call("apply_cyberdeck_upgrades", purchased_upgrades)

	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("apply_cyberdeck_upgrades"):
		player.call("apply_cyberdeck_upgrades", purchased_upgrades)

func _on_fast_travel_pressed(target_district: String) -> void:
	close_pda()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.call("change_district", target_district, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_M:
			toggle_pda()
		elif is_pda_open and event.keycode == KEY_ESCAPE:
			close_pda()

func toggle_pda() -> void:
	if is_pda_open:
		close_pda()
	else:
		open_pda()

func open_pda() -> void:
	if is_pda_open:
		return
	is_pda_open = true
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pda_root.visible = true

	var gm: Node = get_node_or_null("/root/GameManager")
	if credits_label and gm:
		credits_label.text = "Баланс: %d КР  " % int(gm.get("credits"))

	_play_sfx("ui_pda_open")
	pda_opened.emit()

func close_pda() -> void:
	if not is_pda_open:
		return
	is_pda_open = false
	pda_root.visible = false
	Input.mouse_mode = previous_mouse_mode
	_play_sfx("ui_pda_close")
	pda_closed.emit()

func show_radio_banner(station: String, track: String) -> void:
	if not radio_banner:
		return
	radio_station_label.text = "📻 " + station
	radio_track_label.text = "▶ Сейчас в эфире: " + track
	radio_banner.visible = true
	radio_banner_timer = 4.0

func _process(delta: float) -> void:
	if radio_banner and radio_banner.visible:
		radio_banner_timer -= delta
		var bars := ""
		for i in range(12):
			var r := randf()
			if r < 0.25: bars += "."
			elif r < 0.5: bars += "l"
			elif r < 0.75: bars += "I"
			else: bars += "█"
		radio_bars_label.text = bars
		if radio_banner_timer <= 0.0:
			radio_banner.visible = false

	_update_compass()

func _update_compass() -> void:
	if not compass_container:
		return

	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var fwd := -cam.global_transform.basis.z
	var angle_deg := fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)

	var dir_str := "СЕВЕР"
	if angle_deg >= 337.5 or angle_deg < 22.5: dir_str = "С [N]"
	elif angle_deg < 67.5: dir_str = "СВ [NE]"
	elif angle_deg < 112.5: dir_str = "В [E]"
	elif angle_deg < 157.5: dir_str = "ЮВ [SE]"
	elif angle_deg < 202.5: dir_str = "Ю [S]"
	elif angle_deg < 247.5: dir_str = "ЮЗ [SW]"
	elif angle_deg < 292.5: dir_str = "З [W]"
	else: dir_str = "СЗ [NW]"

	compass_heading_label.text = "%03d°  [ %s ]" % [int(angle_deg), dir_str]

	var van = get_tree().get_first_node_in_group("vehicle")
	var van_dist_str := "В машине"
	if is_instance_valid(van):
		var d := cam.global_position.distance_to(van.global_position)
		if d > 4.0:
			van_dist_str = "%d м" % int(d)

	var drone = get_tree().get_first_node_in_group("bubble_drone")
	var drone_dist_str := "Рядом"
	if is_instance_valid(drone):
		var d2 := cam.global_position.distance_to(drone.global_position)
		if d2 > 3.0:
			drone_dist_str = "%d м" % int(d2)

	compass_poi_label.text = "🚗 Фургон: %s   |   🤖 Дрон BUBBLE: %s" % [van_dist_str, drone_dist_str]

const CONTRACT_CARGO_TYPES: Array[Dictionary] = [
	{
		"type": "Хрупкий Концентрат",
		"desc": "Сверхчистый карамельный сироп. Требует осторожной езды без сильных столкновений.",
		"reward": 650,
		"threat": 0.0
	},
	{
		"type": "Экспресс-Доставка",
		"desc": "Срочный заказ для подпольного штаба. Бонус за быстрое прибытие.",
		"reward": 750,
		"threat": 15.0
	},
	{
		"type": "Контрабандная Партия",
		"desc": "Секретный рецепт Кока-Коли! Охота Синдиката обеспечена (+розыск).",
		"reward": 1200,
		"threat": 60.0
	},
	{
		"type": "Стандартная Доставка",
		"desc": "Регулярный рейс с ящиками газировки по торговым точкам.",
		"reward": 450,
		"threat": 0.0
	}
]

func generate_random_contract() -> Dictionary:
	var districts: Array[String] = ["old_district", "city_highway", "red_line_plant", "neon_boulevard", "logistics_hub", "underground_metro"]
	var from_idx := randi() % districts.size()
	var to_idx := (from_idx + 1 + (randi() % (districts.size() - 1))) % districts.size()

	var cargo_cfg: Dictionary = CONTRACT_CARGO_TYPES[randi() % CONTRACT_CARGO_TYPES.size()]
	var from_id: String = districts[from_idx]
	var to_id: String = districts[to_idx]

	var from_name := from_id
	var to_name := to_id
	for d in DISTRICT_INTEL:
		if d["id"] == from_id: from_name = d["name"]
		if d["id"] == to_id: to_name = d["name"]

	var contract := {
		"id": "contract_%d" % (Time.get_ticks_msec()),
		"title": "%s: %s → %s" % [cargo_cfg["type"], from_name, to_name],
		"cargo": cargo_cfg["type"],
		"desc": cargo_cfg["desc"],
		"from_district": from_id,
		"from_name": from_name,
		"to_district": to_id,
		"to_name": to_name,
		"reward": cargo_cfg["reward"],
		"threat": cargo_cfg["threat"],
		"is_completed": false
	}
	active_contract = contract

	if cargo_cfg["threat"] > 0.0 and has_node("/root/ThreatManager"):
		var tm: Node = get_node("/root/ThreatManager")
		tm.call("report_crime", "Перевозка контрабандного концентрата", cargo_cfg["threat"])

	contract_started.emit(contract)
	show_radio_banner("ДИСПЕТЧЕР", "Принят заказ: %s (+%d КР)" % [cargo_cfg["type"], cargo_cfg["reward"]])
	LogManager.info("[КОНТРАКТ]: Взят заказ «%s» (+%d КР)" % [contract["title"], contract["reward"]], "CYBERDECK")
	return contract

func complete_active_contract() -> bool:
	if active_contract.is_empty() or active_contract.get("is_completed", false):
		return false
	active_contract["is_completed"] = true
	var reward: int = int(active_contract.get("reward", 500))
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.call("add_credits", reward)
		gm.call("add_reputation", 20)
	show_radio_banner("ДИСПЕТЧЕР", "Контракт успешно выполнен! (+%d КР)" % reward)
	_play_sfx("upgrade_purchase")
	contract_completed.emit(active_contract)
	LogManager.info("[КОНТРАКТ]: Контракт выполнен! Начислено %d КР." % reward, "CYBERDECK")
	return true

func _play_sfx(sfx_name: String) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", sfx_name)
