class_name RedLinePlant
extends Node3D

# Контроллер Миссии 2 «Операция: Красная Линия» (Вертикальный срез / v0.5.0)
# Полноценный цикл: Синтез сиропа -> Транспортировка -> Проникновение на завод ->
# Заливка в сиропную башню -> Взлом диспетчерской -> Запуск конвейеров розлива «Кока-Коля»!
# Кинематографичный PBR мир: гараж сопротивления, подъездная дорога с освещением,
# заводской комплекс, сиропная башня, охрана, частицы пара и 3D-маяк навигации.

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const SyrupCanisterScript = preload("res://scripts/interaction/syrup_canister.gd")
const VendingMachineScript = preload("res://scripts/interaction/vending_machine.gd")
const LootContainerScript = preload("res://scripts/interaction/loot_container.gd")
const LoreTerminalScript = preload("res://scripts/interaction/lore_terminal.gd")
const DestructibleCrateScript = preload("res://scripts/physics/destructible_crate.gd")
const ExplosiveBarrelScript = preload("res://scripts/physics/explosive_barrel.gd")

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var van: VehicleBody3D = get_node_or_null("DeliveryVan")
@onready var crafting_station: Node3D = get_node_or_null("Garage/CraftingStation")
@onready var syrup_canister: RigidBody3D = get_node_or_null("CanisterSpawnPoint/SyrupCanister")
@onready var plant_arrival: Area3D = get_node_or_null("Triggers/PlantArrivalArea")
@onready var tower_trigger: Area3D = get_node_or_null("Factory/SyrupTower/InjectionArea")
@onready var terminal: Node3D = get_node_or_null("Factory/DispatchTower/AutomationTerminal")
@onready var conveyor: AnimatableBody3D = get_node_or_null("Factory/BottlingLine/ConveyorBelt")

# UI элементы
@onready var quest_label: Label = get_node_or_null("HUD/QuestPanel/Margin/VBox/ObjectiveLabel")
@onready var radio_panel: PanelContainer = get_node_or_null("HUD/RadioPanel")
@onready var radio_speaker: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/SpeakerLabel")
@onready var radio_text: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/MessageLabel")
@onready var victory_panel: PanelContainer = get_node_or_null("HUD/VictoryPanel")

var mission_mgr: Node = null
var dialogue_mgr: Node = null

var stage: int = 1 # 1: Craft, 2: Load, 3: Drive, 4: Infiltrate, 5: Tower, 6: Terminal, 7: Victory

# 3D Навигационный маяк
var waypoint_node: Node3D = null
var waypoint_label: Label3D = null
var waypoint_light: OmniLight3D = null
var waypoint_mesh: MeshInstance3D = null
var current_target_pos: Vector3 = Vector3.ZERO
var current_target_name: String = ""
var tower_strobe: OmniLight3D = null
var strobe_time: float = 0.0

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

	if crafting_station and crafting_station.has_signal("craft_completed"):
		crafting_station.connect("craft_completed", _on_craft_done)

	if plant_arrival:
		plant_arrival.body_entered.connect(_on_plant_arrival)

	if tower_trigger:
		tower_trigger.body_entered.connect(_on_tower_injection)

	if terminal and terminal.has_signal("plant_overridden"):
		terminal.connect("plant_overridden", _on_terminal_hacked)

	_create_waypoint_beacon()
	_spawn_plant_world_details()
	_spawn_road_exit_gates()
	_start_mission_intro()
	_update_waypoint_for_stage()

