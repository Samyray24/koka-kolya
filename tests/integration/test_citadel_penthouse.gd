extends SceneTree

# Автоматический интеграционный тест Уровня 4: Цитадель Синдиката (Mission 4)
# Проверяет: инстанцирование пентхауса, элитную охрану, взлом квантового мейнфрейма и эвакуацию

var passed_count: int = 0
var total_count: int = 4
var frame: int = 0

var citadel_scene: Node = null
var player: CharacterBody3D = null
var terminal: Node3D = null
var helipad_trigger: Area3D = null
var victory_panel: Control = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup()
		3:
			_test_1_scene_instantiation()
		5:
			_test_2_actors_and_surveillance()
		7:
			_test_3_mainframe_hack()
		9:
			_test_4_helipad_extraction_and_victory()
		11:
			_finalize()
			return true
	return false

func _setup() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: CITADEL PENTHOUSE (MISSION 4 - FINALE) <<<")
	print("=======================================================================\n")

func _test_1_scene_instantiation() -> void:
	var scene_res: PackedScene = load("res://scenes/levels/citadel_penthouse.tscn")
	if not scene_res:
		print("[FAIL] Test 1: Не удалось загрузить scenes/levels/citadel_penthouse.tscn")
		return

	citadel_scene = scene_res.instantiate()
	root.add_child(citadel_scene)

	player = citadel_scene.get_node_or_null("Player")
	terminal = citadel_scene.get_node_or_null("ServerRoom/MainframeTerminal")
	helipad_trigger = citadel_scene.get_node_or_null("RooftopHelipad/HelipadTrigger")
	victory_panel = citadel_scene.get_node_or_null("HUD/VictoryPanel")

	if player and terminal and helipad_trigger and victory_panel:
		print("[PASS] Test 1: Сцена CitadelPenthouse успешно загружена со всеми ключевыми объектами.")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Не найдены базовые элементы уровня CitadelPenthouse.")

func _test_2_actors_and_surveillance() -> void:
	var drone: Node = citadel_scene.get_node_or_null("BubbleDrone")
	var guard: Node = citadel_scene.get_node_or_null("EliteGuard")
	var cctv: Node = citadel_scene.get_node_or_null("ServerRoom/CCTV_Penthouse")

	if drone and guard and cctv:
		print("[PASS] Test 2: Дрон BUBBLE, элитный страж и камера наблюдения активны в пентхаусе.")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Отсутствуют акторы или камера в пентхаусе.")

func _test_3_mainframe_hack() -> void:
	if not terminal:
		print("[FAIL] Test 3: Терминал мейнфрейма не найден.")
		return

	# Взлом квантового сервера
	terminal.call("hack_bypass")
	var is_overridden: bool = terminal.get("is_overridden")
	var current_stage: int = citadel_scene.get("stage")

	if is_overridden and current_stage == 3:
		print("[PASS] Test 3: Квантовый мейнфрейм взломан, рецепт скачан, стадия обновлена (Stage 3).")
		passed_count += 1
	else:
		print("[FAIL] Test 3: Ошибка взлома терминала (overridden=%s, stage=%d)." % [is_overridden, current_stage])

func _test_4_helipad_extraction_and_victory() -> void:
	# Имитируем прибытие игрока в зону вертолётной площадки
	citadel_scene.call("_on_helipad_entered", player)
	var final_stage: int = citadel_scene.get("stage")
	var is_victory_visible: bool = victory_panel.visible

	if final_stage == 4 and is_victory_visible:
		print("[PASS] Test 4: Эвакуация на вертолёте успешна, панель финальной победы отображена.")
		passed_count += 1
	else:
		print("[FAIL] Test 4: Ошибка эвакуации или экрана победы (stage=%d, victory=%s)." % [final_stage, is_victory_visible])

func _finalize() -> void:
	print("\n=======================================================================")
	if passed_count == total_count:
		print(">>> ВСЕ 4 ТЕСТА CITADEL PENTHOUSE ПРОЙДЕНЫ УСПЕШНО (0 ОШИБОК) <<<")
		print("=======================================================================\n")
		quit(0)
	else:
		printerr(">>> ОШИБКИ В ТЕСТАХ CITADEL PENTHOUSE: %d/%d <<<" % [passed_count, total_count])
		print("=======================================================================\n")
		quit(1)
