extends CanvasLayer

# ThreatManager — Глобальная система розыска и полицейского преследования Краснограда (1-5 Звёзд)
# Управляет уровнем тревоги Синдиката MERIDIAN, сиренами, радиопереговорами копов,
# блокпостами, перехватчиками и логикой ухода от преследования.

signal wanted_level_changed(new_level: int)
signal pursuit_started()
signal pursuit_evaded()
signal police_radio_chatter(msg: String)

var wanted_level: int = 0
var heat: float = 0.0
const HEAT_PER_STAR: float = 100.0

var is_in_pursuit: bool = false
var evasion_timer: float = 0.0
var max_evasion_time: float = 12.0
var flash_timer: float = 0.0

# Аудио сирены
var siren_player: AudioStreamPlayer = null
var radio_chatter_timer: float = 0.0

# UI Элементы (HUD)
var threat_container: PanelContainer = null
var stars_label: Label = null
var evasion_status_label: Label = null
var police_scanner_banner: PanelContainer = null
var police_scanner_label: Label = null
var police_vignette: ColorRect = null

const POLICE_CHATTER_LINES: Array[String] = [
	"Диспетчер: Внимание всем постам! Замечен красный фургон «Кока-Коля»!",
	"Патруль-4: Подозреваемый превышает скорость и сбивает ограждения!",
	"Центр: Зафиксирован незаконный оборот натурального сиропа. Код 10-44!",
	"Перехватчик-2: Вижу нарушителя на шоссе! Запрашиваю санкцию на таран!",
	"Корпорация MERIDIAN: Задействовать тяжелый броневик Enforcer и блокировать мост!",
	"Штурмовик: Объект скрылся в промзоне. Прочесать контейнеры!",
	"Диспетчер: Всем бортам — не стрелять по цистернам, груз нужен целым!"
]

func _ready() -> void:
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_setup_audio()
	LogManager.info("ThreatManager (Система Розыска 1-5 Звезд) инициализирован.", "THREAT")

func _setup_audio() -> void:
	siren_player = AudioStreamPlayer.new()
	siren_player.name = "PoliceSirenPlayer"
	siren_player.volume_db = -8.0
	siren_player.bus = "Master"
	add_child(siren_player)

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		var sfx_lib = am.get("sfx_library")
		if sfx_lib is Dictionary and sfx_lib.has("police_siren"):
			siren_player.stream = sfx_lib["police_siren"]

func _build_ui() -> void:
	# 1. Красно-синяя мигающая виньетка по краям экрана
	police_vignette = ColorRect.new()
	police_vignette.name = "PoliceVignette"
	police_vignette.anchors_preset = Control.PRESET_FULL_RECT
	police_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	police_vignette.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(police_vignette)

	# 2. Виджет звёзд розыска (вверху справа под компасом)
	threat_container = PanelContainer.new()
	threat_container.name = "ThreatHUD"
	threat_container.anchors_preset = Control.PRESET_TOP_RIGHT
	threat_container.anchor_left = 1.0
	threat_container.anchor_right = 1.0
	threat_container.offset_left = -230.0
	threat_container.offset_right = -20.0
	threat_container.offset_top = 88.0
	threat_container.offset_bottom = 145.0
	threat_container.visible = false
	add_child(threat_container)

	var vbox := VBoxContainer.new()
	threat_container.add_child(vbox)

	stars_label = Label.new()
	stars_label.name = "StarsLabel"
	stars_label.text = "☆☆☆☆☆"
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.add_theme_font_size_override("font_size", 22)
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	vbox.add_child(stars_label)

	evasion_status_label = Label.new()
	evasion_status_label.name = "EvasionLabel"
	evasion_status_label.text = "РОЗЫСК СИНДИКАТА"
	evasion_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evasion_status_label.add_theme_font_size_override("font_size", 11)
	evasion_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(evasion_status_label)

	# 3. Баннер полицейского радио-сканера
	police_scanner_banner = PanelContainer.new()
	police_scanner_banner.name = "PoliceScannerBanner"
	police_scanner_banner.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	police_scanner_banner.anchor_left = 1.0
	police_scanner_banner.anchor_right = 1.0
	police_scanner_banner.anchor_top = 1.0
	police_scanner_banner.anchor_bottom = 1.0
	police_scanner_banner.offset_left = -440.0
	police_scanner_banner.offset_right = -20.0
	police_scanner_banner.offset_top = -140.0
	police_scanner_banner.offset_bottom = -85.0
	police_scanner_banner.visible = false
	add_child(police_scanner_banner)

	police_scanner_label = Label.new()
	police_scanner_label.name = "ScannerText"
	police_scanner_label.text = "🚨 [ПОЛИЦЕЙСКАЯ ВОЛНА MERIDIAN 148.8 МГц]"
	police_scanner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	police_scanner_label.add_theme_font_size_override("font_size", 12)
	police_scanner_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	police_scanner_banner.add_child(police_scanner_label)

