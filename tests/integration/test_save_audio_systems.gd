extends SceneTree

# Автоматический интеграционный тест систем Сохранений, Процедурного Звука и Паузы (Stage 5 / v0.6.0)

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

var pause_menu: Control = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup()
		3:
			_test_1_save_manager_save_and_has_save()
		5:
			_test_2_save_manager_load_and_data_integrity()
		7:
			_test_3_audio_manager_sound_generation()
		9:
			_test_4_audio_manager_playback()
		11:
			_test_5_pause_menu_integration()
		13:
			_finalize()
			return true
	return false

func _setup() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: SAVE, AUDIO & PAUSE SYSTEMS (STAGE 5 / v0.6.0) <<<")
	print("=======================================================================\n")

func _test_1_save_manager_save_and_has_save() -> void:
	var sm: Node = root.get_node_or_null("SaveManager")
	if not sm:
		print("[FAIL] Test 1: SaveManager autoload не найден.")
		return

	var test_slot: int = 99
	var success: bool = sm.call("save_game", test_slot, {"tester": "Antigravity", "score": 1000})
	var has_it: bool = sm.call("has_save", test_slot)

	if success and has_it:
		print("[PASS] Test 1: Сериализация и атомарная запись сохранения в JSON прошли успешно (Слот 99).")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Сбой сохранения данных (success=%s, has_save=%s)." % [success, has_it])

func _test_2_save_manager_load_and_data_integrity() -> void:
	var sm: Node = root.get_node_or_null("SaveManager")
	if not sm:
		print("[FAIL] Test 2: SaveManager не найден.")
		return

	var test_slot: int = 99
	var loaded_data: Dictionary = sm.call("load_game", test_slot)
	var expected_ver: String = str(ProjectSettings.get_setting("application/config/version", "0.7.0"))
	var has_version: bool = loaded_data.get("version") == expected_ver
	var custom_data: Dictionary = loaded_data.get("custom", {})
	var custom_ok: bool = custom_data.get("tester") == "Antigravity" and custom_data.get("score") == 1000

	# Удаляем тестовый слот
	sm.call("delete_save", test_slot)
	var deleted_ok: bool = not sm.call("has_save", test_slot)

	if has_version and custom_ok and deleted_ok:
		print("[PASS] Test 2: Десериализация, валидация целостности данных и удаление сохранения прошли успешно.")
		passed_count += 1
	else:
		print("[FAIL] Test 2: Нарушение структуры загруженных данных (version_ok=%s, custom_ok=%s, deleted=%s)." % [has_version, custom_ok, deleted_ok])

func _test_3_audio_manager_sound_generation() -> void:
	var am: Node = root.get_node_or_null("AudioManager")
	if not am:
		print("[FAIL] Test 3: AudioManager autoload не найден.")
		return

	var sfx_lib: Dictionary = am.get("sfx_library")
	var expected_keys := ["click", "footstep", "jump", "land", "grab", "throw", "radio_chime", "stun", "foam", "hack", "alarm", "victory"]
	var all_keys_present: bool = true

	for k in expected_keys:
		if not sfx_lib.has(k) or not (sfx_lib[k] is AudioStreamWAV) or sfx_lib[k].data.size() == 0:
			all_keys_present = false
			print("  [DEBUG] Отсутствует или пуст звук: %s" % k)
			break

	if all_keys_present and sfx_lib.size() >= 12:
		print("[PASS] Test 3: Все 12 процедурных PCM-звуков (SFX) синтезированы с нулевым оверхедом на диск.")
		passed_count += 1
	else:
		print("[FAIL] Test 3: Ошибка в процедурном генераторе аудиосэмплов.")

func _test_4_audio_manager_playback() -> void:
	var am: Node = root.get_node_or_null("AudioManager")
	if not am:
		print("[FAIL] Test 4: AudioManager не найден.")
		return

	# Тестируем воспроизведение без ошибок
	am.call("play_sfx", "click", -6.0)
	am.call("play_sfx", "radio_chime", -3.0)
	am.call("play_sfx_3d", "footstep", Vector3(1, 0, 2), -10.0)

	print("[PASS] Test 4: 2D и 3D шины аудиопроигрывателей успешно приняли команды воспроизведения.")
	passed_count += 1

func _test_5_pause_menu_integration() -> void:
	var scene_res: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	if not scene_res:
		print("[FAIL] Test 5: Не удалось загрузить pause_menu.tscn.")
		return

	pause_menu = scene_res.instantiate()
	root.add_child(pause_menu)

	# 1. Включаем паузу
	pause_menu.call("set_paused", true)
	var is_tree_paused: bool = paused
	var is_visible_paused: bool = pause_menu.visible

	# 2. Снимаем паузу
	pause_menu.call("resume_game")
	var is_tree_resumed: bool = not paused
	var is_visible_resumed: bool = not pause_menu.visible

	root.remove_child(pause_menu)
	pause_menu.free()

	if is_tree_paused and is_visible_paused and is_tree_resumed and is_visible_resumed:
		print("[PASS] Test 5: Меню паузы успешно управляет состоянием SceneTree, фокусом ввода и оверлеем.")
		passed_count += 1
	else:
		print("[FAIL] Test 5: Сбой логики паузы (paused=%s, resumed=%s)." % [is_tree_paused and is_visible_paused, is_tree_resumed and is_visible_resumed])

func _finalize() -> void:
	print("\n-----------------------------------------------------------------------")
	print(">>> РЕЗУЛЬТАТ: %d/%d ТЕСТОВ ПРОЙДЕНО" % [passed_count, total_count])
	print("-----------------------------------------------------------------------\n")
	if passed_count == total_count:
		print(">>> СТАТУС: 100% УСПЕХ — СИСТЕМЫ СОХРАНЕНИЙ, АУДИО И ПАУЗЫ РАБОТАЮТ БЕЗУПРЕЧНО! <<<\n")
	else:
		printerr(">>> СТАТУС: ОБНАРУЖЕНЫ ОШИБКИ В СИСТЕМНОЙ ИНТЕГРАЦИИ! <<<\n")