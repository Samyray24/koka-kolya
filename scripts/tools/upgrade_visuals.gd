extends SceneTree

var frame: int = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		_upgrade_delivery_van()
		_upgrade_old_district()
		quit(0)
		return true
	return false

func _upgrade_delivery_van() -> void:
	print("--- Upgrading Delivery Van 3D Visuals ---")
	var van_scene: PackedScene = load("res://scenes/vehicles/delivery_van.tscn")
	if not van_scene:
		printerr("Failed to load delivery_van.tscn")
		return

	var van_root: Node = van_scene.instantiate()
	
	# Load vehicle-truck-red
	var truck_model_res: PackedScene = load("res://assets/scenes_3d/vehicle-truck-red.tscn")
	if truck_model_res:
		var truck_model = truck_model_res.instantiate()
		truck_model.name = "VisualTruckModel"
		truck_model.scale = Vector3(1.4, 1.4, 1.4)
		truck_model.position = Vector3(0, 0.45, 0.1)
		# Hide primitive box meshes
		var old_body = van_root.get_node_or_null("BodyMesh")
		if old_body:
			old_body.visible = false
		var old_cabin = van_root.get_node_or_null("CabinGlass")
		if old_cabin:
			old_cabin.visible = false
		van_root.add_child(truck_model)
		truck_model.owner = van_root
		for c in truck_model.get_children():
			c.owner = van_root
		print("[OK] Integrated 3D Truck Model into DeliveryVan")

	var packed = PackedScene.new()
	packed.pack(van_root)
	var err = ResourceSaver.save(packed, "res://scenes/vehicles/delivery_van.tscn")
	print("Saved updated delivery_van.tscn -> err: ", err)
	van_root.free()

