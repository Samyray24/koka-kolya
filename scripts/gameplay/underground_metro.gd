class_name UndergroundMetro
extends Node3D

# Район: «Подземный Метрополитен» (Заброшенная станция «Проспект Революции»)
# Особенности:
# - Мрачные кирпичные арки тоннелей с PBR гранж-текстурами
# - Серверная комната Синдиката (PBR сервера с мигающими светодиодами)
# - Рельсовые пути с заброшенным составом метро
# - Секретный автомат «Черри-Бунт» сопротивления

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const LoreTerminalScript = preload("res://scripts/interaction/lore_terminal.gd")
const VendingMachineScript = preload("res://scripts/interaction/vending_machine.gd")
const LootContainerScript = preload("res://scripts/interaction/loot_container.gd")
const ExplosiveBarrelScript = preload("res://scripts/physics/explosive_barrel.gd")

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var quest_label: Label = get_node_or_null("HUD/QuestPanel/Margin/VBox/ObjectiveLabel")
@onready var radio_panel: PanelContainer = get_node_or_null("HUD/RadioPanel")
@onready var radio_speaker: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/SpeakerLabel")
@onready var radio_text: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/MessageLabel")
@onready var victory_panel: PanelContainer = get_node_or_null("HUD/VictoryPanel")

var mission_mgr: Node = null
var dialogue_mgr: Node = null
var stage: int = 1

var waypoint_node: Node3D = null
var waypoint_label: Label3D = null
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

	mission_mgr.connect("objective_added", func(_id: String, _t: String) -> void: _update_quest_ui())
	mission_mgr.connect("objective_updated", func(_id: String, _c: int, _t: int) -> void: _update_quest_ui())
	mission_mgr.connect("objective_completed", func(_id: String, _t: String) -> void: _update_quest_ui())
	mission_mgr.connect("mission_completed", _on_mission_victory)

	_build_metro_tunnel_and_props()
	_build_server_room()
	_create_waypoint_beacon()
	_start_mission()
	_update_waypoint()

func _build_metro_tunnel_and_props() -> void:
	var mat_brick: Material = load("res://assets/materials/mat_underground_brick_grunge.tres")

	# Стены тоннеля метро (Левая и правая арки)
	for x_side in [-12.5, 12.5]:
		var wall := StaticBody3D.new()
		wall.name = "MetroWall_%.0f" % x_side
		wall.position = Vector3(x_side, 4.0, 0.0)

		var col := CollisionShape3D.new()
		var w_box := BoxShape3D.new()
		w_box.size = Vector3(1.0, 8.0, 200.0)
		col.shape = w_box
		wall.add_child(col)

		var mesh := MeshInstance3D.new()
		var m_box := BoxMesh.new()
		m_box.size = w_box.size
		mesh.mesh = m_box
		if mat_brick:
			mesh.material_override = mat_brick
		wall.add_child(mesh)
		add_child(wall)

	# Потолок тоннеля
	var ceiling := StaticBody3D.new()
	ceiling.name = "MetroCeiling"
	ceiling.position = Vector3(0, 8.0, 0)
	var c_col := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(25.0, 0.8, 200.0)
	c_col.shape = c_box
	ceiling.add_child(c_col)
	var c_mesh := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = c_box.size
	c_mesh.mesh = cm
	if mat_brick:
		c_mesh.material_override = mat_brick
	ceiling.add_child(c_mesh)
	add_child(ceiling)

	# Подземные аварийные фонари (Бирюзовые и оранжевые)
	var light_zs = [75.0, 45.0, 15.0, -15.0, -45.0, -75.0]
	for z_pos in light_zs:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(6.5, 6.5, z_pos)
		lamp.light_color = Color(0.2, 0.9, 0.9) if z_pos > 0 else Color(1.0, 0.6, 0.1)
		lamp.light_energy = 3.5
		lamp.omni_range = 16.0
		add_child(lamp)

	# Заброшенный вагон поезда на рельсах (слева, x = -5.0)
	var train_body := StaticBody3D.new()
	train_body.name = "SubwayTrainCar"
	train_body.position = Vector3(-5.0, 1.8, 10.0)
	var tb_col := CollisionShape3D.new()
	var tb_box := BoxShape3D.new()
	tb_box.size = Vector3(3.2, 3.2, 40.0)
	tb_col.shape = tb_box
	train_body.add_child(tb_col)
	var tb_mesh := MeshInstance3D.new()
	var tbm := BoxMesh.new()
	tbm.size = tb_box.size
	tb_mesh.mesh = tbm
	train_body.add_child(tb_mesh)
	add_child(train_body)

	# Скрытый торговый автомат Сопротивления в конце перрона (Z = -60)
	var secret_vending: Node3D = VendingMachineScript.new()
	secret_vending.name = "SecretMetroVending"
	secret_vending.position = Vector3(10.0, 1.2, -60.0)
	secret_vending.rotation_degrees = Vector3(0, -90, 0)
	add_child(secret_vending)

	# Лутаемые ящики с медикаментами и батареями
	var crate_loot: Node3D = LootContainerScript.new()
	crate_loot.name = "MetroCacheLoot"
	crate_loot.set("container_title", "Схрон Сопротивления")
	crate_loot.set("credits_reward", 250)
	crate_loot.position = Vector3(10.5, 1.2, -62.5)
	add_child(crate_loot)

