class_name BreakableGlass
extends StaticBody3D

# Разрушаемое стекло с авторскими стадиями повреждения (Section 13)
# Стадии: INTACT -> CRACKED -> SHATTERED с пулом ограниченных осколков

signal glass_cracked()
signal glass_shattered()

enum GlassState { INTACT, CRACKED, SHATTERED }

@export var max_health: float = 30.0
@export var impact_impulse_threshold: float = 4.0

var current_health: float = 30.0
var state: GlassState = GlassState.INTACT

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	current_health = max_health

func apply_damage(amount: float) -> void:
	if state == GlassState.SHATTERED:
		return

	current_health -= amount
	LogManager.debug("Стекло получило урон: %.1f (Осталось: %.1f)" % [amount, current_health], "GLASS")

	if current_health <= 0:
		shatter()
	elif current_health <= max_health * 0.5 and state == GlassState.INTACT:
		state = GlassState.CRACKED
		glass_cracked.emit()
		_update_visual_cracked()

func _update_visual_cracked() -> void:
	if mesh_instance and mesh_instance.material_override:
		var mat: BaseMaterial3D = mesh_instance.material_override as BaseMaterial3D
		if mat:
			mat.roughness = 0.85
			mat.albedo_color = Color(0.8, 0.85, 0.95, 0.6)

func shatter() -> void:
	if state == GlassState.SHATTERED:
		return

	state = GlassState.SHATTERED
	glass_shattered.emit()
	LogManager.info("Стекло разбито!", "GLASS")

	# Отключаем коллизию и скрываем основную сетку
	collision_shape.set_deferred("disabled", true)
	mesh_instance.visible = false

	# Спавним ограниченный набор физических осколков (6 шт) с ограничением жизни
	_spawn_shards()

func _spawn_shards() -> void:
	if not is_inside_tree() or not get_parent():
		return
	var parent_node := get_parent()

	for i in range(6):
		var shard := RigidBody3D.new()
		shard.mass = 0.25
		shard.collision_layer = 4
		shard.collision_mask = 5

		var col := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(0.2, 0.2, 0.05)
		col.shape = box_shape
		shard.add_child(col)

		var m_inst := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.2, 0.2, 0.05)
		m_inst.mesh = box_mesh
		shard.add_child(m_inst)

		parent_node.add_child(shard)
		shard.global_position = global_position + Vector3(
			randf_range(-0.4, 0.4),
			randf_range(-0.4, 0.4),
			randf_range(-0.1, 0.1)
		)

		var impulse := Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.0), randf_range(-1.5, 1.5))
		shard.apply_central_impulse(impulse)

		# Автоматическое удаление через 3.5 секунды во избежание засорения физического мира
		var timer := get_tree().create_timer(3.5)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(shard):
				shard.queue_free()
		)
