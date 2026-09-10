class_name CityHighway
extends Node3D

# Контроллер Миссии 3 «Операция: Свободный Красноград» (Открытый мир / v0.7.0)
# Шоссе Краснограда: Скоростная доставка партии Коли, прорыв блокпоста КПП №2 MERIDIAN,
# взлом ретрансляционной вышки и трансляция манифеста сопротивления на весь город!
# Включает: динамический 3D-маяк навигации, ночной киберпанк-скайлайн, фонарные столбы и разметку.

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const VendingMachineScript = preload("res://scripts/interaction/vending_machine.gd")
const LootContainerScript = preload("res://scripts/interaction/loot_container.gd")
const LoreTerminalScript = preload("res://scripts/interaction/lore_terminal.gd")
const DestructibleCrateScript = preload("res://scripts/physics/destructible_crate.gd")
const ExplosiveBarrelScript = preload("res://scripts/physics/explosive_barrel.gd")

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
	_spawn_road_exit_gates()
	_start_mission_intro()
	_update_waypoint_for_stage()

func _spawn_highway_world_details() -> void:
	var mat_metal: Material = load("res://assets/materials/mat_metal.tres")
	var mat_metal_ind: Material = load("res://assets/materials/mat_metal_industrial.tres")
	var mat_concrete: Material = load("res://assets/materials/mat_concrete.tres")
	var mat_neon_cyan: Material = load("res://assets/materials/mat_neon_cyan.tres")
	var mat_neon_amber: Material = load("res://assets/materials/mat_neon_amber.tres")

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
			add_child(light)

	# 2. Дорожная разметка: прерывистая осевая линия шоссе
	var center_line_node := Node3D.new()
	center_line_node.name = "HighwayCenterLine"
	add_child(center_line_node)
	var z_cur: float = 95.0
	while z_cur >= -60.0:
		if abs(z_cur) > 4.0:
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

	# 4. Небоскрёбы Городского Каньона (полная застройка от старта до финиша — ноль пустоты!)
	var highway_canyon = [
		# Левая сторона каньона (x = -24)
		{"type": "building_A", "pos": Vector3(-24.0, 0.0, 85.0), "rot": 90, "scale": Vector3(5.0, 8.0, 5.0)},
		{"type": "building_B", "pos": Vector3(-24.0, 0.0, 55.0), "rot": 90, "scale": Vector3(5.0, 7.5, 5.0)},
		{"type": "building_C", "pos": Vector3(-24.0, 0.0, 25.0), "rot": 90, "scale": Vector3(5.0, 7.0, 5.0)},
		{"type": "building_D", "pos": Vector3(-24.0, 0.0, -10.0), "rot": 90, "scale": Vector3(5.0, 8.0, 5.0)},
		{"type": "building_E", "pos": Vector3(-24.0, 0.0, -40.0), "rot": 90, "scale": Vector3(5.0, 8.5, 5.0)},
		# Правая сторона каньона (x = 24)
		{"type": "building_F", "pos": Vector3(24.0, 0.0, 85.0), "rot": -90, "scale": Vector3(5.0, 8.0, 5.0)},
		{"type": "building_G", "pos": Vector3(24.0, 0.0, 55.0), "rot": -90, "scale": Vector3(5.0, 7.5, 5.0)},
		{"type": "building_H", "pos": Vector3(24.0, 0.0, 25.0), "rot": -90, "scale": Vector3(5.0, 7.0, 5.0)},
		{"type": "building_A", "pos": Vector3(24.0, 0.0, -10.0), "rot": -90, "scale": Vector3(5.0, 8.0, 5.0)},
		{"type": "building_B", "pos": Vector3(24.0, 0.0, -40.0), "rot": -90, "scale": Vector3(5.0, 8.5, 5.0)},
		# Южный торец за спиной игрока на старте
		{"type": "building_G", "pos": Vector3(0.0, 0.0, 108.0), "rot": 0, "scale": Vector3(7.0, 8.5, 7.0)},
		# Площадь у Телебашни
		{"type": "building_A", "pos": Vector3(-24.0, 0.0, -70.0), "rot": 90, "scale": Vector3(5.5, 7.5, 5.5)},
		{"type": "building_B", "pos": Vector3(24.0, 0.0, -70.0), "rot": -90, "scale": Vector3(5.5, 7.0, 5.5)},
		{"type": "building_E", "pos": Vector3(-25.0, 0.0, -92.0), "rot": 90, "scale": Vector3(5.0, 8.0, 5.0)},
		{"type": "building_F", "pos": Vector3(25.0, 0.0, -92.0), "rot": -90, "scale": Vector3(5.0, 8.5, 5.0)},
		{"type": "building_G", "pos": Vector3(0.0, 0.0, -108.0), "rot": 180, "scale": Vector3(6.5, 9.0, 6.5)},
		{"type": "building_H", "pos": Vector3(-14.0, 0.0, -102.0), "rot": 135, "scale": Vector3(4.8, 6.5, 4.8)},
		{"type": "building_C", "pos": Vector3(14.0, 0.0, -102.0), "rot": -135, "scale": Vector3(4.8, 6.5, 4.8)}
	]
	for b_info in highway_canyon:
		var b_res: PackedScene = load("res://assets/scenes_3d/%s.tscn" % b_info["type"])
		if b_res:
			var bld: Node3D = b_res.instantiate()
			bld.name = "Canyon_%s_%.0f" % [b_info["type"], b_info["pos"].z]
			bld.position = b_info["pos"]
			bld.rotation_degrees = Vector3(0, b_info["rot"], 0)
			bld.scale = b_info["scale"]
			if mat_metal_ind:
				_apply_mesh_material_recursive(bld, mat_metal_ind)
			add_child(bld)

	# 5. Укрепления и охранный пост КПП №2
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

		var booth_scene: PackedScene = load("res://assets/scenes_3d/building-small-a.tscn")
		if booth_scene:
			var b1: Node3D = booth_scene.instantiate()
			b1.name = "CheckpointBooth_Left"
			b1.position = Vector3(-9.5, 0.0, 0.5)
			b1.scale = Vector3(1.4, 1.4, 1.4)
			if mat_concrete:
				_apply_mesh_material_recursive(b1, mat_concrete)
			add_child(b1)

	# 5.1 Сюжетный терминал КПП №2 (LoreTerminal)
	var cp_lore: Node3D = LoreTerminalScript.new()
	cp_lore.name = "CheckpointLoreTerminal"
	cp_lore.set("terminal_title", "Терминал КПП №2")
	cp_lore.set("lore_header", "СЕКРЕТНЫЙ ПРИКАЗ СИНДИКАТА №402")
	cp_lore.set("lore_text", "Внимание патрулям! Полная блокада 4-го сектора. Все поставки сахара и газировки немедленно конфисковать в пользу Цитадели.")
	cp_lore.position = Vector3(-9.2, 0.9, 0.5)
	cp_lore.rotation_degrees = Vector3(0, 90, 0)
	add_child(cp_lore)

	# 6. Многополосный затор брошенных автомобилей на шоссе (Traffic Jam)
	var jam_vehicles = [
		{"type": "car_sedan", "pos": Vector3(-2.8, 0.0, 72.0), "rot": Vector3(0, -18, 0), "scale": Vector3(1, 1, 1)},
		{"type": "car_hatchback", "pos": Vector3(3.2, 0.0, 62.0), "rot": Vector3(0, 25, 0), "scale": Vector3(1, 1, 1)},
		{"type": "vehicle-truck-purple", "pos": Vector3(-2.4, 0.0, 44.0), "rot": Vector3(0, -8, 0), "scale": Vector3(1.3, 1.3, 1.3)},
		{"type": "car_stationwagon", "pos": Vector3(3.0, 0.0, 20.0), "rot": Vector3(0, 15, 0), "scale": Vector3(1, 1, 1)},
		{"type": "vehicle-motorcycle", "pos": Vector3(-1.8, 0.0, 8.0), "rot": Vector3(0, 75, 0), "scale": Vector3(1, 1, 1)},
		{"type": "car_police", "pos": Vector3(-3.5, 0.0, -15.0), "rot": Vector3(0, -28, 0), "scale": Vector3(1, 1, 1)},
		{"type": "vehicle-truck-green", "pos": Vector3(2.8, 0.0, -36.0), "rot": Vector3(0, 14, 0), "scale": Vector3(1.25, 1.25, 1.25)}
	]
	for v_info in jam_vehicles:
		var v_scene: PackedScene = load("res://assets/scenes_3d/%s.tscn" % v_info["type"])
		if v_scene:
			var v_inst: Node3D = v_scene.instantiate()
			v_inst.name = "Jam_%s_%.0f" % [v_info["type"], v_info["pos"].z]
			v_inst.position = v_info["pos"]
			v_inst.rotation_degrees = v_info["rot"]
			v_inst.scale = v_info["scale"]
			add_child(v_inst)

	# 7. Интерактивные лутаемые багажники брошенных автомобилей (LootContainer)
	var trunk1: Node3D = LootContainerScript.new()
	trunk1.name = "TrunkSedanLoot"
	trunk1.set("container_title", "Багажник брошенного седана")
	trunk1.set("credits_reward", 75)
	trunk1.set("is_locked", false)
	trunk1.position = Vector3(-2.8, 0.35, 74.2)
	trunk1.rotation_degrees = Vector3(0, -18, 0)
	add_child(trunk1)

	var trunk2: Node3D = LootContainerScript.new()
	trunk2.name = "TrunkWagonLoot"
	trunk2.set("container_title", "Багажник универсала")
	trunk2.set("credits_reward", 90)
	trunk2.set("is_locked", false)
	trunk2.position = Vector3(3.0, 0.35, 22.4)
	trunk2.rotation_degrees = Vector3(0, 15, 0)
	add_child(trunk2)

	var trunk3: Node3D = LootContainerScript.new()
	trunk3.name = "TrunkPoliceLoot"
	trunk3.set("container_title", "Оружейный багажник патруля")
	trunk3.set("credits_reward", 160)
	trunk3.set("is_locked", true) # Заперт, взламывается кибер-декой [4]
	trunk3.position = Vector3(-3.5, 0.35, -17.2)
	trunk3.rotation_degrees = Vector3(0, -28, 0)
	add_child(trunk3)

	# Патрульный авто охраны на КПП
	var cop_scene: PackedScene = load("res://assets/scenes_3d/car_police.tscn")
	if cop_scene:
		var cop: Node3D = cop_scene.instantiate()
		cop.name = "Checkpoint_PoliceCar"
		cop.position = Vector3(6.5, 0.0, 3.5)
		cop.rotation_degrees = Vector3(0, 160, 0)
		add_child(cop)

	# 8. Мощный трансляционный маяк на вершине Телебашни
	tower_beam_light = OmniLight3D.new()
	tower_beam_light.name = "BroadcastTowerBeacon"
	tower_beam_light.position = Vector3(0.0, 28.0, -80.0)
	tower_beam_light.light_color = Color(1.0, 0.15, 0.25)
	tower_beam_light.light_energy = 4.0
	tower_beam_light.omni_range = 35.0
	add_child(tower_beam_light)

	# 9. Отбойники шоссе (wall-low) и придорожные деревья (grass-trees)
	var wall_low_res: PackedScene = load("res://assets/scenes_3d/wall-low.tscn")
	var tree_res: PackedScene = load("res://assets/scenes_3d/grass-trees.tscn")
	var z_b: float = 90.0
	var barrier_idx: int = 0
	while z_b >= -55.0:
		if abs(z_b) > 4.5:
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

	# 10. Неоновые информационные табло над трассой
	var gantry_sign := Label3D.new()
	gantry_sign.name = "HighwayGantrySign"
	gantry_sign.position = Vector3(0.0, 7.5, 12.0)
	gantry_sign.text = "▲ КПП №2: СЕКТОР КРАСНОГРАД-ЦЕНТР ▲"
	gantry_sign.font_size = 28
	gantry_sign.modulate = Color(1.0, 0.75, 0.2)
	gantry_sign.outline_size = 8
	add_child(gantry_sign)

	var gantry_sign2 := Label3D.new()
	gantry_sign2.name = "HighwayGantrySign2"
	gantry_sign2.position = Vector3(0.0, 7.5, 52.0)
	gantry_sign2.text = "◆ ВНИМАНИЕ: СКОРОСТНОЕ ШОССЕ КРАСНОГРАДА ◆"
	gantry_sign2.font_size = 24
	gantry_sign2.modulate = Color(0.2, 0.85, 1.0)
	gantry_sign2.outline_size = 8
	add_child(gantry_sign2)

	# 11. Фонтаны и благоустройство Городской Площади у Телебашни
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

	var bench_res: PackedScene = load("res://assets/scenes_3d/bench.tscn")
	if bench_res:
		var b1: Node3D = bench_res.instantiate()
		b1.name = "PlazaBench_1"
		b1.position = Vector3(-6.2, 0.0, -74.0)
		b1.rotation_degrees = Vector3(0, 45, 0)
		add_child(b1)

		var b2: Node3D = bench_res.instantiate()
		b2.name = "PlazaBench_2"
		b2.position = Vector3(6.2, 0.0, -74.0)
		b2.rotation_degrees = Vector3(0, -45, 0)
		add_child(b2)

	# Автомат «Кока-Коля» на городской площади для подкрепления
	var plaza_vend: Node3D = VendingMachineScript.new()
	plaza_vend.name = "PlazaVendingMachine"
	plaza_vend.position = Vector3(-5.0, 0.0, -78.0)
	plaza_vend.rotation_degrees = Vector3(0, 30, 0)
	add_child(plaza_vend)

	# 12. Физические взрывоопасные бочки горючего (ExplosiveBarrel)
	var highway_barrels = [
		Vector3(-4.2, 0.6, 2.5),
		Vector3(4.2, 0.6, 2.5),
		Vector3(-8.5, 0.6, 3.2),
		Vector3(-8.0, 0.6, 3.8),
		Vector3(8.5, 0.6, -72.0),
		Vector3(-8.5, 0.6, -72.0)
	]
	for i in range(highway_barrels.size()):
		var b_inst: RigidBody3D = ExplosiveBarrelScript.new()
		b_inst.name = "HighwayExplosiveBarrel_%d" % i
		b_inst.position = highway_barrels[i]
		add_child(b_inst)

	# 13. Разрушаемые ящики снабжения (DestructibleCrate)
	var highway_crates = [
		Vector3(-7.5, 0.5, -2.5),
		Vector3(-8.2, 0.5, -3.2),
		Vector3(5.5, 0.5, 4.0),
		Vector3(-1.2, 0.5, 32.0),
		Vector3(3.8, 0.5, -66.0),
		Vector3(-7.2, 0.5, -76.0)
	]
	for i in range(highway_crates.size()):
		var c_inst: RigidBody3D = DestructibleCrateScript.new()
		c_inst.name = "HighwayDestructibleCrate_%d" % i
		c_inst.position = highway_crates[i]
		add_child(c_inst)

	# ═══ AAA РАСШИРЕНИЕ v2.0 ═══════════════════════════════════════════════

	# 14. Лужи на шоссе
	for pp in [Vector3(-2.0,0.22,45.0), Vector3(3.0,0.22,25.0), Vector3(-1.5,0.22,-18.0), Vector3(2.5,0.22,-50.0)]:
		var pd := MeshInstance3D.new()
		var pq := QuadMesh.new(); pq.size = Vector2(2.5, 1.2)
		pq.orientation = PlaneMesh.FACE_Y
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.1,0.15,0.22,0.65)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.metallic = 0.95; pm.roughness = 0.02
		pd.mesh = pq; pd.material_override = pm; pd.position = pp
		add_child(pd)

	# 16. Граффити на отбойниках КПП
	var hw_graffiti := [
		{"pos": Vector3(-13.0,1.2,1.0), "rot": Vector3(0,90,0), "text": "СВОБОДУ КРАСНОГРАДУ!", "col": Color(1.0,0.1,0.1)},
		{"pos": Vector3(13.5,1.0,-1.0), "rot": Vector3(0,-90,0), "text": "ДОЛОЙ СИНДИКАТ!", "col": Color(0.2,1.0,0.3)},
		{"pos": Vector3(0.0,1.5,98.0),  "rot": Vector3(0,180,0), "text": "КОЛЯ ЗДЕСЬ БЫЛ", "col": Color(1.0,0.85,0.0)},
	]
	for gd in hw_graffiti:
		var g := Label3D.new()
		g.text = gd["text"]; g.font_size = 14; g.modulate = gd["col"]; g.outline_size = 2
		g.position = gd["pos"]; g.rotation_degrees = gd["rot"]
		add_child(g)

	# 17. Дополнительные небоскрёбы на горизонте (фон)
	var bg_hw := [
		{"x": -42.0, "z": 40.0, "h": 50.0}, {"x": 42.0, "z": 40.0, "h": 55.0},
		{"x": -42.0, "z": -20.0, "h": 45.0}, {"x": 42.0, "z": -20.0, "h": 48.0},
		{"x": -42.0, "z": -80.0, "h": 60.0}, {"x": 42.0, "z": -80.0, "h": 58.0},
	]
	for bh in bg_hw:
		var bb := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(8.0, bh["h"], 8.0)
		bb.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.06, 0.09, 0.16)
		bmat.metallic = 0.5; bmat.roughness = 0.4
		bb.material_override = bmat
		bb.position = Vector3(bh["x"], bh["h"]*0.5, bh["z"])
		add_child(bb)
		# Сигнальный свет на крыше
		var sl := OmniLight3D.new()
		sl.position = Vector3(bh["x"], bh["h"] + 0.5, bh["z"])
		sl.light_color = Color(1.0, 0.2, 0.2); sl.light_energy = 2.0; sl.omni_range = 5.0
		add_child(sl)

	# 18. Рекламные щиты над шоссе
	var hw_billboard_data := [
		{"pos": Vector3(-18.0, 10.0, 55.0), "rot": Vector3(0,90,0), "text": "КОКА-КОЛЯ: ВКУС СВОБОДЫ ★"},
		{"pos": Vector3(18.0, 10.0, 25.0),  "rot": Vector3(0,-90,0), "text": "MERIDIAN CORP — МЫ ЗАБОТИМСЯ"},
		{"pos": Vector3(-18.0, 10.0, -15.0),"rot": Vector3(0,90,0),  "text": "★ НОВЫЙ ВКУС: КОЛА ПЛЮС ★"},
	]
	for bd in hw_billboard_data:
		var sign := Label3D.new()
		sign.text = bd["text"]; sign.font_size = 20
		sign.modulate = Color(0.2, 0.9, 1.0); sign.outline_size = 6
		sign.position = bd["pos"]; sign.rotation_degrees = bd["rot"]
		add_child(sign)
		var sl2 := SpotLight3D.new()
		sl2.position = bd["pos"] + Vector3(0, 2.0, 0)
		sl2.rotation_degrees = Vector3(-30, bd["rot"].y, 0)
		sl2.light_color = Color(0.2, 0.9, 1.0); sl2.light_energy = 3.0
		sl2.spot_range = 10.0; sl2.spot_angle = 40.0
		add_child(sl2)

	# 19. Предупреждающие конусы на дороге
	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color(1.0, 0.42, 0.0); cone_mat.roughness = 0.8
	for cx in [Vector3(-3.5, 0.22, 6.0), Vector3(-2.8, 0.22, -2.0), Vector3(3.2, 0.22, 4.5), Vector3(2.6, 0.22, -4.0)]:
		var cone := MeshInstance3D.new()
		var con_m := CylinderMesh.new()
		con_m.top_radius = 0.01; con_m.bottom_radius = 0.2; con_m.height = 0.55
		cone.mesh = con_m; cone.material_override = cone_mat
		cone.position = cx; add_child(cone)

	# 20. Дополнительные NPC у КПП и площади
	var npc_hw: PackedScene = load("res://scenes/characters/npc_character.tscn")
	if npc_hw:
		for nd in [{"p": Vector3(-9.5,0,-2.5),"r":45.0}, {"p":Vector3(5.0,0,-80.0),"r":-30.0}, {"p":Vector3(-5.0,0,-78.0),"r":120.0}]:
			var n: Node3D = npc_hw.instantiate()
			n.position = nd["p"]; n.rotation_degrees = Vector3(0, nd["r"], 0)
			add_child(n)


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
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup_victory_panel_buttons()

	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("mark_mission_completed", "operation_free_krasnograd")

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", 2.0)

	dialogue_mgr.call("queue_message", "СашаV", "Трансляция идет на каждый экран города! Красноград свободен! Кока-Коля победила!", Color(0.3, 1.0, 0.4), 6.0)
	LogManager.info(">>> ГЛОБАЛЬНАЯ КАМПАНИЯ «КОКА-КОЛЯ» (v0.7.0) УСПЕШНО ЗАВЕРШЕНА! <<<", "VICTORY")