func _spawn_plant_world_details() -> void:
	var mat_concrete: Material = load("res://assets/materials/mat_concrete.tres")
	var mat_metal_ind: Material = load("res://assets/materials/mat_metal_industrial.tres")
	var mat_metal: Material = load("res://assets/materials/mat_metal.tres")
	var mat_hazard: Material = load("res://assets/materials/mat_hazard.tres")
	var mat_asphalt: Material = load("res://assets/materials/mat_asphalt.tres")

	# 1. 3D-Здание Гаража сопротивления (building-garage) в точке старта
	var garage_res: PackedScene = load("res://assets/scenes_3d/building-garage.tscn")
	if garage_res:
		var gar: Node3D = garage_res.instantiate()
		gar.name = "ResistanceGarage_Building"
		gar.position = Vector3(0.0, 0.0, 52.0)
		gar.scale = Vector3(3.8, 3.8, 3.8)
		if mat_concrete:
			_apply_mesh_material_recursive(gar, mat_concrete)
		add_child(gar)

	# 2. Освещение базы и неоновая вывеска
	var gar_light := OmniLight3D.new()
	gar_light.name = "GarageInteriorLight"
	gar_light.position = Vector3(-2.0, 3.5, 50.0)
	gar_light.light_color = Color(1.0, 0.92, 0.8)
	gar_light.light_energy = 2.8
	gar_light.omni_range = 10.0
	add_child(gar_light)

	var gar_neon := Label3D.new()
	gar_neon.name = "GarageNeon"
	gar_neon.position = Vector3(0.0, 5.2, 47.0)
	gar_neon.text = "★ ПОДПОЛЬНЫЙ ЦЕХ «КОКА-КОЛЯ» ★"
	gar_neon.font_size = 26
	gar_neon.modulate = Color(1.0, 0.85, 0.2)
	gar_neon.outline_size = 8
	add_child(gar_neon)

	# 2.1 Зона отдыха и инструктажа повстанцев (Интерактивная зона)
	var vend: Node3D = VendingMachineScript.new()
	vend.name = "ResistanceVendingMachine"
	vend.position = Vector3(-5.2, 0.0, 48.0)
	vend.rotation_degrees = Vector3(0, 75, 0)
	add_child(vend)

	var boombox_res: PackedScene = load("res://assets/scenes_3d/BoomBox.tscn")
	if boombox_res:
		var bb: Node3D = boombox_res.instantiate()
		bb.name = "GarageBoomBox"
		bb.position = Vector3(-4.6, 0.85, 46.2)
		bb.scale = Vector3(1.2, 1.2, 1.2)
		add_child(bb)

	# Столик под бумбокс
	var table := MeshInstance3D.new()
	var t_mesh := BoxMesh.new()
	t_mesh.size = Vector3(1.2, 0.8, 0.8)
	table.mesh = t_mesh
	if mat_metal_ind:
		table.material_override = mat_metal_ind
	table.position = Vector3(-4.6, 0.4, 46.2)
	add_child(table)

	# Скамейки отдыха
	var bench_res: PackedScene = load("res://assets/scenes_3d/bench.tscn")
	if bench_res:
		var b1: Node3D = bench_res.instantiate()
		b1.name = "GarageBench_1"
		b1.position = Vector3(-6.2, 0.0, 46.0)
		b1.rotation_degrees = Vector3(0, 90, 0)
		add_child(b1)

	# Планшет СашиV с разведданными
	var lore_pad: Node3D = LoreTerminalScript.new()
	lore_pad.name = "SashaLorePad"
	lore_pad.set("terminal_title", "Планшет СашиV")
	lore_pad.set("lore_header", "ДИРЕКТИВА СОПРОТИВЛЕНИЯ #14")
	lore_pad.set("lore_text", "Коля, синтезируй сироп на верстаке, загрузи канистру в фургон и двигай к заводу. Залей концентрат в главную башню — конвейеры наполнят город настоящей Колей!")
	lore_pad.position = Vector3(-2.8, 0.92, 50.8)
	lore_pad.rotation_degrees = Vector3(-25, 30, 0)
	add_child(lore_pad)

	# 2.2 Дополнительный транспорт повстанцев
	var bike_res: PackedScene = load("res://assets/scenes_3d/vehicle-motorcycle.tscn")
	if bike_res:
		var bike: Node3D = bike_res.instantiate()
		bike.name = "ResistanceMotorcycle"
		bike.position = Vector3(-5.8, 0.0, 52.8)
		bike.rotation_degrees = Vector3(0, 35, 0)
		add_child(bike)

	var civ_car_res: PackedScene = load("res://assets/scenes_3d/car_hatchback.tscn")
	if civ_car_res:
		var ccar: Node3D = civ_car_res.instantiate()
		ccar.name = "ResistanceSupportCar"
		ccar.position = Vector3(7.2, 0.0, 46.0)
		ccar.rotation_degrees = Vector3(0, -20, 0)
		add_child(ccar)

	# 3. Подъездная дорога к заводу (z от 48 до -20) с освещением
	var road_parent := Node3D.new()
	road_parent.name = "PlantAccessRoad"
	add_child(road_parent)

	var road_bed := MeshInstance3D.new()
	var rb_mesh := BoxMesh.new()
	rb_mesh.size = Vector3(10.0, 0.15, 75.0)
	road_bed.mesh = rb_mesh
	if mat_asphalt:
		road_bed.material_override = mat_asphalt
	road_bed.position = Vector3(0.0, 0.08, 14.0)
	road_parent.add_child(road_bed)

	var z_road: float = 48.0
	while z_road >= -20.0:
		var dash := MeshInstance3D.new()
		var d_mesh := QuadMesh.new()
		d_mesh.size = Vector2(0.2, 2.2)
		d_mesh.orientation = PlaneMesh.FACE_Y
		dash.mesh = d_mesh
		var d_mat := StandardMaterial3D.new()
		d_mat.albedo_color = Color(1.0, 0.88, 0.25, 0.9)
		dash.material_override = d_mat
		dash.position = Vector3(0.0, 0.17, z_road)
		road_parent.add_child(dash)
		z_road -= 5.0

	var road_lamps = [42.0, 24.0, 6.0, -12.0]
	for z_pos in road_lamps:
		for x_side in [-5.8, 5.8]:
			var pole := MeshInstance3D.new()
			var p_mesh := CylinderMesh.new()
			p_mesh.top_radius = 0.06
			p_mesh.bottom_radius = 0.12
			p_mesh.height = 4.8
			pole.mesh = p_mesh
			if mat_metal:
				pole.material_override = mat_metal
			pole.position = Vector3(x_side, 2.4, z_pos)
			add_child(pole)

			var lamp := OmniLight3D.new()
			lamp.name = "RoadLamp_%.0f_%.0f" % [x_side, z_pos]
			lamp.position = Vector3(x_side, 4.6, z_pos)
			lamp.light_color = Color(1.0, 0.92, 0.82)
			lamp.light_energy = 2.2
			lamp.omni_range = 12.0
			lamp.omni_attenuation = 1.3
			add_child(lamp)

	# 4. Защитный замкнутый периметр завода (стены и барьеры)
	var wall_high_res: PackedScene = load("res://assets/scenes_3d/wall-high.tscn")
	if wall_high_res:
		var wall_positions = [
			Vector3(-22.0, 0.0, -18.0),
			Vector3(-16.0, 0.0, -18.0),
			Vector3(16.0, 0.0, -18.0),
			Vector3(22.0, 0.0, -18.0),
			Vector3(-24.0, 0.0, -32.0),
			Vector3(-24.0, 0.0, -46.0),
			Vector3(-24.0, 0.0, -60.0),
			Vector3(24.0, 0.0, -32.0),
			Vector3(24.0, 0.0, -46.0),
			Vector3(24.0, 0.0, -60.0)
		]
		for i in range(wall_positions.size()):
			var w: Node3D = wall_high_res.instantiate()
			w.name = "PlantWall_%d" % i
			w.position = wall_positions[i]
			var is_side: bool = abs(wall_positions[i].x) > 20.0
			w.rotation_degrees = Vector3(0, 90 if is_side else 0, 0)
			w.scale = Vector3(2.6, 2.8, 2.6)
			if mat_concrete:
				_apply_mesh_material_recursive(w, mat_concrete)
			add_child(w)

	# 5. Плотная застройка периметра — устранение пустоты со всех сторон!
	var complex_buildings = [
		{"type": "building_C", "pos": Vector3(-28.0, 0.0, -50.0), "rot": 90, "scale": Vector3(4.5, 5.5, 4.5)},
		{"type": "building_D", "pos": Vector3(28.0, 0.0, -50.0), "rot": -90, "scale": Vector3(4.5, 5.5, 4.5)},
		{"type": "building_G", "pos": Vector3(-27.0, 0.0, -72.0), "rot": 90, "scale": Vector3(4.2, 5.0, 4.2)},
		{"type": "building-garage", "pos": Vector3(26.0, 0.0, -72.0), "rot": -90, "scale": Vector3(3.8, 3.8, 3.8)},
		{"type": "building_H", "pos": Vector3(0.0, 0.0, -84.0), "rot": 180, "scale": Vector3(6.5, 6.5, 6.5)}, # Северный фасад
		{"type": "building_A", "pos": Vector3(-32.0, 0.0, -18.0), "rot": 90, "scale": Vector3(4.5, 6.0, 4.5)},
		{"type": "building_B", "pos": Vector3(32.0, 0.0, -18.0), "rot": -90, "scale": Vector3(4.5, 6.0, 4.5)},
		{"type": "building_E", "pos": Vector3(-26.0, 0.0, 15.0), "rot": 90, "scale": Vector3(4.0, 5.5, 4.0)},
		{"type": "building_F", "pos": Vector3(26.0, 0.0, 15.0), "rot": -90, "scale": Vector3(4.0, 5.5, 4.0)},
		{"type": "building_A", "pos": Vector3(-24.0, 0.0, 42.0), "rot": 90, "scale": Vector3(4.0, 5.0, 4.0)},
		{"type": "building_B", "pos": Vector3(24.0, 0.0, 42.0), "rot": -90, "scale": Vector3(4.0, 5.0, 4.0)},
		{"type": "building-garage", "pos": Vector3(0.0, 0.0, 68.0), "rot": 0, "scale": Vector3(4.5, 4.0, 4.5)} # Южный фасад
	]
	for b_info in complex_buildings:
		var b_scene: PackedScene = load("res://assets/scenes_3d/%s.tscn" % b_info["type"])
		if b_scene:
			var bld: Node3D = b_scene.instantiate()
			bld.name = "FactoryWing_%s_%.0f" % [b_info["type"], b_info["pos"].z]
			bld.position = b_info["pos"]
			bld.rotation_degrees = Vector3(0, b_info["rot"], 0)
			bld.scale = b_info["scale"]
			if mat_metal_ind:
				_apply_mesh_material_recursive(bld, mat_metal_ind)
			add_child(bld)

	# Охранная будка КПП завода
	var booth_res: PackedScene = load("res://assets/scenes_3d/building-small-a.tscn")
	if booth_res:
		var booth: Node3D = booth_res.instantiate()
		booth.name = "PlantGate_SecurityBooth"
		booth.position = Vector3(-9.5, 0.0, -18.0)
		booth.scale = Vector3(1.4, 1.4, 1.4)
		if mat_concrete:
			_apply_mesh_material_recursive(booth, mat_concrete)
		add_child(booth)

	# Бетонный погрузочный двор завода
	var apron := MeshInstance3D.new()
	var ap_mesh := BoxMesh.new()
	ap_mesh.size = Vector3(56.0, 0.18, 55.0)
	apron.mesh = ap_mesh
	if mat_concrete:
		apron.material_override = mat_concrete
	apron.position = Vector3(0.0, 0.09, -46.0)
	add_child(apron)

	# Предупреждающая зона безопасности сиропной башни
	var hazard_ring := MeshInstance3D.new()
	var hr_mesh := BoxMesh.new()
	hr_mesh.size = Vector3(9.5, 0.22, 9.5)
	hazard_ring.mesh = hr_mesh
	if mat_hazard:
		hazard_ring.material_override = mat_hazard
	hazard_ring.position = Vector3(14.0, 0.11, -50.0)
	add_child(hazard_ring)

	# Придорожные деревья и растительность вдоль подъездного пути
	var tree_tall_res: PackedScene = load("res://assets/scenes_3d/grass-trees-tall.tscn")
	var tree_res: PackedScene = load("res://assets/scenes_3d/grass-trees.tscn")
	var foliage_spots = [
		Vector3(-8.8, 0.0, 42.0), Vector3(8.8, 0.0, 42.0),
		Vector3(-9.2, 0.0, 26.0), Vector3(9.2, 0.0, 26.0),
		Vector3(-8.9, 0.0, 10.0), Vector3(8.9, 0.0, 10.0),
		Vector3(-9.5, 0.0, -6.0), Vector3(9.5, 0.0, -6.0)
	]
	for i in range(foliage_spots.size()):
		var t_scene: PackedScene = tree_tall_res if i % 2 == 0 else tree_res
		if t_scene:
			var tree_inst: Node3D = t_scene.instantiate()
			tree_inst.name = "PlantTree_%d" % i
			tree_inst.position = foliage_spots[i]
			tree_inst.scale = Vector3(1.6, 1.6, 1.6)
			add_child(tree_inst)

	# 6. Транспорт охраны и снабжения
	var police_scene: PackedScene = load("res://assets/scenes_3d/car_police.tscn")
	if police_scene:
		var cop: Node3D = police_scene.instantiate()
		cop.name = "PlantGate_PoliceCruiser"
		cop.position = Vector3(-8.5, 0.0, -20.0)
		cop.rotation_degrees = Vector3(0, 25, 0)
		add_child(cop)

	var truck_scene: PackedScene = load("res://assets/scenes_3d/vehicle-truck-red.tscn")
	if truck_scene:
		var truck: Node3D = truck_scene.instantiate()
		truck.name = "PlantDock_HeavyTruck"
		truck.position = Vector3(10.5, 0.0, -42.0)
		truck.rotation_degrees = Vector3(0, -90, 0)
		truck.scale = Vector3(1.35, 1.35, 1.35)
		add_child(truck)

	var truck_yellow_scene: PackedScene = load("res://assets/scenes_3d/vehicle-truck-yellow.tscn")
	if truck_yellow_scene:
		var truck_y: Node3D = truck_yellow_scene.instantiate()
		truck_y.name = "PlantDock_YellowTruck"
		truck_y.position = Vector3(-14.0, 0.0, -42.0)
		truck_y.rotation_degrees = Vector3(0, 90, 0)
		truck_y.scale = Vector3(1.35, 1.35, 1.35)
		add_child(truck_y)

	# 7. Интерактивные лут-контейнеры снабжения
	var loot1: Node3D = LootContainerScript.new()
	loot1.name = "PlantToolboxLoot"
	loot1.set("container_title", "Ящик инструментов цеха")
	loot1.set("credits_reward", 80)
	loot1.set("is_locked", false)
	loot1.position = Vector3(-15.5, 0.0, -25.0)
	loot1.rotation_degrees = Vector3(0, 45, 0)
	add_child(loot1)

	var loot2: Node3D = LootContainerScript.new()
	loot2.name = "PlantSafeLoot"
	loot2.set("container_title", "Сейф снабжения MERIDIAN")
	loot2.set("credits_reward", 150)
	loot2.set("is_locked", true) # Взламывается кибер-декой [4]
	loot2.position = Vector3(12.0, 0.0, -48.0)
	loot2.rotation_degrees = Vector3(0, -45, 0)
	add_child(loot2)

	# 8. Взрывоопасные бочки горючего (ExplosiveBarrel) — реагируют на стрельбу, толчки и детонацию
	var barrel_coords = [
		Vector3(7.0, 0.6, -34.0),
		Vector3(7.8, 0.6, -34.5),
		Vector3(7.4, 1.6, -34.2),
		Vector3(-12.5, 0.6, -30.0),
		Vector3(-13.2, 0.6, -30.4),
		Vector3(15.2, 0.6, -42.0)
	]
	for i in range(barrel_coords.size()):
		var barrel: RigidBody3D = ExplosiveBarrelScript.new()
		barrel.name = "PlantExplosiveBarrel_%d" % i
		barrel.position = barrel_coords[i]
		add_child(barrel)

	# 9. Разрушаемые ящики снабжения (DestructibleCrate) с физикой щепок и лутом
	var crate_spots = [
		Vector3(-6.5, 0.5, 48.0),
		Vector3(-6.2, 0.5, 51.5),
		Vector3(-7.0, 1.4, 49.0),
		Vector3(-14.5, 0.5, -24.0),
		Vector3(-15.2, 0.5, -25.5),
		Vector3(12.5, 0.5, -32.0),
		Vector3(13.2, 0.5, -33.5),
		Vector3(12.8, 1.4, -32.8)
	]
	for i in range(crate_spots.size()):
		var crate: RigidBody3D = DestructibleCrateScript.new()
		crate.name = "PlantDestructibleCrate_%d" % i
		crate.position = crate_spots[i]
		add_child(crate)

	# 10. Промышленные прожекторы периметра завода
	var floodlight_coords = [
		Vector3(-12.0, 0.0, -18.0),
		Vector3(12.0, 0.0, -18.0),
		Vector3(-18.0, 0.0, -45.0),
		Vector3(18.0, 0.0, -45.0),
		Vector3(0.0, 0.0, 38.0)
	]
	for i in range(floodlight_coords.size()):
		var f_pos = floodlight_coords[i]
		var pole := MeshInstance3D.new()
		var p_mesh := CylinderMesh.new()
		p_mesh.top_radius = 0.08
		p_mesh.bottom_radius = 0.14
		p_mesh.height = 5.5
		pole.mesh = p_mesh
		if mat_metal:
			pole.material_override = mat_metal
		pole.position = f_pos + Vector3(0, 2.75, 0)
		add_child(pole)

		var spot := OmniLight3D.new()
		spot.name = "IndustrialFloodlight_%d" % i
		spot.position = f_pos + Vector3(0, 5.4, 0)
		spot.light_color = Color(0.85, 0.92, 1.0)
		spot.light_energy = 2.4
		spot.omni_range = 16.0
		spot.omni_attenuation = 1.2
		add_child(spot)

	# 11. Клубящийся пар вентиляционных труб и сиропной башни (CPUParticles3D)
	var steam_coords = [
		Vector3(14.0, 14.2, -50.0),
		Vector3(-6.0, 12.2, -58.0),
		Vector3(6.0, 12.2, -62.0),
		Vector3(-4.0, 0.1, 46.0)
	]
	for i in range(steam_coords.size()):
		var steam := CPUParticles3D.new()
		steam.name = "PlantSteam_%d" % i
		steam.position = steam_coords[i]
		steam.amount = 24
		steam.lifetime = 2.8
		steam.explosiveness = 0.0
		steam.randomness = 0.4
		steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		steam.emission_sphere_radius = 0.45
		steam.direction = Vector3(0, 1, 0)
		steam.spread = 20.0
		steam.gravity = Vector3(0.2, 0.6, 0)
		steam.initial_velocity_min = 0.6
		steam.initial_velocity_max = 1.4
		var p_mesh := SphereMesh.new()
		p_mesh.radius = 0.28
		p_mesh.height = 0.56
		var p_mat := StandardMaterial3D.new()
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		p_mat.albedo_color = Color(0.92, 0.94, 0.98, 0.22)
		p_mat.roughness = 1.0
		p_mesh.material = p_mat
		steam.mesh = p_mesh
		add_child(steam)

	# 12. Проблесковый маяк на вершине сиропной башни
	tower_strobe = OmniLight3D.new()
	tower_strobe.name = "SyrupTowerStrobe"
	tower_strobe.position = Vector3(14.0, 14.5, -50.0)
	tower_strobe.light_color = Color(1.0, 0.18, 0.18)
	tower_strobe.light_energy = 3.5
	tower_strobe.omni_range = 14.0
	add_child(tower_strobe)


