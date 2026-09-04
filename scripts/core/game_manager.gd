extends Node

# GameManager — Главный менеджер игрового состояния и межрайонных переходов «Кока-Коля»
# Управляет переходами между уровнями, валютой (Коля-рубли), репутацией и глобальным циклом.

signal district_changed(district_name: String)
signal credits_changed(new_amount: int)
signal reputation_changed(new_reputation: int)

var current_district: String = "old_district"
var credits: int = 250
var reputation: int = 10
var completed_missions: Array[String] = []

const DISTRICT_SCENES: Dictionary = {
	"garage": "res://scenes/testlabs/foundation_graybox.tscn",
	"old_district": "res://scenes/levels/old_district.tscn",
	"city_highway": "res://scenes/levels/city_highway.tscn",
	"red_line_plant": "res://scenes/levels/red_line_plant.tscn",
	"test_hub": "res://scenes/testlabs/test_hub.tscn",
	"main_menu": "res://scenes/ui/main_menu.tscn"
}

func _ready() -> void:
	LogManager.info("GameManager инициализирован. Текущий район: %s, Баланс: %d КР." % [current_district, credits], "GAME")

func change_district(district_key: String, save_before_transition: bool = true) -> bool:
	if not DISTRICT_SCENES.has(district_key):
		LogManager.warn("Неизвестный район для перехода: %s" % district_key, "GAME")
		return false

	var target_scene_path: String = DISTRICT_SCENES[district_key]
	LogManager.info("Переход в район: %s -> %s" % [district_key, target_scene_path], "GAME")

	# Сохраняем состояние перед переходом
	if save_before_transition and has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		sm.call("save_game", 0, {"last_district": district_key})

	current_district = district_key
	district_changed.emit(district_key)

	var err := get_tree().change_scene_to_file(target_scene_path)
	return err == OK

func add_credits(amount: int) -> void:
	credits = maxi(0, credits + amount)
	credits_changed.emit(credits)
	LogManager.info("Баланс изменен (%+d КР). Итого: %d КР." % [amount, credits], "ECONOMY")
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "click")

func add_reputation(amount: int) -> void:
	reputation += amount
	reputation_changed.emit(reputation)
	LogManager.info("Репутация сопротивления повышена: %+d (Всего: %d)." % [amount, reputation], "GAME")

func mark_mission_completed(mission_id: String) -> void:
	if not completed_missions.has(mission_id):
		completed_missions.append(mission_id)
		add_credits(500)
		add_reputation(25)
		LogManager.info("Миссия официально занесена в архив завершенных: %s" % mission_id, "CAMPAIGN")