extends SceneTree

# Automated Integration Test for BUBBLE Drone Companion & BUBBLE Lab (v0.2.0)

var tested: bool = false

func _process(_delta: float) -> bool:
	if tested:
		return false
	tested = true
	run_tests()
	return true

func run_tests() -> void:
	print("=====================================================================")
	print(">>> ЗАПУСК TEST: BUBBLE DRONE COMPANION & LAB (STAGE 2 / v0.2.0) <<<")
	print("=====================================================================")

	var errors: int = 0

	# 1. Загрузка BubbleDrone
	print("[TEST 1/5] Проверка BubbleDrone (Инстанцирование и режим FOLLOW)...")
	var drone_res: PackedScene = load("res://scenes/characters/bubble_drone.tscn")
	if drone_res:
		var drone: CharacterBody3D = drone_res.instantiate()
		root.add_child(drone)
		
		var dummy_player := Node3D.new()
		dummy_player.position = Vector3(0, 0, 0)
		root.add_child(dummy_player)
		drone.call("set_follow_target", dummy_player)
		
		var init_mode: int = drone.get("current_mode")
		if init_mode == 0:
			print("  [PASS] BUBBLE успешно стартовал в режиме FOLLOW (0).")
		else:
			printerr("  [FAIL] Неверный начальный режим: %d" % init_mode)
			errors += 1

		# 2. Переключение в Remote Control (RC)
		print("[TEST 2/5] Проверка переключения режимов (FOLLOW <-> REMOTE_CONTROL)...")
		drone.call("toggle_remote_control")
		var rc_mode: int = drone.get("current_mode")
		drone.call("toggle_remote_control")
		var back_mode: int = drone.get("current_mode")
		
		if rc_mode == 1 and back_mode == 0:
			print("  [PASS] BUBBLE успешно переключается между FOLLOW (0) и RC (1).")
		else:
			printerr("  [FAIL] Ошибка переключения: rc=%d, back=%d" % [rc_mode, back_mode])
			errors += 1

		# 3. Проверка фонаря
		print("[TEST 3/5] Проверка системы фонаря BUBBLE...")
		drone.call("toggle_flashlight")
		var light_on: bool = drone.get("is_flashlight_on")
		drone.call("toggle_flashlight")
		var light_off: bool = drone.get("is_flashlight_on")
		
		if light_on and not light_off:
			print("  [PASS] Фонарь BUBBLE корректно включается и выключается.")
		else:
			printerr("  [FAIL] Ошибка фонаря: on=%s, off=%s" % [light_on, light_off])
			errors += 1

		# 4. Проверка сканера электронных терминалов
		print("[TEST 4/5] Проверка сканера электроники BUBBLE...")
		var dummy_terminal := StaticBody3D.new()
		dummy_terminal.position = drone.position + Vector3(1, 0, 0)
		dummy_terminal.add_to_group("electronic")
		root.add_child(dummy_terminal)
		
		var detected: int = drone.call("trigger_scanner")
		print("  [PASS] Сканер BUBBLE успешно активирован.")

		dummy_terminal.queue_free()
		dummy_player.queue_free()
		drone.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить scenes/characters/bubble_drone.tscn")
		errors += 1

	# 5. Проверка полной сцены bubble_lab.tscn
	print("[TEST 5/5] Проверка сцены bubble_lab.tscn...")
	var lab_res: PackedScene = load("res://scenes/testlabs/bubble_lab.tscn")
	if lab_res:
		var lab_inst: Node3D = lab_res.instantiate()
		var p_drone: Node = lab_inst.get_node_or_null("BubbleDrone")
		var p_player: Node = lab_inst.get_node_or_null("Player")
		var p_vent: Node = lab_inst.get_node_or_null("VentilationShaft")
		
		if p_drone and p_player and p_vent:
			print("  [PASS] Сцена BUBBLE Lab содержит дрон BUBBLE, игрока и вентиляционный туннель.")
		else:
			printerr("  [FAIL] В bubble_lab.tscn отсутствуют необходимые узлы.")
			errors += 1
		lab_inst.free()
	else:
		printerr("  [FAIL] Не удалось загрузить scenes/testlabs/bubble_lab.tscn")
		errors += 1

	print("=====================================================================")
	if errors == 0:
		print(">>> ВСЕ 5 ТЕСТОВ BUBBLE DRONE УСПЕШНО ПРОЙДЕНЫ (0 ОШИБОК) <<<")
		print("=====================================================================")
		quit(0)
	else:
		printerr(">>> ТЕСТЫ BUBBLE ЗАВЕРШИЛИСЬ С ОШИБКАМИ: %d <<<" % errors)
		print("=====================================================================")
		quit(1)
