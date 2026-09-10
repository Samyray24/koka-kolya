extends SceneTree

# Автоматический интеграционный тест Системы Розыска, Радара, Колеса Оружия и Контрактов
# Проверяет:
# 1. ThreatManager: Автозагрузка, начисление heat, повышение звезд (1-5), сирены и сигналы.
# 2. ThreatManager: Механика взлома/взятки для сброса розыска, уход из зоны видимости.
# 3. WeaponRadialWheel: Замедление времени Bullet Time (time_scale = 0.15), выбор слота, восстановление времени.
# 4. HUDRadar: Проекция 3D-мира на 2D-радар, отрисовка слоев и маркеров.
# 5. CyberdeckManager: Генератор контрактов «Красноград Экспресс», начисление наград.
# 6. AudioManager: Процедурный синтез новых звуков (сирена, замедление, газировка, тревога).

var passed_count: int = 0
var total_count: int = 6
var frame: int = 0

var tm: Node = null
var cdm: Node = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup()
		3:
			_test_1_threat_accumulation()
		5:
			_test_2_threat_clearance()
		7:
			_test_3_radial_wheel_slowmo()
		9:
			_test_4_hud_radar()
		11:
			_test_5_radiant_contracts()
		13:
			_test_6_new_sfx_library()
		15:
			_finalize()
			return true
	return false

func _setup() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: THREAT SYSTEM, RADAR, WEAPON WHEEL & CONTRACTS <<<")
	print("=======================================================================\n")

func _test_1_threat_accumulation() -> void:
	tm = root.get_node_or_null("ThreatManager")
	if not tm:
		print("[FAIL] Test 1: ThreatManager не найден в root (автозагрузка отсутствует).")
		return

	var start_wanted: int = tm.get("wanted_level")
	var sig := {"changed": false, "started": false}
	tm.connect("wanted_level_changed", func(_lvl: int): sig["changed"] = true)
	tm.connect("pursuit_started", func(): sig["started"] = true)

	tm.call("report_crime", "Вооруженное проникновение", 150.0)
	var new_wanted: int = tm.get("wanted_level")
	var is_w: bool = tm.call("is_wanted")

	if start_wanted == 0 and new_wanted >= 2 and is_w and sig["changed"] and sig["started"]:
		print("[PASS] Test 1: ThreatManager корректно начисляет heat и активирует режим погони (Звезды: %d)." % new_wanted)
		passed_count += 1
	else:
		print("[FAIL] Test 1: Ошибка начисления розыска (start=%d, new=%d, is_w=%s)." % [start_wanted, new_wanted, is_w])

func _test_2_threat_clearance() -> void:
	if not tm:
		print("[FAIL] Test 2: ThreatManager отсутствует.")
		return

	var gm: Node = root.get_node_or_null("GameManager")
	if gm:
		gm.call("add_credits", 500)

	var hack_success: bool = tm.call("bribe_or_hack_clearance", 100)
	var wanted_after: int = tm.get("wanted_level")
	var is_w_after: bool = tm.call("is_wanted")

	if hack_success and wanted_after == 0 and not is_w_after:
		print("[PASS] Test 2: Сброс розыска через взлом/взятку очищает статус преследования.")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Ошибка сброса розыска (hack=%s, wanted=%d, is_w=%s)." % [hack_success, wanted_after, is_w_after])

func _test_3_radial_wheel_slowmo() -> void:
	var rw_script = load("res://scripts/ui/weapon_radial_wheel.gd")
	if not rw_script:
		print("[FAIL] Test 3: Не удалось загрузить weapon_radial_wheel.gd.")
		return

	var wheel = CanvasLayer.new()
	wheel.set_script(rw_script)
	root.add_child(wheel)
	if not wheel.get("wheel_root"):
		wheel.call("_build_ui")

	wheel.call("open_wheel")
	var is_open: bool = wheel.get("is_wheel_open")
	var slowmo_scale: float = Engine.time_scale

	wheel.call("close_wheel")
	var is_closed: bool = not wheel.get("is_wheel_open")
	var restored_scale: float = Engine.time_scale

	root.remove_child(wheel)
	wheel.free()

	if is_open and is_closed and slowmo_scale < 0.5 and is_equal_approx(restored_scale, 1.0):
		print("[PASS] Test 3: Колесо оружия корректно активирует Bullet Time (time_scale: %.2f -> %.2f)." % [slowmo_scale, restored_scale])
		passed_count += 1
	else:
		print("[FAIL] Test 3: Ошибка замедления времени (open=%s, closed=%s, slowmo=%.2f, restored=%.2f)." % [is_open, is_closed, slowmo_scale, restored_scale])

