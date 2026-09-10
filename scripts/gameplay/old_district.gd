class_name OldDistrict
extends Node3D

# Игровой контроллер Первого играбельного района «Старый район & Складской терминал №4» (v0.3.0)
# Включает:
# - Динамическую 3D-навигацию (Waypoint Beacon) с дистанцией до активной цели
# - Пошаговую кампанию с радиопереговорами и фиксацией груза
# - Реактивные HUD-уведомления и звуковое сопровождение

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const RoadExitGateScript = preload("res://scripts/world/road_exit_gate.gd")

# Предзагрузка PBR-материалов для устранения фризов основного потока
const MAT_ASPHALT: Material = preload("res://assets/materials/mat_asphalt.tres")
const MAT_PAVING: Material = preload("res://assets/materials/mat_paving.tres")
const MAT_GRASS: Material = preload("res://assets/materials/mat_grass.tres")
const MAT_FOLIAGE: Material = preload("res://assets/materials/mat_foliage.tres")
const MAT_BRICK: Material = preload("res://assets/materials/mat_brick.tres")
const MAT_CONCRETE: Material = preload("res://assets/materials/mat_concrete.tres")
const MAT_BRICK_DARK: Material = preload("res://assets/materials/mat_brick_dark.tres")
const MAT_SANDSTONE: Material = preload("res://assets/materials/mat_sandstone.tres")
const MAT_METAL: Material = preload("res://assets/materials/mat_metal.tres")
const MAT_BILLBOARD: Material = preload("res://assets/materials/mat_neon_billboard.tres")

# Предзагрузка 3D-моделей и сцен
const NPC_SCENE: PackedScene = preload("res://scenes/characters/npc_character.tscn")
const CAR_POLICE_SCENE: PackedScene = preload("res://assets/scenes_3d/car_police.tscn")
const CAR_SEDAN_SCENE: PackedScene = preload("res://assets/scenes_3d/car_sedan.tscn")
const CAR_HATCH_SCENE: PackedScene = preload("res://assets/scenes_3d/car_hatchback.tscn")
const CAR_WAGON_SCENE: PackedScene = preload("res://assets/scenes_3d/car_stationwagon.tscn")
const CAR_TRUCK_SCENE: PackedScene = preload("res://assets/scenes_3d/vehicle-truck-purple.tscn")
const BENCH_SCENE: PackedScene = preload("res://assets/scenes_3d/bench.tscn")
const WALL_HIGH_SCENE: PackedScene = preload("res://assets/scenes_3d/wall-high.tscn")
const BOX_A_SCENE: PackedScene = preload("res://assets/scenes_3d/box_A.tscn")
const BOX_B_SCENE: PackedScene = preload("res://assets/scenes_3d/box_B.tscn")

const BUILDING_SCENES: Array[PackedScene] = [
	preload("res://assets/scenes_3d/building_A.tscn"),
	preload("res://assets/scenes_3d/building_B.tscn"),
	preload("res://assets/scenes_3d/building_C.tscn"),
	preload("res://assets/scenes_3d/building_D.tscn"),
	preload("res://assets/scenes_3d/building_E.tscn"),
	preload("res://assets/scenes_3d/building_F.tscn"),
	preload("res://assets/scenes_3d/building_G.tscn"),
	preload("res://assets/scenes_3d/building_H.tscn")
]

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
	_spawn_world_details()
	_spawn_road_exit_gates()
	_start_mission_intro()
	_update_waypoint_for_stage()