func _setup_victory_panel_buttons() -> void:
	if not victory_panel:
		return
	var vbox = victory_panel.get_node_or_null("Margin/VBox")
	if not vbox or vbox.has_node("BtnNextDistrict"):
		return

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_next := Button.new()
	btn_next.name = "BtnNextDistrict"
	btn_next.text = " ▶ СЛЕДУЮЩИЙ РАЙОН: НЕОНОВЫЙ БУЛЬВАР "
	btn_next.custom_minimum_size = Vector2(0, 44)
	btn_next.add_theme_font_size_override("font_size", 15)
	btn_next.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	btn_next.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("change_district"):
			gm.call("change_district", "neon_boulevard", true)
		else:
			get_tree().change_scene_to_file("res://scenes/levels/neon_boulevard.tscn")
	)
	vbox.add_child(btn_next)

	var btn_map := Button.new()
	btn_map.name = "BtnOpenMap"
	btn_map.text = " 🗺️ КАРТА ГОРОДА (ВЫБОР РАЙОНА) "
	btn_map.custom_minimum_size = Vector2(0, 38)
	btn_map.pressed.connect(func() -> void:
		victory_panel.visible = false
		var cdm: Node = get_node_or_null("/root/CyberdeckManager")
		if cdm and cdm.has_method("open_pda"):
			cdm.call("open_pda")
	)
	vbox.add_child(btn_map)

	var btn_menu := Button.new()
	btn_menu.name = "BtnReturnMenu"
	btn_menu.text = " 🏠 В ГЛАВНОЕ МЕНЮ "
	btn_menu.custom_minimum_size = Vector2(0, 38)
	btn_menu.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("change_district"):
			gm.call("change_district", "main_menu", true)
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	vbox.add_child(btn_menu)

func _spawn_road_exit_gates() -> void:
	var gate_script = load("res://scripts/world/road_exit_gate.gd")
	if not gate_script:
		return

	# 1. Северный выезд на Неоновый бульвар (за медиа-башней)
	var north_gate = Node3D.new()
	north_gate.set_script(gate_script)
	north_gate.name = "ExitGate_NeonBoulevard"
	north_gate.set("target_district_id", "neon_boulevard")
	north_gate.set("gate_title", "НЕОНОВЫЙ БУЛЬВАР")
	north_gate.set("direction_hint", "Въезд в Даунтаун: небоскрёбы, эстакада и Неон-Плаза")
	north_gate.position = Vector3(0, 0, -105)
	add_child(north_gate)

	# 2. Южный возврат в Старый район (начало шоссе)
	var south_gate = Node3D.new()
	south_gate.set_script(gate_script)
	south_gate.name = "ExitGate_OldDistrict"
	south_gate.set("target_district_id", "old_district")
	south_gate.set("gate_title", "СТАРЫЙ РАЙОН")
	south_gate.set("direction_hint", "Возврат в трущобы и конспиративный гараж Коли")
	south_gate.position = Vector3(0, 0, 95)
	add_child(south_gate)

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
