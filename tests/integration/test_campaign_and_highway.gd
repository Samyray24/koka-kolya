extends SceneTree

# Автоматический интеграционный тест Открытого Мира и Кампании (Stage 6 / v0.7.0)
# Проверяет: GameManager, EnvironmentManager, VehicleRadio, шоссе, прорыв КПП №2 и победу у Телебашни

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

var highway_scene: Node = null
var van: VehicleBody3D = null
var player: CharacterBody3D = null
var barrier: Node3D = null
var terminal: Node3D = null
var victory_panel: Control = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup()
		3:
			_test_1_managers_and_environment()
		5:
			_test_2_highway_scene_instantiation()
		7:
			_test_3_vehicle_radio()
		9:
			_test_4_checkpoint_breach()
		11:
			_test_5_broadcast_and_campaign_victory()
		13:
			_finalize()
			return true
	return false

func _setup() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: CAMPAIGN & HIGHWAY HUB (STAGE 6 / v0.7.0) <<<")
	print("=======================================================================\n")

func _test_1_managers_and_environment() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	var em: Node = root.get_node_or_null("EnvironmentManager")

	if not gm or not em:
		print("[FAIL] Test 1: Autoloads GameManager или EnvironmentManager не найдены.")
		return

	# Проверка кредитов и репутации
	var initial_credits: int = gm.get("credits")
	gm.call("add_credits", 150)
	var new_credits: int = gm.get("credits")

	var initial_rep: int = gm.get("reputation")
	gm.call("add_reputation", 20)
	var new_rep: int = gm.get("reputation")

	# Проверка смены времени суток и погоды
	em.call("set_time", 14.0) # Полдень
	var noon_color: Color = em.call("get_ambient_light_color")
	em.call("set_weather", "NEON_RAIN")
	var current_weather: int = em.get("current_weather")

	var credits_ok: bool = new_credits == initial_credits + 150
	var rep_ok: bool = new_rep == initial_rep + 20
	var time_ok: bool = is_equal_approx(em.get("time_of_day"), 14.0) and noon_color.r > 0.8
	var weather_ok: bool = current_weather == 2 # WeatherType.NEON_RAIN

	if credits_ok and rep_ok and time_ok and weather_ok:
		print("[PASS] Test 1: GameManager и EnvironmentManager успешно управляют экономикой, временем суток и неоновым дождем.")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Ошибка параметров окружения или экономики (credits_ok=%s, rep_ok=%s, time_ok=%s, weather_ok=%s)." % [credits_ok, rep_ok, time_ok, weather_ok])

func _test_2_highway_scene_instantiation() -> void:
	var scene_res: PackedScene = load("res://scenes/levels/city_highway.tscn")
	if not scene_res:
		print("[FAIL] Test 2: Не удалось загрузить scenes/levels/city_highway.tscn")
		return

	highway_scene = scene_res.instantiate()
	root.add_child(highway_scene)

	player = highway_scene.get_node_or_null("Player")
	van = highway_scene.get_node_or_null("DeliveryVan")
	var drone: Node = highway_scene.get_node_or_null("BubbleDrone")
	var guard: Node = highway_scene.get_node_or_null("GuardAI")
	var checkpoint: Area3D = highway_scene.get_node_or_null("Highway/CheckpointTrigger")
	barrier = highway_scene.get_node_or_null("Highway/SecurityBarrier")
	var cctv: Node = highway_scene.get_node_or_null("Highway/CCTV_Checkpoint")
	var tower: Node = highway_scene.get_node_or_null("CityPlaza/BroadcastTower")
	terminal = highway_scene.get_node_or_null("CityPlaza/BroadcastTower/BroadcastTerminal")
	victory_panel = highway_scene.get_node_or_null("HUD/VictoryPanel")

	if player and van and drone and guard and checkpoint and barrier and cctv and tower and terminal and victory_panel:
		print("[PASS] Test 2: Сцена CityHighway успешно инстанцирована со всеми элементами блокпоста и медиа-вышки.")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Отсутствуют необходимые компоненты на уровне CityHighway.")

