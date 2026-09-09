class_name LogisticsHub
extends Node3D

# Район: «Логистический Хаб Меридиана»
# Особенности:
# - Стеки грузовых контейнеров (PBR металл и ржавчина)
# - Тяжелые погрузочные краны и промышленные платформы
# - Защитная лазерная сетка и охранные турели
# - Захват контейнеров с сиропом и погрузка в фургон

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const LoreTerminalScript = preload("res://scripts/interaction/lore_terminal.gd")
const LootContainerScript = preload("res://scripts/interaction/loot_container.gd")
const ExplosiveBarrelScript = preload("res://scripts/physics/explosive_barrel.gd")
const DestructibleCrateScript = preload("res://scripts/physics/destructible_crate.gd")
const VendingMachineScript = preload("res://scripts/interaction/vending_machine.gd")

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var van: VehicleBody3D = get_node_or_null("DeliveryVan")
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

var laser_barrier: Node3D = null
var laser_light: OmniLight3D = null

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

	_build_container_terminal()
	_build_laser_security()
	_create_waypoint_beacon()
	_start_mission()
	_update_waypoint()

func _build_container_terminal() -> void:
	var mat_cont: Material = load("res://assets/materials/mat_metal_corrugated_slum.tres")
	var mat_rust: Material = load("res://assets/materials/mat_metal_rust_plates.tres")
	var mat_titanium: Material = load("res://assets/materials/mat_meridian_titanium_wall.tres")
	var mat_diamond: Material = load("res://assets/materials/mat_metal_industrial_diamond.tres")

	# Контейнерные лабиринты (20 контейнеров в рядах и стеках)
	var container_positions = [
		Vector3(-18, 0, 50), Vector3(-18, 2.8, 50), Vector3(-18, 0, 36),
		Vector3(18, 0, 50), Vector3(18, 2.8, 50), Vector3(18, 0, 36),
		Vector3(-24, 0, 10), Vector3(-24, 2.8, 10), Vector3(-24, 5.6, 10),
		Vector3(24, 0, 10), Vector3(24, 2.8, 10),
		Vector3(-12, 0, -20), Vector3(-12, 2.8, -20),
		Vector3(12, 0, -20), Vector3(12, 2.8, -20), Vector3(12, 5.6, -20),
		Vector3(-20, 0, -60), Vector3(20, 0, -60),
		Vector3(0, 0, -70), Vector3(0, 2.8, -70)
	]

	for i in range(container_positions.size()):
		var c_pos = container_positions[i]
		var c_node := StaticBody3D.new()
		c_node.name = "ShippingContainer_%d" % i
		c_node.position = c_pos + Vector3(0, 1.4, 0)

		var col := CollisionShape3D.new()
		var c_box := BoxShape3D.new()
		c_box.size = Vector3(6.0, 2.8, 12.0)
		col.shape = c_box
		c_node.add_child(col)

		var mesh := MeshInstance3D.new()
		var m_box := BoxMesh.new()
		m_box.size = c_box.size
		mesh.mesh = m_box
		mesh.material_override = mat_cont if (i % 2 == 0) else mat_rust
		c_node.add_child(mesh)
		add_child(c_node)

	# Стальные платформы кранов (Diamond plate)
	var crane_platform := StaticBody3D.new()
	crane_platform.name = "CranePlatform"
	crane_platform.position = Vector3(0, 10.0, -10.0)
	var cp_col := CollisionShape3D.new()
	var cp_shape := BoxShape3D.new()
	cp_shape.size = Vector3(28.0, 0.8, 8.0)
	cp_col.shape = cp_shape
	crane_platform.add_child(cp_col)
	var cp_mesh := MeshInstance3D.new()
	var cpm := BoxMesh.new()
	cpm.size = cp_shape.size
	cp_mesh.mesh = cpm
	if mat_diamond:
		cp_mesh.material_override = mat_diamond
	crane_platform.add_child(cp_mesh)
	add_child(crane_platform)

	# Опоры крана
	for k_x in [-13.0, 13.0]:
		var leg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.8
		cyl.height = 10.0
		leg.mesh = cyl
		leg.position = Vector3(k_x, 5.0, -10.0)
		add_child(leg)

	# Промышленные прожекторы на вышках
	for light_x in [-25.0, 25.0]:
		for light_z in [60.0, -30.0]:
			var flood := SpotLight3D.new()
			flood.position = Vector3(light_x, 14.0, light_z)
			flood.rotation_degrees = Vector3(-65, 45 if light_x < 0 else -45, 0)
			flood.light_color = Color(1.0, 0.85, 0.6)
			flood.light_energy = 5.0
			flood.spot_range = 35.0
			flood.spot_angle = 50.0
			add_child(flood)

	# Интерактивные лутаемые контейнеры
	var loot1: Node3D = LootContainerScript.new()
	loot1.name = "TerminalLoot1"
	loot1.set("container_title", "Контейнер запчастей Меридиана")
	loot1.set("credits_reward", 120)
	loot1.position = Vector3(-15.0, 0.5, 40.0)
	add_child(loot1)

	var loot2: Node3D = LootContainerScript.new()
	loot2.name = "TerminalLoot2"
	loot2.set("container_title", "Сейф с крипто-чипами")
	loot2.set("credits_reward", 200)
	loot2.set("is_locked", true)
	loot2.position = Vector3(15.0, 0.5, -15.0)
	add_child(loot2)

	# Взрывные бочки
	for b_idx in range(6):
		var barrel := ExplosiveBarrelScript.new()
		barrel.name = "HubBarrel_%d" % b_idx
		barrel.position = Vector3(randf_range(-8, 8), 0.6, randf_range(-5, 45))
		add_child(barrel)

