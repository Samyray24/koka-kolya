class_name LoadingScreen
extends Control

# LoadingScreen — Киберпанк экран асинхронной загрузки уровней Краснограда
# Предотвращает зависания при переходе между районами, плавно загружая сцены через ResourceLoader (фоновый поток).
# Отображает анимированный неоновый прогресс-бар, статус нейросети, карточку района и полезные советы.

@onready var progress_bar: ProgressBar = get_node_or_null("Margin/VBox/BottomBar/Margin/VBox/ProgressBar")
@onready var label_status: Label = get_node_or_null("Margin/VBox/BottomBar/Margin/VBox/HBoxStatus/LabelStatus")
@onready var label_percent: Label = get_node_or_null("Margin/VBox/BottomBar/Margin/VBox/HBoxStatus/LabelPercent")
@onready var label_tip: Label = get_node_or_null("Margin/VBox/BottomBar/Margin/VBox/LabelTip")
@onready var label_district_title: Label = get_node_or_null("Margin/VBox/CenterContent/DistrictCard/Margin/VBox/LabelTitle")
@onready var label_district_desc: Label = get_node_or_null("Margin/VBox/CenterContent/DistrictCard/Margin/VBox/LabelDesc")
@onready var label_danger: Label = get_node_or_null("Margin/VBox/CenterContent/DistrictCard/Margin/VBox/LabelDanger")
@onready var label_sector: Label = get_node_or_null("Margin/VBox/CenterContent/DistrictCard/Margin/VBox/LabelSector")
@onready var spinner_icon: Control = get_node_or_null("Margin/VBox/CenterContent/SpinnerContainer/SpinnerIcon")
@onready var fade_overlay: ColorRect = get_node_or_null("FadeOverlay")

var target_scene_path: String = ""
var target_district_id: String = ""
var load_progress: Array = []
var is_loading: bool = false
var elapsed_time: float = 0.0
var min_display_time: float = 0.6
var tip_timer: float = 0.0
var current_tip_idx: int = 0

const TIPS: Array[String] = [
	"💡 СОВЕТ: Взламывайте терминалы и турели Синдиката клавишей [4] с помощью кибердеки.",
	"🥤 ИНФО: Автоматы «Кока-Коля» восполняют здоровье и дают мощный буст к выносливости.",
	"🚚 СОВЕТ: Грузовой фургон Коли легко таранит лёгкие патрульные автомобили — держите скорость!",
	"🕵️ ИНФО: В тёмных переулках ищите скрытые тайники Сопротивления с кредитами и чертежами.",
	"🤖 СОВЕТ: Дрон BUBBLE автоматически сканирует местность на наличие врагов и полезных ресурсов.",
	"📻 ИНФО: Переключайте радиостанции через КПК [Tab], чтобы слушать подпольное «Радио Свободный Коля».",
	"🎯 СОВЕТ: Попадание в колёса патрульной машины моментально выводит её из погони.",
	"⚡ ИНФО: Уровень розыска снижается, если оторваться от патрулей и переждать в гараже."
]

