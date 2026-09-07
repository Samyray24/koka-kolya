class_name OldDistrict
extends Node3D

# Игровой контроллер Первого играбельного района «Старый район & Складской терминал №4» (v0.3.0)
# Включает:
# - Динамическую 3D-навигацию (Waypoint Beacon) с дистанцией до активной цели
# - Пошаговую кампанию с радиопереговорами и фиксацией груза
# - Реактивные HUD-уведомления и звуковое сопровождение

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var van: VehicleBody3D = get_node_or_null("DeliveryVan")
@onready var drone: CharacterBody3D = get_node_or_null("BubbleDrone")
@onready var warehouse_trigger: Area3D = get_node_or_null("Triggers/WarehouseArrivalArea")
@onready var return_trigger: Area3D = get_node_or_null("Triggers/GarageReturnArea")
@onready var secret_formula: Node3D = get_node_or_null("Warehouse/Vault/SecretFormula")

# UI элементы
@onready var objective_label: Label = get_node_or_null("HUD/QuestPanel/Margin/VBox/ObjectiveLabel")
@onready var radio_speaker: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/SpeakerLabel")
@onready var radio_text: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/MessageLabel")
@onready var radio_panel: PanelContainer = get_node_or_null("HUD/RadioPanel")
@onready var complete_panel: PanelContainer = get_node_or_null("HUD/MissionCompletePanel")

var mission_mgr: Node = null
var dialogue_mgr: Node = null

var stage: int = 1 # 1: Loading, 2: Driving, 3: Infiltration, 4: Stealing, 5: Return, 6: Complete
var crates_loaded: int = 0

# 3D Навигационный маяк
var waypoint_node: Node3D = null
var waypoint_label: Label3D = null
var waypoint_light: OmniLight3D = null
var waypoint_mesh: MeshInstance3D = null
var current_target_pos: Vector3 = Vector3.ZERO
var current_target_name: String = ""

func _ready() -> void:
	mission_mgr = MissionManagerScript.new()
	mission_mgr.name = "MissionManager"
	add_child(mission_mgr)
	
	dialogue_mgr = DialogueManagerScript.new()
	dialogue_mgr.name = "DialogueManager"
	add_child(dialogue_mgr)
	
	dialogue_mgr.connect("message_displayed", _on_radio_message)
	dialogue_mgr.connect("dialogue_finished", _on_radio_finished)
	
	mission_mgr.connect("objective_added", _on_objective_updated)
	mission_mgr.connect("objective_updated", func(_id: String, _c: int, _t: int) -> void: _update_objective_ui())
	mission_mgr.connect("objective_completed", func(_id: String, _t: String) -> void: _update_objective_ui())
	mission_mgr.connect("mission_completed", _on_mission_completed)
	
	if warehouse_trigger:
		warehouse_trigger.body_entered.connect(_on_warehouse_entered)
		
	if return_trigger:
		return_trigger.body_entered.connect(_on_return_entered)
		
	if secret_formula and secret_formula.has_signal("formula_collected"):
		secret_formula.connect("formula_collected", _on_formula_secured)

	_create_waypoint_beacon()
	_start_mission_intro()
	_update_waypoint_for_stage()

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "WaypointBeacon"
	add_child(waypoint_node)

	# Светящийся кристалл маркера
	waypoint_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.6, 0.9, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 3.0
	waypoint_mesh.mesh = prism
	waypoint_mesh.material_override = mat
	waypoint_node.add_child(waypoint_mesh)

	# Точечный свет
	waypoint_light = OmniLight3D.new()
	waypoint_light.light_color = Color(0.2, 0.8, 1.0)
	waypoint_light.light_energy = 1.8
	waypoint_light.omni_range = 6.0
	waypoint_node.add_child(waypoint_light)

	# 3D Текстовая метка цели
	waypoint_label = Label3D.new()
	waypoint_label.position = Vector3(0, 1.0, 0)
	waypoint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint_label.font_size = 28
	waypoint_label.outline_size = 4
	waypoint_label.modulate = Color(1.0, 0.9, 0.2)
	waypoint_node.add_child(waypoint_label)

func _process(delta: float) -> void:
	if waypoint_node and waypoint_node.visible:
		# Плавное вращение и парение маркера
		if waypoint_mesh:
			waypoint_mesh.rotate_y(2.0 * delta)
			waypoint_mesh.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.15

		# Расчет дистанции от активной камеры/игрока
		var active_pos: Vector3 = player.global_position if player else Vector3.ZERO
		if van and van.get("is_driven") == true:
			active_pos = van.global_position
		
		var dist := int(active_pos.distance_to(waypoint_node.global_position))
		if waypoint_label:
			waypoint_label.text = "▼ %s\n[%d м]" % [current_target_name, dist]

