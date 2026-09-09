class_name TacticalAxe
extends Node3D

# Тактический боевой топор Сопротивления
# Тяжёлое кинетическое оружие ближнего боя для взлома ящиков, баррикад и нейтрализации охраны.

signal axe_swung()
signal hit_landed(target: Node, point: Vector3)

@export var tool_name: String = "Тактический топор"
@export var reach: float = 2.6
@export var damage: float = 55.0
@export var stun_duration: float = 4.5
@export var cooldown: float = 0.55

var current_cooldown: float = 0.0
var base_pos: Vector3 = Vector3(0.28, -0.24, -0.42)
var base_rot: Vector3 = Vector3(deg_to_rad(12), deg_to_rad(-18), deg_to_rad(-8))
var model_node: Node3D = null

func _ready() -> void:
	position = base_pos
	rotation = base_rot
	_setup_viewmodel()

func _setup_viewmodel() -> void:
	var axe_scene: PackedScene = load("res://assets/scenes_3d/axe_1handed.tscn")
	if axe_scene:
		model_node = axe_scene.instantiate()
		model_node.name = "AxeMesh"
		model_node.scale = Vector3(0.45, 0.45, 0.45)
		model_node.rotation_degrees = Vector3(-10, 80, -20)
		add_child(model_node)

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)

func can_use() -> bool:
	return current_cooldown <= 0.0

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
	axe_swung.emit()

	# Звук замаха
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "axe_swing", -2.0)

	# Анимация удара
	_play_attack_animation()

	# Raycast попадания
	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * reach

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4
	query.exclude = [self, camera.owner]

	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		var hit_pos: Vector3 = hit.get("position", to)
		result["success"] = true
		result["hit_target"] = collider
		result["hit_point"] = hit_pos
		hit_landed.emit(collider, hit_pos)

		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "impact", 0.0)

		if has_node("/root/NoiseManager"):
			var nm: Node = get_node("/root/NoiseManager")
			nm.call("emit_noise", hit_pos, 14.0, self, "axe_hit")

		if collider is Node and (collider as Node).has_method("apply_stun"):
			(collider as Node).call("apply_stun", stun_duration)
			result["action"] = "stun_guard"
			LogManager.info("Топор: цель оглушена на %.1f с." % stun_duration, "Combat")
		elif collider is Node and (collider as Node).has_method("take_damage"):
			(collider as Node).call("take_damage", damage)
			result["action"] = "damage_object"
			LogManager.info("Топор: нанесён урон %.1f по %s." % [damage, (collider as Node).name], "Combat")
		elif collider is RigidBody3D:
			var push_dir := -camera.global_transform.basis.z.normalized()
			(collider as RigidBody3D).apply_central_impulse(push_dir * 22.0)
			result["action"] = "knockback"
		else:
			result["action"] = "hit_wall"

	return result

func _play_attack_animation() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	# Замах и удар
	tw.tween_property(self, "rotation", Vector3(deg_to_rad(-25), deg_to_rad(-40), deg_to_rad(-20)), 0.08)
	tw.tween_property(self, "position", base_pos + Vector3(0.04, 0.06, -0.08), 0.08)
	# Резкий рубящий выпад
	tw.tween_property(self, "rotation", Vector3(deg_to_rad(65), deg_to_rad(10), deg_to_rad(30)), 0.12)
	tw.tween_property(self, "position", base_pos + Vector3(-0.06, -0.12, -0.16), 0.12)
	# Возврат в исходную позицию
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rotation", base_rot, 0.22)
	tw.tween_property(self, "position", base_pos, 0.22)
