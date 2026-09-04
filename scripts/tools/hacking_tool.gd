class_name HackingTool
extends Node3D

# Портативная кибер-дека радиоэлектронного взлома и подавления
# Позволяет удаленно взламывать замки дверей, отключать камеры и терминалы на расстоянии.

signal hack_started(target: Node3D)
signal hack_completed(target: Node3D, target_name: String)
signal hack_failed(reason: String)

@export var tool_name: String = "Кибер-дека взлома"
@export var max_range: float = 22.0
@export var cooldown: float = 0.5
@export var energy_cost: float = 20.0

var current_cooldown: float = 0.0
var energy: float = 100.0
var max_energy: float = 100.0

@onready var mesh_root: Node3D = get_node_or_null("MeshRoot")
var screen_mat: StandardMaterial3D = null

func _ready() -> void:
	if not mesh_root:
		_create_procedural_mesh()

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)
	# Регенерация энергии
	energy = minf(max_energy, energy + 12.0 * delta)

func can_use() -> bool:
	return current_cooldown <= 0.0 and energy >= energy_cost

func use(camera: Camera3D) -> Dictionary:
	var result := {
		"success": false,
		"target": null,
		"action": "none"
	}
	
	if not can_use() or not camera:
		return result
		
	current_cooldown = cooldown
	
	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * max_range
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4 | 8
	query.exclude = [self, camera.owner]
	
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		hack_failed.emit("В зоне видимости нет электронных целей")
		return result
		
	var collider: Object = hit.get("collider")
	if not (collider is Node):
		hack_failed.emit("Цель не является узлом системы")
		return result
		
	var node := collider as Node
	var target_handled: bool = false
	
	energy -= energy_cost
	hack_started.emit(node as Node3D)
	_pulse_screen_color(Color(0.2, 1.0, 0.4))

	if has_node("/root/AudioManager"):
		var audio_mgr: Node = get_node("/root/AudioManager")
		audio_mgr.call("play_sfx", "hack", -3.0)
	
	# 1. Проверка на дверь или узел с unlock_and_open
	var target_door: Node = null
	if node.has_method("unlock_and_open"):
		target_door = node
	elif node.get_parent() and node.get_parent().has_method("unlock_and_open"):
		target_door = node.get_parent()
		
	if target_door:
		target_door.call("unlock_and_open")
		result["success"] = true
		result["target"] = target_door
		result["action"] = "door_unlocked"
		target_handled = true
		LogManager.info("Взломщик: защищенный замок двери взломан!", "Hacking")
	elif node.has_node("Interactable"):
		var interactable: Node = node.get_node("Interactable")
		if interactable and interactable.has_method("trigger_interaction"):
			interactable.call("trigger_interaction", camera.owner)
			result["success"] = true
			result["target"] = node
			result["action"] = "interactable_bypassed"
			target_handled = true
			LogManager.info("Взломщик: терминал активирован удаленно.", "Hacking")

	# 2. Проверка на охранника — создание ложного акустического шума в радиостанции
	if not target_handled and node.has_method("apply_stun"):
		node.call("apply_stun", 3.5)
		result["success"] = true
		result["target"] = node
		result["action"] = "guard_glitched"
		target_handled = true
		LogManager.info("Взломщик: интерфейс шлема охранника перегружен помехами!", "Hacking")

	# 3. Общая проверка на электронный узел (hack_bypass)
	var target_bypass: Node = null
	if node.has_method("hack_bypass"):
		target_bypass = node
	elif node.get_parent() and node.get_parent().has_method("hack_bypass"):
		target_bypass = node.get_parent()

	if not target_handled and target_bypass:
		target_bypass.call("hack_bypass")
		result["success"] = true
		result["target"] = target_bypass
		result["action"] = "custom_bypass"
		target_handled = true
		LogManager.info("Взломщик: протокол обхода выполнен на узле %s." % target_bypass.name, "Hacking")

	if target_handled:
		hack_completed.emit(node as Node3D, node.name)
		if has_node("/root/NoiseManager"):
			var noise_mgr: Node = get_node("/root/NoiseManager")
			noise_mgr.call("emit_noise", hit.get("position", to), 5.0, self, "hack_signal")
	else:
		hack_failed.emit("Устройство не поддается дешифровке")
		_pulse_screen_color(Color(1.0, 0.2, 0.2))
		
	return result

func _pulse_screen_color(target_color: Color) -> void:
	if not screen_mat:
		return
	var tw := create_tween()
	tw.tween_property(screen_mat, "emission", target_color, 0.08)
	tw.tween_property(screen_mat, "emission", Color(0.1, 0.8, 0.9), 0.35)

func _create_procedural_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)
	
	# Корпус коммуникатора / деки
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.12, 0.04, 0.18)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.15, 0.16, 0.18)
	body_mat.roughness = 0.5
	body_mat.metallic = 0.8
	var body_inst := MeshInstance3D.new()
	body_inst.mesh = body_mesh
	body_inst.material_override = body_mat
	mesh_root.add_child(body_inst)
	
	# Экран со свечением
	var scr_mesh := PlaneMesh.new()
	scr_mesh.size = Vector2(0.09, 0.13)
	screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.05, 0.1, 0.15)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.1, 0.8, 0.9)
	screen_mat.emission_energy_multiplier = 2.0
	var scr_inst := MeshInstance3D.new()
	scr_inst.mesh = scr_mesh
	scr_inst.material_override = screen_mat
	scr_inst.position = Vector3(0, 0.021, 0)
	mesh_root.add_child(scr_inst)
	
	# Антенна
	var ant_mesh := CylinderMesh.new()
	ant_mesh.top_radius = 0.003
	ant_mesh.bottom_radius = 0.005
	ant_mesh.height = 0.12
	var ant_inst := MeshInstance3D.new()
	ant_inst.mesh = ant_mesh
	ant_inst.position = Vector3(0.045, 0.05, -0.07)
	mesh_root.add_child(ant_inst)
