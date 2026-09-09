class_name DestructibleCrate
extends RigidBody3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# Разрушаемый деревянный ящик с честной Jolt-физикой обломков и лута
signal crate_destroyed(pos: Vector3)

@export var max_health: float = 40.0
@export var drops_loot: bool = true
var current_health: float = 40.0
var is_broken: bool = false

var mesh_node: Node3D = null

func _ready() -> void:
	current_health = max_health
	mass = 16.0
	linear_damp = 0.6
	angular_damp = 1.8
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = 4 # Объекты / AI / Захват
	collision_mask = 7 # Мир, Игрок, Объекты
	add_to_group("destructible")

	var p_mat := PhysicsMaterial.new()
	p_mat.friction = 0.78
	p_mat.bounce = 0.08
	physics_material_override = p_mat

	body_entered.connect(_on_crate_impact)
	_build_visuals()

func _on_crate_impact(body: Node) -> void:
	if is_broken:
		return
	var rel_speed: float = linear_velocity.length()
	if body is RigidBody3D:
		rel_speed = (linear_velocity - (body as RigidBody3D).linear_velocity).length()

	if rel_speed > 1.4:
		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			var vol: float = clampf(lerpf(-16.0, 0.0, (rel_speed - 1.4) / 7.0), -16.0, 0.0)
			var pitch: float = randf_range(1.05, 1.25)
			am.call("play_sfx", "impact", vol, pitch)
		if rel_speed > 4.5 and is_inside_tree():
			var root_n = get_parent() if get_parent() else get_tree().root
			if root_n:
				ImpactFX.spawn_splinters(root_n, global_position + Vector3(0, 0.3, 0), -linear_velocity.normalized(), 6)

func _build_visuals() -> void:
	var box_scene: PackedScene = load("res://assets/scenes_3d/box_A.tscn")
	if box_scene:
		mesh_node = box_scene.instantiate()
		mesh_node.scale = Vector3(1.3, 1.3, 1.3)
		add_child(mesh_node)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 1.0, 1.0)
		mi.mesh = bm
		var mat: Material = load("res://assets/materials/mat_metal.tres")
		if mat:
			mi.material_override = mat
		add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = bs
	add_child(cs)

func take_damage(amount: float, impulse_dir: Vector3 = Vector3.ZERO, impulse_force: float = 0.0, hit_pos: Vector3 = Vector3.ZERO) -> void:
	if is_broken:
		return

	current_health -= amount
	if impulse_force > 0.0 and is_inside_tree():
		if hit_pos != Vector3.ZERO:
			var local_contact: Vector3 = hit_pos - global_position
			apply_impulse(impulse_dir.normalized() * impulse_force, local_contact)
		else:
			apply_central_impulse(impulse_dir.normalized() * impulse_force)

	# Звук удара по дереву
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "impact", -3.0, randf_range(1.1, 1.3))

	# Спавн щепок
	var spark_pos: Vector3 = hit_pos if hit_pos != Vector3.ZERO else (global_position + Vector3(0, 0.4, 0))
	ImpactFX.spawn_splinters(get_parent() if get_parent() else self, spark_pos, -impulse_dir)

	if current_health <= 0.0:
		destroy(impulse_dir, impulse_force)

func destroy(hit_dir: Vector3 = Vector3.ZERO, force: float = 12.0) -> void:
	if is_broken:
		return
	is_broken = true
	crate_destroyed.emit(global_position)

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "impact", 2.0, 0.8)

	_spawn_debris(hit_dir, force)

	if drops_loot:
		_spawn_loot()

	queue_free()

func _spawn_debris(hit_dir: Vector3, force: float) -> void:
	var root_node = get_parent() if get_parent() else get_tree().root

	# Спавним 5 физических обломков досок с честной физикой Jolt
	for i in range(5):
		var plank := RigidBody3D.new()
		plank.name = "PlankDebris_%d" % randi()
		plank.mass = randf_range(2.5, 3.8)
		plank.linear_damp = 0.8
		plank.angular_damp = 2.4
		plank.continuous_cd = true
		plank.contact_monitor = true
		plank.max_contacts_reported = 2
		plank.collision_layer = 4
		plank.collision_mask = 1 | 4

		var pmat_phys := PhysicsMaterial.new()
		pmat_phys.friction = 0.82
		pmat_phys.bounce = 0.06
		plank.physics_material_override = pmat_phys

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(randf_range(0.35, 0.6), 0.08, randf_range(0.18, 0.32))
		col.shape = box
		plank.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		mesh_inst.mesh = bm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.65, 0.45, 0.28) # Цвет дерева
		pmat.roughness = 0.85
		mesh_inst.material_override = pmat
		plank.add_child(mesh_inst)

		var offset := Vector3(randf_range(-0.35, 0.35), randf_range(0.15, 0.5), randf_range(-0.35, 0.35))
		root_node.add_child(plank)
		plank.global_position = global_position + offset

		plank.body_entered.connect(func(_b: Node) -> void:
			if is_instance_valid(plank) and plank.linear_velocity.length() > 1.8:
				if plank.has_node("/root/AudioManager"):
					var am: Node = plank.get_node("/root/AudioManager")
					am.call("play_sfx", "impact", -18.0, randf_range(1.3, 1.6))
		)

		var launch_dir := (hit_dir * 0.6 + offset.normalized() * 0.8 + Vector3.UP * 0.8).normalized()
		var blast_impulse := launch_dir * randf_range(force * 0.6, force * 1.3 + 6.0)
		plank.apply_impulse(blast_impulse, offset * 0.5)
		plank.apply_torque_impulse(Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)))

		var tw := plank.create_tween()
		tw.tween_interval(8.0)
		tw.tween_property(plank, "scale", Vector3.ZERO, 0.5)
		tw.tween_callback(plank.queue_free)

func _spawn_loot() -> void:
	var root_node = get_parent() if get_parent() else get_tree().root
	if randf() > 0.4:
		var can := RigidBody3D.new()
		can.name = "LootSodaCan_%d" % randi()
		can.mass = 0.35
		can.linear_damp = 0.4
		can.angular_damp = 0.6
		can.continuous_cd = true
		can.collision_layer = 4
		can.collision_mask = 1 | 4

		var can_mat_phys := PhysicsMaterial.new()
		can_mat_phys.friction = 0.55
		can_mat_phys.bounce = 0.22
		can.physics_material_override = can_mat_phys

		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.08
		cyl.height = 0.2
		col.shape = cyl
		can.add_child(col)

		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.08
		cm.height = 0.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.15, 0.15)
		mat.metallic = 0.8
		mat.roughness = 0.2
		mi.mesh = cm
		mi.material_override = mat
		can.add_child(mi)

		root_node.add_child(can)
		can.global_position = global_position + Vector3(0, 0.45, 0)
		can.apply_impulse(Vector3(randf_range(-1.2, 1.2), 3.2, randf_range(-1.2, 1.2)), Vector3(0.02, 0.05, 0.02))
	else:
		if has_node("/root/GameManager"):
			var gm: Node = get_node("/root/GameManager")
			gm.call("add_credits", 25)