func _process(delta: float) -> void:
	if wanted_level <= 0:
		if threat_container and threat_container.visible:
			threat_container.visible = false
		if police_vignette and police_vignette.color.a > 0.0:
			police_vignette.color = Color(0, 0, 0, 0)
		if siren_player and siren_player.playing:
			siren_player.stop()
		return

	# Активный розыск
	flash_timer += delta * 4.0
	var flash_on: bool = int(flash_timer) % 2 == 0

	# Мигание виньетки (красный/синий полицейский стробоскоп)
	if police_vignette:
		var flash_color: Color = Color(0.8, 0.1, 0.1, 0.15) if flash_on else Color(0.1, 0.3, 0.9, 0.15)
		police_vignette.color = flash_color

	# Логика ухода от погони
	if not is_in_pursuit:
		evasion_timer -= delta
		if evasion_status_label:
			evasion_status_label.text = "УХОД ИЗ ЗОНЫ: %02.0f СЕК" % maxf(0.0, evasion_timer)
			evasion_status_label.modulate = Color(0.3, 1.0, 0.4) if flash_on else Color(1.0, 1.0, 1.0)
		if evasion_timer <= 0.0:
			_drop_one_star()
	else:
		if evasion_status_label:
			evasion_status_label.text = "АКТИВНОЕ ПРЕСЛЕДОВАНИЕ"
			evasion_status_label.modulate = Color(1.0, 0.3, 0.3)

	# Полицейский радиосканер (периодические реплики копов)
	radio_chatter_timer -= delta
	if radio_chatter_timer <= 0.0:
		radio_chatter_timer = randf_range(7.0, 14.0)
		_trigger_random_chatter()

func _drop_one_star() -> void:
	if wanted_level > 1:
		set_wanted_level(wanted_level - 1)
		evasion_timer = max_evasion_time
		LogManager.info("[РОЗЫСК]: Уровень снижен до %d звезд." % wanted_level, "THREAT")
	else:
		clear_heat()
		pursuit_evaded.emit()
		LogManager.info("[РОЗЫСК]: Хвост сброшен! Преследование прекращено.", "THREAT")

func add_heat(amount: float) -> void:
	heat += amount
	var new_lvl := clampi(int(heat / HEAT_PER_STAR) + 1, 1, 5)
	if new_lvl != wanted_level:
		set_wanted_level(new_lvl)
	else:
		_refresh_stars_display()

func set_wanted_level(lvl: int) -> void:
	var old_lvl := wanted_level
	wanted_level = clampi(lvl, 0, 5)
	heat = float(wanted_level) * HEAT_PER_STAR

	if wanted_level > 0:
		is_in_pursuit = true
		evasion_timer = max_evasion_time
		if threat_container:
			threat_container.visible = true
		if siren_player and not siren_player.playing:
			siren_player.play()
		if wanted_level > old_lvl and has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "wanted_level_up")
			_trigger_random_chatter()
	else:
		clear_heat()

	_refresh_stars_display()
	wanted_level_changed.emit(wanted_level)

	if old_lvl == 0 and wanted_level > 0:
		pursuit_started.emit()

func clear_heat() -> void:
	wanted_level = 0
	heat = 0.0
	is_in_pursuit = false
	evasion_timer = 0.0
	if threat_container:
		threat_container.visible = false
	if police_scanner_banner:
		police_scanner_banner.visible = false
	if police_vignette:
		police_vignette.color = Color(0, 0, 0, 0)
	if siren_player and siren_player.playing:
		siren_player.stop()
	_refresh_stars_display()
	wanted_level_changed.emit(0)

func report_crime(crime_type: String, heat_amount: float = 35.0) -> void:
	LogManager.warn("[ПРЕСТУПЛЕНИЕ]: Зафиксировано нарушение: %s (+%.0f heat)" % [crime_type, heat_amount], "THREAT")
	add_heat(heat_amount)

func bribe_or_hack_clearance(cost: int = 250) -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var cur_cr: int = int(gm.get("credits"))
		if cur_cr < cost:
			LogManager.warn("Недостаточно кредитов для взлома полицейской базы (%d < %d)" % [cur_cr, cost], "THREAT")
			return false
		gm.call("add_credits", -cost)
	clear_heat()
	LogManager.info("[ВЗЛОМ]: Полицейские базы очищены! Розыск сброшен за %d КР." % cost, "THREAT")
	return true

func set_in_pursuit(pursuing: bool) -> void:
	if is_in_pursuit != pursuing:
		is_in_pursuit = pursuing
		if not is_in_pursuit:
			evasion_timer = max_evasion_time
			LogManager.info("[РОЗЫСК]: Копы потеряли визуальный контакт. Запущен таймер ухода: %.0f с" % evasion_timer, "THREAT")

func is_wanted() -> bool:
	return wanted_level > 0

func _trigger_random_chatter() -> void:
	if wanted_level <= 0:
		return
	var idx := randi() % POLICE_CHATTER_LINES.size()
	var line := POLICE_CHATTER_LINES[idx]
	if police_scanner_banner and police_scanner_label:
		police_scanner_label.text = "🚨 " + line
		police_scanner_banner.visible = true
	police_radio_chatter.emit(line)
	LogManager.info("[ПОЛИЦИЯ]: %s" % line, "THREAT")

func _refresh_stars_display() -> void:
	if not stars_label:
		return
	var text := ""
	for i in range(5):
		if i < wanted_level:
			text += "★ "
		else:
			text += "☆ "
	stars_label.text = text.strip_edges()
	match wanted_level:
		1: stars_label.modulate = Color(1.0, 0.9, 0.2)
		2: stars_label.modulate = Color(1.0, 0.65, 0.1)
		3: stars_label.modulate = Color(1.0, 0.4, 0.1)
		4: stars_label.modulate = Color(1.0, 0.2, 0.2)
		5: stars_label.modulate = Color(1.0, 0.05, 0.4)
		_: stars_label.modulate = Color(0.6, 0.6, 0.6)