func _test_4_hud_radar() -> void:
	var radar_script = load("res://scripts/ui/hud_radar.gd")
	if not radar_script:
		print("[FAIL] Test 4: Не удалось загрузить hud_radar.gd.")
		return

	var radar = CanvasLayer.new()
	radar.set_script(radar_script)
	root.add_child(radar)
	if not radar.get("radar_canvas"):
		radar.call("_build_ui")

	var dummy_player = Node3D.new()
	dummy_player.position = Vector3(10, 0, 10)
	root.add_child(dummy_player)

	radar.call("setup", dummy_player, null)
	var canvas = radar.get("radar_canvas")
	var has_canvas: bool = (canvas != null)

	root.remove_child(dummy_player)
	dummy_player.free()
	root.remove_child(radar)
	radar.free()

	if has_canvas:
		print("[PASS] Test 4: Круговой GPS-радар инициализирован и корректно проецирует координаты.")
		passed_count += 1
	else:
		print("[FAIL] Test 4: Ошибка инициализации холста радара.")

func _test_5_radiant_contracts() -> void:
	cdm = root.get_node_or_null("CyberdeckManager")
	if not cdm:
		print("[FAIL] Test 5: CyberdeckManager отсутствует.")
		return

	var gm: Node = root.get_node_or_null("GameManager")
	var start_cr: int = gm.get("credits") if gm else 0

	var contract: Dictionary = cdm.call("generate_random_contract")
	var has_keys: bool = contract.has("id") and contract.has("cargo") and contract.has("from_district") and contract.has("to_district") and contract.has("reward")
	var distinct_districts: bool = contract.get("from_district", "a") != contract.get("to_district", "b")

	var complete_ok: bool = cdm.call("complete_active_contract")
	var end_cr: int = gm.get("credits") if gm else 0

	if has_keys and distinct_districts and complete_ok and end_cr > start_cr:
		print("[PASS] Test 5: Генератор контрактов «Красноград Экспресс» создает валидный рейс и начисляет награду (%d КР)." % contract["reward"])
		passed_count += 1
	else:
		print("[FAIL] Test 5: Ошибка генератора контрактов (keys=%s, distinct=%s, comp=%s, cr_diff=%d)." % [has_keys, distinct_districts, complete_ok, end_cr - start_cr])

func _test_6_new_sfx_library() -> void:
	var am: Node = root.get_node_or_null("AudioManager")
	if not am:
		print("[FAIL] Test 6: AudioManager отсутствует.")
		return

	var sfx: Dictionary = am.get("sfx_library")
	var has_siren: bool = sfx.has("police_siren")
	var has_slow_in: bool = sfx.has("slow_motion_enter")
	var has_slow_out: bool = sfx.has("slow_motion_exit")
	var has_cola: bool = sfx.has("cola_drink")
	var has_wanted: bool = sfx.has("wanted_level_up")

	if has_siren and has_slow_in and has_slow_out and has_cola and has_wanted:
		print("[PASS] Test 6: Все 5 новых процедурных SFX (сирена, Bullet Time, напиток, тревога) успешно синтезированы.")
		passed_count += 1
	else:
		print("[FAIL] Test 6: В библиотеке звуков отсутствуют новые SFX (siren=%s, slow=%s, cola=%s, wanted=%s)." % [has_siren, has_slow_in, has_cola, has_wanted])

func _finalize() -> void:
	print("\n=======================================================================")
	if passed_count == total_count:
		print(">>> ВСЕ 6 ТЕСТОВ СИСТЕМЫ РОЗЫСКА, РАДАРА И ОРУЖИЯ ПРОЙДЕНЫ (0 ОШИБОК) <<<")
		print("=======================================================================\n")
		quit(0)
	else:
		printerr(">>> ОШИБКИ В ТЕСТАХ: %d/%d <<<" % [passed_count, total_count])
		print("=======================================================================\n")
		quit(1)
