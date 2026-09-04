extends SceneTree

# Автоматический тест упаковки и целостности автономного релиза (Stage 7 / v1.0.0)
# Проверяет: KokaKolya.exe, KokaKolya.pck, GDExtension Jolt, версию и бюджет веса

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup()
		3:
			_test_1_build_files_existence()
		5:
			_test_2_pck_integrity_and_size()
		7:
			_test_3_gdextension_jolt_binaries()
		9:
			_test_4_project_version_and_metadata()
		11:
			_test_5_size_budget_compliance()
		13:
			_finalize()
			return true
	return false

func _setup() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: STANDALONE PACKAGING & GOLD MASTER (STAGE 7 / v1.0.0) <<<")
	print("=======================================================================\n")

func _test_1_build_files_existence() -> void:
	var exe_exists: bool = FileAccess.file_exists("res://builds/windows/KokaKolya.exe")
	var pck_exists: bool = FileAccess.file_exists("res://builds/windows/KokaKolya.pck")
	var preset_exists: bool = FileAccess.file_exists("res://export_presets.cfg")

	if exe_exists and pck_exists and preset_exists:
		print("[PASS] Test 1: Автономный исполняемый файл (KokaKolya.exe) и пакет ресурсов (KokaKolya.pck) найдены в builds/windows.")
		passed_count += 1
	else:
		print("[FAIL] Test 1: Отсутствуют файлы сборки (exe=%s, pck=%s, cfg=%s)." % [exe_exists, pck_exists, preset_exists])

func _test_2_pck_integrity_and_size() -> void:
	var f := FileAccess.open("res://builds/windows/KokaKolya.pck", FileAccess.READ)
	if not f:
		print("[FAIL] Test 2: Не удалось открыть KokaKolya.pck.")
		return

	var pck_len: int = f.get_length()
	# Проверка заголовка пакета Godot PCK ("GDPC" = 0x43504447)
	var magic: int = f.get_32()
	var magic_ok: bool = magic == 0x43504447
	f.close()

	if magic_ok and pck_len > 1024 * 1024:
		print("[PASS] Test 2: Пакет ресурсов валиден (Magic: GDPC, Размер: %.2f МБ)." % (float(pck_len) / (1024.0 * 1024.0)))
		passed_count += 1
	else:
		print("[FAIL] Test 2: Поврежден или мал файл PCK (magic_ok=%s, size=%d)." % [magic_ok, pck_len])

func _test_3_gdextension_jolt_binaries() -> void:
	var gdext: bool = FileAccess.file_exists("res://builds/windows/addons/addons/godot-jolt/godot-jolt.gdextension")
	var dll_x64: bool = FileAccess.file_exists("res://builds/windows/addons/addons/godot-jolt/windows/godot-jolt_windows-x64.dll")

	if gdext and dll_x64:
		print("[PASS] Test 3: Бинарные библиотеки Jolt Physics 3D для Windows x64 включены в автономную сборку.")
		passed_count += 1
	else:
		print("[FAIL] Test 3: Отсутствуют GDExtension-библиотеки Jolt (gdext=%s, dll=%s)." % [gdext, dll_x64])

func _test_4_project_version_and_metadata() -> void:
	var ver: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var proj_name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))

	var is_gold_master: bool = ver == "1.0.0" and proj_name == "Кока-Коля" and main_scene == "res://scenes/boot/boot.tscn"

	if is_gold_master:
		print("[PASS] Test 4: Релизные метаданные соответствуют Gold Master (Версия: 1.0.0, Название: «Кока-Коля», Стартовая сцена: Boot).")
		passed_count += 1
	else:
		print("[FAIL] Test 4: Неверные метаданные релиза (ver=%s, name=%s, scene=%s)." % [ver, proj_name, main_scene])

func _test_5_size_budget_compliance() -> void:
	var exe_file := FileAccess.open("res://builds/windows/KokaKolya.exe", FileAccess.READ)
	var exe_len: int = exe_file.get_length() if exe_file else 0
	if exe_file: exe_file.close()

	var pck_file := FileAccess.open("res://builds/windows/KokaKolya.pck", FileAccess.READ)
	var pck_len: int = pck_file.get_length() if pck_file else 0
	if pck_file: pck_file.close()

	var total_bytes: int = exe_len + pck_len
	var total_gb: float = float(total_bytes) / (1024.0 * 1024.0 * 1024.0)

	# Лимит <= 20.0 GB, цель <= 18.0 GB. Автономная сборка весит ~0.18 GB!
	if total_gb <= 20.0:
		print("[PASS] Test 5: Общий размер автономного дистрибутива строго соблюден (%.3f GB <= 20.0 GB limit)." % total_gb)
		passed_count += 1
	else:
		print("[FAIL] Test 5: Превышен бюджет веса дистрибутива (%.3f GB > 20.0 GB)." % total_gb)

func _finalize() -> void:
	print("\n-----------------------------------------------------------------------")
	print(">>> РЕЗУЛЬТАТ: %d/%d ТЕСТОВ ПРОЙДЕНО" % [passed_count, total_count])
	print("-----------------------------------------------------------------------\n")
	if passed_count == total_count:
		print(">>> СТАТУС: 100% УСПЕХ — STANDALONE GOLD MASTER РЕЛИЗ v1.0.0 ГОТОВ К ВЫПУСКУ! <<<\n")
	else:
		printerr(">>> СТАТУС: НАЙДЕНЫ ОШИБКИ В СБОРКЕ ДИСТРИБУТИВА! <<<\n")