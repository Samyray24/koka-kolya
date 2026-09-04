class_name SkillValidator
extends RefCounted

# Валидатор дизайн-системы дерева навыков (416 узлов + 64 синергии) по разделу 18

static func validate_skills_manifest(manifest_path: String = "res://data/skills/skills_manifest.json") -> Dictionary:
	var report: Dictionary = {
		"is_valid": true,
		"errors": [],
		"warnings": [],
		"total_nodes": 0,
		"implemented_nodes": 0,
		"branches_count": 0
	}

	if not FileAccess.file_exists(manifest_path):
		report["is_valid"] = false
		report["errors"].append("Файл манифеста не найден: %s" % manifest_path)
		return report

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(content)
	if err != OK or not (json.data is Dictionary):
		report["is_valid"] = false
		report["errors"].append("Ошибка парсинга JSON манифеста навыков.")
		return report

	var data: Dictionary = json.data
	var skills_arr: Array = data.get("skills", [])
	report["total_nodes"] = skills_arr.size()

	if skills_arr.size() != 416:
		report["is_valid"] = false
		report["errors"].append("Требуется ровно 416 базовых узлов (найдено: %d)" % skills_arr.size())

	var id_set := {}
	var branch_set := {}

	for node_data: Dictionary in skills_arr:
		var node_id: String = node_data.get("id", "")
		if node_id.is_empty():
			report["errors"].append("Обнаружен узел с пустым ID")
			report["is_valid"] = false
		elif id_set.has(node_id):
			report["errors"].append("Дублирующийся ID узла: %s" % node_id)
			report["is_valid"] = false
		id_set[node_id] = true

		var b_name: String = node_data.get("branch", "")
		branch_set[b_name] = true

		if node_data.get("implementation_status", "") == "implemented":
			report["implemented_nodes"] += 1

	report["branches_count"] = branch_set.size()
	if branch_set.size() != 16:
		report["is_valid"] = false
		report["errors"].append("Требуется ровно 16 веток навыков (найдено: %d)" % branch_set.size())

	return report

static func validate_synergies_manifest(manifest_path: String = "res://data/skills/synergies_manifest.json") -> Dictionary:
	var report: Dictionary = {
		"is_valid": true,
		"errors": [],
		"total_synergies": 0
	}

	if not FileAccess.file_exists(manifest_path):
		report["is_valid"] = false
		report["errors"].append("Файл синергий не найден: %s" % manifest_path)
		return report

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(content)
	if err != OK or not (json.data is Dictionary):
		report["is_valid"] = false
		report["errors"].append("Ошибка парсинга JSON синергий.")
		return report

	var syn_arr: Array = json.data.get("synergies", [])
	report["total_synergies"] = syn_arr.size()

	if syn_arr.size() < 64:
		report["is_valid"] = false
		report["errors"].append("Требуется минимум 64 синергии (найдено: %d)" % syn_arr.size())

	return report
