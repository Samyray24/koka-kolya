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
	mass = 14.0
	collision_layer = 4 # Объекты / AI / Захват
	collision_mask = 7 # Мир, Игрок, Объекты
	add_to_group("destructible")

	var p_mat := PhysicsMaterial.new()
	p_mat.friction = 0.8
	p_mat.bounce = 0.15
	physics_material_override = p_mat

	_build_visuals()

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

func take_damage(amount: float, impulse_dir: Vector3 = Vector3.ZERO, impulse_force: float = 0.0) -> void:
	if is_broken:
		return

	current_health -= amount
	if impulse_force > 0.0:
		apply_central_impulse(impulse_dir.normalized() * impulse_force)

	# Звук удара по дереву
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "impact", -3.0, randf_range(1.1, 1.3))

	# Спавн щепок
	ImpactFX.spawn_splinters(get_parent() if get_parent() else self, global_position + Vector3(0, 0.4, 0), -impulse_dir)

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

	# Спавним 5 физических обломков досок
	for i in range(5):
		var plank := RigidBody3D.new()
		plank.name = "PlankDebris_%d" % randi()
		plank.mass = 2.0
		plank.collision_layer = 4
		plank.collision_mask = 1 | 4

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

		var launch_dir := (hit_dir * 0.6 + offset.normalized() * 0.8 + Vector3.UP * 0.8).normalized()
		var blast_impulse := launch_dir * randf_range(force * 0.6, force * 1.3 + 6.0)
		plank.apply_central_impulse(blast_impulse)
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
		can.mass = 0.4
		can.collision_layer = 4
		can.collision_mask = 1 | 4

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
		can.apply_central_impulse(Vector3(randf_range(-1.2, 1.2), 3.2, randf_range(-1.2, 1.2)))
	else:
		if has_node("/root/GameManager"):
			var gm: Node = get_node("/root/GameManager")
			gm.call("add_credits", 25)
