class_name StunBaton
extends Node3D

# Электрошоковая дубинка охранного корпуса MERIDIAN
# Позволяет бесшумно нейтрализовать охрану на время и выводить из строя электронные щитки.

signal baton_swung()
signal target_stunned(target: Node3D)

@export var tool_name: String = "Электродубинка"
@export var reach: float = 2.4
@export var stun_duration: float = 6.0
@export var damage: float = 35.0
@export var cooldown: float = 0.6
@export var energy_cost: float = 12.0

var current_cooldown: float = 0.0
var energy: float = 100.0
var max_energy: float = 100.0

@onready var mesh_root: Node3D = get_node_or_null("MeshRoot")

func _ready() -> void:
	if not mesh_root:
		_create_procedural_mesh()

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)
	# Пассивная регенерация энергии батареи
	energy = minf(max_energy, energy + 8.0 * delta)

func can_use() -> bool:
	return current_cooldown <= 0.0 and energy >= energy_cost

func use(camera: Camera3D) -> Dictionary:
	var result := {
		"success": false,
		"hit_target": null,
		"hit_point": Vector3.ZERO,
		"action": "miss"
	}
	
	if not can_use() or not camera:
		return result
		
	current_cooldown = cooldown
	energy -= energy_cost
	baton_swung.emit()
	
	# Анимация взмаха дубинкой
	_play_swing_animation()
	
	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4 # Мир, Игрок, Объекты/AI
	query.exclude = [self, camera.owner]
	
	var hit := space_state.intersect_ray(query)
	
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		var hit_pos: Vector3 = hit.get("position", to)
		result["success"] = true
		result["hit_target"] = collider
		result["hit_point"] = hit_pos
		
		# Акустический шум разряда
		if has_node("/root/NoiseManager"):
			var noise_mgr: Node = get_node("/root/NoiseManager")
			noise_mgr.call("emit_noise", hit_pos, 12.0, self, "electro_shock")

		if has_node("/root/AudioManager"):
			var audio_mgr: Node = get_node("/root/AudioManager")
			audio_mgr.call("play_sfx", "stun", -3.0)
			
		# Проверка на охранника (GuardAI)
		if collider is Node and (collider as Node).has_method("apply_stun"):
			(collider as Node).call("apply_stun", stun_duration)
			target_stunned.emit(collider as Node3D)
			result["action"] = "stun_guard"
			LogManager.info("Электродубинка: охранник успешно нейтрализован на %.1f с." % stun_duration, "Combat")
		# Проверка на разрушаемый объект (стекло/ящик)
		elif collider is Node and (collider as Node).has_method("take_damage"):
			(collider as Node).call("take_damage", damage)
			result["action"] = "damage_object"
			LogManager.info("Электродубинка: нанесён урон %.1f объекту %s." % [damage, (collider as Node).name], "Combat")
		elif collider is RigidBody3D:
			var push_dir := -camera.global_transform.basis.z.normalized()
			(collider as RigidBody3D).apply_central_impulse(push_dir * 14.0)
			result["action"] = "knockback_rigid"
		else:
			result["action"] = "hit_wall"
	else:
		# Взмах в воздух
		if has_node("/root/NoiseManager"):
			var noise_mgr: Node = get_node("/root/NoiseManager")
			noise_mgr.call("emit_noise", camera.global_position, 4.0, self, "baton_swing")
			
	return result

func _play_swing_animation() -> void:
	if not mesh_root:
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_root, "rotation:x", deg_to_rad(-45.0), 0.12)
	tween.parallel().tween_property(mesh_root, "position:z", -0.2, 0.12)
	tween.tween_property(mesh_root, "rotation:x", 0.0, 0.25)
	tween.parallel().tween_property(mesh_root, "position:z", 0.0, 0.25)

func _create_procedural_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)
	
	# Рукоять
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.02
	handle_mesh.bottom_radius = 0.022
	handle_mesh.height = 0.22
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.12, 0.12, 0.14)
	handle_mat.roughness = 0.8
	var handle_inst := MeshInstance3D.new()
	handle_inst.mesh = handle_mesh
	handle_inst.material_override = handle_mat
	handle_inst.position = Vector3(0, 0.1, 0)
	mesh_root.add_child(handle_inst)
	
	# Стержень электрошокера
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.015
	rod_mesh.bottom_radius = 0.018
	rod_mesh.height = 0.4
	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.25, 0.28, 0.32)
	rod_mat.metallic = 0.9
	rod_mat.roughness = 0.25
	var rod_inst := MeshInstance3D.new()
	rod_inst.mesh = rod_mesh
	rod_inst.material_override = rod_mat
	rod_inst.position = Vector3(0, 0.4, 0)
	mesh_root.add_child(rod_inst)
	
	# Эмиттер разряда (светящийся наконечник)
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.025
	tip_mesh.height = 0.05
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.2, 0.8, 1.0)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(0.1, 0.7, 1.0)
	tip_mat.emission_energy_multiplier = 3.5
	var tip_inst := MeshInstance3D.new()
	tip_inst.mesh = tip_mesh
	tip_inst.material_override = tip_mat
	tip_inst.position = Vector3(0, 0.61, 0)
	mesh_root.add_child(tip_inst)
