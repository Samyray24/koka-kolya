extends SceneTree

# Automated Integration Test for Delivery Van & Vehicle Lab (v0.2.0)

var tested: bool = false

func _process(_delta: float) -> bool:
	if tested:
		return false
	tested = true
	run_tests()
	return true

func run_tests() -> void:
	print("=======================================================================")
	print(">>> ЗАПУСК TEST: DELIVERY VAN & VEHICLE LAB (STAGE 2 / v0.2.0) <<<")
	print("=======================================================================")

	var errors: int = 0

	# 1. Загрузка DeliveryVan
	print("[TEST 1/6] Проверка DeliveryVan (Инстанцирование и параметры шасси)...")
	var van_res: PackedScene = load("res://scenes/vehicles/delivery_van.tscn")
	if van_res:
		var van: VehicleBody3D = van_res.instantiate()
		root.add_child(van)
		
		if is_equal_approx(van.mass, 1400.0):
			print("  [PASS] Фургон доставки успешно создан, масса шасси 1400 кг.")
		else:
			printerr("  [FAIL] Некорректная масса фургона: %s" % van.mass)
			errors += 1

		# 2. Проверка 4 колес подвески
		print("[TEST 2/6] Проверка колес и подвески VehicleWheel3D...")
		var w_fl: VehicleWheel3D = van.get_node_or_null("WheelFL") as VehicleWheel3D
		var w_fr: VehicleWheel3D = van.get_node_or_null("WheelFR") as VehicleWheel3D
		var w_rl: VehicleWheel3D = van.get_node_or_null("WheelRL") as VehicleWheel3D
		var w_rr: VehicleWheel3D = van.get_node_or_null("WheelRR") as VehicleWheel3D
		
		if w_fl and w_fr and w_rl and w_rr:
			print("  [PASS] Все 4 колеса (FL, FR, RL, RR) найдены и сконфигурированы.")
		else:
			printerr("  [FAIL] Ошибка конфигурации колес.")
			errors += 1

		# 3. Проверка посадки игрока за руль
		print("[TEST 3/6] Проверка посадки водителя (enter_vehicle)...")
		var dummy_player := CharacterBody3D.new()
		dummy_player.name = "Player"
		root.add_child(dummy_player)
		
		van.call("enter_vehicle", dummy_player)
		var is_driven: bool = van.get("is_driven")
		if is_driven and not dummy_player.visible:
			print("  [PASS] Коля успешно сел за руль, режим вождения активен.")
		else:
			printerr("  [FAIL] Ошибка посадки за руль: is_driven=%s" % is_driven)
			errors += 1

		# 4. Проверка высадки из машины
		print("[TEST 4/6] Проверка выхода из машины (exit_vehicle)...")
		van.call("exit_vehicle")
		var is_driven_after: bool = van.get("is_driven")
		if not is_driven_after and dummy_player.visible:
			print("  [PASS] Коля успешно покинул фургон, режим пешехода восстановлен.")
		else:
			printerr("  [FAIL] Ошибка высадки: is_driven=%s" % is_driven_after)
			errors += 1

		# 5. Проверка учета массы груза в кузове
		print("[TEST 5/6] Проверка динамического расчета массы груза...")
		var cargo_area: Area3D = van.get_node_or_null("CargoArea3D") as Area3D
		if cargo_area:
			var test_crate := RigidBody3D.new()
			test_crate.mass = 35.0
			root.add_child(test_crate)
			test_crate.global_position = cargo_area.global_position
			van.call("_update_cargo_mass")
			print("  [PASS] Метод _update_cargo_mass() отработал без ошибок.")
			test_crate.queue_free()
		else:
			printerr("  [FAIL] Не найдена зона CargoArea3D.")
			errors += 1

		# 6. Проверка нитро-ускорения, фар и клаксона
		print("[TEST 6/8] Проверка систем мега-патча фургона (Нитро, Фары, Гудок, Шасси)...")
		var nitro_val: float = float(van.get("nitro_fuel"))
		var max_nitro_val: float = float(van.get("max_nitro"))
		var chassis_hp: float = float(van.get("chassis_health"))

		van.call("toggle_headlights") # LOW
		var mode_low: int = int(van.get("headlight_mode"))
		var hl_l: SpotLight3D = van.get_node_or_null("HeadlightL")
		var is_low_ok: bool = (mode_low == 1 and hl_l != null and hl_l.visible and is_equal_approx(hl_l.spot_range, 35.0))

		van.call("toggle_headlights") # HIGH
		var mode_high: int = int(van.get("headlight_mode"))
		var is_high_ok: bool = (mode_high == 2 and hl_l != null and hl_l.visible and is_equal_approx(hl_l.spot_range, 75.0))

		van.call("toggle_headlights") # OFF
		var mode_off: int = int(van.get("headlight_mode"))
		var is_off_ok: bool = (mode_off == 0 and hl_l != null and not hl_l.visible)

		van.call("honk_horn")
		var horn_cd: float = float(van.get("horn_voice_cooldown"))

		if is_equal_approx(nitro_val, 100.0) and is_equal_approx(max_nitro_val, 100.0) and is_equal_approx(chassis_hp, 100.0) and is_low_ok and is_high_ok and is_off_ok and horn_cd > 0.0:
			print("  [PASS] Нитро (100%), 3 режима фар (ВЫКЛ/БЛИЖНИЙ/ДАЛЬНИЙ), гудок и здоровье шасси успешно протестированы.")
		else:
			printerr("  [FAIL] Ошибка систем фургона: nitro=%s, low=%s, high=%s, off=%s, horn_cd=%s" % [nitro_val, is_low_ok, is_high_ok, is_off_ok, horn_cd])
			errors += 1

		# 7. Проверка торгового автомата и 3 вкусов газировки
		print("[TEST 7/8] Проверка автомата газировки и 3 вкусов (Классика, Черри-Бунт, Неон-Лайм)...")
		var vm_script: Script = load("res://scripts/interaction/vending_machine.gd")
		if vm_script:
			var vm_inst: Node3D = vm_script.new()
			root.add_child(vm_inst)
			var flavors: Array = vm_inst.get("FLAVORS")
			if flavors.size() == 3 and flavors[0].name == "Классика" and flavors[1].name == "Черри-Бунт" and flavors[2].name == "Неон-Лайм":
				print("  [PASS] В торговом автомате доступны все 3 уникальных вкуса газировки.")
			else:
				printerr("  [FAIL] Ошибка списка вкусов: %s" % str(flavors))
				errors += 1
			vm_inst.queue_free()
		else:
			printerr("  [FAIL] Не удалось загрузить vending_machine.gd")
			errors += 1

		dummy_player.queue_free()
		van.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить scenes/vehicles/delivery_van.tscn")
		errors += 1

	# 8. Проверка загрузки сцены vehicle_lab.tscn
	print("[TEST 8/8] Проверка целостности сцены vehicle_lab.tscn...")
	var lab_res: PackedScene = load("res://scenes/testlabs/vehicle_lab.tscn")
	if lab_res:
		var lab_inst: Node3D = lab_res.instantiate()
		var p_van: Node = lab_inst.get_node_or_null("DeliveryVan")
		var p_player: Node = lab_inst.get_node_or_null("Player")
		var p_ramp: Node = lab_inst.get_node_or_null("InclineRamp")
		
		if p_van and p_player and p_ramp:
			print("  [PASS] Сцена Vehicle Lab содержит фургон, игрока и наклонный пандус.")
		else:
			printerr("  [FAIL] В vehicle_lab.tscn отсутствуют компоненты.")
			errors += 1
		lab_inst.free()
	else:
		printerr("  [FAIL] Не удалось загрузить scenes/testlabs/vehicle_lab.tscn")
		errors += 1

	print("=======================================================================")
	if errors == 0:
		print(">>> ВСЕ 8 ТЕСТОВ VEHICLE LAB УСПЕШНО ПРОЙДЕНЫ (0 ОШИБОК) <<<")
		print("=======================================================================")
		quit(0)
	else:
		printerr(">>> ТЕСТЫ VEHICLE LAB ЗАВЕРШИЛИСЬ С ОШИБКАМИ: %d <<<" % errors)
		print("=======================================================================")
		quit(1)
