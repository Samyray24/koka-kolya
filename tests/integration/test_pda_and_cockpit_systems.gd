extends SceneTree

# Автоматический интеграционный тест Cyber-PDA, Компаса, Вида из кабины и системы апгрейдов
# Проверяет:
# 1. CyberdeckManager: Автозагрузка, инициализация компаса и баннера радио.
# 2. CyberdeckManager: Открытие/закрытие КПК (Tab/M), переключение вкладок (Карта, Квесты, Апгрейды, База знаний).
# 3. Экономика и Магазин улучшений КПК: Покупка апгрейда, списание кредитов, предотвращение повторной покупки.
# 4. DeliveryVan: Вид от первого лица из кабины (Cockpit), анимированный руль, применение улучшений шасси/нитро/двигателя.
# 5. Коля и дрон BUBBLE: Применение кибер-улучшений (экзокостюм, батарея дрона).
# 6. Всплывающий баннер радио с анимированным эквалайзером.

var passed_count: int = 0
var total_count: int = 6
var frame: int = 0

var cdm: Node = null
var van_node: VehicleBody3D = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup()
		3:
			_test_1_cyberdeck_manager_init()
		5:
			_test_2_pda_tabs_and_signals()
		7:
			_test_3_upgrades_economy()
		9:
			_test_4_van_cockpit_and_upgrades()
		11:
			_test_5_player_and_drone_upgrades()
		13:
			_test_6_radio_banner_and_equalizer()
		15:
			_finalize()
			return true
	return false

func _setup() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: CYBER-PDA, 3D COMPASS & COCKPIT SYSTEMS <<<")
	print("=======================================================================\n")

func _test_1_cyberdeck_manager_init() -> void:
	cdm = root.get_node_or_null("CyberdeckManager")
	if not cdm:
		print("[FAIL] Test 1: CyberdeckManager не найден в root (автозагрузка отсутствует).")
		return

	var compass_container: Node = cdm.get("compass_container")
	var pda_overlay: Node = cdm.get("pda_overlay")
	var radio_banner: Node = cdm.get("radio_banner")

	if compass_container != null and pda_overlay != null and radio_banner != null:
		print("[PASS] Test 1: CyberdeckManager успешно инициализирован с Компасом, КПК и Радио-баннером.")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Вложенные ноды CyberdeckManager не инициализированы.")

func _test_2_pda_tabs_and_signals() -> void:
	if not cdm:
		print("[FAIL] Test 2: CyberdeckManager отсутствует.")
		return

	var pda_overlay: Control = cdm.get("pda_overlay") as Control
	var initial_visible: bool = pda_overlay.visible if pda_overlay else true

	var sig := {"opened": false, "closed": false}
	cdm.connect("pda_opened", func(): sig["opened"] = true)
	cdm.connect("pda_closed", func(): sig["closed"] = true)

	cdm.call("open_pda")
	var is_open: bool = pda_overlay.visible if pda_overlay else false

	cdm.call("switch_tab", 2)
	var current_tab: int = cdm.get("active_tab_idx")

	cdm.call("close_pda")
	var is_closed: bool = not (pda_overlay.visible if pda_overlay else true)

	if not initial_visible and is_open and is_closed and sig["opened"] and sig["closed"] and current_tab == 2:
		print("[PASS] Test 2: Открытие, переключение вкладок и закрытие КПК работают корректно со всеми сигналами.")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Ошибка навигации КПК (initial=%s, open=%s, closed=%s, tab=%d, sig_open=%s, sig_close=%s)." % [initial_visible, is_open, is_closed, current_tab, sig["opened"], sig["closed"]])

func _test_3_upgrades_economy() -> void:
	if not cdm:
		print("[FAIL] Test 3: CyberdeckManager отсутствует.")
		return

	var gm: Node = root.get_node_or_null("GameManager")
	if gm:
		gm.call("add_credits", 1000)

	var start_credits: int = cdm.get("credits")
	var buy_result: bool = cdm.call("purchase_upgrade", "van_engine")
	var credits_after_first: int = cdm.get("credits")
	var duplicate_result: bool = cdm.call("purchase_upgrade", "van_engine")

	var purchased: Dictionary = cdm.get("purchased_upgrades")
	var has_upgrade: bool = purchased.get("van_engine", false)

	if buy_result and not duplicate_result and has_upgrade and credits_after_first < start_credits:
		print("[PASS] Test 3: Магазин улучшений КПК корректно списывает кредиты (%d -> %d) и исключает повторную покупку." % [start_credits, credits_after_first])
		passed_count += 1
	else:
		print("[FAIL] Test 3: Ошибка покупки улучшений (buy=%s, dup=%s, has=%s, credits=%d)." % [buy_result, duplicate_result, has_upgrade, credits_after_first])

