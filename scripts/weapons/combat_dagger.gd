class_name CombatDagger
extends Node3D

# Тактический боевой кинжал скрытого проникновения
# Бесшумное холодное оружие с высоким критическим уроном со спины

signal dagger_swung()
signal dagger_hit(target: Node, damage_dealt: float)

@export var tool_name: String = "Тактический кинжал"
@export var base_damage: float = 55.0
@export var backstab_damage: float = 130.0
@export var attack_range: float = 2.4
@export var cooldown: float = 0.35

var current_cooldown: float = 0.0
var base_pos: Vector3 = Vector3(0.22, -0.24, -0.38)
var base_rot: Vector3 = Vector3(deg_to_rad(10), deg_to_rad(-15), deg_to_rad(5))
var model_node: Node3D = null
var is_swinging: bool = false

func _ready() -> void:
	position = base_pos
	rotation = base_rot
	_setup_viewmodel()

func _setup_viewmodel() -> void:
	var scene_res: PackedScene = load("res://assets/scenes_3d/dagger.tscn")
	if scene_res:
		model_node = scene_res.instantiate()
		model_node.name = "DaggerMesh"
		model_node.scale = Vector3(0.26, 0.26, 0.26)
		model_node.rotation_degrees = Vector3(0, 180, 0)
		add_child(model_node)

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)

func can_use() -> bool:
	return current_cooldown <= 0.0 and not is_swinging

func use(camera: Camera3D) -> Dictionary:
	var result := {
		"success": false,
		"hit_target": null,
		"damage": 0.0,
		"action": "slash_miss"
	}

	if not can_use() or not camera:
		return result

	current_cooldown = cooldown
	is_swinging = true
	dagger_swung.emit()

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "axe_swing", 3.0)

	_play_slash_animation()

	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * attack_range

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4
	query.exclude = [self, camera.owner]

	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		var hit_pos: Vector3 = hit.get("position", to)

		result["success"] = true
		result["hit_target"] = collider
		result["action"] = "slash_hit"

		var applied_dmg := base_damage
		if collider is Node3D:
			var target_forward: Vector3 = -(collider as Node3D).global_transform.basis.z
			var attack_dir: Vector3 = -camera.global_transform.basis.z
			if attack_dir.dot(target_forward) > 0.4:
				applied_dmg = backstab_damage
				LogManager.info("КРИТИЧЕСКИЙ УДАР СО СПИНЫ! Урон: %.1f" % applied_dmg, "Combat")

		result["damage"] = applied_dmg

		if collider and collider.has_method("take_damage"):
			collider.call("take_damage", applied_dmg)
		elif collider is RigidBody3D:
			var push_dir: Vector3 = -camera.global_transform.basis.z
			(collider as RigidBody3D).apply_central_impulse(push_dir * 12.0)

		dagger_hit.emit(collider, applied_dmg)

	return result

func _play_slash_animation() -> void:
	var tw := create_tween()
	var strike_pos := base_pos + Vector3(-0.15, 0.08, -0.22)
	var strike_rot := base_rot + Vector3(deg_to_rad(-45.0), deg_to_rad(30.0), deg_to_rad(-60.0))

	tw.tween_property(self, "position", strike_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "rotation", strike_rot, 0.08)
	tw.tween_property(self, "position", base_pos, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "rotation", base_rot, 0.18)
	tw.tween_callback(func() -> void: is_swinging = false)
