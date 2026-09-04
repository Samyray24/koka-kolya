extends Node

# Менеджер семантических сохранений и загрузки игры «Кока-Коля»
# Сериализует состояние игрока, инвентаря, разблокированных навыков и квестов в JSON.

signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_failed(reason: String)

const SAVE_DIR: String = "user://saves"

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	LogManager.info("SaveManager инициализирован. Директория: %s" % SAVE_DIR, "SAVE")

func get_save_path(slot: int = 0) -> String:
	return "%s/save_slot_%d.json" % [SAVE_DIR, slot]

func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

func save_game(slot: int = 0, custom_data: Dictionary = {}) -> bool:
	var current_ver: String = str(ProjectSettings.get_setting("application/config/version", "0.7.0"))
	var save_data := {
		"version": current_ver,
		"timestamp": Time.get_datetime_string_from_system(),
		"player": {},
		"inventory": {},
		"skills": [],
		"missions": {},
		"custom": custom_data
	}

	# 1. Сбор данных игрока
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player is Node3D:
		var p3d := player as Node3D
		save_data["player"] = {
			"position": [p3d.global_position.x, p3d.global_position.y, p3d.global_position.z],
			"rotation": [p3d.rotation.x, p3d.rotation.y, p3d.rotation.z],
			"health": p3d.get("health") if "health" in p3d else 100.0
		}

	# 2. Сбор данных инвентаря
	if player and player.has_node("InventoryManager"):
		var inv: Node = player.get_node("InventoryManager")
		save_data["inventory"] = {
			"current_slot": inv.get("current_slot") if "current_slot" in inv else 0
		}

	# 3. Сбор разблокированных навыков
	var skill_file := "user://skills.json"
	if FileAccess.file_exists(skill_file):
		var f_skill := FileAccess.open(skill_file, FileAccess.READ)
		if f_skill:
			var txt := f_skill.get_as_text()
			var parsed: Variant = JSON.parse_string(txt)
			if parsed is Dictionary and parsed.has("unlocked"):
				save_data["skills"] = parsed["unlocked"]

	# 4. Сбор состояния квестов (MissionManager)
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.has_node("MissionManager"):
		var mm: Node = current_scene.get_node("MissionManager")
		save_data["missions"] = {
			"title": mm.get("mission_title"),
			"objectives": mm.get("objectives")
		}

	# 5. Атомарная запись файла
	var path := get_save_path(slot)
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		save_failed.emit("Не удалось открыть файл сохранения: %d" % err)
		LogManager.error("Сбой записи сохранения в %s: ошибка %d" % [temp_path, err], "SAVE")
		return false

	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	# Переименовываем временный файл в финальный
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var rename_err := DirAccess.rename_absolute(temp_path, path)
	if rename_err != OK:
		save_failed.emit("Сбой финализации сохранения: %d" % rename_err)
		return false

	game_saved.emit(slot)
	LogManager.info("Игра успешно сохранена в слот %d (%s)" % [slot, path], "SAVE")
	return true

func load_game(slot: int = 0) -> Dictionary:
	var path := get_save_path(slot)
	if not FileAccess.file_exists(path):
		LogManager.warn("Файл сохранения не найден: %s" % path, "SAVE")
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		LogManager.error("Не удалось открыть файл сохранения: %s" % path, "SAVE")
		return {}

	var text := file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		LogManager.error("Поврежденные данные сохранения в %s" % path, "SAVE")
		return {}

	var save_dict: Dictionary = data as Dictionary

	# 1. Восстановление состояния игрока
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player is Node3D and save_dict.has("player"):
		var p_data: Dictionary = save_dict["player"]
		if p_data.has("position"):
			var pos_arr: Array = p_data["position"]
			(player as Node3D).global_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
		if p_data.has("health") and "health" in player:
			player.set("health", p_data["health"])

	# 2. Восстановление инвентаря
	if player and player.has_node("InventoryManager") and save_dict.has("inventory"):
		var inv: Node = player.get_node("InventoryManager")
		var inv_data: Dictionary = save_dict["inventory"]
		if inv_data.has("current_slot") and inv.has_method("equip_slot"):
			inv.call("equip_slot", int(inv_data["current_slot"]))

	# 3. Восстановление навыков
	if save_dict.has("skills") and save_dict["skills"] is Array:
		var skill_file := "user://skills.json"
		var f_skill := FileAccess.open(skill_file, FileAccess.WRITE)
		if f_skill:
			f_skill.store_string(JSON.stringify({"unlocked": save_dict["skills"]}, "\t"))
			f_skill.close()

	game_loaded.emit(slot)
	LogManager.info("Сохранение успешно загружено из слота %d" % slot, "SAVE")
	return save_dict

func delete_save(slot: int = 0) -> bool:
	var path := get_save_path(slot)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		return err == OK
	return false