const DISTRICT_INFO: Dictionary = {
	"old_district": {
		"title": "СТАРЫЙ РАЙОН (ТРУЩОБЫ КРАСНОГРАДА)",
		"desc": "Конспиративный гараж Коли, улицы трущоб и Складской терминал №4 Синдиката MERIDIAN.",
		"danger": "ОПАСНОСТЬ: ★☆☆ (НИЗКАЯ)",
		"sector": "СЕКТОР: 04-A // СТАТУС СЕТИ: ПЕРЕХВАЧЕНА СОПРОТИВЛЕНИЕМ"
	},
	"city_highway": {
		"title": "СКОРОСТНОЕ ШОССЕ КРАСНОГРАДА",
		"desc": "Скоростная 4-полосная автомагистраль, КПП №2 Синдиката и главная вещательная телебашня.",
		"danger": "ОПАСНОСТЬ: ★★☆ (СРЕДНЯЯ)",
		"sector": "СЕКТОР: 02-HW // СТАТУС СЕТИ: БЛОКАДА ПАТРУЛЕЙ"
	},
	"neon_boulevard": {
		"title": "НЕОНОВЫЙ БУЛЬВАР (ДАУНТАУН)",
		"desc": "Небоскрёбы, двухуровневая эстакада, автоматы с колой, киоски и Неон-Плаза.",
		"danger": "ОПАСНОСТЬ: ★★☆ (СРЕДНЯЯ)",
		"sector": "СЕКТОР: 01-DT // СТАТУС СЕТИ: ПОД НАДЗОРОМ MERIDIAN"
	},
	"red_line_plant": {
		"title": "ЗАВОД «КРАСНАЯ ЛИНИЯ»",
		"desc": "Огромный заводской комплекс по розливу газировки, автоматизированная диспетчерская и сиропная башня.",
		"danger": "ОПАСНОСТЬ: ★★☆ (СРЕДНЯЯ)",
		"sector": "СЕКТОР: 03-IND // СТАТУС СЕТИ: АВТОМАТИЗИРОВАННЫЙ КОМПЛЕКС"
	},
	"logistics_hub": {
		"title": "ЛОГИСТИЧЕСКИЙ ХАБ MERIDIAN",
		"desc": "Складской грузовой терминал с контейнерами, кранами, лазерной охраной и фурами.",
		"danger": "ОПАСНОСТЬ: ★★★ (ВЫСОКАЯ)",
		"sector": "СЕКТОР: 05-LOG // СТАТУС СЕТИ: МАКСИМАЛЬНАЯ ОХРАНА"
	},
	"underground_metro": {
		"title": "ПОДЗЕМНЫЙ МЕТРОПОЛИТЕН",
		"desc": "Станция «Проспект Революции», туннели, стрелки, рельсы и партизанский схрон.",
		"danger": "ОПАСНОСТЬ: ★★☆ (СРЕДНЯЯ)",
		"sector": "СЕКТОР: 00-SUB // СТАТУС СЕТИ: АВТОНОМНЫЙ УЗЕЛ"
	},
	"citadel_penthouse": {
		"title": "ПЕНТХАУС ЦИТАДЕЛИ",
		"desc": "Штаб-квартира Синдиката MERIDIAN на высоте 100 метров, элитная охрана и главный сервер.",
		"danger": "ОПАСНОСТЬ: ★★★ (ЭКСТРЕМАЛЬНАЯ)",
		"sector": "СЕКТОР: 07-HQ // СТАТУС СЕТИ: ЦЕНТРАЛЬНОЕ ЯДРО СИНДИКАТА"
	}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if target_scene_path.is_empty() and has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		target_district_id = str(gm.get("pending_district_id"))
		if target_district_id.is_empty():
			target_district_id = str(gm.get("current_district"))
		var scenes_dict: Dictionary = gm.get("DISTRICT_SCENES") if "DISTRICT_SCENES" in gm else {}
		if scenes_dict.has(target_district_id):
			target_scene_path = scenes_dict[target_district_id]

	if target_scene_path.is_empty():
		target_scene_path = "res://scenes/levels/old_district.tscn"
		target_district_id = "old_district"

	_setup_district_info()
	_update_tip()
	_start_background_loading()

func _setup_district_info() -> void:
	var info: Dictionary = DISTRICT_INFO.get(target_district_id, {
		"title": "ПЕРЕХОД В РАЙОН: %s" % target_district_id.to_upper(),
		"desc": "Загрузка сектора Краснограда...",
		"danger": "ОПАСНОСТЬ: НЕИЗВЕСТНО",
		"sector": "СЕКТОР: -- // СТАТУС СЕТИ: ПОДКЛЮЧЕНИЕ"
	})
	
	if label_district_title:
		label_district_title.text = info["title"]
	if label_district_desc:
		label_district_desc.text = info["desc"]
	if label_danger:
		label_danger.text = info["danger"]
	if label_sector:
		label_sector.text = info["sector"]

func _start_background_loading() -> void:
	is_loading = true
	elapsed_time = 0.0
	
	if progress_bar:
		progress_bar.value = 0.0
	if label_percent:
		label_percent.text = "0%"
	if label_status:
		label_status.text = "СИНХРОНИЗАЦИЯ СЕКТОРА..."
		
	var err := ResourceLoader.load_threaded_request(target_scene_path)
	if err != OK:
		push_error("LoadingScreen: Ошибка запуска load_threaded_request для %s: %d" % [target_scene_path, err])
		get_tree().change_scene_to_file(target_scene_path)

func _process(delta: float) -> void:
	elapsed_time += delta
	tip_timer += delta
	
	if tip_timer >= 3.0:
		tip_timer = 0.0
		current_tip_idx = (current_tip_idx + 1) % TIPS.size()
		_update_tip()

	if spinner_icon:
		spinner_icon.rotation += delta * 3.5

	if not is_loading:
		return

	load_progress.clear()
	var status := ResourceLoader.load_threaded_get_status(target_scene_path, load_progress)
	
	var progress_val: float = 0.0
	if load_progress.size() > 0:
		progress_val = float(load_progress[0]) * 100.0
	
	if progress_bar:
		progress_bar.value = maxf(progress_bar.value, progress_val)
	if label_percent:
		label_percent.text = "%d%%" % int(progress_bar.value if progress_bar else progress_val)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress_bar and progress_bar.value > 50.0:
				if label_status:
					label_status.text = "КОМПИЛЯЦИЯ ШЕЙДЕРОВ И ОКРУЖЕНИЯ..."
			else:
				if label_status:
					label_status.text = "ДЕКОДИРОВАНИЕ ТЕКСТУР И ГЕОМЕТРИИ..."
					
		ResourceLoader.THREAD_LOAD_LOADED:
			if elapsed_time >= min_display_time:
				is_loading = false
				if progress_bar:
					progress_bar.value = 100.0
				if label_percent:
					label_percent.text = "100%"
				if label_status:
					label_status.text = "СЕКТОР ГОТОВ // ВХОД В СИСТЕМУ..."
				
				var loaded_packed: PackedScene = ResourceLoader.load_threaded_get(target_scene_path)
				_finish_transition(loaded_packed)
				
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LoadingScreen: Ошибка загрузки ресурса: %d" % status)
			is_loading = false
			if label_status:
				label_status.text = "ОШИБКА ЗАГРУЗКИ. АВАРИЙНЫЙ ПЕРЕХОД..."
			get_tree().change_scene_to_file(target_scene_path)

func _update_tip() -> void:
	if label_tip:
		var tween := create_tween()
		tween.tween_property(label_tip, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func() -> void:
			label_tip.text = TIPS[current_tip_idx]
		)
		tween.tween_property(label_tip, "modulate:a", 1.0, 0.3)

func _finish_transition(packed_scene: PackedScene) -> void:
	if not packed_scene:
		get_tree().change_scene_to_file(target_scene_path)
		return

	if fade_overlay:
		var tween := create_tween()
		tween.tween_property(fade_overlay, "color:a", 1.0, 0.35)
		tween.tween_callback(func() -> void:
			get_tree().change_scene_to_packed(packed_scene)
		)
	else:
		get_tree().change_scene_to_packed(packed_scene)