func _spawn_world_details() -> void:
	# 0. Инициализация и наложение фотореалистичных PBR материалов на геометрию уровня
	var city_arch: Node3D = get_node_or_null("CityArchitecture")
	if city_arch:
		_apply_city_materials_recursive(city_arch, MAT_ASPHALT, MAT_PAVING, MAT_GRASS, MAT_FOLIAGE)

	# 1. Спавн 3D-модели связного Саши V (Rogue_Hooded) возле гаража Коли
	if NPC_SCENE:
		var sasha: Node3D = NPC_SCENE.instantiate()
		sasha.name = "SashaV_NPC"
		sasha.set("is_sasha", true)
		sasha.set("npc_name", "Саша V (Сопротивление)")
		sasha.position = Vector3(3.5, 0.0, 52.0)
		sasha.rotation_degrees = Vector3(0, -140, 0)
		add_child(sasha)

	# 2. Спавн патрульной машины (car_police) на обочине улицы
	if CAR_POLICE_SCENE:
		var cop_car: Node3D = CAR_POLICE_SCENE.instantiate()
		cop_car.name = "PoliceCruiser_Deco"
		cop_car.position = Vector3(-6.2, 0.0, 18.0)
		cop_car.rotation_degrees = Vector3(0, 15, 0)
		add_child(cop_car)

	# 3. Спавн седана горожан (car_sedan) у площади
	if CAR_SEDAN_SCENE:
		var sedan: Node3D = CAR_SEDAN_SCENE.instantiate()
		sedan.name = "CitySedan_Deco"
		sedan.position = Vector3(6.5, 0.0, 5.0)
		sedan.rotation_degrees = Vector3(0, -10, 0)
		add_child(sedan)

	# 4. Хэтчбек и универсал жителей города
	if CAR_HATCH_SCENE:
		var hatch: Node3D = CAR_HATCH_SCENE.instantiate()
		hatch.name = "CityHatch_Deco"
		hatch.position = Vector3(-6.2, 0.0, 34.0)
		hatch.rotation_degrees = Vector3(0, 20, 0)
		add_child(hatch)

	if CAR_WAGON_SCENE:
		var wagon: Node3D = CAR_WAGON_SCENE.instantiate()
		wagon.name = "CityWagon_Deco"
		wagon.position = Vector3(6.2, 0.0, -8.0)
		wagon.rotation_degrees = Vector3(0, -15, 0)
		add_child(wagon)

	# 5. Грузовой фургон корпорации в переулке
	if CAR_TRUCK_SCENE:
		var truck: Node3D = CAR_TRUCK_SCENE.instantiate()
		truck.name = "CargoTruck_Deco"
		truck.position = Vector3(-7.5, 0.0, -16.0)
		truck.rotation_degrees = Vector3(0, 90, 0)
		truck.scale = Vector3(1.3, 1.3, 1.3)
		add_child(truck)

	# 6. Уличные скамейки (bench.tscn) вдоль тротуаров
	if BENCH_SCENE:
		var bench_spots = [
			Vector3(-4.1, 0.12, 42.0),
			Vector3(4.1, 0.12, 40.0),
			Vector3(-4.1, 0.12, 26.0),
			Vector3(4.1, 0.12, 22.0),
			Vector3(-4.1, 0.12, 8.0),
			Vector3(4.1, 0.12, -4.0)
		]
		for i in range(bench_spots.size()):
			var b: Node3D = BENCH_SCENE.instantiate()
			b.name = "Bench_%d" % i
			b.position = bench_spots[i]
			b.rotation_degrees = Vector3(0, 90 if bench_spots[i].x < 0 else -90, 0)
			b.scale = Vector3(1.2, 1.2, 1.2)
			add_child(b)

	# 7. Уличные фонари с физическими столбами и теплым светом (OmniLight3D)
	var lamp_z_coords = [46.0, 30.0, 14.0, -2.0, -18.0]
	for z_pos in lamp_z_coords:
		for x_side in [-4.3, 4.3]:
			var pole := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.06
			p_mesh.bottom_radius = 0.1
			p_mesh.height = 3.2
			pole.mesh = p_mesh
			if MAT_METAL:
				pole.material_override = MAT_METAL
			pole.position = Vector3(x_side, 1.6, z_pos)
			add_child(pole)

			var head := MeshInstance3D.new()
			var s_mesh := SphereMesh.new()
			s_mesh.radius = 0.16
			s_mesh.height = 0.32
			head.mesh = s_mesh
			var glow_mat := StandardMaterial3D.new()
			glow_mat.albedo_color = Color(1.0, 0.92, 0.75)
			glow_mat.emission_enabled = true
			glow_mat.emission = Color(1.0, 0.88, 0.65)
			glow_mat.emission_energy_multiplier = 2.0
			head.material_override = glow_mat
			head.position = Vector3(x_side, 3.2, z_pos)
			add_child(head)

			var lamp := OmniLight3D.new()
			lamp.name = "StreetLamp_Light_%.0f_%.0f" % [x_side, z_pos]
			lamp.position = Vector3(x_side, 3.2, z_pos)
			lamp.light_color = Color(1.0, 0.90, 0.72)
			lamp.light_energy = 1.8
			lamp.omni_range = 8.0
			lamp.omni_attenuation = 1.4
			lamp.shadow_enabled = false
			add_child(lamp)

	# 8. Настоящие 3D здания (building_A - building_H) вдоль улицы с PBR отделкой
	var bld_materials: Array[Material] = [MAT_BRICK, MAT_CONCRETE, MAT_BRICK_DARK, MAT_SANDSTONE]
	var street_z_list = [52.0, 44.0, 36.0, 28.0, 20.0, 12.0, 4.0, -4.0, -12.0, -20.0, -28.0]
	for idx in range(street_z_list.size()):
		var z_val = street_z_list[idx]
		# Левая сторона
		var left_res: PackedScene = BUILDING_SCENES[idx % BUILDING_SCENES.size()]
		if left_res:
			var lb: Node3D = left_res.instantiate()
			lb.name = "StreetBld_L_%d" % idx
			lb.position = Vector3(-8.8, 0.0, z_val)
			lb.rotation_degrees = Vector3(0, 90, 0)
			lb.scale = Vector3(4.0, 4.0 + (idx % 3) * 0.5, 4.0)
			if bld_materials.size() > 0:
				_apply_mesh_material_recursive(lb, bld_materials[idx % bld_materials.size()])
			add_child(lb)
		# Правая сторона
		var right_res: PackedScene = BUILDING_SCENES[(idx + 3) % BUILDING_SCENES.size()]
		if right_res:
			var rb: Node3D = right_res.instantiate()
			rb.name = "StreetBld_R_%d" % idx
			rb.position = Vector3(8.8, 0.0, z_val)
			rb.rotation_degrees = Vector3(0, -90, 0)
			rb.scale = Vector3(4.0, 4.2 + ((idx + 1) % 3) * 0.5, 4.0)
			if bld_materials.size() > 0:
				_apply_mesh_material_recursive(rb, bld_materials[(idx + 2) % bld_materials.size()])
			add_child(rb)

	# 9. Защитные стены периметра склада (wall-high, wall-low)
	if WALL_HIGH_SCENE:
		var wall_coords = [
			Vector3(-9.0, 0.0, -36.0),
			Vector3(-9.0, 0.0, -42.0),
			Vector3(-9.0, 0.0, -48.0),
			Vector3(9.0, 0.0, -36.0),
			Vector3(9.0, 0.0, -42.0),
			Vector3(9.0, 0.0, -48.0)
		]
		for i in range(wall_coords.size()):
			var w: Node3D = WALL_HIGH_SCENE.instantiate()
			w.name = "PerimeterWall_%d" % i
			w.position = wall_coords[i]
			w.rotation_degrees = Vector3(0, 0, 0)
			w.scale = Vector3(3.5, 3.5, 3.5)
			add_child(w)

	# 10. Промышленные ящики у терминала (box_A, box_B)
	if BOX_A_SCENE and BOX_B_SCENE:
		var crate_spots = [
			Vector3(-4.8, 0.0, -28.0),
			Vector3(-5.2, 0.0, -29.0),
			Vector3(5.0, 0.0, -27.5),
			Vector3(5.5, 0.0, -28.8)
		]
		for i in range(crate_spots.size()):
			var bx: Node3D = (BOX_A_SCENE if i % 2 == 0 else BOX_B_SCENE).instantiate()
			bx.name = "DecoCrate_%d" % i
			bx.position = crate_spots[i]
			bx.scale = Vector3(1.5, 1.5, 1.5)
			add_child(bx)

	# 11. Эффект клубящегося пара из канализационных люков (CPUParticles3D)
	var steam_spots = [Vector3(1.0, 0.04, 34.0), Vector3(-1.2, 0.04, 10.0), Vector3(0.5, 0.04, -14.0)]
	for i in range(steam_spots.size()):
		var steam := CPUParticles3D.new()
		steam.name = "ManholeSteam_%d" % i
		steam.position = steam_spots[i]
		steam.amount = 18
		steam.lifetime = 2.4
		steam.preprocess = 1.0
		steam.explosiveness = 0.0
		steam.randomness = 0.3
		steam.direction = Vector3(0, 1, 0)
		steam.spread = 15.0
		steam.gravity = Vector3(0, 0.45, 0)
		steam.initial_velocity_min = 0.4
		steam.initial_velocity_max = 0.8
		var p_mesh := SphereMesh.new()
		p_mesh.radius = 0.18
		p_mesh.height = 0.36
		var p_mat := StandardMaterial3D.new()
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p_mat.albedo_color = Color(0.9, 0.92, 0.95, 0.18)
		p_mat.roughness = 1.0
		p_mesh.material = p_mat
		steam.mesh = p_mesh
		add_child(steam)

	# 12. Неоновая вывеска «КОКА-КОЛЯ: ВКУС СВОБОДЫ» на базе Коли
	var neon_sign := Label3D.new()
	neon_sign.name = "NeonSign_Cola"
	neon_sign.position = Vector3(0.0, 4.8, 50.8)
	neon_sign.text = "★ КОКА-КОЛЯ: ВКУС СВОБОДЫ ★"
	neon_sign.font_size = 32
	neon_sign.modulate = Color(0.3, 1.0, 0.45, 1.0)
	neon_sign.outline_modulate = Color(0.05, 0.4, 0.15, 1.0)
	neon_sign.outline_size = 8
	add_child(neon_sign)

	var neon_light := OmniLight3D.new()
	neon_light.name = "NeonSign_Light"
	neon_light.position = Vector3(0.0, 4.8, 49.8)
	neon_light.light_color = Color(0.3, 1.0, 0.45)
	neon_light.light_energy = 2.2
	neon_light.omni_range = 6.0
	add_child(neon_light)

	# 12.5. Большой светящийся киберпанк-билборд «ИСТИННАЯ СВЕЖЕСТЬ: КОКА-КОЛЯ»
	if MAT_BILLBOARD:
		var bb := MeshInstance3D.new()
		bb.name = "CyberpunkNeonBillboard"
		var b_quad := QuadMesh.new()
		b_quad.size = Vector2(8.0, 4.0)
		bb.mesh = b_quad
		bb.material_override = MAT_BILLBOARD
		bb.position = Vector3(-8.5, 6.5, 22.0)
		bb.rotation_degrees = Vector3(0, 90, 0)
		add_child(bb)

		var bb_light := SpotLight3D.new()
		bb_light.name = "BillboardSpotLight"
		bb_light.light_color = Color(0.0, 0.9, 1.0)
		bb_light.light_energy = 3.5
		bb_light.spot_range = 14.0
		bb_light.spot_angle = 50.0
		bb_light.position = Vector3(-7.2, 6.5, 22.0)
		bb_light.rotation_degrees = Vector3(0, -90, 0)
		add_child(bb_light)

	# 13. Дорожная разметка: Пешеходный переход «зебра» на перекрестке (z = 16)
	var zebra_parent := Node3D.new()
	zebra_parent.name = "RoadMarkings_Zebra"
	add_child(zebra_parent)
	for i in range(-5, 6):
		var stripe := MeshInstance3D.new()
		var q_mesh := QuadMesh.new()
		q_mesh.size = Vector2(0.5, 3.2)
		q_mesh.orientation = PlaneMesh.FACE_Y
		var s_mat := StandardMaterial3D.new()
		s_mat.albedo_color = Color(0.94, 0.95, 0.98, 0.9)
		s_mat.roughness = 0.8
		stripe.mesh = q_mesh
		stripe.material_override = s_mat
		stripe.position = Vector3(i * 0.75, 0.03, 16.0)
		zebra_parent.add_child(stripe)

	# 14. Прерывистая разделительная полоса по центру дороги
	var line_parent := Node3D.new()
	line_parent.name = "RoadMarkings_CenterLine"
	add_child(line_parent)
	var z_coord := 52.0
	while z_coord >= -35.0:
		if abs(z_coord - 16.0) > 3.0:
			var dash := MeshInstance3D.new()
			var d_mesh := QuadMesh.new()
			d_mesh.size = Vector2(0.2, 2.0)
			d_mesh.orientation = PlaneMesh.FACE_Y
			var d_mat := StandardMaterial3D.new()
			d_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.85)
			d_mat.roughness = 0.7
			dash.mesh = d_mesh
			dash.material_override = d_mat
			dash.position = Vector3(0.0, 0.025, z_coord)
			line_parent.add_child(dash)
		z_coord -= 4.0

	# ═══════════════════════════════════════════════════════════════════════
	# AAA РАСШИРЕНИЕ МИРА v2.0 — 16 новых систем деталей окружения
	# ═══════════════════════════════════════════════════════════════════════

	# 15. Мусорные баки
	var trash_spots := [
		Vector3(-4.6, 0.0, 37.0), Vector3(4.5, 0.0, 25.0),
		Vector3(-4.7, 0.0, 6.0),  Vector3(4.6, 0.0, -6.0),
		Vector3(-4.8, 0.0, -20.0),Vector3(-8.5, 0.0, -32.0)
	]
	for i in range(trash_spots.size()):
		var trash := MeshInstance3D.new()
		var t_cyl := CylinderMesh.new()
		t_cyl.top_radius = 0.28
		t_cyl.bottom_radius = 0.24
		t_cyl.height = 0.72
		var t_mat := StandardMaterial3D.new()
		t_mat.albedo_color = [Color(0.2,0.6,0.2), Color(0.2,0.3,0.7), Color(0.7,0.2,0.2)][i % 3]
		t_mat.roughness = 0.7
		trash.mesh = t_cyl
		trash.material_override = t_mat
		trash.position = trash_spots[i] + Vector3(0, 0.36, 0)
		add_child(trash)

	# 16. Граффити на стенах зданий
	var graffiti_data := [
		{"pos": Vector3(-8.9, 2.5, 40.0), "rot": Vector3(0,90,0), "text": "СВОБОДА!", "col": Color(1.0,0.2,0.2)},
		{"pos": Vector3(8.9, 1.8, 26.0),  "rot": Vector3(0,-90,0),"text": "MERIDIAN = ЛОЖЬ", "col": Color(0.2,1.0,0.4)},
		{"pos": Vector3(-8.9, 2.0, 10.0), "rot": Vector3(0,90,0), "text": "КОЛЯ ЖИВ!", "col": Color(1.0,0.85,0.0)},
		{"pos": Vector3(8.9, 3.0, -5.0),  "rot": Vector3(0,-90,0),"text": "СОПРОТИВЛЯЙСЯ", "col": Color(0.3,0.8,1.0)},
		{"pos": Vector3(-8.9, 2.2, -14.0),"rot": Vector3(0,90,0), "text": "НЕТ КОРПОРАЦИЯМ", "col": Color(1.0,0.3,0.9)},
	]
	for gd in graffiti_data:
		var graf := Label3D.new()
		graf.text = gd["text"]; graf.font_size = 20
		graf.modulate = gd["col"]; graf.outline_size = 4
		graf.position = gd["pos"]; graf.rotation_degrees = gd["rot"]
		add_child(graf)

	# 17. Дорожные лужи
	var puddle_pos := [Vector3(-1.5,0.015,38.0), Vector3(1.8,0.015,20.5), Vector3(-0.8,0.015,4.5)]
	for pp in puddle_pos:
		var puddle := MeshInstance3D.new()
		var pq := QuadMesh.new(); pq.size = Vector2(1.8, 0.9)
		pq.orientation = PlaneMesh.FACE_Y
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.15,0.2,0.25,0.6)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.metallic = 0.8; pm.roughness = 0.1
		puddle.mesh = pq; puddle.material_override = pm
		puddle.position = pp
		add_child(puddle)

	# 18. Пожарные гидранты
	var hydrant_mat := StandardMaterial3D.new()
	hydrant_mat.albedo_color = Color(0.9,0.1,0.1)
	hydrant_mat.metallic = 0.7; hydrant_mat.roughness = 0.3
	for hp in [Vector3(-4.6,0,34.8), Vector3(4.5,0,17.2), Vector3(-4.7,0,-1.5)]:
		var hyd := MeshInstance3D.new()
		var hc := CylinderMesh.new()
		hc.top_radius = 0.12; hc.bottom_radius = 0.15; hc.height = 0.55
		hyd.mesh = hc; hyd.material_override = hydrant_mat
		hyd.position = hp + Vector3(0, 0.275, 0)
		add_child(hyd)

	# 19. Дополнительные NPC-прохожие
	if NPC_SCENE:
		var peds := [
			{"pos": Vector3(-3.6, 0.0, 35.0), "rot": 150.0, "name": "Житель района"},
			{"pos": Vector3(3.6, 0.0, 14.0),  "rot": -45.0, "name": "Прохожий"},
			{"pos": Vector3(-3.6, 0.0, 18.0), "rot": 60.0,  "name": "Инженер связи"},
			{"pos": Vector3(3.6, 0.0, -12.0), "rot": -120.0,"name": "Горожанин"},
		]
		for i in range(peds.size()):
			var ped: Node3D = NPC_SCENE.instantiate()
			ped.name = "Pedestrian_%d" % i
			ped.set("npc_name", peds[i]["name"])
			ped.set("is_sasha", false)
			ped.position = peds[i]["pos"]
			ped.rotation_degrees = Vector3(0, peds[i]["rot"], 0)
			add_child(ped)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "WaypointBeacon"
	add_child(waypoint_node)

	# Светящийся кристалл маркера
	waypoint_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.5, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.0
	waypoint_mesh.mesh = prism
	waypoint_mesh.material_override = mat
	waypoint_node.add_child(waypoint_mesh)

	# Точечный свет
	waypoint_light = OmniLight3D.new()
	waypoint_light.light_color = Color(0.2, 0.8, 1.0)
	waypoint_light.light_energy = 1.2
	waypoint_light.omni_range = 5.0
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
	
	if player and player.has_method("set_step_guidance"):
		player.call("set_step_guidance", "ЭТАП 1: ПОГРУЗКА ЯЩИКОВ (0/3)", "Подойдите к ящику «Кока-Коля» и нажмите [E], чтобы взять его")

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
		
		if player and player.has_method("set_step_guidance"):
			if crates_loaded < 3:
				player.call("set_step_guidance", "ЭТАП 1: ПОГРУЗКА В ФУРГОН (%d/3)" % crates_loaded, "Отнесите ящик к задней части фургона и закрепите [E]")
			else:
				player.call("set_step_guidance", "ЭТАП 2: ВЫЕЗД НА СКЛАД", "Все ящики погружены! Подойдите к водительской двери фургона сбоку и нажмите [E]")

		var is_done: bool = mission_mgr.call("is_objective_completed", "load_crates")
		if crates_loaded >= 3 and not is_done:
			mission_mgr.call("complete_objective", "load_crates")
			stage = 2
			_update_waypoint_for_stage()
			mission_mgr.call("add_objective", "drive_to_warehouse", "Сесть за руль и доехать до Складского терминала №4", 1)
			dialogue_mgr.call("queue_message", "СашаV", "Кузов полон! Прыгай за руль [E] и гони на склад. Дорога через промзону свободна!", Color(0.3, 0.8, 1.0), 4.0)
			if has_node("/root/VoiceManager"):
				var vm: Node = get_node("/root/VoiceManager")
				vm.call("speak_sasha", "sasha_radio_order", "Саша Вэ на связи: Коля, ящики надёжно в кузове, двигай на Складской терминал номер четыре!")