func _build_server_room() -> void:
	var mat_server: Material = load("res://assets/materials/mat_sci_fi_server_rack.tres")

	# Серверная комната дата-центра Меридиана (Z = -20)
	var rack_positions = [
		Vector3(10.0, 2.5, -15.0),
		Vector3(10.0, 2.5, -20.0),
		Vector3(10.0, 2.5, -25.0),
		Vector3(10.0, 2.5, -30.0)
	]

	for i in range(rack_positions.size()):
		var rack := StaticBody3D.new()
		rack.name = "ServerRack_%d" % i
		rack.position = rack_positions[i]
		var r_col := CollisionShape3D.new()
		var r_box := BoxShape3D.new()
		r_box.size = Vector3(1.2, 2.6, 3.5)
		r_col.shape = r_box
		rack.add_child(r_col)
		var r_mesh := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = r_box.size
		r_mesh.mesh = rm
		if mat_server:
			r_mesh.material_override = mat_server
		rack.add_child(r_mesh)
		add_child(rack)

	# Главный серверный терминал для скачивания чертежей
	var srv_term: Node3D = LoreTerminalScript.new()
	srv_term.name = "MainframeTerminal"
	srv_term.set("terminal_title", "Главный дата-сервер Меридиана")
	srv_term.set("lore_header", "СЕКРЕТНЫЙ РЕЦЕПТ СИНТ-КОЛЫ")
	srv_term.set("lore_text", "Доступ получен. Исходные коды производственной линии завода скопированы на квантовый накопитель Коли!")
	srv_term.position = Vector3(8.5, 1.8, -20.0)
	srv_term.rotation_degrees = Vector3(0, -90, 0)
	add_child(srv_term)

	var trig := Area3D.new()
	trig.name = "ServerDownloadTrigger"
	trig.position = Vector3(8.5, 1.8, -20.0)
	var t_col := CollisionShape3D.new()
	var t_box := BoxShape3D.new()
	t_box.size = Vector3(3.0, 2.0, 3.0)
	t_col.shape = t_box
	trig.add_child(t_col)
	trig.body_entered.connect(_on_server_download_entered)
	add_child(trig)

	# Выход через аварийный эскалатор (Z = -85)
	var exit_trig := Area3D.new()
	exit_trig.name = "MetroEscalatorExit"
	exit_trig.position = Vector3(6.5, 1.8, -85.0)
	var et_col := CollisionShape3D.new()
	var et_box := BoxShape3D.new()
	et_box.size = Vector3(6.0, 3.0, 6.0)
	et_col.shape = et_box
	exit_trig.add_child(et_col)
	exit_trig.body_entered.connect(_on_metro_exit_entered)
	add_child(exit_trig)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "MetroWaypoint"
	add_child(waypoint_node)

	var mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 0.7, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 1.0)
	mat.emission_energy_multiplier = 3.0
	prism.material = mat
	mesh.mesh = prism
	mesh.rotation_degrees = Vector3(180, 0, 0)
	waypoint_node.add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 0.9, 1.0)
	light.light_energy = 3.0
	light.omni_range = 8.0
	waypoint_node.add_child(light)

	waypoint_label = Label3D.new()
	waypoint_label.position = Vector3(0, 0.8, 0)
	waypoint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint_label.font_size = 18
	waypoint_label.outline_size = 6
	waypoint_node.add_child(waypoint_label)

