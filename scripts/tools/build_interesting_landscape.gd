extends SceneTree

var frame: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_build_district()
		quit(0)
		return true
	return false

func _build_district() -> void:
	print("=== Building Rich, Interesting 3D Landscape for Old District ===")
	var scene_res: PackedScene = load("res://scenes/levels/old_district.tscn")
	var root_node = scene_res.instantiate()

	# 1. Balanced Daylight Lighting (Soft, Natural, No Blinding Flares, No Harsh Contrast)
	var sun: DirectionalLight3D = root_node.get_node_or_null("SunLight")
	if sun:
		sun.rotation_degrees = Vector3(-42, 45, 0)
		sun.light_color = Color(1.0, 0.96, 0.90)
		sun.light_energy = 1.15
		sun.shadow_enabled = true
		sun.shadow_bias = 0.05
		sun.directional_shadow_max_distance = 100.0
		print("[OK] Sun configured: energy=1.15, warm daylight, natural soft shadows")

	var env_node: WorldEnvironment = root_node.get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment:
		var env = env_node.environment
		env.background_mode = Environment.BG_SKY
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.28, 0.48, 0.78, 1.0)
		sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88, 1.0)
		sky_mat.ground_bottom_color = Color(0.20, 0.22, 0.25, 1.0)
		sky_mat.ground_horizon_color = Color(0.65, 0.72, 0.80, 1.0)
		var sky_obj = Sky.new()
		sky_obj.sky_material = sky_mat
		env.sky = sky_obj
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.62, 0.70, 0.80, 1.0)
		env.ambient_light_energy = 0.65
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = 0.95
		env.glow_enabled = false
		print("[OK] Environment configured: ACES tonemap, ambient 0.65, exposure 0.95")

	# 2. Garage Interior Light (Soft accent)
	var garage_light: OmniLight3D = root_node.get_node_or_null("GarageBuilding/GarageLight")
	if garage_light:
		garage_light.light_energy = 0.4
		garage_light.omni_range = 8.0
		garage_light.light_color = Color(1.0, 0.92, 0.75)
		print("[OK] GarageLight softened to 0.4")

	# 3. Ground Plane with PBR Asphalt
	var ground_mesh: MeshInstance3D = root_node.get_node_or_null("Ground/MeshInstance3D")
	var mat_asphalt: Material = load("res://assets/materials/mat_asphalt.tres")
	if ground_mesh and mat_asphalt:
		ground_mesh.material_override = mat_asphalt

	# 4. Clean and Rebuild CityArchitecture
	var old_city = root_node.get_node_or_null("CityArchitecture")
	if old_city:
		old_city.free()
	var city = Node3D.new()
	city.name = "CityArchitecture"
	root_node.add_child(city)
	city.owner = root_node

	# Preload 3D Models
	var res_road_straight = load("res://assets/scenes_3d/road-straight.tscn")
	var res_road_lights = load("res://assets/scenes_3d/road-straight-lightposts.tscn")
	var res_road_inter = load("res://assets/scenes_3d/road-intersection.tscn")
	var res_pavement = load("res://assets/scenes_3d/pavement.tscn")
	var res_fountain = load("res://assets/scenes_3d/pavement-fountain.tscn")
	var res_trees = load("res://assets/scenes_3d/grass-trees.tscn")
	var res_trees_tall = load("res://assets/scenes_3d/grass-trees-tall.tscn")
	var res_grass = load("res://assets/scenes_3d/grass.tscn")
	var res_bldg_a = load("res://assets/scenes_3d/building-small-a.tscn")
	var res_bldg_b = load("res://assets/scenes_3d/building-small-b.tscn")
	var res_bldg_c = load("res://assets/scenes_3d/building-small-c.tscn")
	var res_bldg_d = load("res://assets/scenes_3d/building-small-d.tscn")
	var res_motorcycle = load("res://assets/scenes_3d/vehicle-motorcycle.tscn")
	var res_truck_yellow = load("res://assets/scenes_3d/vehicle-truck-yellow.tscn")
	var res_truck_green = load("res://assets/scenes_3d/vehicle-truck-green.tscn")
	var res_char = load("res://assets/scenes_3d/character.tscn")

	var bldgs = [res_bldg_a, res_bldg_b, res_bldg_c, res_bldg_d]

	var add_elem = func(packed_res: PackedScene, pos: Vector3, rot_deg: Vector3, sc: Vector3, parent_node: Node) -> Node3D:
		if not packed_res:
			return null
		var inst = packed_res.instantiate()
		inst.position = pos
		inst.rotation_degrees = rot_deg
		inst.scale = sc
		parent_node.add_child(inst)
		inst.owner = root_node
		return inst

	# A. Main Road (X = 0, Z from 52 to -32 by 4m)
	var z_coords = [52.0, 48.0, 44.0, 40.0, 36.0, 32.0, 28.0, 24.0, 20.0, 16.0, 12.0, 8.0, 4.0, 0.0, -4.0, -8.0, -12.0, -16.0, -20.0, -24.0, -28.0, -32.0]
	for z in z_coords:
		if abs(z - 16.0) < 0.1:
			add_elem.call(res_road_inter, Vector3(0, 0.02, z), Vector3(0, 0, 0), Vector3(4, 4, 4), city)
			add_elem.call(res_road_straight, Vector3(-4, 0.02, 16), Vector3(0, 90, 0), Vector3(4, 4, 4), city)
			add_elem.call(res_road_straight, Vector3(-8, 0.02, 16), Vector3(0, 90, 0), Vector3(4, 4, 4), city)
			add_elem.call(res_road_straight, Vector3(4, 0.02, 16), Vector3(0, 90, 0), Vector3(4, 4, 4), city)
		else:
			var has_lights = (abs(z - 44.0) < 0.1 or abs(z - 28.0) < 0.1 or abs(z - 4.0) < 0.1 or abs(z - (-12.0)) < 0.1 or abs(z - (-28.0)) < 0.1)
			var r_res = res_road_lights if has_lights else res_road_straight
			add_elem.call(r_res, Vector3(0, 0.02, z), Vector3(0, 0, 0), Vector3(4, 4, 4), city)

	# B. Sidewalks (West X = -4.0, East X = +4.0, elevated at Y = 0.12)
	for z in z_coords:
		if abs(z - 16.0) > 0.1:
			add_elem.call(res_pavement, Vector3(-4.0, 0.12, z), Vector3(0, 0, 0), Vector3(4, 4, 4), city)
			add_elem.call(res_pavement, Vector3(4.0, 0.12, z), Vector3(0, 0, 0), Vector3(4, 4, 4), city)

	# C. Town Square / Fountain Plaza (East side: X in [8, 12, 16], Z in [4, 8, 12, 16, 20])
	for px in [8.0, 12.0, 16.0]:
		for pz in [4.0, 8.0, 12.0, 16.0, 20.0]:
			if abs(px - 12.0) < 0.1 and abs(pz - 12.0) < 0.1:
				add_elem.call(res_fountain, Vector3(px, 0.12, pz), Vector3(0, 0, 0), Vector3(4, 4, 4), city)
			elif abs(px - 8.0) < 0.1 and abs(pz - 16.0) < 0.1:
				pass
			else:
				add_elem.call(res_pavement, Vector3(px, 0.12, pz), Vector3(0, 0, 0), Vector3(4, 4, 4), city)

	# D. Green Parks & Tree Clusters
	add_elem.call(res_trees_tall, Vector3(20.0, 0.12, 20.0), Vector3(0, 15, 0), Vector3(4, 4, 4), city)
	add_elem.call(res_trees, Vector3(20.0, 0.12, 16.0), Vector3(0, 45, 0), Vector3(4, 4, 4), city)
	add_elem.call(res_trees_tall, Vector3(20.0, 0.12, 12.0), Vector3(0, 90, 0), Vector3(4, 4, 4), city)
	add_elem.call(res_grass, Vector3(20.0, 0.12, 8.0), Vector3(0, 0, 0), Vector3(4, 4, 4), city)
	add_elem.call(res_trees, Vector3(20.0, 0.12, 4.0), Vector3(0, -30, 0), Vector3(4, 4, 4), city)

	add_elem.call(res_trees, Vector3(-8.0, 0.12, 32.0), Vector3(0, 60, 0), Vector3(4, 4, 4), city)
	add_elem.call(res_trees_tall, Vector3(-8.0, 0.12, 8.0), Vector3(0, -45, 0), Vector3(4, 4, 4), city)
	add_elem.call(res_trees, Vector3(-8.0, 0.12, -4.0), Vector3(0, 120, 0), Vector3(4, 4, 4), city)
	add_elem.call(res_trees_tall, Vector3(-8.0, 0.12, -20.0), Vector3(0, 15, 0), Vector3(4, 4, 4), city)

	# Sidewalk trees along the street
	add_elem.call(res_trees, Vector3(-4.0, 0.12, 44.0), Vector3(0, 20, 0), Vector3(2.5, 2.5, 2.5), city)
	add_elem.call(res_trees, Vector3(4.0, 0.12, 32.0), Vector3(0, 70, 0), Vector3(2.5, 2.5, 2.5), city)
	add_elem.call(res_trees, Vector3(4.0, 0.12, -8.0), Vector3(0, 40, 0), Vector3(2.5, 2.5, 2.5), city)

	# E. Varied Buildings Wall
	var west_bldg_z = [52.0, 48.0, 44.0, 40.0, 36.0, 28.0, 24.0, 20.0, 12.0, 4.0, 0.0, -8.0, -12.0, -16.0, -24.0, -28.0]
	var west_heights = [4.5, 6.0, 7.2, 5.0, 5.8, 6.5, 4.8, 7.0, 5.2, 6.2, 4.8, 6.8, 5.0, 6.0, 7.5, 4.5]
	for i in range(west_bldg_z.size()):
		var wz = west_bldg_z[i]
		var b_res = bldgs[i % bldgs.size()]
		var h = west_heights[i % west_heights.size()]
		add_elem.call(b_res, Vector3(-8.0, 0.12, wz), Vector3(0, 90, 0), Vector3(4.0, h, 4.0), city)

	var east_bldg_z = [52.0, 48.0, 44.0, 40.0, 36.0, 32.0, 28.0, 0.0, -4.0, -8.0, -12.0, -16.0, -20.0, -24.0, -28.0]
	var east_heights = [6.0, 5.0, 7.0, 4.8, 6.2, 5.5, 6.8, 5.2, 6.5, 4.8, 6.0, 7.2, 5.0, 6.5, 4.8]
	for i in range(east_bldg_z.size()):
		var ez = east_bldg_z[i]
		var b_res = bldgs[(i + 2) % bldgs.size()]
		var h = east_heights[i % east_heights.size()]
		add_elem.call(b_res, Vector3(8.0, 0.12, ez), Vector3(0, -90, 0), Vector3(4.0, h, 4.0), city)

	var plaza_wall_z = [24.0, 20.0, 16.0, 12.0, 8.0, 4.0]
	for i in range(plaza_wall_z.size()):
		var pz = plaza_wall_z[i]
		var b_res = bldgs[(i + 1) % bldgs.size()]
		add_elem.call(b_res, Vector3(24.0, 0.12, pz), Vector3(0, -90, 0), Vector3(4.0, 5.5 + (i % 3), 4.0), city)

	# F. Props and Secondary Vehicles
	# Parked Motorcycle further down the sidewalk
	add_elem.call(res_motorcycle, Vector3(-3.2, 0.15, 36.0), Vector3(0, 35, 0), Vector3(1.4, 1.4, 1.4), city)

	# Parked Yellow Service Truck down the side street
	add_elem.call(res_truck_yellow, Vector3(-8.0, 0.15, 16.0), Vector3(0, 90, 0), Vector3(1.4, 1.4, 1.4), city)

	# Parked Green Truck near plaza
	add_elem.call(res_truck_green, Vector3(16.0, 0.15, 0.0), Vector3(0, 0, 0), Vector3(1.4, 1.4, 1.4), city)

	# NPC Kolya in the Plaza
	add_elem.call(res_char, Vector3(10.0, 0.12, 14.0), Vector3(0, 180, 0), Vector3(1.8, 1.8, 1.8), city)

	# 5. Position Player, Delivery Van, and Crate Objects
	# Delivery Van: centered on the road, facing forward (-Z) towards the warehouse
	var van: Node3D = root_node.get_node_or_null("DeliveryVan")
	if van:
		van.position = Vector3(0.0, 0.45, 38.0)
		van.rotation_degrees = Vector3(0, 0, 0)
		print("[OK] DeliveryVan positioned at (0.0, 0.45, 38.0) facing forward")

	# Crates: neatly positioned on the flat asphalt road behind the van
	var mat_wood: Material = load("res://assets/materials/mat_wood.tres")
	var crate_positions = [
		Vector3(-0.6, 0.35, 41.8),
		Vector3(0.6, 0.35, 41.8),
		Vector3(0.0, 0.35, 42.8)
	]
	for i in [1, 2, 3]:
		var crate: RigidBody3D = root_node.get_node_or_null("ColaCrate" + str(i))
		if crate:
			crate.position = crate_positions[i - 1]
			crate.rotation_degrees = Vector3(0, (i - 1) * 15.0, 0)
			var cm: MeshInstance3D = crate.get_node_or_null("MeshInstance3D")
			if cm and mat_wood:
				cm.material_override = mat_wood
	print("[OK] Cola Crates arranged on asphalt behind the van")

	# Bubble Drone: hovering smoothly
	var drone: Node3D = root_node.get_node_or_null("BubbleDrone")
	if drone:
		drone.position = Vector3(-2.0, 2.5, 42.0)
		print("[OK] BubbleDrone hovering at (-2.0, 2.5, 42.0)")

	# Player start: positioned at Z = 45.0, looking down the street towards the van
	var player: Node3D = root_node.get_node_or_null("Player")
	if player:
		player.position = Vector3(0.0, 1.4, 45.0)
		player.rotation_degrees = Vector3(0, 0, 0)
		print("[OK] Player at (0.0, 1.4, 45.0)")

	# Save updated scene
	var packed = PackedScene.new()
	var err = packed.pack(root_node)
	if err == OK:
		var save_err = ResourceSaver.save(packed, "res://scenes/levels/old_district.tscn")
		if save_err == OK:
			print("[SUCCESS] Saved old_district.tscn!")
		else:
			printerr("[ERROR] Failed to save scene: ", save_err)
	else:
		printerr("[ERROR] Failed to pack scene: ", err)

	root_node.free()