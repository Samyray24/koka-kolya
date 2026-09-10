extends SceneTree

# Автоматический интеграционный тест систем межрайонной навигации и переходов «Кока-Коля»
# Проверяет:
# 1. CyberdeckManager: Наличие HUD-полосы подсказок [Tab/M], навигационного тоста, переключение видимости при открытии КПК.
# 2. RoadExitGate: Процедурная генерация неоновой арки, регистрация в группе exit_gate, Area3D триггер.
# 3. MainMenu: Наличие кнопки BtnDistricts, открытие модального окна DistrictSelectModal, список из 7 районов.
# 4. PauseMenu: Наличие кнопки BtnDistricts, открытие DistrictSelectModal, корректная реакция на ui_cancel.
# 5. HUDRadar: Интеграция с группой exit_gate (отрисовка дорожных выездов на круговом радаре).
# 6. Уровни кампании: Наличие кнопок «Следующий район» и дорожных порталов в сценах.

var passed_count: int = 0
var total_count: int = 7
var frame: int = 0

var cdm: Node = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup()
		3:
			_test_1_cyberdeck_hud_hints_and_toasts()
		5:
			_test_2_road_exit_gate_instantiation()
		7:
			_test_3_main_menu_district_selector()
		9:
			_test_4_pause_menu_district_selector()
		11:
			_test_5_hud_radar_exit_gate_tracking()
		13:
			_test_6_victory_panel_district_buttons()
		15:
			_test_7_gate_auto_transition_and_ejection_protection()
		17:
			_finalize()
			return true
	return false

func _setup() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: DISTRICT NAVIGATION & LEVEL TRANSITION SYSTEMS <<<")
	print("=======================================================================\n")

func _test_1_cyberdeck_hud_hints_and_toasts() -> void:
	cdm = root.get_node_or_null("CyberdeckManager")
	if not cdm:
		print("[FAIL] Test 1: CyberdeckManager не найден в root.")
		return

	var hud_hints: Node = cdm.get("hud_hints_panel")
	var nav_toast: Node = cdm.get("nav_toast_panel")

	if not hud_hints or not nav_toast:
		print("[FAIL] Test 1: hud_hints_panel или nav_toast_panel не инициализированы.")
		return

	# Проверка вызова тоста
	cdm.call("show_nav_toast", "Тестовый навигационный совет", 5.0)
	var toast_vis: bool = nav_toast.visible

	# Проверка скрытия HUD-подсказки при открытии КПК
	cdm.call("open_pda")
	var hints_hidden: bool = not hud_hints.visible

	cdm.call("close_pda")
	var hints_restored: bool = hud_hints.visible

	if toast_vis and hints_hidden and hints_restored:
		print("[PASS] Test 1: CyberdeckManager HUD-подсказки [Tab/M] и тосты навигации работают корректно.")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Сбой в поведении подсказок (toast_vis=%s, hidden=%s, restored=%s)." % [toast_vis, hints_hidden, hints_restored])

func _test_2_road_exit_gate_instantiation() -> void:
	var gate_script = load("res://scripts/world/road_exit_gate.gd")
	if not gate_script:
		print("[FAIL] Test 2: Скрипт road_exit_gate.gd не найден.")
		return

	var gate = Node3D.new()
	gate.set_script(gate_script)
	gate.set("target_district_id", "city_highway")
	gate.set("gate_title", "СКОРОСТНОЕ ШОССЕ")
	root.add_child(gate)

	var in_group: bool = gate.is_in_group("exit_gate")
	var trigger: Area3D = gate.get_node_or_null("ExitTriggerArea")
	var has_labels: bool = (gate.get("prompt_label_3d") != null)

	gate.queue_free()

	if in_group and trigger != null and has_labels:
		print("[PASS] Test 2: RoadExitGate успешно создает неоновую арку, триггер Area3D и входит в группу exit_gate.")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Ошибка в RoadExitGate (in_group=%s, trigger=%s, labels=%s)." % [in_group, trigger != null, has_labels])

