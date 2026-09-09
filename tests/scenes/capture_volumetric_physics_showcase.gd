extends SceneTree

# Showcase capture for Volumetric 3D Models & Physics Props

var frames_waited: int = 0
var test_world: Node3D = null

func _process(_delta: float) -> bool:
	frames_waited += 1

	if frames_waited == 1:
		test_world = Node3D.new()
		test_world.name = ShowcaseWorld
		root.add_child(test_world)

		# Пол
		var floor_mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(18.0, 0.2, 14.0)
		floor_mesh.mesh = bm
		var mat_floor: Material = load(res://assets/materials/mat_concrete.tres)
		if mat_floor:
			floor_mesh.material_override = mat_floor
		floor_mesh.position = Vector3(0, -0.1, 0)
		test_world.add_child(floor_mesh)

		# Освещение сцены
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 45, 0)
		sun.light_energy = 1.4
		sun.shadow_enabled = true
		test_world.add_child(sun)

		var fill_light := OmniLight3D.new()
		fill_light.position = Vector3(0, 3.5, 2.5)
		fill_light.light_energy = 1.8
		fill_light.omni_range = 10.0
		fill_light.light_color = Color(1.0, 0.95, 0.85)
		test_world.add_child(fill_light)

		# 1. Автомат Кока-Коля (объемный)
		var vend_script = load(res://scripts/interaction/vending_machine.gd)
		if vend_script:
			var vm = vend_script.new()
			vm.name = ShowcaseVendingMachine
			vm.position = Vector3(-2.2, 0.0, 0.0)
			vm.rotation_degrees = Vector3(0, 15, 0)
			test_world.add_child(vm)

		# 2. Лут-контейнер (объемный)
		var loot_script = load(res://scripts/interaction/loot_container.gd)
		if loot_script:
			var lc = loot_script.new()
			lc.name = ShowcaseLootContainer
			lc.position = Vector3(-0.7, 0.0, 0.2)
			lc.rotation_degrees = Vector3(0, -20, 0)
			test_world.add_child(lc)

		# 3. Разрушаемый деревянный ящик с физикой (DestructibleCrate)
		var crate_script = load(res://scripts/physics/destructible_crate.gd)
		if crate_script:
			var crate = crate_script.new()
			crate.name = ShowcaseDestructibleCrate
			crate.position = Vector3(0.8, 0.5, 0.1)
			crate.rotation_degrees = Vector3(0, 30, 0)
			test_world.add_child(crate)

		# 4. Взрывоопасная бочка горючего (ExplosiveBarrel)
		var barrel_script = load(res://scripts/physics/explosive_barrel.gd)
		if barrel_script:
			var barrel = barrel_script.new()
			barrel.name = ShowcaseExplosiveBarrel
			barrel.position = Vector3(2.2, 0.53, 0.0)
			barrel.rotation_degrees = Vector3(0, -15, 0)
			test_world.add_child(barrel)

		# Камера крупного плана
		var cam := Camera3D.new()
		cam.name = ShowcaseCamera
		cam.position = Vector3(0.0, 1.45, 3.4)
		cam.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
		cam.current = true
		cam.make_current()
		test_world.add_child(cam)

	if frames_waited == 45:
		var img := root.get_texture().get_image()
		if img:
			var save_path := docs/screenshots/volumetric_physics_showcase.png
			var err := img.save_png(save_path)
			if err == OK:
				print([SCREENSHOT] Successfully saved showcase screenshot to: %s % save_path)
		quit(0)
		return true

	return false