func _update_waypoint_for_stage() -> void:
	if not waypoint_node:
		return

	match stage:
		1:
			waypoint_node.visible = true
			if van:
				current_target_pos = van.global_position + (van.global_transform.basis * Vector3(0, 1.2, 1.0))
			else:
				current_target_pos = Vector3(0, 1.5, 39.0)
			current_target_name = "Кузов фургона (Погрузка)"
			if waypoint_light:
				waypoint_light.light_color = Color(1.0, 0.8, 0.2)
		2:
			waypoint_node.visible = true
			current_target_pos = Vector3(0.0, 1.5, -25.0)
			current_target_name = "Складской терминал №4"
			if waypoint_light:
				waypoint_light.light_color = Color(0.2, 0.9, 1.0)
		3:
			waypoint_node.visible = true
			current_target_pos = Vector3(0.0, 1.5, -33.0)
			current_target_name = "Рецептурный чип (Хранилище)"
			if waypoint_light:
				waypoint_light.light_color = Color(0.3, 1.0, 0.4)
		4:
			waypoint_node.visible = true
			current_target_pos = Vector3(3.0, 1.5, 45.0)
			current_target_name = "Гараж Коли (Эвакуация)"
			if waypoint_light:
				waypoint_light.light_color = Color(1.0, 0.3, 0.3)
		_:
			waypoint_node.visible = false

	waypoint_node.global_position = current_target_pos

func _start_mission_intro() -> void:
	mission_mgr.call("start_mission", "Операция: Шипучка")
	mission_mgr.call("add_objective", "load_crates", "Загрузить 3 ящика «Кока-Коля» в кузов фургона", 3)
	
	dialogue_mgr.call("queue_message", "СашаV", "Коля, рация работает! MERIDIAN перекрыл поставки сиропа. Нам нужен их секретный чип с терминала №4.", Color(0.3, 0.8, 1.0), 4.5)
	dialogue_mgr.call("queue_message", "Коля", "Понял тебя. Сначала загружу готовые ящики в кузов [E], чтобы не ехать пустым.", Color(1.0, 0.8, 0.2), 3.5)

func _physics_process(_delta: float) -> void:
	if stage == 1 and van:
		_check_crate_loading()

func _check_crate_loading() -> void:
	var loaded_crates: Array = van.call("get_cargo_crates") if van.has_method("get_cargo_crates") else []
	if loaded_crates.size() != crates_loaded:
		crates_loaded = loaded_crates.size()
		var objectives: Dictionary = mission_mgr.get("objectives")
		if objectives.has("load_crates"):
			var cur: int = objectives["load_crates"]["current"]
			mission_mgr.call("advance_objective", "load_crates", crates_loaded - cur)
		
		var is_done: bool = mission_mgr.call("is_objective_completed", "load_crates")
		if crates_loaded >= 3 and not is_done:
			mission_mgr.call("complete_objective", "load_crates")
			stage = 2
			_update_waypoint_for_stage()
			mission_mgr.call("add_objective", "drive_to_warehouse", "Сесть за руль и доехать до Складского терминала №4", 1)
			dialogue_mgr.call("queue_message", "СашаV", "Кузов полон! Прыгай за руль [E] и гони на склад. Дорога через промзону свободна!", Color(0.3, 0.8, 1.0), 4.0)

func _on_warehouse_entered(body: Node) -> void:
	if stage == 2 and (body == van or body == player):
		stage = 3
		_update_waypoint_for_stage()
		mission_mgr.call("complete_objective", "drive_to_warehouse")
		mission_mgr.call("add_objective", "steal_formula", "Проникнуть в хранилище и похитить рецептурный чип", 1)
		dialogue_mgr.call("queue_message", "СашаV", "Ты на месте! Ворота заперты. Используй кибер-деку [4], пенные ступени [3] или дрона BUBBLE.", Color(0.3, 0.8, 1.0), 5.0)

func _on_formula_secured() -> void:
	if stage == 3:
		stage = 4
		_update_waypoint_for_stage()
		mission_mgr.call("complete_objective", "steal_formula")
		mission_mgr.call("add_objective", "return_to_garage", "Вернуться на фургоне в гараж Коли", 1)
		dialogue_mgr.call("queue_message", "СашаV", "ЧИП У ТЕБЯ! Отличная работа! Прыгай в фургон и возвращайся на базу, пока тревога не поднята!", Color(0.3, 1.0, 0.4), 4.5)

func _on_return_entered(body: Node) -> void:
	if stage == 4 and (body == van or body == player):
		stage = 5
		_update_waypoint_for_stage()
		mission_mgr.call("complete_objective", "return_to_garage")

func _on_mission_completed(_title: String) -> void:
	if complete_panel:
		complete_panel.visible = true
	dialogue_mgr.call("queue_message", "Коля", "Груз доставлен, формула у нас. «Кока-Коля» будет жить!", Color(1.0, 0.8, 0.2), 5.0)
	LogManager.info(">>> ВЕРТИКАЛЬНЫЙ СРЕЗ (STAGE 3) УСПЕШНО ПРОЙДЕН! <<<", "QUEST")

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

func _on_objective_updated(_id: String, _title: String) -> void:
	_update_objective_ui()

func _update_objective_ui() -> void:
	if not objective_label or not mission_mgr:
		return
	var objectives: Dictionary = mission_mgr.get("objectives")
	var lines: Array[String] = []
	for id in objectives:
		var obj: Dictionary = objectives[id]
		var checkmark: String = "[X]" if obj["completed"] else "[ ]"
		var progress: String = " (%d/%d)" % [obj["current"], obj["total"]] if obj["total"] > 1 else ""
		lines.append("%s %s%s" % [checkmark, obj["title"], progress])
	objective_label.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