func _test_3_vehicle_radio() -> void:
	if not van:
		print("[FAIL] Test 3: Фургон не найден.")
		return

	var radio: Node = van.get_node_or_null("VehicleRadio")
	if not radio:
		print("[FAIL] Test 3: VehicleRadio не обнаружено в delivery_van.")
		return

	var initial_station: String = radio.call("get_current_station")
	var station_1: String = radio.call("cycle_station")
	var is_playing_1: bool = radio.get("is_playing")

	var station_2: String = radio.call("cycle_station")
	var station_3: String = radio.call("cycle_station")
	var off_station: String = radio.call("cycle_station")
	var is_playing_off: bool = radio.get("is_playing")

	var station_cycle_ok: bool = initial_station == "Выключено" and station_1.contains("Радио Красноград") and is_playing_1 and off_station == "Выключено" and not is_playing_off

	if station_cycle_ok:
		print("[PASS] Test 3: Автомобильное радио фургона корректно переключает волны вещания Краснограда.")
		passed_count += 1
	else:
		print("[FAIL] Test 3: Сбой в логике VehicleRadio (initial=%s, st1=%s, playing=%s, off=%s)." % [initial_station, station_1, is_playing_1, off_station])

func _test_4_checkpoint_breach() -> void:
	if not highway_scene or not barrier or not van:
		print("[FAIL] Test 4: CityHighway или компоненты блокпоста не найдены.")
		return

	# Имитируем въезд фургона в зону КПП
	highway_scene.call("_on_checkpoint_entered", van)
	var stage_after_cp: int = highway_scene.get("stage")

	# Взламываем и открываем шлагбаум
	barrier.call("unlock_and_open")
	var is_barrier_open: bool = barrier.get("is_open")
	var stage_after_barrier: int = highway_scene.get("stage")

	if stage_after_cp == 2 and is_barrier_open and stage_after_barrier == 3:
		print("[PASS] Test 4: Зона КПП №2 пройдена, электронный шлагбаум взломан, стадия квеста обновлена (Stage 3).")
		passed_count += 1
	else:
		print("[FAIL] Test 4: Ошибка прорыва блокпоста (stage_cp=%d, open=%s, stage_bar=%d)." % [stage_after_cp, is_barrier_open, stage_after_barrier])

func _test_5_broadcast_and_campaign_victory() -> void:
	if not highway_scene or not terminal or not victory_panel:
		print("[FAIL] Test 5: Компоненты медиа-вышки не найдены.")
		return

	var gm: Node = root.get_node_or_null("GameManager")
	var credits_before: int = gm.get("credits") if gm else 0

	# Взлом медиа-терминала телебашни
	terminal.call("override_plant")
	var is_overridden: bool = terminal.get("is_overridden")

	# Завершение кампании
	var is_victory_visible: bool = victory_panel.visible
	var campaign_archived: bool = gm.completed_missions.has("operation_free_krasnograd") if gm else false
	var credits_rewarded: bool = gm.get("credits") >= credits_before + 500 if gm else false

	if is_overridden and is_victory_visible and campaign_archived and credits_rewarded:
		print("[PASS] Test 5: Манифест свободы Кока-Коли транслирован на город, кампания завершена, награда 500 КР начислена!")
		passed_count += 1
	else:
		print("[FAIL] Test 5: Сбой трансляции манифеста (overridden=%s, victory=%s, archived=%s, rewarded=%s)." % [is_overridden, is_victory_visible, campaign_archived, credits_rewarded])

func _finalize() -> void:
	if highway_scene:
		root.remove_child(highway_scene)
		highway_scene.free()

	print("\n-----------------------------------------------------------------------")
	print(">>> РЕЗУЛЬТАТ: %d/%d ТЕСТОВ ПРОЙДЕНО" % [passed_count, total_count])
	print("-----------------------------------------------------------------------\n")
	if passed_count == total_count:
		print(">>> СТАТУС: 100% УСПЕХ — STAGE 6 OPEN WORLD & CAMPAIGN ПОЛНОСТЬЮ ГОТОВ! <<<\n")
	else:
		printerr(">>> СТАТУС: ОБНАРУЖЕНЫ ОШИБКИ В СЦЕНАРИИ КАМПАНИИ! <<<\n")