func _on_warehouse_entered(body: Node) -> void:
	if stage == 2 and (body == van or body == player):
		stage = 3
		_update_waypoint_for_stage()
		mission_mgr.call("complete_objective", "drive_to_warehouse")
		mission_mgr.call("add_objective", "steal_formula", "Проникнуть в хранилище и похитить рецептурный чип", 1)
		if player and player.has_method("set_step_guidance"):
			player.call("set_step_guidance", "ЭТАП 3: ПРОНИКНОВЕНИЕ В СКЛАД №4", "Взломайте терминал ворот [4] или проникните внутрь")
		dialogue_mgr.call("queue_message", "СашаV", "Ты на месте! Ворота заперты. Используй кибер-деку [4], пенные ступени [3] или дрона BUBBLE.", Color(0.3, 0.8, 1.0), 5.0)

func _on_formula_secured() -> void:
	if stage == 3:
		stage = 4
		_update_waypoint_for_stage()
		mission_mgr.call("complete_objective", "steal_formula")
		mission_mgr.call("add_objective", "return_to_garage", "Вернуться на фургоне в гараж Коли", 1)
		if player and player.has_method("set_step_guidance"):
			player.call("set_step_guidance", "ЭТАП 4: ЭВАКУАЦИЯ В ГАРАЖ", "Чип похищен! Садитесь в фургон и возвращайтесь на базу")
		dialogue_mgr.call("queue_message", "СашаV", "ЧИП У ТЕБЯ! Отличная работа! Прыгай в фургон и возвращайся на базу, пока тревога не поднята!", Color(0.3, 1.0, 0.4), 4.5)

