class_name NeonBoulevard
extends Node3D

# Район: «Неоновый Бульвар» (Красноград-Центр)
# Особенности:
# - Небоскрёбы с PBR-фасадами и гигантскими неоновыми голограммами
# - Двухуровневая эстакада для скоростного прорыва
# - Доставка колы в торговый автомат на Неон-Плазе
# - Взлом голографического рекламного билборда Синдиката

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const VendingMachineScript = preload("res://scripts/interaction/vending_machine.gd")
const LootContainerScript = preload("res://scripts/interaction/loot_container.gd")
const LoreTerminalScript = preload("res://scripts/interaction/lore_terminal.gd")
const ExplosiveBarrelScript = preload("res://scripts/physics/explosive_barrel.gd")
const DestructibleCrateScript = preload("res://scripts/physics/destructible_crate.gd")

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

var holo_billboard_label: Label3D = null
var plaza_vending: Node3D = null

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

	_build_neon_skyline()
	_build_flyover_bridge()
	_build_neon_plaza()
	_create_waypoint_beacon()
	_start_mission()
	_update_waypoint()

func _build_neon_skyline() -> void:
	var mat_facade: Material = load("res://assets/materials/mat_concrete_cyber_facade.tres")
	var mat_holo: Material = load("res://assets/materials/mat_neon_hologram_grid.tres")

	# Небоскрёбы вдоль бульвара
	var buildings = [
		{"pos": Vector3(-26, 0, 90), "scale": Vector3(8, 14, 8), "color": Color(0.1, 0.8, 1.0)},
		{"pos": Vector3(26, 0, 90), "scale": Vector3(8, 16, 8), "color": Color(1.0, 0.2, 0.8)},
		{"pos": Vector3(-26, 0, 40), "scale": Vector3(8, 18, 8), "color": Color(0.2, 1.0, 0.5)},
		{"pos": Vector3(26, 0, 40), "scale": Vector3(8, 15, 8), "color": Color(1.0, 0.7, 0.1)},
		{"pos": Vector3(-26, 0, -10), "scale": Vector3(9, 22, 9), "color": Color(0.3, 0.6, 1.0)},
		{"pos": Vector3(26, 0, -10), "scale": Vector3(9, 20, 9), "color": Color(1.0, 0.1, 0.4)},
		{"pos": Vector3(-26, 0, -60), "scale": Vector3(8, 16, 8), "color": Color(0.9, 0.9, 0.2)},
		{"pos": Vector3(26, 0, -60), "scale": Vector3(8, 17, 8), "color": Color(0.0, 0.9, 0.9)},
		{"pos": Vector3(-26, 0, -110), "scale": Vector3(10, 25, 10), "color": Color(1.0, 0.3, 0.9)},
		{"pos": Vector3(26, 0, -110), "scale": Vector3(10, 24, 10), "color": Color(0.2, 0.8, 1.0)},
	]

	for i in range(buildings.size()):
		var b_info = buildings[i]
		var b_node := StaticBody3D.new()
		b_node.name = "Skyscraper_%d" % i
		b_node.position = b_info["pos"]

		var col := CollisionShape3D.new()
		var b_box := BoxShape3D.new()
		b_box.size = Vector3(b_info["scale"].x * 2.0, b_info["scale"].y * 2.0, b_info["scale"].z * 2.0)
		col.shape = b_box
		col.position.y = b_info["scale"].y
		b_node.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = b_box.size
		mesh_inst.mesh = b_mesh
		if mat_facade:
			mesh_inst.material_override = mat_facade
		mesh_inst.position.y = b_info["scale"].y
		b_node.add_child(mesh_inst)
		add_child(b_node)

		# Неоновый контур крыши
		var roof_light := OmniLight3D.new()
		roof_light.name = "RoofLight_%d" % i
		roof_light.position = b_info["pos"] + Vector3(0, b_info["scale"].y * 2.0, 0)
		roof_light.light_color = b_info["color"]
		roof_light.light_energy = 5.0
		roof_light.omni_range = 28.0
		add_child(roof_light)

	# Неоновые фонари вдоль бульвара
	var lamp_zs = [95.0, 65.0, 35.0, 5.0, -25.0, -55.0, -85.0]
	for z_pos in lamp_zs:
		for x_side in [-11.5, 11.5]:
			var pole := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.1
			p_mesh.bottom_radius = 0.18
			p_mesh.height = 7.0
			pole.mesh = p_mesh
			pole.position = Vector3(x_side, 3.5, z_pos)
			add_child(pole)

			var n_light := OmniLight3D.new()
			n_light.name = "NeonLamp_%.0f_%.0f" % [x_side, z_pos]
			n_light.position = Vector3(x_side + (1.5 if x_side < 0 else -1.5), 7.0, z_pos)
			n_light.light_color = Color(0.1, 0.9, 1.0) if x_side < 0 else Color(1.0, 0.2, 0.8)
			n_light.light_energy = 3.5
			n_light.omni_range = 16.0
			add_child(n_light)

