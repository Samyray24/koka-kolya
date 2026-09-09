class_name BlasterWeapon
extends Node3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# Высокоточный плазменный бластер Сопротивления
# Полуавтоматическое энергетическое оружие со световым трассером, вспышкой и отдачей.

signal blaster_fired()
signal hit_landed(target: Node, point: Vector3)

@export var tool_name: String = "Плазменный бластер"
@export var damage: float = 40.0
@export var range_distance: float = 65.0
@export var cooldown: float = 0.32
@export var max_ammo: int = 24
@export var ammo: int = 24

var current_cooldown: float = 0.0
var base_pos: Vector3 = Vector3(0.24, -0.22, -0.42)
var base_rot: Vector3 = Vector3(0, 0, 0)
var model_node: Node3D = null
var muzzle_light: OmniLight3D = null
var muzzle_offset: Vector3 = Vector3(0, 0.08, -0.45)

func _ready() -> void:
	position = base_pos
	rotation = base_rot
	_setup_viewmodel()
	_setup_muzzle_flash()

func _setup_viewmodel() -> void:
	var blaster_scene: PackedScene = load("res://assets/scenes_3d/blaster.tscn")
	if blaster_scene:
		model_node = blaster_scene.instantiate()
		model_node.name = "BlasterMesh"
		model_node.scale = Vector3(0.28, 0.28, 0.28)
		# Вращение модели, чтобы ствол смотрел строго вперёд (-Z)
		model_node.rotation_degrees = Vector3(0, 180, 0)
		add_child(model_node)

func _setup_muzzle_flash() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "MuzzleFlash"
	muzzle_light.light_color = Color(0.15, 0.85, 1.0) # Неоновый циан
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 4.0
	muzzle_light.position = muzzle_offset
	add_child(muzzle_light)

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)

func can_use() -> bool:
	return current_cooldown <= 0.0 and ammo > 0

func reload() -> void:
	ammo = max_ammo
	LogManager.info("Бластер перезаряжен: %d/%d" % [ammo, max_ammo], "Weapons")

func use(camera: Camera3D) -> Dictionary:
	var result := {
		"success": false,
		"hit_target": null,
		"hit_point": Vector3.ZERO,
		"action": "miss"
	}

	if not can_use() or not camera:
		if ammo <= 0:
			reload() # Автоподзарядка плазменного накопителя
		return result

	ammo -= 1
	current_cooldown = cooldown
	blaster_fired.emit()

	# Аудио выстрела
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "laser_shot", -1.0)

	# Вспышка и отдача
	_trigger_muzzle_flash()
	_play_recoil_animation()

	# Физический Raycast луча
	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * range_distance

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
			am.call("play_sfx", "impact", -1.5)

		if has_node("/root/NoiseManager"):
			var nm: Node = get_node("/root/NoiseManager")
			nm.call("emit_noise", hit_pos, 22.0, self, "blaster_shot")

		var push_dir := -camera.global_transform.basis.z.normalized()
		ImpactFX.spawn_sparks(get_tree().root, hit_pos, push_dir, 12)

		if collider is Node and (collider as Node).has_method("take_damage"):
			(collider as Node).call("take_damage", damage, push_dir, 20.0, hit_pos)
			result["action"] = "damage_enemy"
		elif collider is Node and (collider as Node).has_method("apply_stun"):
			(collider as Node).call("apply_stun", 3.0)
			result["action"] = "stun_guard"

		if collider is RigidBody3D:
			var rb := collider as RigidBody3D
			var local_contact: Vector3 = hit_pos - rb.global_position
			rb.apply_impulse(push_dir * 22.0, local_contact)
			result["action"] = "knockback"
		else:
			result["action"] = "hit_wall"
			var hit_norm: Vector3 = hit.get("normal", -push_dir)
			var root_node = get_tree().root if get_tree() else get_parent()
			if root_node:
				ImpactFX.spawn_bullet_scorch(root_node, hit_pos, hit_norm)
				ImpactFX.spawn_dust(root_node, hit_pos, 5)

	# Трассер выстрела
	_spawn_tracer(global_position + global_transform.basis * muzzle_offset, end_point)

	return result

func _trigger_muzzle_flash() -> void:
	if not muzzle_light:
		return
	muzzle_light.light_energy = 3.5
	var tw := create_tween()
	tw.tween_property(muzzle_light, "light_energy", 0.0, 0.06)

func _play_recoil_animation() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	# Резкий откат назад и подброс ствола вверх
	tw.tween_property(self, "position", base_pos + Vector3(0.0, 0.02, 0.07), 0.04)
	tw.parallel().tween_property(self, "rotation", base_rot + Vector3(deg_to_rad(7), 0, 0), 0.04)
	# Возврат
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "position", base_pos, 0.16)
	tw.parallel().tween_property(self, "rotation", base_rot, 0.16)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var root_node := get_tree().current_scene if get_tree() else get_parent()
	if not root_node:
		return

	var tracer := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	tracer.mesh = immediate_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.9, 1.0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 4.0
	tracer.material_override = mat

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()

	root_node.add_child(tracer)

	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.08)
	tw.tween_callback(tracer.queue_free)
