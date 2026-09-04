class_name DeliveryVan
extends VehicleBody3D

# Фургон доставки «Кока-Коля» на Jolt Physics 3D (Section 11)
# Поддерживает посадку/высадку, честную физику 4 колес, ручник,
# расчет массы груза в кузове и влияние на управляемость фургона.

signal player_entered()
signal player_exited()

@export var max_engine_force: float = 380.0
@export var max_brake_force: float = 18.0
@export var max_steer_angle: float = 0.55 # ~31 градус

var is_driven: bool = false
var driver_passenger: CharacterBody3D = null
var current_cargo_mass: float = 0.0

@onready var wheel_fl: VehicleWheel3D = get_node_or_null("WheelFL")
@onready var wheel_fr: VehicleWheel3D = get_node_or_null("WheelFR")
@onready var wheel_rl: VehicleWheel3D = get_node_or_null("WheelRL")
@onready var wheel_rr: VehicleWheel3D = get_node_or_null("WheelRR")
@onready var chase_camera: Camera3D = get_node_or_null("SpringArm3D/ChaseCamera3D")
@onready var cargo_area: Area3D = get_node_or_null("CargoArea3D")
@onready var exit_marker: Marker3D = get_node_or_null("ExitMarker3D")
@onready var door_interactable: Node = get_node_or_null("DoorInteractable/Interactable")

func _ready() -> void:
	LogManager.info("Фургон доставки инициализирован. Масса шасси: %.1f кг" % mass, "VEHICLE")
	if door_interactable and door_interactable.has_signal("interacted"):
		door_interactable.connect("interacted", _on_door_interacted)

func _on_door_interacted(instigator: Node) -> void:
	if not is_driven and instigator is CharacterBody3D:
		enter_vehicle(instigator as CharacterBody3D)

func enter_vehicle(player: CharacterBody3D) -> void:
	is_driven = true
	driver_passenger = player
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED

	if chase_camera:
		chase_camera.make_current()

	LogManager.info("Коля сел за руль фургона доставки.", "VEHICLE")
	player_entered.emit()

func exit_vehicle() -> void:
	if not is_driven or not driver_passenger:
		return

	is_driven = false
	engine_force = 0.0
	brake = max_brake_force * 0.5
	steering = 0.0

	var exit_pos := global_position + (global_transform.basis * Vector3(-2.2, 0.5, 0.0))
	if exit_marker:
		exit_pos = exit_marker.global_position

	driver_passenger.global_position = exit_pos
	driver_passenger.visible = true
	driver_passenger.process_mode = Node.PROCESS_MODE_INHERIT

	var p_cam: Camera3D = driver_passenger.get_node_or_null("Head/Camera3D") as Camera3D
	if p_cam:
		p_cam.make_current()

	LogManager.info("Коля вышел из фургона.", "VEHICLE")
	player_exited.emit()
	driver_passenger = null

func _physics_process(delta: float) -> void:
	_update_cargo_mass()

	if not is_driven:
		# Автоматический тормоз на парковке
		brake = move_toward(brake, 15.0, 10.0 * delta)
		engine_force = 0.0
		steering = 0.0
		return

	# Управление автомобилем
	var throttle := 0.0
	if Input.is_action_pressed("move_forward"):
		throttle += 1.0
	if Input.is_action_pressed("move_backward"):
		throttle -= 1.0

	var steer_input := 0.0
	if Input.is_action_pressed("move_left"):
		steer_input += 1.0
	if Input.is_action_pressed("move_right"):
		steer_input -= 1.0

	# Ручной тормоз
	var is_handbrake := Input.is_action_pressed("crouch") or Input.is_action_pressed("jump")

	# Динамика разгона и поворота с учетом массы груза
	var mass_penalty := clampf(1.0 - (current_cargo_mass / 500.0) * 0.35, 0.65, 1.0)
	engine_force = throttle * max_engine_force * mass_penalty

	var target_steer: float = steer_input * max_steer_angle
	steering = move_toward(steering, target_steer, 2.5 * delta)

	if is_handbrake:
		brake = max_brake_force * 2.0
	elif throttle < 0.0 and linear_velocity.dot(-global_transform.basis.z) > 0.5:
		brake = max_brake_force
	else:
		brake = 0.0

	if Input.is_action_just_pressed("interact"):
		exit_vehicle()

func _update_cargo_mass() -> void:
	if not cargo_area:
		return
	var total_cargo: float = 0.0
	var bodies := cargo_area.get_overlapping_bodies()
	for b in bodies:
		if b is RigidBody3D and b != self:
			total_cargo += (b as RigidBody3D).mass
	current_cargo_mass = total_cargo

func get_cargo_crates() -> Array[RigidBody3D]:
	var crates: Array[RigidBody3D] = []
	if not cargo_area:
		return crates
	for b in cargo_area.get_overlapping_bodies():
		if b is RigidBody3D and b != self and (b.name.begins_with("ColaCrate") or b.is_in_group("cargo")):
			crates.append(b as RigidBody3D)
	return crates

