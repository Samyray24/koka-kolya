class_name CityHighway
extends Node3D

# Контроллер Миссии 3 «Операция: Свободный Красноград» (Открытый мир / v0.7.0)
# Шоссе Краснограда: Скоростная доставка партии Коли, прорыв блокпоста КПП №2 MERIDIAN,
# взлом ретрансляционной вышки и трансляция манифеста сопротивления на весь город!
# Включает: динамический 3D-маяк навигации, ночной киберпанк-скайлайн, фонарные столбы и разметку.

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

# 3D Навигационный маяк
var waypoint_node: Node3D = null
var waypoint_label: Label3D = null
var waypoint_light: OmniLight3D = null
var waypoint_mesh: MeshInstance3D = null
var current_target_pos: Vector3 = Vector3.ZERO
var current_target_name: String = ""
var tower_beam_light: OmniLight3D = null
var is_broadcasting: bool = false

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

	_create_waypoint_beacon()
	_spawn_highway_world_details()
	_start_mission_intro()
	_update_waypoint_for_stage()

func _spawn_highway_world_details() -> void:
	var mat_metal: Material = load("res://assets/materials/mat_metal.tres")
	var mat_metal_ind: Material = load("res://assets/materials/mat_metal_industrial.tres")
	var mat_brick_dark: Material = load("res://assets/materials/mat_brick_dark.tres")
	var mat_concrete: Material = load("res://assets/materials/mat_concrete.tres")

	# 1. Фонарные столбы вдоль скоростного шоссе (с обеих сторон, z от 90 до -60)
	var lamp_z_coords = [88.0, 68.0, 48.0, 28.0, 8.0, -12.0, -32.0, -52.0]
	for z_pos in lamp_z_coords:
		for x_side in [-8.8, 8.8]:
			var pole := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.08
			p_mesh.bottom_radius = 0.16
			p_mesh.height = 6.2
			pole.mesh = p_mesh
			if mat_metal:
				pole.material_override = mat_metal
			pole.position = Vector3(x_side, 3.1, z_pos)
			add_child(pole)

			var arm := MeshInstance3D.new()
			var a_mesh := BoxMesh.new()
			a_mesh.size = Vector3(1.4, 0.1, 0.1)
			arm.mesh = a_mesh
			if mat_metal:
				arm.material_override = mat_metal
			arm.position = Vector3(x_side + (0.6 if x_side < 0 else -0.6), 6.1, z_pos)
			add_child(arm)

			var light := OmniLight3D.new()
			light.name = "HighwayLamp_%.0f_%.0f" % [x_side, z_pos]
			light.position = Vector3(x_side + (1.2 if x_side < 0 else -1.2), 6.0, z_pos)
			light.light_color = Color(1.0, 0.90, 0.75)
			light.light_energy = 2.2
			light.omni_range = 14.0
			light.omni_attenuation = 1.3
			light.shadow_enabled = false
			add_child(light)

	# 2. Дорожная разметка: прерывистая осевая линия шоссе
	var center_line_node := Node3D.new()
	center_line_node.name = "HighwayCenterLine"
	add_child(center_line_node)
	var z_cur: float = 95.0
	while z_cur >= -60.0:
		if abs(z_cur) > 4.0: # Не перекрывать зону шлагбаума
			var dash := MeshInstance3D.new()
			var d_mesh := QuadMesh.new()
			d_mesh.size = Vector2(0.25, 3.0)
			d_mesh.orientation = PlaneMesh.FACE_Y
			dash.mesh = d_mesh
			var d_mat := StandardMaterial3D.new()
			d_mat.albedo_color = Color(0.96, 0.96, 0.98, 0.9)
			d_mat.roughness = 0.6
			dash.material_override = d_mat
			dash.position = Vector3(0.0, 0.22, z_cur)
			center_line_node.add_child(dash)
		z_cur -= 5.5

	# 3. Боковые сплошные полосы безопасности
	for x_shoulder in [-7.2, 7.2]:
		var shoulder_line := MeshInstance3D.new()
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(0.25, 0.02, 160.0)
		shoulder_line.mesh = s_mesh
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.9)
		s_mat.roughness = 0.5
		shoulder_line.material_override = s_mat
		shoulder_line.position = Vector3(x_shoulder, 0.22, 18.0)
		add_child(shoulder_line)

	# 4. Небоскрёбы Даунтауна вокруг Телебашни на Городской Площади (z от -65 до -105)
	var b_types = ["building_A", "building_B", "building_E", "building_F", "building_G", "building_H"]
	var plaza_buildings = [
		{"type": "building_A", "pos": Vector3(-24.0, 0.0, -70.0), "rot": 90, "scale": Vector3(5.5, 7.5, 5.5)},
		{"type": "building_B", "pos": Vector3(24.0, 0.0, -70.0), "rot": -90, "scale": Vector3(5.5, 7.0, 5.5)},
		{"type": "building_E", "pos": Vector3(-25.0, 0.0, -92.0), "rot": 90, "scale": Vector3(5.0, 8.0, 5.0)},
		{"type": "building_F", "pos": Vector3(25.0, 0.0, -92.0), "rot": -90, "scale": Vector3(5.0, 8.5, 5.0)},
		{"type": "building_G", "pos": Vector3(0.0, 0.0, -108.0), "rot": 180, "scale": Vector3(6.5, 9.0, 6.5)},
		{"type": "building_H", "pos": Vector3(-14.0, 0.0, -102.0), "rot": 135, "scale": Vector3(4.8, 6.5, 4.8)},
		{"type": "building_C", "pos": Vector3(14.0, 0.0, -102.0), "rot": -135, "scale": Vector3(4.8, 6.5, 4.8)}
	]
	for b_info in plaza_buildings:
		var b_res: PackedScene = load("res://assets/scenes_3d/%s.tscn" % b_info["type"])
		if b_res:
			var bld: Node3D = b_res.instantiate()
			bld.name = "PlazaSkyscraper_%s" % b_info["type"]
			bld.position = b_info["pos"]
			bld.rotation_degrees = Vector3(0, b_info["rot"], 0)
			bld.scale = b_info["scale"]
			if mat_metal_ind:
				_apply_mesh_material_recursive(bld, mat_metal_ind)
			add_child(bld)

	# 5. Укрепления и заграждения блокпоста КПП №2 (wall-high, box_A, box_B)
	var wall_high_res: PackedScene = load("res://assets/scenes_3d/wall-high.tscn")
	if wall_high_res:
		var cp_walls = [
			Vector3(-12.0, 0.0, 0.0),
			Vector3(-18.0, 0.0, 0.0),
			Vector3(12.0, 0.0, 0.0),
			Vector3(18.0, 0.0, 0.0)
		]
		for i in range(cp_walls.size()):
			var w: Node3D = wall_high_res.instantiate()
			w.name = "CheckpointWall_%d" % i
			w.position = cp_walls[i]
			w.scale = Vector3(2.5, 2.8, 2.5)
			if mat_concrete:
				_apply_mesh_material_recursive(w, mat_concrete)
			add_child(w)

		# Модульные охранные посты КПП №2
		var booth_scene: PackedScene = load("res://assets/scenes_3d/building-small-a.tscn")
		if booth_scene:
			var b1: Node3D = booth_scene.instantiate()
			b1.name = "CheckpointBooth_Left"
			b1.position = Vector3(-9.5, 0.0, 0.5)
			b1.scale = Vector3(1.4, 1.4, 1.4)
			if mat_concrete:
				_apply_mesh_material_recursive(b1, mat_concrete)
			add_child(b1)

	var box_a_res: PackedScene = load("res://assets/scenes_3d/box_A.tscn")
	var box_b_res: PackedScene = load("res://assets/scenes_3d/box_B.tscn")
	if box_a_res and box_b_res:
		var cp_boxes = [
			Vector3(-7.5, 0.0, 2.0),
			Vector3(-8.2, 0.0, 3.2),
			Vector3(-7.8, 0.9, 2.5),
			Vector3(7.2, 0.0, 2.0),
			Vector3(7.8, 0.0, 3.5)
		]
		for i in range(cp_boxes.size()):
			var bx: Node3D = (box_a_res if i % 2 == 0 else box_b_res).instantiate()
			bx.name = "CPBox_%d" % i
			bx.position = cp_boxes[i]
			bx.scale = Vector3(1.35, 1.35, 1.35)
			add_child(bx)

	# 6. Патрульный автомобиль охраны на КПП
	var cop_scene: PackedScene = load("res://assets/scenes_3d/car_police.tscn")
	if cop_scene:
		var cop: Node3D = cop_scene.instantiate()
		cop.name = "Checkpoint_PoliceCar"
		cop.position = Vector3(6.5, 0.0, 3.5)
		cop.rotation_degrees = Vector3(0, 160, 0)
		add_child(cop)

	# 7. Автомобили жителей вдоль обочины шоссе
	var sedan_scene: PackedScene = load("res://assets/scenes_3d/car_sedan.tscn")
	if sedan_scene:
		var car1: Node3D = sedan_scene.instantiate()
		car1.name = "ShoulderCar_Sedan"
		car1.position = Vector3(7.2, 0.0, 55.0)
		car1.rotation_degrees = Vector3(0, 5, 0)
		add_child(car1)

	var hatch_scene: PackedScene = load("res://assets/scenes_3d/car_hatchback.tscn")
	if hatch_scene:
		var car2: Node3D = hatch_scene.instantiate()
		car2.name = "ShoulderCar_Hatch"
		car2.position = Vector3(-7.2, 0.0, 32.0)
		car2.rotation_degrees = Vector3(0, -8, 0)
		add_child(car2)

	var wagon_scene: PackedScene = load("res://assets/scenes_3d/car_stationwagon.tscn")
	if wagon_scene:
		var car3: Node3D = wagon_scene.instantiate()
		car3.name = "ShoulderCar_Wagon"
		car3.position = Vector3(7.2, 0.0, -28.0)
		car3.rotation_degrees = Vector3(0, 10, 0)
		add_child(car3)

	# 8. Мощный трансляционный маяк на вершине Телебашни
	tower_beam_light = OmniLight3D.new()
	tower_beam_light.name = "BroadcastTowerBeacon"
	tower_beam_light.position = Vector3(0.0, 28.0, -80.0)
	tower_beam_light.light_color = Color(1.0, 0.15, 0.25)
	tower_beam_light.light_energy = 4.0
	tower_beam_light.omni_range = 35.0
	add_child(tower_beam_light)


	# 8. Отбойники шоссе (wall-low) и придорожные деревья (grass-trees)
	var wall_low_res: PackedScene = load("res://assets/scenes_3d/wall-low.tscn")
	var tree_res: PackedScene = load("res://assets/scenes_3d/grass-trees.tscn")
	var z_b: float = 90.0
	var barrier_idx: int = 0
	while z_b >= -55.0:
		if abs(z_b) > 4.5: # Проезд на КПП открыт
			for x_side in [-8.4, 8.4]:
				if wall_low_res:
					var b_inst: Node3D = wall_low_res.instantiate()
					b_inst.name = "HighwayBarrier_%d_%.0f" % [barrier_idx, x_side]
					b_inst.position = Vector3(x_side, 0.12, z_b)
					b_inst.rotation_degrees = Vector3(0, 90, 0)
					b_inst.scale = Vector3(1.8, 1.8, 1.8)
					if mat_concrete:
						_apply_mesh_material_recursive(b_inst, mat_concrete)
					add_child(b_inst)

				if tree_res and barrier_idx % 3 == 0:
					var tr: Node3D = tree_res.instantiate()
					tr.name = "HighwayTree_%d_%.0f" % [barrier_idx, x_side]
					tr.position = Vector3(x_side + (3.2 if x_side > 0 else -3.2), 0.0, z_b)
					tr.scale = Vector3(1.5, 1.5, 1.5)
					add_child(tr)
			barrier_idx += 1
		z_b -= 6.0

	# 9. Неоновые рекламные щиты над трассой
	var mat_neon_cyan: Material = load("res://assets/materials/mat_neon_cyan.tres")
	var mat_neon_amber: Material = load("res://assets/materials/mat_neon_amber.tres")
	var gantry_sign := Label3D.new()
	gantry_sign.name = "HighwayGantrySign"
	gantry_sign.position = Vector3(0.0, 7.5, 12.0)
	gantry_sign.text = "▲ КПП №2: СЕКТОР КРАСНОГРАД-ЦЕНТР ▲"
	gantry_sign.font_size = 28
	gantry_sign.modulate = Color(1.0, 0.75, 0.2)
	gantry_sign.outline_size = 8
	add_child(gantry_sign)

	# 10. Фонтан и благоустройство Городской Площади у Телебашни
	var fountain_res: PackedScene = load("res://assets/scenes_3d/pavement-fountain.tscn")
	if fountain_res:
		var f1: Node3D = fountain_res.instantiate()
		f1.name = "PlazaFountain_Left"
		f1.position = Vector3(-8.5, 0.0, -82.0)
		f1.scale = Vector3(2.0, 2.0, 2.0)
		add_child(f1)

		var f2: Node3D = fountain_res.instantiate()
		f2.name = "PlazaFountain_Right"
		f2.position = Vector3(8.5, 0.0, -82.0)
		f2.scale = Vector3(2.0, 2.0, 2.0)
		add_child(f2)

