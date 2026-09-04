extends SceneTree

# Headless Smoke Test for «Кока-Коля» (v0.0.1 Foundation)
# Runs automated validation of scenes, physics backend, and core nodes.

var frame: int = 0
var errors: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_run_smoke_tests()
		2:
			_finalize()
			return true
	return false

func _run_smoke_tests() -> void:
	print("==========================================================")
	print(">>> ЗАПУСК HEADLESS SMOKE TEST: «КОКА-КОЛЯ» (v0.0.1) <<<")
	print("==========================================================")

	# 1. Проверка настроек физики
	var physics_engine: String = ProjectSettings.get_setting("physics/3d/physics_engine", "Default")
	print("[TEST 1/5] Проверка 3D Physics Engine: %s" % physics_engine)
	if physics_engine != "JoltPhysics3D":
		printerr("  [FAIL] Physics engine is not JoltPhysics3D (got: %s)" % physics_engine)
		errors += 1
	else:
		print("  [PASS] Jolt Physics 3D успешно сконфигурирован.")

	# 2. Проверка загрузки Boot Scene
	print("[TEST 2/5] Проверка загрузки Boot сцены...")
	var boot_scene: PackedScene = load("res://scenes/boot/boot.tscn")
	if boot_scene == null:
		printerr("  [FAIL] Не удалось загрузить scenes/boot/boot.tscn")
		errors += 1
	else:
		var boot_inst := boot_scene.instantiate()
		if boot_inst:
			print("  [PASS] Boot сцена инстанциирована корректно.")
			boot_inst.free()

	# 3. Проверка загрузки Main Menu
	print("[TEST 3/5] Проверка загрузки MainMenu...")
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu.tscn")
	if menu_scene == null:
		printerr("  [FAIL] Не удалось загрузить scenes/ui/main_menu.tscn")
		errors += 1
	else:
		var menu_inst := menu_scene.instantiate()
		if menu_inst:
			print("  [PASS] MainMenu сцена инстанциирована корректно.")
			menu_inst.free()

	# 4. Проверка загрузки Test Hub
	print("[TEST 4/5] Проверка загрузки TestHub...")
	var testhub_scene: PackedScene = load("res://scenes/testlabs/test_hub.tscn")
	if testhub_scene == null:
		printerr("  [FAIL] Не удалось загрузить scenes/testlabs/test_hub.tscn")
		errors += 1
	else:
		var testhub_inst := testhub_scene.instantiate()
		if testhub_inst:
			print("  [PASS] TestHub сцена инстанциирована корректно.")
			testhub_inst.free()

	# 5. Проверка загрузки Foundation Graybox и игрока
	print("[TEST 5/5] Проверка загрузки Foundation Graybox и PlayerController...")
	var graybox_scene: PackedScene = load("res://scenes/testlabs/foundation_graybox.tscn")
	if graybox_scene == null:
		printerr("  [FAIL] Не удалось загрузить scenes/testlabs/foundation_graybox.tscn")
		errors += 1
	else:
		var graybox_inst := graybox_scene.instantiate()
		if graybox_inst:
			var player_node := graybox_inst.get_node_or_null("Player")
			if player_node and player_node is CharacterBody3D:
				print("  [PASS] Foundation Graybox и узел Player (CharacterBody3D) найдены и валидны.")
			else:
				printerr("  [FAIL] Узел Player не найден или не является CharacterBody3D")
				errors += 1
			graybox_inst.free()

func _finalize() -> void:
	print("==========================================================")
	if errors == 0:
		print(">>> ВСЕ 5 ТЕСТОВ SMOKE TEST ПРОЙДЕНЫ УСПЕШНО (0 ОШИБОК) <<<")
		print("==========================================================")
		quit(0)
	else:
		printerr(">>> SMOKE TEST ЗАВЕРШИЛСЯ С ОШИБКАМИ: %d <<<" % errors)
		print("==========================================================")
		quit(1)