extends SceneTree

# Автоматический интеграционный тест Вертикального среза (Stage 4 / v0.5.0)
# Завод «Красная Линия»: Синтез рецептуры, камеры CCTV, сиропная башня, автоматика конвейеров

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

var level_scene: Node = null
var crafting_station: Node3D = null
var syrup_canister: RigidBody3D = null
var cctv_camera: Node3D = null
var terminal: Node3D = null
var conveyor: AnimatableBody3D = null
var mission_mgr: Node = null
var victory_panel: Control = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup_level()
		3:
			_test_1_scene_and_subsystems()
		5:
			_test_2_crafting_synthesis()
		7:
			_test_3_camera_surveillance_and_countermeasures()
		9:
			_test_4_syrup_injection_and_tower()
		11:
			_test_5_automation_override_and_bottling_victory()
		13:
			_finalize()
			return true
	return false

func _setup_level() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: VERTICAL SLICE (RED LINE PLANT MISSION 2 / v0.5.0) <<<")
	print("=======================================================================\n")

	var scene_res: PackedScene = load("res://scenes/levels/red_line_plant.tscn")
	level_scene = scene_res.instantiate()
	root.add_child(level_scene)

	crafting_station = level_scene.get_node_or_null("Garage/CraftingStation")
	syrup_canister = level_scene.get_node_or_null("CanisterSpawnPoint/SyrupCanister")
	cctv_camera = level_scene.get_node_or_null("Factory/CCTV_Gate")
	terminal = level_scene.get_node_or_null("Factory/DispatchTower/AutomationTerminal")
	conveyor = level_scene.get_node_or_null("Factory/BottlingLine/ConveyorBelt")
	mission_mgr = level_scene.get_node_or_null("MissionManager")
	victory_panel = level_scene.get_node_or_null("HUD/VictoryPanel")

func _test_1_scene_and_subsystems() -> void:
	var player: Node = level_scene.get_node_or_null("Player")
	var drone: Node = level_scene.get_node_or_null("BubbleDrone")
	var van: Node = level_scene.get_node_or_null("DeliveryVan")
	var guard: Node = level_scene.get_node_or_null("Factory/GuardAI")
	var tower: Node = level_scene.get_node_or_null("Factory/SyrupTower")

	if player and drone and van and guard and tower and crafting_station and syrup_canister and cctv_camera and terminal and conveyor:
		print("[PASS] Test 1: Все ключевые компоненты сцены RedLinePlant успешно инстанцированы.")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Отсутствуют ключевые узлы фабрики или акторы.")

func _test_2_crafting_synthesis() -> void:
	if not crafting_station:
		print("[FAIL] Test 2: CraftingStation не найден.")
		return

	# Запускаем синтез концентрата «Кока-Коля»
	crafting_station.call("start_synthesis")
	var is_crafted: bool = crafting_station.get("is_crafted")
	
	# Имитируем завершение синтеза и переход на стадию 2
	level_scene.call("_on_craft_done", "SyrupCanister")
	var stage: int = level_scene.get("stage")

	if is_crafted and stage == 2:
		print("[PASS] Test 2: Синтез концентрата Коли инициирован, стадия квеста обновлена (Stage 2).")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Сбой логики верстака синтеза (is_crafted=%s, stage=%d)." % [is_crafted, stage])

func _test_3_camera_surveillance_and_countermeasures() -> void:
	if not cctv_camera:
		print("[FAIL] Test 3: CCTV_Gate не найден.")
		return

	# 1. Проверяем взлом кибер-декой
	cctv_camera.call("hack_bypass")
	var is_disabled_hack: bool = cctv_camera.get("is_disabled")

	# 2. Проверяем ослепление пеной
	cctv_camera.call("blind_with_foam")
	var is_blinded: bool = cctv_camera.get("is_blinded")
	var is_disabled_foam: bool = cctv_camera.get("is_disabled")

	if is_disabled_hack and is_blinded and is_disabled_foam:
		print("[PASS] Test 3: Камера CCTV успешно реагирует на радиовзлом и ослепление пеной BUBBLE.")
		passed_count += 1
	else:
		print("[FAIL] Test 3: Ошибка в протоколах противодействия камерам наблюдения.")

func _test_4_syrup_injection_and_tower() -> void:
	if not syrup_canister:
		print("[FAIL] Test 4: SyrupCanister не найден.")
		return

	# Имитируем доставку к заводу
	level_scene.set("stage", 3)
	var arrival_area: Area3D = level_scene.get_node_or_null("Triggers/PlantArrivalArea")
	level_scene.call("_on_plant_arrival", level_scene.get_node_or_null("Player"))

	var stage_after_arrival: int = level_scene.get("stage")

	# Заливка в сиропную башню
	syrup_canister.call("inject_into_tower")
	var canister_used: bool = syrup_canister.get("is_used")
	level_scene.call("_on_tower_injection", syrup_canister)
	var stage_after_injection: int = level_scene.get("stage")

	if stage_after_arrival == 4 and canister_used and stage_after_injection == 5:
		print("[PASS] Test 4: Прибытие на завод зафиксировано, сироп залит в башню (Stage 5).")
		passed_count += 1
	else:
		print("[FAIL] Test 4: Сбой этапа диверсии на сиропной башне (stage=%d, used=%s)." % [stage_after_injection, canister_used])

func _test_5_automation_override_and_bottling_victory() -> void:
	if not terminal or not conveyor:
		print("[FAIL] Test 5: Terminal или Conveyor не найден.")
		return

	# Взламываем терминал автоматизации
	terminal.call("override_plant")
	var is_overridden: bool = terminal.get("is_overridden")

	# Имитируем завершение миссии
	level_scene.call("_on_terminal_hacked")
	level_scene.call("_on_mission_victory", "Операция: Красная Линия")

	var is_conveyor_running: bool = conveyor.constant_linear_velocity.length() > 0.1
	var is_victory_visible: bool = victory_panel != null and victory_panel.visible

	if is_overridden and is_conveyor_running and is_victory_visible:
		print("[PASS] Test 5: Автоматизация перехвачена, конвейер запущен, победный экран активирован!")
		passed_count += 1
	else:
		print("[FAIL] Test 5: Сбой перехвата автоматики (overridden=%s, conveyor_vel=%s, victory=%s)." % [is_overridden, conveyor.constant_linear_velocity, is_victory_visible])

func _finalize() -> void:
	print("\n-----------------------------------------------------------------------")
	print(">>> РЕЗУЛЬТАТ: %d/%d ТЕСТОВ ПРОЙДЕНО" % [passed_count, total_count])
	print("-----------------------------------------------------------------------\n")
	if passed_count == total_count:
		print(">>> СТАТУС: 100% УСПЕХ — VERTICAL SLICE v0.5.0 ПОЛНОСТЬЮ ГОТОВ! <<<\n")
	else:
		printerr(">>> СТАТУС: НАЙДЕНЫ ОШИБКИ В СЦЕНАРИИ ФАБРИКИ! <<<\n")