func _on_return_entered(body: Node) -> void:
	if stage == 4 and (body == van or body == player):
		stage = 5
		_update_waypoint_for_stage()
		mission_mgr.call("complete_objective", "return_to_garage")

func _on_mission_completed(_title: String) -> void:
	if complete_panel:
		complete_panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup_complete_panel_buttons()
	if player and player.has_method("set_step_guidance"):
		player.call("set_step_guidance", "МИССИЯ УСПЕШНО ВЫПОЛНЕНА!", "Рецептурный чип «Кока-Коля» в безопасности!")
	dialogue_mgr.call("queue_message", "Коля", "Груз доставлен, формула у нас. «Кока-Коля» будет жить!", Color(1.0, 0.8, 0.2), 5.0)
	if has_node("/root/VoiceManager"):
		var vm: Node = get_node("/root/VoiceManager")
		vm.call("speak_sasha", "sasha_radio_victory", "Миссия выполнена на отлично! Весь Красноград теперь пьёт настоящую Кока-Колю!")
	LogManager.info(">>> ВЕРТИКАЛЬНЫЙ СРЕЗ (STAGE 3) УСПЕШНО ПРОЙДЕН! <<<", "QUEST")

func _setup_complete_panel_buttons() -> void:
	if not complete_panel:
		return
	var vbox = complete_panel.get_node_or_null("Margin/VBox")
	if not vbox or vbox.has_node("BtnNextDistrict"):
		return

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_next := Button.new()
	btn_next.name = "BtnNextDistrict"
	btn_next.text = " ▶ СЛЕДУЮЩИЙ РАЙОН: СКОРОСТНОЕ ШОССЕ "
	btn_next.custom_minimum_size = Vector2(0, 44)
	btn_next.add_theme_font_size_override("font_size", 15)
	btn_next.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	btn_next.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("change_district"):
			gm.call("change_district", "city_highway", true)
		else:
			get_tree().change_scene_to_file("res://scenes/levels/city_highway.tscn")
	)
	vbox.add_child(btn_next)

	var btn_map := Button.new()
	btn_map.name = "BtnOpenMap"
	btn_map.text = " 🗺️ КАРТА ГОРОДА (ВЫБОР РАЙОНА) "
	btn_map.custom_minimum_size = Vector2(0, 38)
	btn_map.pressed.connect(func() -> void:
		complete_panel.visible = false
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
	if not RoadExitGateScript:
		return

	# 1. Северный выезд на Скоростное шоссе (за складом №4)
	var north_gate = Node3D.new()
	north_gate.set_script(RoadExitGateScript)
	north_gate.name = "ExitGate_CityHighway"
	north_gate.set("target_district_id", "city_highway")
	north_gate.set("gate_title", "СКОРОСТНОЕ ШОССЕ")
	north_gate.set("direction_hint", "Выезд на скоростную автомагистраль и КПП №2")
	north_gate.position = Vector3(0, 0, -68)
	add_child(north_gate)

	# 2. Южный переход в Подземный Метрополитен (за гаражом)
	var south_gate = Node3D.new()
	south_gate.set_script(RoadExitGateScript)
	south_gate.name = "ExitGate_Metro"
	south_gate.set("target_district_id", "underground_metro")
	south_gate.set("gate_title", "ПОДЗЕМНЫЙ МЕТРОПОЛИТЕН")
	south_gate.set("direction_hint", "Спуск на станцию «Проспект Революции» и схрон Сопротивления")
	south_gate.position = Vector3(0, 0, 72)
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

func _apply_city_materials_recursive(node: Node, mat_asphalt: Material, mat_paving: Material, mat_grass: Material, mat_foliage: Material) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var s_name := mi.name.to_lower()
		var p_name := mi.get_parent().name.to_lower() if mi.get_parent() else ""
		if "road" in s_name or "road" in p_name:
			if mat_asphalt:
				mi.material_override = mat_asphalt
		elif "pavement" in s_name or "pavement" in p_name:
			if mat_paving:
				mi.material_override = mat_paving
		elif "tree" in s_name or "tree" in p_name:
			if mat_foliage:
				mi.material_override = mat_foliage
		elif "grass" in s_name or "grass" in p_name:
			if mat_grass:
				mi.material_override = mat_grass
	for child in node.get_children():
		_apply_city_materials_recursive(child, mat_asphalt, mat_paving, mat_grass, mat_foliage)

func _apply_mesh_material_recursive(node: Node, mat: Material) -> void:
	if not mat:
		return
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_mesh_material_recursive(child, mat)

