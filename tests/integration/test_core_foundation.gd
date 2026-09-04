extends SceneTree

# Automated Integration Test for Stage 1 Core Foundation (v0.1.0)
# Validates: LogManager, SettingsManager, InputManager, PhysicsGrabber, and PlayerController

var tested: bool = false

func _process(_delta: float) -> bool:
	if tested:
		return false
	tested = true
	run_tests()
	return true

func run_tests() -> void:
	print("==================================================================")
	print(">>> ЗАПУСК INTEGRATION TEST: CORE FOUNDATION (STAGE 1 / v0.1.0) <<<")
	print("==================================================================")

	var errors: int = 0

	# 1. Проверка LogManager
	print("[TEST 1/5] Проверка LogManager...")
	var log_mgr: Node = root.get_node_or_null("LogManager")
	if log_mgr:
		log_mgr.call("info", "Тестовое сообщение интеграционного теста", "INTEG_TEST")
		print("  [PASS] LogManager найден в Autoload и успешно записал лог.")
	else:
		printerr("  [FAIL] LogManager не найден в root/LogManager")
		errors += 1

	# 2. Проверка SettingsManager (Save, Load, Modify)
	print("[TEST 2/5] Проверка SettingsManager...")
	var settings_mgr: Node = root.get_node_or_null("SettingsManager")
	if settings_mgr:
		var orig_fov: float = settings_mgr.call("get_val", "display", "fov", 85.0)
		settings_mgr.call("set_val", "display", "fov", 95.0)
		var new_fov: float = settings_mgr.call("get_val", "display", "fov", 85.0)
		if is_equal_approx(new_fov, 95.0):
			print("  [PASS] SettingsManager корректно обновил значение (FOV: %.1f -> %.1f)." % [orig_fov, new_fov])
			settings_mgr.call("set_val", "display", "fov", orig_fov)
		else:
			printerr("  [FAIL] SettingsManager вернул некорректное значение: %s" % new_fov)
			errors += 1
	else:
		printerr("  [FAIL] SettingsManager не найден в root/SettingsManager")
		errors += 1

	# 3. Проверка InputManager
	print("[TEST 3/5] Проверка InputManager...")
	var input_mgr: Node = root.get_node_or_null("InputManager")
	if input_mgr:
		var kb_prompt: String = input_mgr.call("get_action_prompt", "interact")
		input_mgr.set("is_gamepad_active", true)
		var pad_prompt: String = input_mgr.call("get_action_prompt", "interact")
		input_mgr.set("is_gamepad_active", false)
		if kb_prompt == "[E]" and pad_prompt == "[X]":
			print("  [PASS] InputManager корректно переключает подсказки (KB: %s, Pad: %s)." % [kb_prompt, pad_prompt])
		else:
			printerr("  [FAIL] Ошибка подсказок InputManager: KB: %s, Pad: %s" % [kb_prompt, pad_prompt])
			errors += 1
	else:
		printerr("  [FAIL] InputManager не найден в root/InputManager")
		errors += 1

	# 4. Проверка PhysicsGrabber (Захват и бросок)
	print("[TEST 4/5] Проверка PhysicsGrabber...")
	var grabber_script: Script = load("res://scripts/interaction/physics_grabber.gd")
	if grabber_script:
		var grabber_node: Node3D = grabber_script.new()
		var hold_marker := Marker3D.new()
		hold_marker.name = "HoldPoint"
		hold_marker.position = Vector3(0, 0, -2)
		grabber_node.add_child(hold_marker)
		
		var ray := RayCast3D.new()
		ray.name = "RayCast3D"
		grabber_node.add_child(ray)
		
		var test_body := RigidBody3D.new()
		test_body.mass = 0.35
		root.add_child(grabber_node)
		root.add_child(test_body)
		
		grabber_node.call("grab_object", test_body)
		var held: Object = grabber_node.get("held_body")
		if held == test_body:
			print("  [PASS] PhysicsGrabber успешно захватил RigidBody3D.")
			grabber_node.call("throw_object")
			if grabber_node.get("held_body") == null:
				print("  [PASS] PhysicsGrabber успешно выбросил предмет.")
			else:
				printerr("  [FAIL] Предмет не сброшен после throw_object()")
				errors += 1
		else:
			printerr("  [FAIL] grab_object() не установил held_body")
			errors += 1
		
		test_body.queue_free()
		grabber_node.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить physics_grabber.gd")
		errors += 1

	# 5. Проверка полной сцены Graybox с игроком и банками Колы
	print("[TEST 5/5] Проверка сцены Foundation Graybox с новыми объектами...")
	var graybox_res: PackedScene = load("res://scenes/testlabs/foundation_graybox.tscn")
	if graybox_res:
		var scene_inst: Node3D = graybox_res.instantiate()
		var can1: Node = scene_inst.get_node_or_null("ColaCan1")
		var can2: Node = scene_inst.get_node_or_null("ColaCan2")
		var player_node: Node = scene_inst.get_node_or_null("Player")
		var grabber_inst: Node = player_node.get_node_or_null("Head/Camera3D/PhysicsGrabber") if player_node else null
		
		if can1 and can2 and player_node and grabber_inst:
			print("  [PASS] Все объекты (ColaCan1, ColaCan2, Player, PhysicsGrabber) найдены и валидны.")
		else:
			printerr("  [FAIL] Отсутствуют ожидаемые ноды в Graybox.")
			errors += 1
		scene_inst.free()
	else:
		printerr("  [FAIL] Не удалось загрузить foundation_graybox.tscn")
		errors += 1

	print("==================================================================")
	if errors == 0:
		print(">>> ВСЕ 5 ИНТЕГРАЦИОННЫХ ТЕСТОВ ПРОЙДЕНЫ УСПЕШНО (0 ОШИБОК) <<<")
		print("==================================================================")
		quit(0)
	else:
		printerr(">>> ИНТЕГРАЦИОННЫЙ ТЕСТ ЗАВЕРШИЛСЯ С ОШИБКАМИ: %d <<<" % errors)
		print("==================================================================")
		quit(1)