func _apply_mesh_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_mesh_material_recursive(child, mat)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "PlantWaypointBeacon"
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
			current_target_pos = Vector3(-4.0, 1.8, 50.0)
			current_target_name = "Верстак: Синтез сиропа"
		2:
			current_target_pos = Vector3(2.0, 2.0, 48.0)
			current_target_name = "Кузов фургона: Погрузка канистры"
		3:
			current_target_pos = Vector3(0.0, 2.5, -25.0)
			current_target_name = "КПП: Въезд на завод"
		4:
			current_target_pos = Vector3(14.0, 8.5, -50.0)
			current_target_name = "Башня: Заливка концентрата"
		5:
			current_target_pos = Vector3(-12.0, 5.2, -42.0)
			current_target_name = "Диспетчерская: Взлом автоматики"
		_:
			if waypoint_node:
				waypoint_node.visible = false
			return

	if waypoint_node:
		waypoint_node.visible = true
		waypoint_node.position = current_target_pos

func _process(delta: float) -> void:
	# Пульсация навигационного маяка
	if waypoint_node and waypoint_node.visible:
		var time := Time.get_ticks_msec() / 1000.0
		var hover_y: float = sin(time * 3.5) * 0.18
		waypoint_node.position = current_target_pos + Vector3(0, hover_y, 0)
		if waypoint_mesh:
			waypoint_mesh.rotation_degrees.y = fmod(time * 75.0, 360.0)
		if waypoint_label and player:
			var dist: float = player.global_position.distance_to(current_target_pos)
			waypoint_label.text = "%s\n[ %.1f м ]" % [current_target_name, dist]

	# Проблесковый строб сиропной башни
	if tower_strobe:
		strobe_time += delta
		tower_strobe.light_energy = 3.5 if fmod(strobe_time, 1.2) < 0.25 else 0.4

