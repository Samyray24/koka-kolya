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

static func spawn_drift_smoke(parent: Node, pos: Vector3, dir: Vector3 = Vector3.UP) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.name = "DriftSmokeFX"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 8
	p.lifetime = 0.55
	p.direction = dir + Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4))
	p.spread = 50.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, 1.2, 0)

	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.85, 0.88, 0.35)
	mesh.material = mat
	p.mesh = mesh

	parent.add_child(p)
	p.global_position = pos
	p.restart()

	var tw := p.create_tween()
	tw.tween_interval(0.65)
	tw.tween_callback(p.queue_free)

static func spawn_bullet_scorch(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var s := MeshInstance3D.new()
	s.name = "BulletScorch"
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	s.mesh = qm

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.1, 0.12, 0.85)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material_override = mat

	parent.add_child(s)
	s.global_position = pos + normal * 0.01
	if normal.abs().is_equal_approx(Vector3.UP):
		s.look_at(s.global_position + normal, Vector3.FORWARD)
	else:
		s.look_at(s.global_position + normal, Vector3.UP)

	var tw := s.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tw.tween_callback(s.queue_free)

static func spawn_exhaust_flame(parent: Node, pos: Vector3, dir: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.name = "ExhaustFlameFX"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.22
	p.direction = dir
	p.spread = 15.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, 1.5, 0)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 0.25)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.05)
	mat.emission_energy_multiplier = 5.0
	mesh.material = mat
	p.mesh = mesh

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.1)
	light.light_energy = 3.5
	light.omni_range = 3.0
	parent.add_child(light)
	light.global_position = pos

	parent.add_child(p)
	p.global_position = pos
	p.restart()

	var tw := p.create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(p.queue_free)
	var tw_l := light.create_tween()
	tw_l.tween_property(light, "light_energy", 0.0, 0.2)
	tw_l.tween_callback(light.queue_free)

static func spawn_nitro_flame(parent: Node, pos: Vector3, dir: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.name = "NitroFlameFX"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.98
	p.amount = 22
	p.lifetime = 0.28
	p.direction = dir
	p.spread = 12.0
	p.initial_velocity_min = 9.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0, 0.5, 0)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.32)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.95, 1.0)
	mat.emission_energy_multiplier = 6.0
	mesh.material = mat
	p.mesh = mesh

	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 0.9, 1.0)
	light.light_energy = 4.5
	light.omni_range = 4.0
	parent.add_child(light)
	light.global_position = pos

	parent.add_child(p)
	p.global_position = pos
	p.restart()

	var tw := p.create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(p.queue_free)
	var tw_l := light.create_tween()
	tw_l.tween_property(light, "light_energy", 0.0, 0.25)
	tw_l.tween_callback(light.queue_free)


static func spawn_steam_vent(parent: Node, pos: Vector3, count: int = 14) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.name = "SteamVentFX"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.75
	p.amount = count
	p.lifetime = 1.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, 1.2, 0)

	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.22)
	mat.roughness = 1.0
	mesh.material = mat
	p.mesh = mesh

	parent.add_child(p)
	p.global_position = pos
	p.restart()

	var tw := p.create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(p.queue_free)

static func spawn_shield_ripple(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var ripple := MeshInstance3D.new()
	ripple.name = "ShieldRippleFX"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.1
	cyl.height = 0.02
	ripple.mesh = cyl

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.8, 1.0, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.9, 1.0)
	mat.emission_energy_multiplier = 3.5
	ripple.material_override = mat

	parent.add_child(ripple)
	ripple.global_position = pos
	if normal.abs().is_equal_approx(Vector3.UP):
		ripple.look_at(ripple.global_position + normal, Vector3.FORWARD)
	else:
		ripple.look_at(ripple.global_position + normal, Vector3.UP)

	var tw := ripple.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ripple, "scale", Vector3(6.0, 1.0, 6.0), 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(ripple.queue_free)

	spawn_sparks(parent, pos, normal, 8)

