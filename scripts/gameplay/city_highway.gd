class_name CityHighway
extends Node3D

# Контроллер Миссии 3 «Операция: Свободный Красноград» (Открытый мир / v0.7.0)
# Шоссе Краснограда: Скоростная доставка партии Коли, прорыв блокпоста КПП №2 MERIDIAN,
# взлом ретрансляционной вышки и трансляция манифеста сопротивления на весь город!

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var van: VehicleBody3D = get_node_or_null("DeliveryVan")
@onready var checkpoint_area: Area3D = get_node_or_null("Highway/CheckpointTrigger")
@onready var barrier_gate: Node3D = get_node_or_null("Highway/SecurityBarrier")
@onready var broadcast_tower: Node3D = get_node_or_null("CityPlaza/BroadcastTower")
@onready var broadcast_terminal: Node3D = get_node_or_null("CityPlaza/BroadcastTower/BroadcastTerminal")
@onready var cctv_camera: Node3D = get_node_or_null("Highway/CCTV_Checkpoint")

# UI элементы
@onready var quest_label: Label = get_node_or_null("HUD/QuestPanel/Margin/VBox/ObjectiveLabel")
@onready var radio_panel: PanelContainer = get_node_or_null("HUD/RadioPanel")
@onready var radio_speaker: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/SpeakerLabel")
@onready var radio_text: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/MessageLabel")
@onready var victory_panel: PanelContainer = get_node_or_null("HUD/VictoryPanel")

var mission_mgr: Node = null
var dialogue_mgr: Node = null

var stage: int = 1 # 1: Drive Highway, 2: Checkpoint, 3: Hack Barrier, 4: Drive Plaza, 5: Broadcast, 6: Victory

func _ready() -> void:
	mission_mgr = MissionManagerScript.new()
	mission_mgr.name = "MissionManager"
	add_child(mission_mgr)

	dialogue_mgr = DialogueManagerScript.new()
	dialogue_mgr.name = "DialogueManager"
	add_child(dialogue_mgr)

	dialogue_mgr.connect("message_displayed", _on_radio_message)
	dialogue_mgr.connect("dialogue_finished", _on_radio_finished)

	mission_mgr.connect("objective_added", func(_id: String, _t: String) -> void: _update_quest_ui())
	mission_mgr.connect("objective_updated", func(_id: String, _c: int, _t: int) -> void: _update_quest_ui())
	mission_mgr.connect("objective_completed", func(_id: String, _t: String) -> void: _update_quest_ui())
	mission_mgr.connect("mission_completed", _on_mission_victory)

	if checkpoint_area:
		checkpoint_area.body_entered.connect(_on_checkpoint_entered)

	if barrier_gate and barrier_gate.has_signal("door_opened"):
		barrier_gate.connect("door_opened", _on_barrier_opened)

	if broadcast_terminal and broadcast_terminal.has_signal("plant_overridden"):
		broadcast_terminal.connect("plant_overridden", _on_broadcast_started)

	_start_mission_intro()

func _start_mission_intro() -> void:
	mission_mgr.call("start_mission", "Операция: Свободный Красноград")
	mission_mgr.call("add_objective", "drive_highway", "Разогнать фургон на автостраде и добраться до КПП №2", 1)
	mission_mgr.call("add_objective", "breach_checkpoint", "Прорвать блокпост КПП №2 (Взломать терминал шлагбаума [4])", 1)
	mission_mgr.call("add_objective", "reach_plaza", "Добраться до Центральной Телебашни Краснограда", 1)
	mission_mgr.call("add_objective", "broadcast_manifesto", "Транслировать манифест свободы Кока-Коли", 1)

	dialogue_mgr.call("queue_message", "СашаV", "Коля, завод наш! Партия газировки разлита. Врубай радио в фургоне на [R] и жми на шоссе!", Color(0.3, 0.8, 1.0), 5.0)
	dialogue_mgr.call("queue_message", "Коля", "Включаю передачу. Красноград ждал этой Колы слишком долго.", Color(1.0, 0.8, 0.2), 4.0)

func _on_checkpoint_entered(body: Node) -> void:
	if stage == 1 and (body == van or body == player):
		stage = 2
		mission_mgr.call("complete_objective", "drive_highway")
		dialogue_mgr.call("queue_message", "СашаV", "Впереди автоматический блокпост MERIDIAN! Взломай терминал шлагбаума или ослепи турель пеной.", Color(0.3, 0.8, 1.0), 5.0)

func _on_barrier_opened() -> void:
	if stage == 2:
		stage = 3
		mission_mgr.call("complete_objective", "breach_checkpoint")
		dialogue_mgr.call("queue_message", "СашаV", "Шлагбаум открыт! Прорывайся к медиа-вышке в центре города!", Color(0.3, 1.0, 0.4), 4.5)

func _on_broadcast_started() -> void:
	if stage >= 2:
		stage = 5
		mission_mgr.call("complete_objective", "reach_plaza")
		mission_mgr.call("complete_objective", "broadcast_manifesto")

func _on_mission_victory(_title: String) -> void:
	if victory_panel:
		victory_panel.visible = true

	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("mark_mission_completed", "operation_free_krasnograd")

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", 2.0)

	dialogue_mgr.call("queue_message", "СашаV", "Трансляция идет на каждый экран города! Красноград свободен! Кока-Коля победила!", Color(0.3, 1.0, 0.4), 6.0)
	LogManager.info(">>> ГЛОБАЛЬНАЯ КАМПАНИЯ «КОКА-КОЛЯ» (v0.7.0) УСПЕШНО ЗАВЕРШЕНА! <<<", "VICTORY")

func _on_radio_message(speaker: String, text: String, col: Color) -> void:
	if radio_panel:
		radio_panel.visible = true
	if radio_speaker:
		radio_speaker.text = "[РАДИО: %s]" % speaker
		radio_speaker.modulate = col
	if radio_text:
		radio_text.text = text

func _on_radio_finished() -> void:
	if radio_panel:
		radio_panel.visible = false

func _update_quest_ui() -> void:
	if not quest_label or not mission_mgr:
		return
	var objectives: Dictionary = mission_mgr.get("objectives")
	var lines: Array[String] = []
	for id in objectives:
		var obj: Dictionary = objectives[id]
		var checkmark: String = "[X]" if obj["completed"] else "[ ]"
		lines.append("%s %s" % [checkmark, obj["title"]])
	quest_label.text = "\n".join(lines)