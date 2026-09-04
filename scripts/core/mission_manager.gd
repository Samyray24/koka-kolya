class_name MissionManager
extends Node

# Менеджер квестов, целей и сюжетных этапов «Кока-Коля»

signal objective_added(id: String, title: String)
signal objective_updated(id: String, current: int, total: int)
signal objective_completed(id: String, title: String)
signal mission_completed(mission_title: String)

var mission_title: String = "Операция: Шипучка"
var objectives: Dictionary = {}

func start_mission(title: String) -> void:
	mission_title = title
	objectives.clear()
	LogManager.info("Миссия начата: «%s»" % title, "QUEST")

func add_objective(id: String, title: String, total: int = 1) -> void:
	objectives[id] = {
		"id": id,
		"title": title,
		"current": 0,
		"total": total,
		"completed": false
	}
	objective_added.emit(id, title)
	LogManager.info("Новая задача: [%s] %s (0/%d)" % [id, title, total], "QUEST")

func advance_objective(id: String, amount: int = 1) -> void:
	if not objectives.has(id):
		return
		
	var obj: Dictionary = objectives[id]
	if obj["completed"]:
		return
		
	obj["current"] = mini(obj["total"], obj["current"] + amount)
	objective_updated.emit(id, obj["current"], obj["total"])
	LogManager.info("Прогресс задачи: [%s] (%d/%d)" % [id, obj["current"], obj["total"]], "QUEST")
	
	if obj["current"] >= obj["total"]:
		complete_objective(id)

func complete_objective(id: String) -> void:
	if not objectives.has(id):
		return
		
	var obj: Dictionary = objectives[id]
	if obj["completed"]:
		return
		
	obj["completed"] = true
	obj["current"] = obj["total"]
	objective_completed.emit(id, obj["title"])
	LogManager.info("Задача выполнена: [%s] %s!" % [id, obj["title"]], "QUEST")
	
	_check_all_completed()

func is_objective_completed(id: String) -> bool:
	if objectives.has(id):
		return objectives[id]["completed"]
	return false

func _check_all_completed() -> void:
	if objectives.is_empty():
		return
	for obj_id in objectives:
		if not objectives[obj_id]["completed"]:
			return
	mission_completed.emit(mission_title)
	LogManager.info("Все задачи выполнены! Миссия «%s» успешно завершена!" % mission_title, "QUEST")