func _build_flyover_bridge() -> void:
	var mat_road: Material = load("res://assets/materials/mat_road_cyber_highway.tres")

	# Верхняя скоростная эстакада (высота 8.0, z от 60 до -60)
	var bridge := StaticBody3D.new()
	bridge.name = "CyberFlyoverBridge"
	bridge.position = Vector3(0, 8.0, 0)

	var col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(14.0, 0.8, 120.0)
	col.shape = b_shape
	bridge.add_child(col)

	var mesh := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = b_shape.size
	mesh.mesh = b_mesh
	if mat_road:
		mesh.material_override = mat_road
	bridge.add_child(mesh)
	add_child(bridge)

	# Опоры эстакады
	for p_z in [50.0, 20.0, -10.0, -40.0]:
		for p_x in [-6.0, 6.0]:
			var pylon := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.4
			cyl.bottom_radius = 0.6
			cyl.height = 8.0
			pylon.mesh = cyl
			pylon.position = Vector3(p_x, 4.0, p_z)
			add_child(pylon)

func _build_neon_plaza() -> void:
	var mat_holo: Material = load("res://assets/materials/mat_neon_hologram_grid.tres")

	# Торговый автомат Кока-Коля на Неон-Плазе (Z = 15)
	plaza_vending = VendingMachineScript.new()
	plaza_vending.name = "PlazaVendingMachine"
	plaza_vending.position = Vector3(-9.5, 0.3, 15.0)
	plaza_vending.rotation_degrees = Vector3(0, 75, 0)
	add_child(plaza_vending)

	# Гигантский голографический рекламный щит Синдиката над перекрестком (Z = -30)
	var board_anchor := StaticBody3D.new()
	board_anchor.name = "HoloBillboardAnchor"
	board_anchor.position = Vector3(0, 14.0, -30.0)

	var b_col := CollisionShape3D.new()
	var b_box := BoxShape3D.new()
	b_box.size = Vector3(18.0, 7.0, 0.5)
	b_col.shape = b_box
	board_anchor.add_child(b_col)

	var b_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = b_box.size
	b_mesh.mesh = bm
	if mat_holo:
		b_mesh.material_override = mat_holo
	board_anchor.add_child(b_mesh)

	holo_billboard_label = Label3D.new()
	holo_billboard_label.name = "HoloText"
	holo_billboard_label.position = Vector3(0, 0, 0.3)
	holo_billboard_label.text = "СИНДИКАТ МЕРИДИАН: ПОДЧИНЯЙСЯ"
	holo_billboard_label.font_size = 42
	holo_billboard_label.modulate = Color(1.0, 0.1, 0.2)
	holo_billboard_label.outline_size = 12
	board_anchor.add_child(holo_billboard_label)
	add_child(board_anchor)

	# Терминал взлома щита на уровне земли
	var hack_terminal: Node3D = LoreTerminalScript.new()
	hack_terminal.name = "HoloHackTerminal"
	hack_terminal.set("terminal_title", "Узел управления голо-экраном")
	hack_terminal.set("lore_header", "ВЗЛОМ ТРАНСЛЯЦИИ")
	hack_terminal.set("lore_text", "Сеть перехвачена! Нажмите [4 / E], чтобы запустить видеоролик Кока-Коли на весь бульвар!")
	hack_terminal.position = Vector3(9.5, 0.8, -30.0)
	hack_terminal.rotation_degrees = Vector3(0, -90, 0)
	add_child(hack_terminal)

	var trig := Area3D.new()
	trig.name = "HoloHackTrigger"
	trig.position = Vector3(9.5, 1.0, -30.0)
	var t_col := CollisionShape3D.new()
	var t_box := BoxShape3D.new()
	t_box.size = Vector3(3.0, 2.0, 3.0)
	t_col.shape = t_box
	trig.add_child(t_col)
	trig.body_entered.connect(_on_hack_trigger_entered)
	add_child(trig)

	# Укрытие разгрузки на финише (Z = -120)
	var exit_trig := Area3D.new()
	exit_trig.name = "BoulevardExitTrigger"
	exit_trig.position = Vector3(0, 1.0, -120.0)
	var et_col := CollisionShape3D.new()
	var et_box := BoxShape3D.new()
	et_box.size = Vector3(14.0, 3.0, 8.0)
	et_col.shape = et_box
	exit_trig.add_child(et_col)
	exit_trig.body_entered.connect(_on_exit_entered)
	add_child(exit_trig)

	# Интерактивные ящики и бочки
	for i in range(4):
		var barrel := ExplosiveBarrelScript.new()
		barrel.name = "NeonBarrel_%d" % i
		barrel.position = Vector3(randf_range(-10, 10), 0.6, randf_range(10, 60))
		add_child(barrel)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "BoulevardWaypoint"
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
	mission_mgr.call("start_mission", "Рейс на Неоновом Бульваре")
	mission_mgr.call("add_objective", "deliver_plaza", "Добраться на фургоне до торгового автомата на Неон-Плазе", 1)
	mission_mgr.call("add_objective", "hack_billboard", "Взломать голографический рекламный экран Синдиката [4 / E]", 1)
	mission_mgr.call("add_objective", "reach_safehouse", "Оторваться от патрулей и приехать на базу разгрузки", 1)

	dialogue_mgr.call("queue_message", "СашаV", "Коля, мы на Неоновом Бульваре! Врубай радио в фургоне на [R], меняй покраску на [T] и вперед на Неон-Плазу!", Color(0.3, 0.8, 1.0), 5.0)