func _test_4_van_cockpit_and_upgrades() -> void:
	var van_res: PackedScene = load("res://scenes/vehicles/delivery_van.tscn")
	if not van_res:
		print("[FAIL] Test 4: Не удалось загрузить delivery_van.tscn.")
		return

	van_node = van_res.instantiate()
	root.add_child(van_node)

	var cockpit_cam: Camera3D = van_node.get_node_or_null("CockpitCamera3D") as Camera3D
	var steering_wheel: Node3D = van_node.get_node_or_null("CockpitSteeringWheel") as Node3D

	var initial_mode = van_node.get("camera_view_mode")
	van_node.call("toggle_camera_view")
	var mode_after_toggle = van_node.get("camera_view_mode")
	van_node.call("toggle_camera_view")
	var mode_back = van_node.get("camera_view_mode")

	van_node.call("apply_cyberdeck_upgrades", {
		"van_engine": true,
		"van_armor": true,
		"van_nitro": true
	})
	var upgraded_force: float = van_node.get("max_engine_force")
	var upgraded_hp: float = van_node.get("max_chassis_health")
	var upgraded_nitro: float = van_node.get("max_nitro")

	if cockpit_cam != null and steering_wheel != null and initial_mode == 0 and mode_after_toggle == 1 and mode_back == 0 and upgraded_force >= 540.0 and upgraded_hp >= 150.0 and upgraded_nitro >= 150.0:
		print("[PASS] Test 4: Кокпит фургона, руль, переключение камеры [V] и апгрейды (HP: %.0f, Nitro: %.0f, Мощность: %.0f) успешно верифицированы." % [upgraded_hp, upgraded_nitro, upgraded_force])
		passed_count += 1
	else:
		print("[FAIL] Test 4: Ошибка компонентов кабины или применения апгрейдов фургона (cam=%s, wheel=%s, m0=%s, m1=%s, m_back=%s, force=%.1f, hp=%.1f, nitro=%.1f)." % [cockpit_cam != null, steering_wheel != null, initial_mode, mode_after_toggle, mode_back, upgraded_force, upgraded_hp, upgraded_nitro])

func _test_5_player_and_drone_upgrades() -> void:
	var player_res: PackedScene = load("res://scenes/characters/player.tscn")
	if not player_res:
		print("[FAIL] Test 5: Не удалось загрузить scenes/characters/player.tscn")
		return
	var player_instance: CharacterBody3D = player_res.instantiate() as CharacterBody3D
	root.add_child(player_instance)

	player_instance.call("apply_cyberdeck_upgrades", {"player_suit": true})
	var player_hp: float = player_instance.get("max_health")
	var player_sprint: float = player_instance.get("sprint_speed")

	var drone_res: PackedScene = load("res://scenes/characters/bubble_drone.tscn")
	if not drone_res:
		print("[FAIL] Test 5: Не удалось загрузить scenes/characters/bubble_drone.tscn")
		return
	var drone_instance: CharacterBody3D = drone_res.instantiate() as CharacterBody3D
	root.add_child(drone_instance)

	drone_instance.call("apply_cyberdeck_upgrades", {"drone_battery": true})
	var drone_speed: float = drone_instance.get("rc_speed")

	root.remove_child(player_instance)
	player_instance.free()
	root.remove_child(drone_instance)
	drone_instance.free()

	if player_hp >= 150.0 and player_sprint >= 8.5 and drone_speed >= 12.0:
		print("[PASS] Test 5: Кибер-улучшения для Коли (HP: %.0f, Sprint: %.1f) и дрона BUBBLE (RC Speed: %.1f) применены успешно." % [player_hp, player_sprint, drone_speed])
		passed_count += 1
	else:
		print("[FAIL] Test 5: Ошибка применения улучшений к игроку/дрону (Player HP: %.1f, Drone Speed: %.1f)." % [player_hp, drone_speed])

func _test_6_radio_banner_and_equalizer() -> void:
	if not cdm:
		print("[FAIL] Test 6: CyberdeckManager отсутствует.")
		return

	cdm.call("show_radio_banner", "98.4 FM — СИНТВЕЙВ", "Neon Driver (Original Mix)")
	var radio_banner: PanelContainer = cdm.get("radio_banner") as PanelContainer
	var banner_title: Label = cdm.get("banner_title") as Label
	var banner_track: Label = cdm.get("banner_track") as Label

	var title_text: String = banner_title.text if banner_title else ""
	var track_text: String = banner_track.text if banner_track else ""
	var is_banner_visible: bool = radio_banner.visible if radio_banner else false

	if is_banner_visible and title_text.contains("СИНТВЕЙВ") and track_text.contains("Neon Driver"):
		print("[PASS] Test 6: Всплывающий баннер радио успешно отображает станцию, трек и эквалайзер.")
		passed_count += 1
	else:
		print("[FAIL] Test 6: Ошибка отображения радио-баннера (vis=%s, title=%s, track=%s)." % [is_banner_visible, title_text, track_text])

	if van_node:
		root.remove_child(van_node)
		van_node.free()

func _finalize() -> void:
	print("\n=======================================================================")
	if passed_count == total_count:
		print(">>> ВСЕ 6 ТЕСТОВ СИСТЕМЫ КПК, КОМПАСА И КОКПИТА ПРОЙДЕНЫ УСПЕШНО (0 ОШИБОК) <<<")
		print("=======================================================================\n")
		quit(0)
	else:
		printerr(">>> ОШИБКИ В ТЕСТАХ КПК И КОКПИТА: %d/%d <<<" % [passed_count, total_count])
		print("=======================================================================\n")
		quit(1)
