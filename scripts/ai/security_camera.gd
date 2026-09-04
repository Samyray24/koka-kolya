class_name SecurityCamera3D
extends Node3D

# Камера видеонаблюдения службы безопасности MERIDIAN
# Особенности: панорамное сканирование, визуальный световой конус,
# ослепление пеной (FoamLauncher), взлом (HackingTool) и вызов тревоги.

signal player_detected(pos: Vector3)
signal camera_hacked()
signal camera_blinded()

@export var scan_angle: float = 45.0 # Градусы отклонения
@export var scan_speed: float = 0.8
@export var detection_range: float = 14.0
@export var detection_fov: float = 65.0

var is_disabled: bool = false
var is_blinded: bool = false
var sweep_time: float = 0.0
var disable_timer: float = 0.0

@onready var head: Node3D = get_node_or_null("Head")
@onready var spot_light: SpotLight3D = get_node_or_null("Head/SpotLight3D")
@onready var lens_mesh: MeshInstance3D = get_node_or_null("Head/LensMesh")

func _ready() -> void:
	if not head:
		_create_procedural_nodes()
	_update_light_color(Color(0.2, 0.7, 1.0)) # Синий - режим сканирования

func _physics_process(delta: float) -> void:
	if is_disabled:
		disable_timer -= delta
		if disable_timer <= 0.0:
			is_disabled = false
			is_blinded = false
			_update_light_color(Color(0.2, 0.7, 1.0))
			LogManager.info("Камера наблюдения перезагрузилась и вернулась в строй.", "SECURITY")
		return

	if is_blinded:
		return

	# Панорамный поворот камеры
	sweep_time += delta * scan_speed
	var current_yaw := sin(sweep_time) * deg_to_rad(scan_angle)
	if head:
		head.rotation.y = current_yaw

	_scan_for_player()

func _scan_for_player() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player or not head:
		return

	var cam_pos := head.global_position
	var target_pos := player.global_position + Vector3(0, 1.0, 0)
	var to_player := target_pos - cam_pos
	var dist := to_player.length()

	if dist > detection_range:
		return

	# Проверка угла FOV
	var forward := -head.global_transform.basis.z.normalized()
	var angle := rad_to_deg(forward.angle_to(to_player.normalized()))
	if angle > (detection_fov * 0.5):
		return

	# RayCast прямая видимость
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(cam_pos, target_pos)
	query.collision_mask = 1 | 2 # Мир и Игрок
	query.exclude = [self]

	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") == player:
		_trigger_alarm(target_pos)

func _trigger_alarm(pos: Vector3) -> void:
	_update_light_color(Color(1.0, 0.1, 0.1)) # Красный - тревога
	player_detected.emit(pos)
	
	if has_node("/root/NoiseManager"):
		var nm: Node = get_node("/root/NoiseManager")
		nm.call("emit_noise", global_position, 22.0, self, "security_alarm")
	LogManager.warn("СИСТЕМА БЕЗОПАСНОСТИ: Камера обнаружила нарушителя в %s!" % pos, "SECURITY")

func hack_bypass() -> void:
	is_disabled = true
	disable_timer = 15.0
	_update_light_color(Color(0.2, 0.2, 0.2)) # Свет гаснет
	camera_hacked.emit()
	LogManager.info("Камера видеонаблюдения взломана и отключена на 15 секунд.", "SECURITY")

func blind_with_foam() -> void:
	is_blinded = true
	is_disabled = true
	disable_timer = 20.0
	_update_light_color(Color(0.95, 0.75, 0.15)) # Жёлтый (залеплена пеной)
	camera_blinded.emit()
	LogManager.info("Камера видеонаблюдения залеплена полимерной пеной BUBBLE-BLOC!", "SECURITY")

func take_damage(_amount: float) -> void:
	is_disabled = true
	disable_timer = 9999.0
	_update_light_color(Color(0.05, 0.05, 0.05))
	LogManager.info("Камера видеонаблюдения уничтожена электроударом.", "SECURITY")

func _update_light_color(col: Color) -> void:
	if spot_light:
		spot_light.light_color = col
		spot_light.light_energy = 3.0 if col != Color(0.2, 0.2, 0.2) else 0.0

func _create_procedural_nodes() -> void:
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.3, 0.2, 0.4)
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_mesh
	head.add_child(base_inst)

	var body := StaticBody3D.new()
	body.name = "CameraBody"
	body.collision_layer = 4
	body.collision_mask = 7
	var cshape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.4, 0.3, 0.5)
	cshape.shape = bshape
	body.add_child(cshape)
	head.add_child(body)
	
	spot_light = SpotLight3D.new()
	spot_light.name = "SpotLight3D"
	spot_light.spot_angle = detection_fov * 0.5
	spot_light.spot_range = detection_range
	spot_light.shadow_enabled = true
	spot_light.position = Vector3(0, 0, -0.2)
	head.add_child(spot_light)