func _update_waypoint() -> void:
	match stage:
		1:
			current_target_pos = Vector3(-9.5, 2.0, 15.0)
			current_target_name = "Торговый автомат Неон-Плаза"
		2:
			current_target_pos = Vector3(9.5, 2.0, -30.0)
			current_target_name = "Терминал управления экраном"
		3:
			current_target_pos = Vector3(0.0, 2.0, -120.0)
			current_target_name = "Конспиративный ангар разгрузки"
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

	if stage == 1 and plaza_vending and player:
		if player.global_position.distance_to(plaza_vending.global_position) < 8.0:
			stage = 2
			mission_mgr.call("complete_objective", "deliver_plaza")
			dialogue_mgr.call("queue_message", "СашаV", "Автомат заправлен свежей колой! Теперь взломай терминал и перехвати главный голо-экран города!", Color(0.3, 1.0, 0.4), 5.0)
			_update_waypoint()

func _on_hack_trigger_entered(body: Node) -> void:
	if stage == 2 and (body == player or body == van):
		stage = 3
		mission_mgr.call("complete_objective", "hack_billboard")
		if holo_billboard_label:
			holo_billboard_label.text = "★ ПЕЙТЕ КОКА-КОЛЮ! СВОБОДА КРАСНОГРАДУ! ★"
			holo_billboard_label.modulate = Color(0.2, 1.0, 0.4)
		dialogue_mgr.call("queue_message", "Коля", "Ха! Экран взломан, теперь весь город знает правду! Жми на газ к ангару!", Color(1.0, 0.8, 0.2), 5.0)
		_update_waypoint()

func _on_exit_entered(body: Node) -> void:
	if stage == 3 and (body == player or body == van):
		stage = 4
		mission_mgr.call("complete_objective", "reach_safehouse")
		_update_waypoint()

func _on_mission_victory(_title: String) -> void:
	if victory_panel:
		victory_panel.visible = true
	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("mark_mission_completed", "mission_neon_boulevard")
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
