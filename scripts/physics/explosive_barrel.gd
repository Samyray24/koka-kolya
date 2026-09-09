class_name ExplosiveBarrel
extends RigidBody3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# Взрывоопасная бочка с горючим: честная Jolt-физика, реакция на выстрелы и детонационная волна
signal barrel_exploded(pos: Vector3)

@export var max_health: float = 30.0
@export var blast_radius: float = 6.5
@export var blast_force: float = 48.0
@export var blast_damage: float = 95.0

var current_health: float = 30.0
var is_exploded: bool = false
var is_smoking: bool = false

var smoke_particles: CPUParticles3D = null

func _ready() -> void:
	current_health = max_health
	mass = 22.0
	collision_layer = 4 # Объекты / AI / Захват
	collision_mask = 7 # Мир, Игрок, Объекты
	add_to_group("explosive")
	add_to_group("destructible")

	var p_mat := PhysicsMaterial.new()
	p_mat.friction = 0.7
	p_mat.bounce = 0.2
	physics_material_override = p_mat

	_build_visuals()

func _build_visuals() -> void:
	# Стальной цилиндр бочки с кольцами жесткости
	var b_mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.36
	cm.bottom_radius = 0.36
	cm.height = 1.05
	b_mesh.mesh = cm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.18, 0.12) # Сигнальный красный цвет
	mat.metallic = 0.8
	mat.roughness = 0.3
	b_mesh.material_override = mat
	add_child(b_mesh)

	# Желто-черная полоса опасности на бочке
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.365
	band_mesh.bottom_radius = 0.365
	band_mesh.height = 0.2
	band.mesh = band_mesh
	var mat_hazard: Material = load("res://assets/materials/mat_hazard.tres")
	if mat_hazard:
		band.material_override = mat_hazard
	else:
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = Color(1.0, 0.8, 0.1)
		band.material_override = band_mat
	add_child(band)

	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.36
	cyl.height = 1.05
	cs.shape = cyl
	add_child(cs)

func take_damage(amount: float, impulse_dir: Vector3 = Vector3.ZERO, impulse_force: float = 0.0) -> void:
	if is_exploded:
		return

	current_health -= amount
	if impulse_force > 0.0 and is_inside_tree():
		apply_central_impulse(impulse_dir.normalized() * impulse_force)

	# Искры от попадания по металлу
	var root_node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if root_node and is_inside_tree():
		ImpactFX.spawn_sparks(root_node, global_position + Vector3(0, 0.4, 0), -impulse_dir)

	if current_health <= 15.0 and not is_smoking and is_inside_tree():
		_start_smoking()

	if current_health <= 0.0:
		explode()

func _start_smoking() -> void:
	is_smoking = true
	smoke_particles = CPUParticles3D.new()
	smoke_particles.name = "PreExplosionSmoke"
	smoke_particles.amount = 12
	smoke_particles.lifetime = 0.7
	smoke_particles.direction = Vector3(0, 1, 0)
	smoke_particles.spread = 20.0
	smoke_particles.gravity = Vector3(0, 2, 0)
	smoke_particles.initial_velocity_min = 1.0
	smoke_particles.initial_velocity_max = 2.5
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.2, 0.2, 0.5)
	sm.material = mat
	smoke_particles.mesh = sm
	add_child(smoke_particles)

func explode() -> void:
	if is_exploded:
		return
	is_exploded = true
	var blast_pos: Vector3 = global_position if is_inside_tree() else position
	barrel_exploded.emit(blast_pos)

	var root_node = get_parent() if get_parent() else (get_tree().root if get_tree() else null)
	if root_node:
		ImpactFX.spawn_explosion(root_node, blast_pos)

	# Звук взрыва
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "impact", 4.0, 0.6)

	# Распространение радиальной ударной волны
	if is_inside_tree():
		_apply_blast_physics(root_node)

	queue_free()

func _apply_blast_physics(root_node: Node) -> void:
	if not is_inside_tree():
		return
	var world := get_world_3d()
	if not world:
		return
	var space_state := world.direct_space_state
	if not space_state:
		return

	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = blast_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere_shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 1 | 2 | 4

	var hits := space_state.intersect_shape(query, 32)
	for hit in hits:
		var collider = hit.get("collider")
		if collider == self or not is_instance_valid(collider):
			continue

		var dist: float = global_position.distance_to(collider.global_position)
		if dist > blast_radius:
			continue

		var dist_factor: float = clampf(1.0 - (dist / blast_radius), 0.15, 1.0)
		var blast_dir: Vector3 = (collider.global_position - global_position).normalized()
		if blast_dir.length_squared() < 0.01:
			blast_dir = Vector3.UP
		blast_dir = (blast_dir + Vector3.UP * 0.4).normalized()

		# 1. Воздействие на физические тела (бочки, ящики, осколки, транспорт)
		if collider is RigidBody3D:
			(collider as RigidBody3D).apply_central_impulse(blast_dir * (blast_force * dist_factor))
			(collider as RigidBody3D).apply_torque_impulse(Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)))

		# 2. Воздействие на врагов и персонажей
		if collider is Node and (collider as Node).has_method("take_damage"):
			(collider as Node).call("take_damage", blast_damage * dist_factor, blast_dir, blast_force * dist_factor * 0.4)
		elif collider is Node and (collider as Node).has_method("apply_stun"):
			(collider as Node).call("apply_stun", 4.0)