func _start_mission_intro() -> void:
	mission_mgr.call("start_mission", "Операция: Красная Линия")
	mission_mgr.call("add_objective", "craft_syrup", "Синтезировать концентрат «Кока-Коля» на верстаке", 1)

	dialogue_mgr.call("queue_message", "СашаV", "Коля, данные с чипа расшифрованы! Рецепт идеален. Подойди к верстаку и начни синтез.", Color(0.3, 0.8, 1.0), 4.5)
	dialogue_mgr.call("queue_message", "Коля", "Займусь этим прямо сейчас. Пора вернуть настоящую газировку в город.", Color(1.0, 0.8, 0.2), 3.5)

func _on_craft_done(_item: String) -> void:
	if stage == 1:
		stage = 2
		mission_mgr.call("complete_objective", "craft_syrup")
		mission_mgr.call("add_objective", "load_canister", "Погрузить канистру концентрата в фургон", 1)
		dialogue_mgr.call("queue_message", "СашаV", "Концентрат готов! Загружай канистру в кузов фургона [E] и отправляйся на Завод «Красная Линия».", Color(0.3, 0.8, 1.0), 4.5)
		_update_waypoint_for_stage()

func _physics_process(_delta: float) -> void:
	if stage == 2 and van:
		var has_canister: bool = false
		if van.has_method("get_cargo_crates"):
			for b in van.call("get_cargo_crates"):
				if b is RigidBody3D and (b.name.begins_with("SyrupCanister") or b.is_in_group("canister")):
					has_canister = true
					break
		if has_canister:
			stage = 3
			mission_mgr.call("complete_objective", "load_canister")
			mission_mgr.call("add_objective", "drive_to_plant", "Доехать на фургоне до Завода «Красная Линия»", 1)
			dialogue_mgr.call("queue_message", "СашаV", "Груз на борту! Заводи мотор и держи курс на промышленную зону.", Color(0.3, 0.8, 1.0), 4.0)
			_update_waypoint_for_stage()

