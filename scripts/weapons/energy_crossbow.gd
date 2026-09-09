class_name EnergyCrossbow
extends Node3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# Бесшумный энергетический арбалет Спецназа Сопротивления
# Стреляет высокоскоростными плазменными болтами с повышенным уроном

signal crossbow_fired()
signal bolt_hit(target: Node, point: Vector3)

@export var tool_name: String = "Энергетический арбалет"
@export var damage: float = 85.0
@export var range_distance: float = 80.0
@export var cooldown: float = 0.75
@export var max_ammo: int = 12
@export var ammo: int = 12

var current_cooldown: float = 0.0
var base_pos: Vector3 = Vector3(0.24, -0.22, -0.42)
var base_rot: Vector3 = Vector3(0, 0, 0)
var model_node: Node3D = null
var muzzle_light: OmniLight3D = null
var muzzle_offset: Vector3 = Vector3(0, 0.05, -0.5)

func _ready() -> void:
	position = base_pos
	rotation = base_rot
	_setup_viewmodel()
	_setup_muzzle_flash()

func _setup_viewmodel() -> void:
	var scene_res: PackedScene = load("res://assets/scenes_3d/crossbow_1handed.tscn")
	if scene_res:
		model_node = scene_res.instantiate()
		model_node.name = "CrossbowMesh"
		model_node.scale = Vector3(0.25, 0.25, 0.25)
		model_node.rotation_degrees = Vector3(0, 180, 0)
		add_child(model_node)

func _setup_muzzle_flash() -> void:
	muzzle_light = OmniLight3D.new()
	muzzle_light.name = "CrossbowGlow"
	muzzle_light.light_color = Color(0.2, 0.9, 1.0)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 3.5
	muzzle_light.position = muzzle_offset
	add_child(muzzle_light)

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)

func can_use() -> bool:
	return current_cooldown <= 0.0 and ammo > 0

func reload() -> void:
	ammo = max_ammo
	LogManager.info("Арбалет перезаряжен: %d/%d" % [ammo, max_ammo], "Weapons")

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
	crossbow_fired.emit()

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "laser_shot", 1.5)

	_trigger_flash()
	_play_recoil()

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
		result["action"] = "hit"

		var push_dir: Vector3 = -camera.global_transform.basis.z.normalized()
		ImpactFX.spawn_sparks(get_tree().root, hit_pos, push_dir, 18)

		if collider and collider.has_method("take_damage"):
			collider.call("take_damage", damage, push_dir, 38.0, hit_pos)

		if collider is RigidBody3D:
			var rb := collider as RigidBody3D
			var local_contact: Vector3 = hit_pos - rb.global_position
			rb.apply_impulse(push_dir * 42.0, local_contact)
		else:
			var hit_norm: Vector3 = hit.get("normal", -push_dir)
			var root_node = get_tree().root if get_tree() else get_parent()
			if root_node:
				ImpactFX.spawn_bullet_scorch(root_node, hit_pos, hit_norm)
				ImpactFX.spawn_dust(root_node, hit_pos, 6)

		bolt_hit.emit(collider, hit_pos)

	_spawn_bolt_tracer(camera.global_position + camera.global_transform.basis * muzzle_offset, end_point)
	return result

func _trigger_flash() -> void:
	if not muzzle_light:
		return
	muzzle_light.light_energy = 3.0
	var tw := create_tween()
	tw.tween_property(muzzle_light, "light_energy", 0.0, 0.12)

func _play_recoil() -> void:
	var tw := create_tween()
	var kick_pos := base_pos + Vector3(0, 0.04, 0.12)
	var kick_rot := base_rot + Vector3(deg_to_rad(-12.0), 0, 0)
	tw.tween_property(self, "position", kick_pos, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "rotation", kick_rot, 0.06)
	tw.tween_property(self, "position", base_pos, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "rotation", base_rot, 0.28)

func _spawn_bolt_tracer(start_pos: Vector3, end_pos: Vector3) -> void:
	var root_node := get_tree().current_scene
	if not root_node:
		return

	var tracer := MeshInstance3D.new()
	var length: float = start_pos.distance_to(end_pos)
	if length < 0.1:
		return

	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.02
	c_mesh.bottom_radius = 0.02
	c_mesh.height = length

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.95, 1.0, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 1.0)
	mat.emission_energy_multiplier = 4.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c_mesh.material = mat
	tracer.mesh = c_mesh

	tracer.position = (start_pos + end_pos) * 0.5
	tracer.look_at(end_pos, Vector3.UP)
	tracer.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	root_node.add_child(tracer)

	var tw := tracer.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.15)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, 0.15)
	tw.tween_callback(tracer.queue_free)