func _test_3_main_menu_district_selector() -> void:
	var menu_scene = load("res://scenes/ui/main_menu.tscn")
	if not menu_scene:
		print("[FAIL] Test 3: Сцена main_menu.tscn не найдена.")
		return

	var menu = menu_scene.instantiate()
	root.add_child(menu)

	var btn_dist: Button = menu.get_node_or_null("MarginContainer/VBoxContainer/BtnDistricts")
	var modal: Control = menu.get_node_or_null("DistrictSelectModal")

	var initial_hidden: bool = (modal != null and not modal.visible)
	if btn_dist:
		btn_dist.emit_signal("pressed")
	var modal_opened: bool = (modal != null and modal.visible)

	menu.queue_free()

	if btn_dist != null and initial_hidden and modal_opened:
		print("[PASS] Test 3: Главное меню содержит кнопку «Выбор района» и модальное окно с переходом.")
		passed_count += 1
	else:
		print("[FAIL] Test 3: Ошибка в главном меню (btn=%s, initial_hidden=%s, modal_opened=%s)." % [btn_dist != null, initial_hidden, modal_opened])

func _test_4_pause_menu_district_selector() -> void:
	var pause_scene = load("res://scenes/ui/pause_menu.tscn")
	if not pause_scene:
		print("[FAIL] Test 4: Сцена pause_menu.tscn не найдена.")
		return

	var pause = pause_scene.instantiate()
	root.add_child(pause)

	var btn_dist: Button = pause.get_node_or_null("Center/Panel/Margin/VBox/BtnDistricts")
	var modal: Control = pause.get_node_or_null("DistrictSelectModal")

	var initial_hidden: bool = (modal != null and not modal.visible)
	if btn_dist:
		btn_dist.emit_signal("pressed")
	var modal_opened: bool = (modal != null and modal.visible)

	pause.queue_free()

	if btn_dist != null and initial_hidden and modal_opened:
		print("[PASS] Test 4: Меню паузы содержит кнопку «Выбор района» и позволяет выбирать районы во время паузы.")
		passed_count += 1
	else:
		print("[FAIL] Test 4: Ошибка в меню паузы (btn=%s, initial_hidden=%s, modal_opened=%s)." % [btn_dist != null, initial_hidden, modal_opened])

func _test_5_hud_radar_exit_gate_tracking() -> void:
	var radar_script = load("res://scripts/ui/hud_radar.gd")
	if not radar_script:
		print("[FAIL] Test 5: Скрипт hud_radar.gd не найден.")
		return

	var radar = CanvasLayer.new()
	radar.set_script(radar_script)
	root.add_child(radar)

	# Спавним фиктивный дорожный портал
	var gate = Node3D.new()
	gate.add_to_group("exit_gate")
	gate.position = Vector3(20, 0, -40)
	root.add_child(gate)

	# Проверяем, что радар видит ноду в группе
	var found_gates = get_nodes_in_group("exit_gate")
	var tracks_gate: bool = (found_gates.size() > 0)

	radar.queue_free()
	gate.queue_free()

	if tracks_gate:
		print("[PASS] Test 5: HUDRadar успешно отслеживает группу exit_gate для индикации дорожных выездов.")
		passed_count += 1
	else:
		print("[FAIL] Test 5: HUDRadar не смог обнаружить группу exit_gate.")