func _build_laser_security() -> void:
	# Лазерная охранная сетка перед хранилищем (Z = -45)
	laser_barrier = Node3D.new()
	laser_barrier.name = "LaserSecurityGrid"
	laser_barrier.position = Vector3(0, 1.5, -45.0)

	for b_i in range(5):
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 16.0
		beam.mesh = cyl
		beam.rotation_degrees = Vector3(0, 0, 90)
		beam.position = Vector3(0, float(b_i) * 0.7, 0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.1, 0.1)
		mat.emission_energy_multiplier = 4.0
		beam.material_override = mat
		laser_barrier.add_child(beam)

	laser_light = OmniLight3D.new()
	laser_light.light_color = Color(1.0, 0.1, 0.1)
	laser_light.light_energy = 4.0
	laser_light.omni_range = 10.0
	laser_barrier.add_child(laser_light)
	add_child(laser_barrier)

	# Терминал деактивации лазеров
	var hack_term: Node3D = LoreTerminalScript.new()
	hack_term.name = "LaserControlTerminal"
	hack_term.set("terminal_title", "Консоль управления лазерным периметром")
	hack_term.set("lore_header", "СИСТЕМА БЕЗОПАСНОСТИ ХАБА")
	hack_term.set("lore_text", "Лазерная блокировка активна. Взломайте консоль [4 / E], чтобы снять поле и открыть склад.")
	hack_term.position = Vector3(-11.0, 0.8, -40.0)
	hack_term.rotation_degrees = Vector3(0, 90, 0)
	add_child(hack_term)

	var trig := Area3D.new()
	trig.name = "LaserConsoleTrigger"
	trig.position = Vector3(-11.0, 1.0, -40.0)
	var t_col := CollisionShape3D.new()
	var t_box := BoxShape3D.new()
	t_box.size = Vector3(3.0, 2.0, 3.0)
	t_col.shape = t_box
	trig.add_child(t_col)
	trig.body_entered.connect(_on_laser_console_entered)
	add_child(trig)

	# Финальная зона эвакуации (Главные ворота, Z = -95)
	var exit_trig := Area3D.new()
	exit_trig.name = "HubExitTrigger"
	exit_trig.position = Vector3(0, 1.0, -95.0)
	var et_col := CollisionShape3D.new()
	var et_box := BoxShape3D.new()
	et_box.size = Vector3(18.0, 3.0, 8.0)
	et_col.shape = et_box
	exit_trig.add_child(et_col)
	exit_trig.body_entered.connect(_on_hub_exit_entered)
	add_child(exit_trig)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "HubWaypoint"
	add_child(waypoint_node)

	var mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 0.7, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	mat.emission_energy_multiplier = 3.0
	prism.material = mat
	mesh.mesh = prism
	mesh.rotation_degrees = Vector3(180, 0, 0)
	waypoint_node.add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.1)
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
	mission_mgr.call("start_mission", "Логистический Перехват")
	mission_mgr.call("add_objective", "infiltrate_hub", "Проникнуть в центр контейнерного терминала", 1)
	mission_mgr.call("add_objective", "disable_lasers", "Взломать консоль и отключить лазерную сетку [4 / E]", 1)
	mission_mgr.call("add_objective", "retrieve_syrup", "Забрать концентрат сиропа из хранилища", 1)
	mission_mgr.call("add_objective", "escape_hub", "Прорвать главные ворота хаба на фургоне", 1)

	dialogue_mgr.call("queue_message", "СашаV", "Коля, в этом хабе хранится весь запас концентрата! Охрана вооружена, лазеры перекрывают склад. Действуй аккуратно!", Color(0.3, 0.8, 1.0), 5.5)

