extends SceneTree

# Automated Integration Test for Fair AI & AI Arena (v0.2.0)

var tested: bool = false

func _process(_delta: float) -> bool:
	if tested:
		return false
	tested = true
	run_tests()
	return true

func run_tests() -> void:
	print("===============================================================")
	print(">>> ЗАПУСК TEST: FAIR AI & AI ARENA (STAGE 2 / v0.2.0) <<<")
	print("===============================================================")

	var errors: int = 0

	# 1. Проверка NoiseManager
	print("[TEST 1/5] Проверка NoiseManager (эмиссия и подписка)...")
	var nm: Node = root.get_node_or_null("NoiseManager")
	if nm:
		var heard_event: Dictionary = {"called": false}
		var test_callable := func(pos: Vector3, radius: float, _inst: Node, ntype: String) -> void:
			heard_event["called"] = true
			heard_event["pos"] = pos
			heard_event["radius"] = radius
			heard_event["ntype"] = ntype
		
		nm.connect("noise_emitted", test_callable)
		nm.call("emit_noise", Vector3(1, 2, 3), 10.0, null, "test_footstep")
		nm.disconnect("noise_emitted", test_callable)
		
		if heard_event["called"] and heard_event["radius"] == 10.0:
			print("  [PASS] NoiseManager успешно передал акустический стимул подписчику.")
		else:
			printerr("  [FAIL] NoiseManager не передал сигнал")
			errors += 1
	else:
		printerr("  [FAIL] NoiseManager не найден в Autoload")
		errors += 1

	# 2. Проверка AISensorVision
	print("[TEST 2/5] Проверка AISensorVision (конус видимости и прямая видимость)...")
	var vis_script: Script = load("res://scripts/ai/ai_sensor_vision.gd")
	if vis_script:
		var vis_node: Node3D = vis_script.new()
		root.add_child(vis_node)
		
		var dummy_target := Node3D.new()
		dummy_target.position = Vector3(0, 0, -5) # Прямо перед сенсором
		root.add_child(dummy_target)
		vis_node.call("set_target", dummy_target)
		
		var can_see_front: bool = vis_node.call("_check_line_of_sight")
		
		dummy_target.position = Vector3(0, 0, 5) # Сзади сенсора
		var can_see_back: bool = vis_node.call("_check_line_of_sight")
		
		if can_see_front and not can_see_back:
			print("  [PASS] Сенсор зрения честно видит объект спереди (FOV) и игнорирует сзади.")
		else:
			printerr("  [FAIL] Ошибка конуса зрения: front=%s, back=%s" % [can_see_front, can_see_back])
			errors += 1
		
		dummy_target.queue_free()
		vis_node.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить ai_sensor_vision.gd")
		errors += 1

	# 3. Проверка AISensorHearing
	print("[TEST 3/5] Проверка AISensorHearing...")
	var hear_script: Script = load("res://scripts/ai/ai_sensor_hearing.gd")
	if hear_script:
		var hear_node: Node3D = hear_script.new()
		root.add_child(hear_node)
		
		var heard_data: Dictionary = {"heard": false}
		hear_node.connect("noise_heard", func(orig: Vector3, inten: float, ntype: String) -> void:
			heard_data["heard"] = true
			heard_data["intensity"] = inten
		)
		
		# Эмитируем шум рядом (дистанция 2м при радиусе 10м)
		hear_node.call("_on_noise_emitted", Vector3(2, 0, 0), 10.0, null, "glass_shatter")
		if heard_data["heard"] and heard_data["intensity"] > 0.5:
			print("  [PASS] Сенсор слуха честно зафиксировал шум в радиусе слышимости.")
		else:
			printerr("  [FAIL] Ошибка сенсора слуха: %s" % heard_data)
			errors += 1
		hear_node.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить ai_sensor_hearing.gd")
		errors += 1

	# 4. Проверка GuardAI FSM (Конечный автомат состояний)
	print("[TEST 4/5] Проверка переходов состояний GuardAI (IDLE -> INVESTIGATING -> ALERT -> SEARCHING)...")
	var guard_script: Script = load("res://scripts/ai/guard_ai.gd")
	if guard_script:
		var guard_inst: CharacterBody3D = guard_script.new()
		root.add_child(guard_inst)
		
		var initial_state: int = guard_inst.get("current_state")
		guard_inst.call("_on_noise_heard", Vector3(5, 0, 5), 0.8, "can_impact")
		var state_after_noise: int = guard_inst.get("current_state")
		
		var dummy_player := Node3D.new()
		guard_inst.call("_on_target_spotted", dummy_player, Vector3(0, 0, -4))
		var state_after_spot: int = guard_inst.get("current_state")
		
		guard_inst.call("_on_target_lost", Vector3(0, 0, -4))
		var state_after_lost: int = guard_inst.get("current_state")
		
		# 0: IDLE, 2: INVESTIGATING, 3: ALERT, 4: SEARCHING
		if initial_state == 0 and state_after_noise == 2 and state_after_spot == 3 and state_after_lost == 4:
			print("  [PASS] GuardAI FSM корректно отрабатывает цепочку состояний 0 -> 2 -> 3 -> 4.")
		else:
			printerr("  [FAIL] Ошибка FSM: init=%d, noise=%d, spot=%d, lost=%d" % [initial_state, state_after_noise, state_after_spot, state_after_lost])
			errors += 1
		
		dummy_player.queue_free()
		guard_inst.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить guard_ai.gd")
		errors += 1

	# 5. Проверка загрузки сцены AIArena
	print("[TEST 5/5] Проверка целостности сцены ai_arena.tscn...")
	var arena_res: PackedScene = load("res://scenes/testlabs/ai_arena.tscn")
	if arena_res:
		var arena_inst: Node3D = arena_res.instantiate()
		var a_guard: Node = arena_inst.get_node_or_null("GuardAI")
		var a_player: Node = arena_inst.get_node_or_null("Player")
		var a_cover: Node = arena_inst.get_node_or_null("Cover1")
		
		if a_guard and a_player and a_cover:
			print("  [PASS] Сцена AI Arena содержит GuardAI, Player и элементы укрытий.")
		else:
			printerr("  [FAIL] В сцене ai_arena.tscn отсутствуют компоненты.")
			errors += 1
		arena_inst.free()
	else:
		printerr("  [FAIL] Не удалось загрузить scenes/testlabs/ai_arena.tscn")
		errors += 1

	print("===============================================================")
	if errors == 0:
		print(">>> ВСЕ 5 ТЕСТОВ AI ARENA УСПЕШНО ПРОЙДЕНЫ (0 ОШИБОК) <<<")
		print("===============================================================")
		quit(0)
	else:
		printerr(">>> ТЕСТЫ AI ARENA ЗАВЕРШИЛИСЬ С ОШИБКАМИ: %d <<<" % errors)
		print("===============================================================")
		quit(1)
