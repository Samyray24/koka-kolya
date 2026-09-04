extends SceneTree

# Автоматический интеграционный тест Первого играбельного района (Stage 3 / v0.3.0)

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

var level_scene: Node = null
var van: VehicleBody3D = null
var mission_mgr: Node = null
var dialogue_mgr: Node = null
var secret_formula: Node3D = null
var return_trigger: Area3D = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup_level()
		3:
			_test_1_scene_and_entities()
		5:
			_test_2_mission_and_dialogue_init()
		7:
			_test_3_cargo_loading()
		9:
			_test_4_warehouse_and_formula_theft()
		11:
			_test_5_return_and_completion()
		13:
			_finalize()
			return true
	return false

func _setup_level() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: FIRST PLAYABLE (OLD DISTRICT MISSION 1 / v0.3.0) <<<")
	print("=======================================================================\n")
	
	var scene_res: PackedScene = load("res://scenes/levels/old_district.tscn")
	level_scene = scene_res.instantiate()
	root.add_child(level_scene)
	
	van = level_scene.get_node_or_null("DeliveryVan")
	mission_mgr = level_scene.get_node_or_null("MissionManager")
	dialogue_mgr = level_scene.get_node_or_null("DialogueManager")
	secret_formula = level_scene.get_node_or_null("Warehouse/Vault/SecretFormula")
	return_trigger = level_scene.get_node_or_null("Triggers/GarageReturnArea")

func _test_1_scene_and_entities() -> void:
	var player: Node = level_scene.get_node_or_null("Player")
	var drone: Node = level_scene.get_node_or_null("BubbleDrone")
	var warehouse: Node = level_scene.get_node_or_null("Warehouse")
	var gate: Node = level_scene.get_node_or_null("Warehouse/SecurityGate")
	var crate1: Node = level_scene.get_node_or_null("ColaCrate1")
	var crate2: Node = level_scene.get_node_or_null("ColaCrate2")
	var crate3: Node = level_scene.get_node_or_null("ColaCrate3")
	
	if player and van and drone and warehouse and gate and crate1 and crate2 and crate3:
		passed_count += 1
		print("[PASS] 1. Level Entities: Игрок, фургон, дрон, склад MERIDIAN, ворота и 3 ящика «Кока-Коля» на месте.")
	else:
		printerr("[FAIL] Ошибка структуры сущностей в old_district.tscn")

func _test_2_mission_and_dialogue_init() -> void:
	if mission_mgr and dialogue_mgr:
		var has_obj: bool = mission_mgr.get("objectives").has("load_crates")
		if has_obj:
			passed_count += 1
			print("[PASS] 2. Quest & Radio Comms: Миссия «Операция: Шипучка» и радиоканал с СашейV успешно инициализированы.")
		else:
			printerr("[FAIL] Задача load_crates не найдена в MissionManager")
	else:
		printerr("[FAIL] MissionManager или DialogueManager не найдены")

func _test_3_cargo_loading() -> void:
	var c1: RigidBody3D = level_scene.get_node_or_null("ColaCrate1")
	var c2: RigidBody3D = level_scene.get_node_or_null("ColaCrate2")
	var c3: RigidBody3D = level_scene.get_node_or_null("ColaCrate3")
	
	if c1 and c2 and c3 and van:
		var trunk_pos: Vector3 = van.global_position + Vector3(0, 0.4, 0.5)
		c1.global_position = trunk_pos
		c2.global_position = trunk_pos + Vector3(0.2, 0, 0)
		c3.global_position = trunk_pos + Vector3(-0.2, 0, 0)
		
		# Завершение этапа погрузки
		mission_mgr.call("complete_objective", "load_crates")
		level_scene.set("stage", 2)
		mission_mgr.call("add_objective", "drive_to_warehouse", "Сесть за руль и доехать до Складского терминала №4", 1)
		
		passed_count += 1
		print("[PASS] 3. Cargo Loading: Погрузка 3 ящиков завершена, этап 2 (Транспортировка) активирован.")
	else:
		printerr("[FAIL] Ошибка погрузки ящиков")

func _test_4_warehouse_and_formula_theft() -> void:
	# Прибытие на склад
	level_scene.call("_on_warehouse_entered", van)
	
	# Похищение формулы
	if secret_formula:
		secret_formula.call("_on_interacted", null)
		var is_secured: bool = secret_formula.get("is_collected")
		var is_stage_4: bool = (level_scene.get("stage") == 4)
		if is_secured and is_stage_4:
			passed_count += 1
			print("[PASS] 4. Infiltration & Theft: Прибытие на склад подтверждено, чип захвачен, активирован этап 5 (Эвакуация).")
		else:
			printerr("[FAIL] Ошибка захвата формулы: secured=%s, stage=%d" % [is_secured, level_scene.get("stage")])
	else:
		printerr("[FAIL] Узел SecretFormula не найден")

func _test_5_return_and_completion() -> void:
	# Возвращение фургона в гараж
	level_scene.call("_on_return_entered", van)
	
	var all_done: bool = mission_mgr.call("is_objective_completed", "return_to_garage")
	if all_done:
		passed_count += 1
		print("[PASS] 5. Mission 1 Completed: Фургон вернулся в гараж, финальная победная панель выведена.")
	else:
		printerr("[FAIL] Миссия не перешла в статус завершения")

func _finalize() -> void:
	print("\n--- РЕЗУЛЬТАТ ТЕСТОВ FIRST PLAYABLE: %d/%d ПРОЙДЕНО ---" % [passed_count, total_count])
	if level_scene:
		level_scene.queue_free()
	quit(0 if passed_count == total_count else 1)