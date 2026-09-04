class_name DialogueManager
extends Node

# Менеджер сюжетных диалогов, радиопереговоров и субтитров «Кока-Коля»

signal message_displayed(speaker: String, text: String, color: Color)
signal dialogue_finished()

var is_active: bool = false
var queue: Array[Dictionary] = []
var active_timer: SceneTreeTimer = null

func queue_message(speaker: String, text: String, color: Color = Color.WHITE, duration: float = 4.0) -> void:
	queue.append({
		"speaker": speaker,
		"text": text,
		"color": color,
		"duration": duration
	})
	if not is_active:
		_process_next()

func _process_next() -> void:
	if queue.is_empty():
		is_active = false
		dialogue_finished.emit()
		return
		
	is_active = true
	var item: Dictionary = queue.pop_front()
	message_displayed.emit(item["speaker"], item["text"], item["color"])
	LogManager.info("[%s]: %s" % [item["speaker"], item["text"]], "RADIO")
	
	active_timer = get_tree().create_timer(item["duration"])
	active_timer.timeout.connect(_process_next)

func clear_all() -> void:
	queue.clear()
	is_active = false
	dialogue_finished.emit()