func _on_plant_arrival(body: Node) -> void:
	if stage == 3 and (body == van or body == player):
		stage = 4
		mission_mgr.call("complete_objective", "drive_to_plant")
		mission_mgr.call("add_objective", "inject_syrup", "Залить концентрат в Главную Сиропную Башню", 1)
		dialogue_mgr.call("queue_message", "СашаV", "Мы на заводе! Камеры на КПП можно взломать [4] или залепить пеной [3]. Поднимись к сиропной башне!", Color(0.3, 0.8, 1.0), 5.0)
		_update_waypoint_for_stage()

func _on_tower_injection(body: Node) -> void:
	if stage == 4 and (body is SyrupCanisterScript or body.is_in_group("canister") or body == player):
		stage = 5
		mission_mgr.call("complete_objective", "inject_syrup")
		mission_mgr.call("add_objective", "override_automation", "Взломать терминал автоматизации в диспетчерской", 1)
		dialogue_mgr.call("queue_message", "СашаV", "Башня заправлена! Теперь поднимайся в диспетчерскую вышку и перехвати автоматику розлива!", Color(0.3, 1.0, 0.4), 4.5)
		_update_waypoint_for_stage()

func _on_terminal_hacked() -> void:
	if stage == 5:
		stage = 6
		mission_mgr.call("complete_objective", "override_automation")
		
		# Запуск конвейера розлива
		if conveyor:
			conveyor.set("constant_linear_velocity", Vector3(2.5, 0, 0))
			
		LogManager.info("КОНВЕЙЕРЫ ЗАВОДА ЗАПУЩЕНЫ: РОЗЛИВ «КОКА-КОЛЯ» АКТИВЕН!", "FACTORY")
		_update_waypoint_for_stage()