func _apply_mesh_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_mesh_material_recursive(child, mat)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "HighwayWaypointBeacon"
	add_child(waypoint_node)

	waypoint_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.4, 0.6, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.85, 1.0)
	mat.emission_energy_multiplier = 3.0
	prism.material = mat
	waypoint_mesh.mesh = prism
	waypoint_mesh.rotation_degrees = Vector3(180, 0, 0)
	waypoint_node.add_child(waypoint_mesh)

	waypoint_light = OmniLight3D.new()
	waypoint_light.light_color = Color(0.2, 0.9, 1.0)
	waypoint_light.light_energy = 2.5
	waypoint_light.omni_range = 7.0
	waypoint_node.add_child(waypoint_light)

	waypoint_label = Label3D.new()
	waypoint_label.position = Vector3(0, 0.75, 0)
	waypoint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint_label.font_size = 18
	waypoint_label.outline_size = 6
	waypoint_label.modulate = Color(0.25, 0.95, 1.0)
	waypoint_label.outline_modulate = Color(0.05, 0.15, 0.3)
	waypoint_node.add_child(waypoint_label)

func _update_waypoint_for_stage() -> void:
	match stage:
		1:
			current_target_pos = Vector3(0.0, 2.5, 15.0)
			current_target_name = "Блокпост КПП №2: Прорыв"
		2:
			current_target_pos = Vector3(-6.0, 2.0, 0.0)
			current_target_name = "Терминал шлагбаума [Взлом 4 / E]"
		3, 4:
			current_target_pos = Vector3(0.0, 3.0, -77.0)
			current_target_name = "Медиа-Башня: Центр Краснограда"
		5:
			current_target_pos = Vector3(0.0, 2.0, -77.0)
			current_target_name = "Терминал: Запуск трансляции"
		_:
			if waypoint_node:
				waypoint_node.visible = false
			return

	if waypoint_node:
		waypoint_node.visible = true
		waypoint_node.position = current_target_pos

