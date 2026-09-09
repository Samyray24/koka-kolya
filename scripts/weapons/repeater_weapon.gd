class_name RepeaterWeapon
extends Node3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# Скорострельный автоматический импульсный репитер
# Тяжёлое штурмовое плазменное оружие с высокой скорострельностью, оранжевым трассером и отдачей.

signal repeater_fired()
signal hit_landed(target: Node, point: Vector3)

@export var tool_name: String = "Импульсный репитер"
@export var damage: float = 22.0
@export var range_distance: float = 70.0
@export var cooldown: float = 0.11
@export var max_ammo: int = 45
@export var ammo: int = 45

var current_cooldown: float = 0.0
var base_pos: Vector3 = Vector3(0.25, -0.22, -0.40)
var base_rot: Vector3 = Vector3(0, 0, 0)
var model_node: Node3D = null
var muzzle_light: OmniLight3D = null
var muzzle_offset: Vector3 = Vector3(0, 0.09, -0.52)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	position = base_pos
	rotation = base_rot
	_setup_viewmodel()
	_setup_muzzle_flash()

func _setup_viewmodel() -> void:
	var repeater_scene: PackedScene = load("res://assets/scenes_3d/blaster-repeater.tscn")
	if repeater_scene:
		model_node = repeater_scene.instantiate()
		model_node.name = "RepeaterMesh"
		model_node.scale = Vector3(0.28, 0.28, 0.28)
		model_node.rotation_degrees = Vector3(0, 180, 0)
		add_child(model_node)

func _setup_muzzle_flash() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "RepeaterMuzzleFlash"
	muzzle_light.light_color = Color(1.0, 0.65, 0.2) # Огненно-оранжевый
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 4.5
	muzzle_light.position = muzzle_offset
	add_child(muzzle_light)

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)

func can_use() -> bool:
	return current_cooldown <= 0.0 and ammo > 0

func reload() -> void:
	ammo = max_ammo
	LogManager.info("Репитер перезаряжен: %d/%d" % [ammo, max_ammo], "Weapons")

func use(camera: Camera3D) -> Dictionary:
	var result := {
		"success": false,
		"hit_target": null,
		"hit_point": Vector3.ZERO,
		"action": "miss"
	}

	if not can_use() or not camera:
		if ammo <= 0:
			reload()
		return result

	ammo -= 1
	current_cooldown = cooldown
	repeater_fired.emit()

	# Аудио скорострельного выстрела
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "repeater_shot", -2.0)

	# Вспышка и отдача
	_trigger_muzzle_flash()
	_play_rapid_recoil()

	# Небольшой разброс автоматической очереди
	var spread_x := rng.randf_range(-0.018, 0.018)
	var spread_y := rng.randf_range(-0.018, 0.018)
	var forward_dir := (-camera.global_transform.basis.z + camera.global_transform.basis.x * spread_x + camera.global_transform.basis.y * spread_y).normalized()

	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from + forward_dir * range_distance

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4
	query.exclude = [self, camera.owner]

	var hit := space_state.intersect_ray(query)
	var end_point: Vector3 = to

	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		var hit_pos: Vector3 = hit.get("position", to)
		end_point = hit_pos
		result["success"] = true
		result["hit_target"] = collider
		result["hit_point"] = hit_pos
		hit_landed.emit(collider, hit_pos)

		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "impact", -2.5)

		if has_node("/root/NoiseManager"):
			var nm: Node = get_node("/root/NoiseManager")
			nm.call("emit_noise", hit_pos, 25.0, self, "repeater_shot")

		var push_dir := forward_dir
		ImpactFX.spawn_sparks(get_tree().root, hit_pos, push_dir, 10)

		if collider is Node and (collider as Node).has_method("take_damage"):
			(collider as Node).call("take_damage", damage, push_dir, 16.0, hit_pos)
			result["action"] = "damage_enemy"
		elif collider is Node and (collider as Node).has_method("apply_stun"):
			(collider as Node).call("apply_stun", 1.8)
			result["action"] = "stun_guard"

		if collider is RigidBody3D:
			var rb := collider as RigidBody3D
			var local_contact: Vector3 = hit_pos - rb.global_position
			rb.apply_impulse(push_dir * 16.0, local_contact)
			result["action"] = "knockback"
		else:
			result["action"] = "hit_wall"

	_spawn_tracer(global_position + global_transform.basis * muzzle_offset, end_point)

	return result

func _trigger_muzzle_flash() -> void:
	if not muzzle_light:
		return
	muzzle_light.light_energy = 4.0
	var tw := create_tween()
	tw.tween_property(muzzle_light, "light_energy", 0.0, 0.04)

func _play_rapid_recoil() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	var jitter_x := rng.randf_range(-0.005, 0.005)
	var jitter_rot := rng.randf_range(-0.03, 0.03)
	tw.tween_property(self, "position", base_pos + Vector3(jitter_x, 0.015, 0.05), 0.02)
	tw.parallel().tween_property(self, "rotation", base_rot + Vector3(deg_to_rad(4), jitter_rot, 0), 0.02)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", base_pos, 0.08)
	tw.parallel().tween_property(self, "rotation", base_rot, 0.08)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var root_node := get_tree().current_scene if get_tree() else get_parent()
	if not root_node:
		return

	var tracer := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	tracer.mesh = immediate_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.25, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.15)
	mat.emission_energy_multiplier = 4.5
	tracer.material_override = mat

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()

	root_node.add_child(tracer)

	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.06)
	tw.tween_callback(tracer.queue_free)