func _update_waypoint() -> void:
	match stage:
		1:
			current_target_pos = Vector3(0.0, 2.0, 10.0)
			current_target_name = "Центр контейнерного терминала"
		2:
			current_target_pos = Vector3(-11.0, 2.0, -40.0)
			current_target_name = "Консоль лазерной сетки [Взлом]"
		3:
			current_target_pos = Vector3(0.0, 2.0, -65.0)
			current_target_name = "Склад концентрата сиропа"
		4:
			current_target_pos = Vector3(0.0, 2.0, -95.0)
			current_target_name = "Главные ворота: Прорыв"
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
		if player.global_position.distance_to(current_target_pos) < 10.0:
			stage = 2
			mission_mgr.call("complete_objective", "infiltrate_hub")
			dialogue_mgr.call("queue_message", "СашаV", "Мы внутри! Впереди лазерный барьер. Найди консоль управления слева между контейнерами.", Color(0.3, 1.0, 0.4), 5.0)
			_update_waypoint()

	if stage == 3 and player:
		if player.global_position.distance_to(current_target_pos) < 8.0:
			stage = 4
			mission_mgr.call("complete_objective", "retrieve_syrup")
			dialogue_mgr.call("queue_message", "Коля", "Концентрат у нас! Садись в фургон, жми нитро на [Shift] и сноси главные ворота!", Color(1.0, 0.8, 0.2), 5.0)
			_update_waypoint()

func _on_laser_console_entered(body: Node) -> void:
	if stage == 2 and (body == player or body == van):
		stage = 3
		mission_mgr.call("complete_objective", "disable_lasers")
		if laser_barrier:
			laser_barrier.visible = false
		dialogue_mgr.call("queue_message", "СашаV", "Лазерная сетка отключена! Доступ к контейнерам открыт!", Color(0.3, 1.0, 0.4), 4.5)
		_update_waypoint()

func _on_hub_exit_entered(body: Node) -> void:
	if stage == 4 and (body == player or body == van):
		stage = 5
		mission_mgr.call("complete_objective", "escape_hub")
		_update_waypoint()

func _on_mission_victory(_title: String) -> void:
	if victory_panel:
		victory_panel.visible = true
	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("mark_mission_completed", "mission_logistics_hub")
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
