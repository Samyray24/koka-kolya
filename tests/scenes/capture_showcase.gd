extends SceneTree

# High-detail Showcase Capture for Volumetric & Physics Props
var frames: int = 0
var world: Node3D = null

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		world = Node3D.new()
		world.name = "ShowcaseWorld"
		root.add_child(world)

		# Пол
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

		# 1. Объемный автомат Кока-Коля
		var vm_script = load("res://scripts/interaction/vending_machine.gd")
		if vm_script:
			var vm = vm_script.new()
			vm.position = Vector3(-2.2, 0.0, 0.0)
			vm.rotation_degrees = Vector3(0, 15, 0)
			world.add_child(vm)

		# 2. Объемный лут-контейнер
		var lc_script = load("res://scripts/interaction/loot_container.gd")
		if lc_script:
			var lc = lc_script.new()
			lc.position = Vector3(-0.7, 0.0, 0.2)
			lc.rotation_degrees = Vector3(0, -20, 0)
			world.add_child(lc)

		# 3. Разрушаемый ящик (DestructibleCrate)
		var crate_script = load("res://scripts/physics/destructible_crate.gd")
		if crate_script:
			var crate = crate_script.new()
			crate.freeze = true
			crate.position = Vector3(0.65, 0.5, 0.1)
			crate.rotation_degrees = Vector3(0, 25, 0)
			world.add_child(crate)

		# 4. Взрывоопасная бочка (ExplosiveBarrel)
		var barrel_script = load("res://scripts/physics/explosive_barrel.gd")
		if barrel_script:
			var barrel = barrel_script.new()
			barrel.freeze = true
			barrel.position = Vector3(1.85, 0.53, 0.0)
			barrel.rotation_degrees = Vector3(0, -15, 0)
			world.add_child(barrel)

		var cam = Camera3D.new()
		cam.name = "ShowcaseCam"
		world.add_child(cam)
		cam.position = Vector3(0.0, 1.35, 3.4)
		cam.look_at(Vector3(0.0, 0.8, 0.0), Vector3.UP)
		cam.current = true
		cam.make_current()

	if frames == 35:
		var img: Image = root.get_texture().get_image()
		if img:
			var global_path: String = ProjectSettings.globalize_path("res://docs/screenshots/volumetric_physics_showcase.png")
			var err: Error = img.save_png(global_path)
			print("Saved showcase screenshot: ", err)
		quit(0)
		return true

	return false