func _process(_delta: float) -> void:
	# Пульсация навигационного маяка
	if waypoint_node and waypoint_node.visible:
		var time := Time.get_ticks_msec() / 1000.0
		var hover_y: float = sin(time * 3.5) * 0.18
		waypoint_node.position = current_target_pos + Vector3(0, hover_y, 0)
		if waypoint_mesh:
			waypoint_mesh.rotation_degrees.y = fmod(time * 75.0, 360.0)
		if waypoint_label and player:
			var dist: float = player.global_position.distance_to(current_target_pos)
			waypoint_label.text = "%s
[ %.1f м ]" % [current_target_name, dist]

	# Анимация трансляции на Телебашне
	if is_broadcasting and tower_beam_light:
		var time := Time.get_ticks_msec() / 1000.0
		tower_beam_light.light_energy = 6.0 + sin(time * 8.0) * 2.5
		tower_beam_light.light_color = Color(0.2, 0.9, 1.0) if fmod(time, 0.6) < 0.3 else Color(1.0, 0.2, 0.3)

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
		_update_waypoint_for_stage()

func _on_barrier_opened() -> void:
	if stage == 2:
		stage = 3
		mission_mgr.call("complete_objective", "breach_checkpoint")
		dialogue_mgr.call("queue_message", "СашаV", "Шлагбаум открыт! Прорывайся к медиа-вышке в центре города!", Color(0.3, 1.0, 0.4), 4.5)
		_update_waypoint_for_stage()

func _on_broadcast_started() -> void:
	if stage >= 2:
		stage = 5
		is_broadcasting = true
		mission_mgr.call("complete_objective", "reach_plaza")
		mission_mgr.call("complete_objective", "broadcast_manifesto")
		_update_waypoint_for_stage()

func _on_mission_victory(_title: String) -> void:
	stage = 6
	_update_waypoint_for_stage()
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
	quest_label.text = "
".join(lines)
