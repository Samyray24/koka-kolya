class_name ImpactFX
extends RefCounted

# Универсальная процедурная система эффектов ударов и столкновений (Impact FX)
# Генерирует искры, обломки, дым и пыль без тяжёлых текстурных ассетов.

static func spawn_sparks(parent: Node, pos: Vector3, normal: Vector3 = Vector3.UP, count: int = 14) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.name = "SparksFX"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = 0.45
	p.direction = normal + Vector3(randf_range(-0.3, 0.3), randf_range(0.2, 0.6), randf_range(-0.3, 0.3))
	p.spread = 45.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -18.0, 0)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.12)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	mat.emission_energy_multiplier = 4.0
	mesh.material = mat
	p.mesh = mesh

	parent.add_child(p)
	p.global_position = pos
	p.restart()

	var tw := p.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(p.queue_free)

static func spawn_splinters(parent: Node, pos: Vector3, normal: Vector3 = Vector3.UP, count: int = 12) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.name = "SplintersFX"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = count
	p.lifetime = 0.6
	p.direction = normal + Vector3(0, 0.5, 0)
	p.spread = 50.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -12.0, 0)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.03, 0.16)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.42, 0.25)
	mat.roughness = 0.9
	mesh.material = mat
	p.mesh = mesh

	parent.add_child(p)
	p.global_position = pos
	p.restart()

	var tw := p.create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(p.queue_free)

static func spawn_dust(parent: Node, pos: Vector3, count: int = 8) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.name = "DustFX"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = count
	p.lifetime = 0.7
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -1.0, 0)

	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.68, 0.65, 0.28)
	mesh.material = mat
	p.mesh = mesh

	parent.add_child(p)
	p.global_position = pos
	p.restart()

	var tw := p.create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(p.queue_free)

static func spawn_explosion(parent: Node, pos: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	# 1. Вспышка огня
	var p_fire := CPUParticles3D.new()
	p_fire.name = "ExplosionFireFX"
	p_fire.emitting = false
	p_fire.one_shot = true
	p_fire.explosiveness = 1.0
	p_fire.amount = 28
	p_fire.lifetime = 0.65
	p_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p_fire.emission_sphere_radius = 0.5
	p_fire.direction = Vector3(0, 1, 0)
	p_fire.spread = 180.0
	p_fire.initial_velocity_min = 6.0
	p_fire.initial_velocity_max = 14.0
	p_fire.gravity = Vector3(0, -6.0, 0)

	var f_mesh := SphereMesh.new()
	f_mesh.radius = 0.4
	f_mesh.height = 0.8
	var f_mat := StandardMaterial3D.new()
	f_mat.albedo_color = Color(1.0, 0.4, 0.05)
	f_mat.emission_enabled = true
	f_mat.emission = Color(1.0, 0.3, 0.0)
	f_mat.emission_energy_multiplier = 4.0
	f_mesh.material = f_mat
	p_fire.mesh = f_mesh
	parent.add_child(p_fire)
	p_fire.global_position = pos
	p_fire.restart()

	# 2. Дымовой шлейф
	var p_smoke := CPUParticles3D.new()
	p_smoke.name = "ExplosionSmokeFX"
	p_smoke.emitting = false
	p_smoke.one_shot = true
	p_smoke.explosiveness = 0.9
	p_smoke.amount = 20
	p_smoke.lifetime = 1.4
	p_smoke.direction = Vector3(0, 1, 0)
	p_smoke.spread = 70.0
	p_smoke.initial_velocity_min = 2.0
	p_smoke.initial_velocity_max = 5.0
	p_smoke.gravity = Vector3(0, 2.0, 0)

	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.5
	s_mesh.height = 1.0
	var s_mat := StandardMaterial3D.new()
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.albedo_color = Color(0.2, 0.2, 0.22, 0.4)
	s_mesh.material = s_mat
	p_smoke.mesh = s_mesh
	parent.add_child(p_smoke)
	p_smoke.global_position = pos
	p_smoke.restart()

	# 3. Вспышка света
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.1)
	light.light_energy = 8.0
	light.omni_range = 14.0
	parent.add_child(light)
	light.global_position = pos

	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.4)
	tw.tween_callback(light.queue_free)

	var tw2 := p_fire.create_tween()
	tw2.tween_interval(1.8)
	tw2.tween_callback(p_fire.queue_free)
	tw2.tween_callback(p_smoke.queue_free)