func _upgrade_old_district() -> void:
	print("--- Upgrading Old District 3D Visuals & PBR Materials ---")
	var old_scene_res: PackedScene = load("res://scenes/levels/old_district.tscn")
	if not old_scene_res:
		printerr("Failed to load old_district.tscn")
		return

	var root_node: Node = old_scene_res.instantiate()

	# 1. PBR Materials
	var mat_asphalt: Material = load("res://assets/materials/mat_asphalt.tres")
	var mat_wood: Material = load("res://assets/materials/mat_wood.tres")
	var mat_concrete: Material = load("res://assets/materials/mat_concrete.tres")
	var mat_metal: Material = load("res://assets/materials/mat_metal.tres")
	var mat_brick: Material = load("res://assets/materials/mat_brick.tres")

	# Ground
	var ground_mesh: MeshInstance3D = root_node.get_node_or_null("Ground/MeshInstance3D")
	if ground_mesh and mat_asphalt:
		ground_mesh.material_override = mat_asphalt
		print("[OK] Applied mat_asphalt to Ground")

	# Cola Crates
	for i in [1, 2, 3]:
		var crate_mesh: MeshInstance3D = root_node.get_node_or_null("ColaCrate" + str(i) + "/MeshInstance3D")
		if crate_mesh and mat_wood:
			crate_mesh.material_override = mat_wood
			print("[OK] Applied mat_wood to ColaCrate%d" % i)

	# Warehouse
	var wh_mesh: MeshInstance3D = root_node.get_node_or_null("Warehouse/Building/MeshInstance3D")
	if wh_mesh and mat_concrete:
		wh_mesh.material_override = mat_concrete
	var gate_mesh: MeshInstance3D = root_node.get_node_or_null("Warehouse/SecurityGate/DoorLeaf/MeshInstance3D")
	if gate_mesh and mat_metal:
		gate_mesh.material_override = mat_metal

	# 2. 3D Volumetric City Environment
	var city_parent = root_node.get_node_or_null("CityArchitecture")
	if city_parent:
		city_parent.free()
	city_parent = Node3D.new()
	city_parent.name = "CityArchitecture"
	root_node.add_child(city_parent)
	city_parent.owner = root_node

	# Modular road pieces
	var road_light_res: PackedScene = load("res://assets/scenes_3d/road-straight-lightposts.tscn")
	var road_res: PackedScene = load("res://assets/scenes_3d/road-straight.tscn")
	
	var road_z_positions = [42.0, 26.0, 10.0, -6.0, -22.0]
	for z_pos in road_z_positions:
		var r_inst: Node = (road_light_res if abs(z_pos - 26.0) < 1.0 or abs(z_pos - 42.0) < 1.0 or abs(z_pos - 10.0) < 1.0 else road_res).instantiate()
		r_inst.scale = Vector3(3.0, 3.0, 3.0)
		r_inst.position = Vector3(0, 0.05, z_pos)
		city_parent.add_child(r_inst)
		r_inst.owner = root_node
		_set_owner_recursive(r_inst, root_node)

		# Add warm street lamp light for lightpost roads
		if abs(z_pos - 26.0) < 1.0 or abs(z_pos - 42.0) < 1.0 or abs(z_pos - 10.0) < 1.0:
			for side in [-4.5, 4.5]:
				var lamp_light = OmniLight3D.new()
				lamp_light.position = Vector3(side, 4.2, z_pos)
				lamp_light.light_color = Color(1.0, 0.85, 0.58)
				lamp_light.light_energy = 3.5
				lamp_light.omni_range = 14.0
				lamp_light.shadow_enabled = true
				city_parent.add_child(lamp_light)
				lamp_light.owner = root_node

	# 3D Buildings along the street
	var building_scenes = [
		load("res://assets/scenes_3d/building-small-a.tscn"),
		load("res://assets/scenes_3d/building-small-b.tscn"),
		load("res://assets/scenes_3d/building-small-c.tscn"),
		load("res://assets/scenes_3d/building-small-d.tscn")
	]

	# Left side buildings (X = -17)
	var z_coords_bldg = [48.0, 32.0, 16.0, 0.0, -16.0, -32.0]
	for i in range(z_coords_bldg.size()):
		var b_res = building_scenes[i % building_scenes.size()]
		var b_inst = b_res.instantiate()
		b_inst.scale = Vector3(3.8, 3.8, 3.8)
		b_inst.position = Vector3(-17.0, 0.05, z_coords_bldg[i])
		b_inst.rotation = Vector3(0, PI / 2.0, 0)
		city_parent.add_child(b_inst)
		b_inst.owner = root_node
		_set_owner_recursive(b_inst, root_node)

	# Right side buildings (X = 17)
	for i in range(z_coords_bldg.size()):
		var b_res = building_scenes[(i + 2) % building_scenes.size()]
		var b_inst = b_res.instantiate()
		b_inst.scale = Vector3(3.8, 3.8, 3.8)
		b_inst.position = Vector3(17.0, 0.05, z_coords_bldg[i])
		b_inst.rotation = Vector3(0, -PI / 2.0, 0)
		city_parent.add_child(b_inst)
		b_inst.owner = root_node
		_set_owner_recursive(b_inst, root_node)

	# Garage Building model behind player
	var garage_res: PackedScene = load("res://assets/scenes_3d/building-garage.tscn")
	if garage_res:
		var g_inst = garage_res.instantiate()
		g_inst.scale = Vector3(4.5, 4.5, 4.5)
		g_inst.position = Vector3(0, 0.05, 59.0)
		city_parent.add_child(g_inst)
		g_inst.owner = root_node
		_set_owner_recursive(g_inst, root_node)

	# Greenery / trees
	var tree_res: PackedScene = load("res://assets/scenes_3d/grass-trees.tscn")
	var tall_tree_res: PackedScene = load("res://assets/scenes_3d/grass-trees-tall.tscn")
	var tree_spots = [
		Vector3(-8.5, 0.05, 52.0),
		Vector3(8.5, 0.05, 52.0),
		Vector3(-8.5, 0.05, 36.0),
		Vector3(8.5, 0.05, 36.0),
		Vector3(-8.5, 0.05, 18.0),
		Vector3(8.5, 0.05, 18.0),
		Vector3(-8.5, 0.05, -2.0),
		Vector3(8.5, 0.05, -2.0)
	]
	for idx in range(tree_spots.size()):
		var t_res = tree_res if idx % 2 == 0 else tall_tree_res
		var t_inst = t_res.instantiate()
		t_inst.scale = Vector3(2.5, 2.5, 2.5)
		t_inst.position = tree_spots[idx]
		city_parent.add_child(t_inst)
		t_inst.owner = root_node
		_set_owner_recursive(t_inst, root_node)

	# Kolya character model near garage
	var char_res: PackedScene = load("res://assets/scenes_3d/character.tscn")
	if char_res:
		var k_inst = char_res.instantiate()
		k_inst.name = "NPC_Kolya"
		k_inst.scale = Vector3(1.3, 1.3, 1.3)
		k_inst.position = Vector3(-4.0, 0.1, 51.5)
		k_inst.rotation = Vector3(0, deg_to_rad(135.0), 0)
		city_parent.add_child(k_inst)
		k_inst.owner = root_node
		_set_owner_recursive(k_inst, root_node)

	# Save updated scene
	var packed = PackedScene.new()
	packed.pack(root_node)
	var err = ResourceSaver.save(packed, "res://scenes/levels/old_district.tscn")
	print("Saved upgraded old_district.tscn -> err: ", err)
	root_node.free()

func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)

