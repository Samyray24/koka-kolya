class_name FoamLauncher
extends Node3D

# Распылитель быстротвердеющей полимерной пены «BUBBLE-BLOC»
# Создаёт физические твёрдые блоки в пространстве Jolt 3D.
# Применение: подъём на высоту, блокировка дверей/вентиляций, создание укрытий.

signal foam_fired(hit_point: Vector3)
signal foam_block_spawned(block: Node3D)

@export var tool_name: String = "Пенный распылитель"
@export var projectile_speed: float = 30.0
@export var max_range: float = 35.0
@export var block_size: Vector3 = Vector3(0.8, 0.8, 0.8)
@export var block_lifetime: float = 20.0
@export var max_active_blocks: int = 16
@export var cooldown: float = 0.35
@export var max_ammo: int = 24

var current_cooldown: float = 0.0
var ammo: int = 24
var active_blocks: Array[Node3D] = []

@onready var mesh_root: Node3D = get_node_or_null("MeshRoot")

func _ready() -> void:
	if not mesh_root:
		_create_procedural_mesh()

func _process(delta: float) -> void:
	if current_cooldown > 0.0:
		current_cooldown = maxf(0.0, current_cooldown - delta)

func can_use() -> bool:
	return current_cooldown <= 0.0 and ammo > 0

func use(camera: Camera3D) -> Dictionary:
	var result := {
		"success": false,
		"hit_point": Vector3.ZERO,
		"block": null
	}
	
	if not can_use() or not camera:
		return result
		
	current_cooldown = cooldown
	ammo -= 1
	
	_play_recoil_animation()
	
	var space_state := camera.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * max_range
	
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4 # Мир, Статика, Двери
	query.exclude = [self, camera.owner]
	
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit.get("position", to)
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		
		# Смещение блока от нормали поверхности, чтобы блок не застрял внутри геометрии
		var spawn_pos := hit_pos + normal * (block_size.y * 0.45)
		
		var scene_target: Node = camera.get_tree().current_scene if camera.get_tree().current_scene else camera.get_tree().root; var block := _spawn_foam_block(spawn_pos, scene_target)
		result["success"] = true
		result["hit_point"] = hit_pos
		result["block"] = block
		
		foam_fired.emit(hit_pos)
		foam_block_spawned.emit(block)
		
		if has_node("/root/NoiseManager"):
			var noise_mgr: Node = get_node("/root/NoiseManager")
			noise_mgr.call("emit_noise", hit_pos, 6.0, self, "foam_impact")
			
		LogManager.info("Пена выпущена: блок создан в %s. Осталось зарядов: %d" % [spawn_pos, ammo], "Tools")
	else:
		LogManager.info("Пена улетела в пустоту. Осталось зарядов: %d" % ammo, "Tools")
		
	return result

func _spawn_foam_block(pos: Vector3, parent_scene: Node) -> StaticBody3D:
	# Ограничение количества блоков (FIFO)
	while active_blocks.size() >= max_active_blocks:
		var oldest: Node3D = active_blocks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
			
	var body := StaticBody3D.new()
	body.name = "FoamBlock_%d" % Time.get_ticks_msec()
	body.collision_layer = 1 # Мировая коллизия
	body.collision_mask = 0
	
	# Форма коллизии
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = block_size
	col.shape = box_shape
	body.add_child(col)
	
	# Меш пены
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = block_size
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.15) # Ярко-жёлтая полимерная пена
	mat.roughness = 0.85
	mat.metallic = 0.05
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)
	
	# Сначала добавляем в дерево сцены, затем выставляем global_position!
	parent_scene.add_child(body)
	body.global_position = pos
	active_blocks.append(body)
	
	# Таймер растворения пены
	var timer := body.get_tree().create_timer(block_lifetime)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(body):
			active_blocks.erase(body)
			var tw := body.create_tween()
			tw.tween_property(body, "scale", Vector3.ZERO, 0.4)
			tw.tween_callback(body.queue_free)
	)
	
	return body

func _play_recoil_animation() -> void:
	if not mesh_root:
		return
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(mesh_root, "position:z", 0.08, 0.08)
	tween.tween_property(mesh_root, "position:z", 0.0, 0.18)

func _create_procedural_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)
	
	# Баллон для состава
	var canister_mesh := CylinderMesh.new()
	canister_mesh.top_radius = 0.04
	canister_mesh.bottom_radius = 0.04
	canister_mesh.height = 0.28
	var canister_mat := StandardMaterial3D.new()
	canister_mat.albedo_color = Color(0.92, 0.65, 0.12)
	canister_mat.metallic = 0.7
	canister_mat.roughness = 0.3
	var canister_inst := MeshInstance3D.new()
	canister_inst.mesh = canister_mesh
	canister_inst.material_override = canister_mat
	canister_inst.rotation.x = deg_to_rad(90.0)
	mesh_root.add_child(canister_inst)
	
	# Сопло распылителя
	var nozzle_mesh := CylinderMesh.new()
	nozzle_mesh.top_radius = 0.02
	nozzle_mesh.bottom_radius = 0.035
	nozzle_mesh.height = 0.1
	var nozzle_mat := StandardMaterial3D.new()
	nozzle_mat.albedo_color = Color(0.18, 0.18, 0.2)
	nozzle_mat.metallic = 0.9
	var nozzle_inst := MeshInstance3D.new()
	nozzle_inst.mesh = nozzle_mesh
	nozzle_inst.material_override = nozzle_mat
	nozzle_inst.rotation.x = deg_to_rad(90.0)
	nozzle_inst.position = Vector3(0, 0, -0.18)
	mesh_root.add_child(nozzle_inst)
