extends SceneTree

# Unified Screenshot Capture for Updated Physics & Volumetric 3D Levels
var step: int = 0
var active_level: Node = null
var current_cam: Camera3D = null

func _process(_delta: float) -> bool:
	step += 1
	match step:
		1:
			print(">>> CAPTURING LEVEL 2: RED LINE PLANT <<<")
			_load_level("res://scenes/levels/red_line_plant.tscn", Vector3(-8.5, 3.2, 56.0), Vector3(-2.0, 1.2, 46.0))
		40:
			_save_screenshot("res://docs/screenshots/red_line_plant.png")
			_clear_level()
		45:
			print(">>> CAPTURING LEVEL 3: CITY HIGHWAY <<<")
			_load_level("res://scenes/levels/city_highway.tscn", Vector3(0.0, 3.8, 80.0), Vector3(0.0, 1.5, 45.0))
		85:
			_save_screenshot("res://docs/screenshots/city_highway.png")
			_clear_level()
		90:
			print(">>> CAPTURING LEVEL 4: CITADEL PENTHOUSE <<<")
			_load_level("res://scenes/levels/citadel_penthouse.tscn", Vector3(8.0, 2.8, -16.0), Vector3(-4.0, 2.0, 2.0))
		130:
			_save_screenshot("res://docs/screenshots/citadel_penthouse.png")
			_clear_level()
		135:
			print(">>> CAPTURING VOLUMETRIC & PHYSICS SHOWCASE <<<")
			_build_showcase()
		175:
			_save_screenshot("res://docs/screenshots/volumetric_physics_showcase.png")
			_clear_level()
		180:
			print(">>> ALL SCREENSHOTS CAPTURED SUCCESSFULLY! <<<")
			quit(0)
			return true
	return false

func _load_level(scene_path: String, cam_pos: Vector3, cam_look: Vector3) -> void:
	var res: PackedScene = load(scene_path)
	if not res:
		printerr("Failed to load scene: ", scene_path)
		quit(1)
		return
	active_level = res.instantiate()
	root.add_child(active_level)

	var p_cam = active_level.get_node_or_null("Player/Head/Camera3D")
	if p_cam:
		p_cam.set("current", false)

	current_cam = Camera3D.new()
	current_cam.name = "CinematicCaptureCam"
	active_level.add_child(current_cam)
	current_cam.position = cam_pos
	current_cam.look_at(cam_look, Vector3.UP)
	current_cam.current = true
	current_cam.make_current()

func _build_showcase() -> void:
	var world := Node3D.new()
	world.name = "ShowcaseWorld"
	root.add_child(world)
	active_level = world

	var floor_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(18.0, 0.2, 14.0)
	floor_mesh.mesh = bm
	var mat_floor: Material = load("res://assets/materials/mat_concrete.tres")
	if mat_floor:
		floor_mesh.material_override = mat_floor
	floor_mesh.position = Vector3(0, -0.1, 0)
	world.add_child(floor_mesh)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 45, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0, 3.2, 2.8)
	fill_light.light_energy = 1.6
	fill_light.omni_range = 10.0
	fill_light.light_color = Color(1.0, 0.95, 0.85)
	world.add_child(fill_light)

	var vm_script = load("res://scripts/interaction/vending_machine.gd")
	if vm_script:
		var vm = vm_script.new()
		vm.position = Vector3(-2.2, 0.0, 0.0)
		vm.rotation_degrees = Vector3(0, 15, 0)
		world.add_child(vm)

	var lc_script = load("res://scripts/interaction/loot_container.gd")
	if lc_script:
		var lc = lc_script.new()
		lc.position = Vector3(-0.7, 0.0, 0.2)
		lc.rotation_degrees = Vector3(0, -20, 0)
		world.add_child(lc)

	var crate_script = load("res://scripts/physics/destructible_crate.gd")
	if crate_script:
		var crate = crate_script.new()
		crate.position = Vector3(0.8, 0.5, 0.1)
		crate.rotation_degrees = Vector3(0, 25, 0)
		world.add_child(crate)

	var barrel_script = load("res://scripts/physics/explosive_barrel.gd")
	if barrel_script:
		var barrel = barrel_script.new()
		barrel.position = Vector3(2.2, 0.53, 0.0)
		barrel.rotation_degrees = Vector3(0, -15, 0)
		world.add_child(barrel)

	current_cam = Camera3D.new()
	current_cam.name = "ShowcaseCam"
	current_cam.position = Vector3(0.0, 1.45, 3.5)
	current_cam.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	current_cam.current = true
	current_cam.make_current()
	world.add_child(current_cam)

func _save_screenshot(res_path: String) -> void:
	var img: Image = root.get_texture().get_image()
	if img:
		var global_path: String = ProjectSettings.globalize_path(res_path)
		var err: Error = img.save_png(global_path)
		print("Saved screenshot to: ", global_path, " (result=", err, ")")

func _clear_level() -> void:
	if active_level:
		active_level.queue_free()
		active_level = null