func _on_mission_victory(_title: String) -> void:
	if waypoint_node:
		waypoint_node.visible = false
	if victory_panel:
		victory_panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup_victory_panel_buttons()
	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("mark_mission_completed", "mission_red_line_plant")
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", 2.0)
	dialogue_mgr.call("queue_message", "Коля", "Линия розлива работает на полную мощность! Вся партия — наша «Кока-Коля». Мы сделали это!", Color(1.0, 0.8, 0.2), 6.0)
	LogManager.info(">>> ВЕРТИКАЛЬНЫЙ СРЕЗ (STAGE 4 / v0.5.0) ПОЛНОСТЬЮ ПРОЙДЕН! <<<", "VICTORY")

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
	btn_next.text = " ▶ СЛЕДУЮЩИЙ РАЙОН: ЛОГИСТИЧЕСКИЙ ХАБ "
	btn_next.custom_minimum_size = Vector2(0, 44)
	btn_next.add_theme_font_size_override("font_size", 15)
	btn_next.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	btn_next.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("change_district"):
			gm.call("change_district", "logistics_hub", true)
		else:
			get_tree().change_scene_to_file("res://scenes/levels/logistics_hub.tscn")
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

	# 1. Северный выезд в Логистический хаб
	var north_gate = Node3D.new()
	north_gate.set_script(gate_script)
	north_gate.name = "ExitGate_LogisticsHub"
	north_gate.set("target_district_id", "logistics_hub")
	north_gate.set("gate_title", "ЛОГИСТИЧЕСКИЙ ХАБ")
	north_gate.set("direction_hint", "Складской комплекс MERIDIAN и распределительный центр")
	north_gate.position = Vector3(0, 0, -68)
	add_child(north_gate)

	# 2. Южный возврат на Неоновый бульвар
	var south_gate = Node3D.new()
	south_gate.set_script(gate_script)
	south_gate.name = "ExitGate_NeonBoulevard"
	south_gate.set("target_district_id", "neon_boulevard")
	south_gate.set("gate_title", "НЕОНОВЫЙ БУЛЬВАР")
	south_gate.set("direction_hint", "Возврат в Даунтаун и к Неон-Плазе")
	south_gate.position = Vector3(0, 0, 60)
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
	quest_label.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