func _start_mission() -> void:
	mission_mgr.call("start_mission", "Подземный Метрополитен")
	mission_mgr.call("add_objective", "explore_platform", "Пройти по заброшенному перрону станции", 1)
	mission_mgr.call("add_objective", "download_data", "Взломать серверный мейнфрейм Меридиана [4 / E]", 1)
	mission_mgr.call("add_objective", "find_rebel_cache", "Найти тайник и автомат Сопротивления в конце путей", 1)
	mission_mgr.call("add_objective", "escape_escalator", "Подняться на поверхность через аварийный эскалатор", 1)

	dialogue_mgr.call("queue_message", "СашаV", "Коля, ты на заброшенной станции «Проспект Революции». Здесь находится скрытый дата-сервер Меридиана. Скачай данные!", Color(0.3, 0.8, 1.0), 5.5)

func _update_waypoint() -> void:
	match stage:
		1:
			current_target_pos = Vector3(6.5, 1.8, 20.0)
			current_target_name = "Перрон станции «Проспект Революции»"
		2:
			current_target_pos = Vector3(8.5, 1.8, -20.0)
			current_target_name = "Дата-сервер Синдиката [Взлом]"
		3:
			current_target_pos = Vector3(10.0, 1.8, -60.0)
			current_target_name = "Тайник Сопротивления"
		4:
			current_target_pos = Vector3(6.5, 1.8, -85.0)
			current_target_name = "Аварийный эскалатор: Эвакуация"
		_:
			if waypoint_node:
				waypoint_node.visible = false
			return

	if waypoint_node:
		waypoint_node.visible = true
		waypoint_node.position = current_target_pos

func _process(_delta: float) -> void:
	if waypoint_node and waypoint_node.visible:
		var t := Time.get_ticks_msec() / 1000.0
		waypoint_node.position = current_target_pos + Vector3(0, sin(t * 4.0) * 0.2, 0)
		if waypoint_label and player:
			var d := player.global_position.distance_to(current_target_pos)
			waypoint_label.text = "%s\n[ %.1f м ]" % [current_target_name, d]

	if stage == 1 and player:
		if player.global_position.distance_to(current_target_pos) < 6.0:
			stage = 2
			mission_mgr.call("complete_objective", "explore_platform")
			dialogue_mgr.call("queue_message", "СашаV", "Впереди серверная стойка! Подключи кибер-деку и скачай шифры.", Color(0.3, 1.0, 0.4), 5.0)
			_update_waypoint()

	if stage == 3 and player:
		if player.global_position.distance_to(current_target_pos) < 6.0:
			stage = 4
			mission_mgr.call("complete_objective", "find_rebel_cache")
			dialogue_mgr.call("queue_message", "Коля", "Тайник найден, банка ледяного Черри-Бунта в кармане! Бегом к эскалатору!", Color(1.0, 0.8, 0.2), 5.0)
			_update_waypoint()

func _on_server_download_entered(body: Node) -> void:
	if stage == 2 and body == player:
		stage = 3
		mission_mgr.call("complete_objective", "download_data")
		dialogue_mgr.call("queue_message", "СашаV", "Данные получены! Секретный тайник сопротивления прямо дальше по перрону.", Color(0.3, 1.0, 0.4), 4.5)
		_update_waypoint()

func _on_metro_exit_entered(body: Node) -> void:
	if stage == 4 and body == player:
		stage = 5
		mission_mgr.call("complete_objective", "escape_escalator")
		_update_waypoint()

func _on_mission_victory(_title: String) -> void:
	if victory_panel:
		victory_panel.visible = true
	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("mark_mission_completed", "mission_underground_metro")
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", 2.0)

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