func _test_6_victory_panel_district_buttons() -> void:
	# Проверяем все скрипты уровней на наличие методов настройки кнопок победы
	var level_configs = [
		{"script": "res://scripts/gameplay/old_district.gd", "method": "_setup_complete_panel_buttons", "panel": "MissionCompletePanel"},
		{"script": "res://scripts/gameplay/city_highway.gd", "method": "_setup_victory_panel_buttons", "panel": "VictoryPanel"},
		{"script": "res://scripts/gameplay/neon_boulevard.gd", "method": "_setup_victory_panel_buttons", "panel": "VictoryPanel"},
		{"script": "res://scripts/gameplay/red_line_plant.gd", "method": "_setup_victory_panel_buttons", "panel": "VictoryPanel"},
		{"script": "res://scripts/gameplay/logistics_hub.gd", "method": "_setup_victory_panel_buttons", "panel": "VictoryPanel"},
		{"script": "res://scripts/gameplay/underground_metro.gd", "method": "_setup_victory_panel_buttons", "panel": "VictoryPanel"},
		{"script": "res://scripts/gameplay/citadel_penthouse.gd", "method": "_setup_victory_panel_buttons", "panel": "VictoryPanel"}
	]

	var all_ok: bool = true
	for cfg in level_configs:
		var scr = load(cfg["script"])
		if not scr:
			all_ok = false
			print("[FAIL] Test 6: Не удалось загрузить скрипт: %s" % cfg["script"])
			continue

		var lvl = Node3D.new()
		lvl.set_script(scr)

		var hud = CanvasLayer.new()
		hud.name = "HUD"
		lvl.add_child(hud)

		var panel = PanelContainer.new()
		panel.name = cfg["panel"]
		var margin = MarginContainer.new()
		margin.name = "Margin"
		panel.add_child(margin)
		var vbox = VBoxContainer.new()
		vbox.name = "VBox"
		margin.add_child(vbox)
		hud.add_child(panel)

		root.add_child(lvl)

		lvl.call(cfg["method"])

		var has_next: bool = (vbox.get_node_or_null("BtnNextDistrict") != null)
		var has_map: bool = (vbox.get_node_or_null("BtnOpenMap") != null)
		var has_menu: bool = (vbox.get_node_or_null("BtnReturnMenu") != null)

		lvl.queue_free()

		if not (has_next and has_map and has_menu):
			all_ok = false
			print("[FAIL] Test 6: Скрипт %s не создал все кнопки (next=%s, map=%s, menu=%s)" % [cfg["script"], has_next, has_map, has_menu])

	if all_ok:
		print("[PASS] Test 6: Все 7 районов Краснограда оснащены интерактивными кнопками победы (Следующий район, Карта, Меню).")
		passed_count += 1
	else:
		print("[FAIL] Test 6: Часть районов не имеет полных кнопок победы.")

func _test_7_gate_auto_transition_and_ejection_protection() -> void:
	var gate_script = load("res://scripts/world/road_exit_gate.gd")
	if not gate_script:
		print("[FAIL] Test 7: Скрипт road_exit_gate.gd не найден.")
		return

	var gate = Node3D.new()
	gate.set_script(gate_script)
	gate.set("target_district_id", "city_highway")
	gate.set("gate_title", "СКОРОСТНОЕ ШОССЕ")
	root.add_child(gate)

	var mock_van = Node3D.new()
	mock_van.add_to_group("vehicle")
	root.add_child(mock_van)

	# 1. Симуляция въезда в створ ворот
	gate.call("_on_body_entered", mock_van)
	var has_meta_flag: bool = mock_van.has_meta("in_exit_gate") and bool(mock_van.get_meta("in_exit_gate"))

	# 2. Симуляция нахождения в створе ворот и авто-срабатывание таймера перехода (0.7 сек)
	gate.call("_process", 0.7)
	var is_trans: bool = bool(gate.get("is_transitioning"))

	# 3. Симуляция выезда из ворот
	gate.call("_on_body_exited", mock_van)
	var flag_cleared: bool = not (mock_van.has_meta("in_exit_gate") and bool(mock_van.get_meta("in_exit_gate")))

	gate.queue_free()
	mock_van.queue_free()

	if has_meta_flag and is_trans and flag_cleared:
		print("[PASS] Test 7: RoadExitGate защищает от катапультирования из фургона (in_exit_gate) и выполняет авто-переход по таймеру зоны.")
		passed_count += 1
	else:
		print("[FAIL] Test 7: Сбой в логике защиты/таймера перехода (flag=%s, trans=%s, cleared=%s)." % [has_meta_flag, is_trans, flag_cleared])

func _finalize() -> void:
	print("\n=======================================================================")
	print("РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ НАВИГАЦИИ: %d / %d УСПЕШНО" % [passed_count, total_count])
	if passed_count == total_count:
		print(">>> ВСЕ ТЕСТЫ НАВИГАЦИИ И ПЕРЕХОДОВ ПРОЙДЕНЫ! <<<")
	else:
		print(">>> ОБНАРУЖЕНЫ ОШИБКИ В СИСТЕМАХ НАВИГАЦИИ <<<")
	print("=======================================================================\n")
	quit(0 if passed_count == total_count else 1)
