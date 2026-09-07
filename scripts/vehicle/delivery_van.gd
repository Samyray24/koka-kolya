class_name DeliveryVan
extends VehicleBody3D

# Фургон доставки «Кока-Коля» на Jolt Physics 3D (Section 11)
# Оснащен:
# - Честным открытым 3D-кузовом и умной системой фиксации ящиков (snap cargo)
# - Плавной динамической камерой слежения с поддержкой обзора мышью
# - Приборной панелью (спидометр, передача, индикатор груза)
# - Расчетом распределения массы груза и динамическим торможением

signal player_entered()
signal player_exited()
signal cargo_count_changed(count: int, max_count: int)

@export var max_engine_force: float = 420.0
@export var max_brake_force: float = 24.0
@export var max_steer_angle: float = 0.55 # ~31 градус

var is_driven: bool = false
var driver_passenger: CharacterBody3D = null
var current_cargo_mass: float = 0.0

# Слоты фиксации ящиков в кузове фургона (локальные координаты)
const CARGO_SLOTS: Array[Vector3] = [
	Vector3(-0.45, 0.58, 0.4),
	Vector3(0.45, 0.58, 0.4),
	Vector3(0.0, 0.58, 1.3)
]
var secured_crates: Array[RigidBody3D] = []

@onready var wheel_fl: VehicleWheel3D = get_node_or_null("WheelFL")
@onready var wheel_fr: VehicleWheel3D = get_node_or_null("WheelFR")
@onready var wheel_rl: VehicleWheel3D = get_node_or_null("WheelRL")
@onready var wheel_rr: VehicleWheel3D = get_node_or_null("WheelRR")
@onready var spring_arm: SpringArm3D = get_node_or_null("SpringArm3D")
@onready var chase_camera: Camera3D = get_node_or_null("SpringArm3D/ChaseCamera3D")
@onready var cargo_area: Area3D = get_node_or_null("CargoArea3D")
@onready var exit_marker: Marker3D = get_node_or_null("ExitMarker3D")
@onready var vehicle_radio: Node3D = get_node_or_null("VehicleRadio")
@onready var door_interactable: Node = get_node_or_null("DoorInteractable/Interactable")
@onready var interactable_node: Node = get_node_or_null("Interactable")

# Камера и обзор мышью
var cam_yaw: float = 0.0
var cam_pitch: float = -0.18
var base_cam_distance: float = 5.5
var current_speed_kmh: float = 0.0

# HUD приборной панели
var dashboard_canvas: CanvasLayer = null
var speed_label: Label = null
var gear_label: Label = null
var cargo_label: Label = null
var radio_label: Label = null

func _ready() -> void:
	add_to_group("vehicle")
	LogManager.info("Фургон доставки инициализирован. Масса шасси: %.1f кг" % mass, "VEHICLE")

	if door_interactable and door_interactable.has_signal("interacted"):
		door_interactable.connect("interacted", _on_door_interacted)
	if interactable_node and interactable_node.has_signal("interacted") and interactable_node != door_interactable:
		interactable_node.connect("interacted", _on_door_interacted)

	_build_dashboard_ui()

func _on_door_interacted(instigator: Node) -> void:
	if not is_driven and instigator is CharacterBody3D:
		enter_vehicle(instigator as CharacterBody3D)

func enter_vehicle(player: CharacterBody3D) -> void:
	is_driven = true
	driver_passenger = player
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED

	cam_yaw = 0.0
	cam_pitch = -0.18

	if chase_camera:
		chase_camera.make_current()

	if dashboard_canvas:
		dashboard_canvas.visible = true

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	LogManager.info("Коля сел за руль фургона доставки.", "VEHICLE")
	player_entered.emit()

func exit_vehicle() -> void:
	if not is_driven or not driver_passenger:
		return

	is_driven = false
	engine_force = 0.0
	brake = max_brake_force * 0.8
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

	if dashboard_canvas:
		dashboard_canvas.visible = false

	LogManager.info("Коля вышел из фургона.", "VEHICLE")
	player_exited.emit()
	driver_passenger = null

func _physics_process(delta: float) -> void:
	_update_cargo_mass()

	current_speed_kmh = linear_velocity.length() * 3.6

	if not is_driven:
		brake = move_toward(brake, 20.0, 15.0 * delta)
		engine_force = 0.0
		steering = 0.0
		return

	# Управление акселератором и рулем
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

	var is_handbrake := Input.is_action_pressed("crouch") or Input.is_action_pressed("jump")

	# Динамика с учетом массы груза
	var mass_penalty := clampf(1.0 - (current_cargo_mass / 500.0) * 0.35, 0.65, 1.0)
	engine_force = throttle * max_engine_force * mass_penalty

	var target_steer: float = steer_input * max_steer_angle
	# На высокой скорости чувствительность руля плавно уменьшается для стабильности
	var speed_steer_damping := clampf(1.0 - (current_speed_kmh / 80.0) * 0.4, 0.6, 1.0)
	steering = move_toward(steering, target_steer * speed_steer_damping, 3.2 * delta)

	# Логика торможения и реверса
	var forward_speed := -linear_velocity.dot(global_transform.basis.z)
	if is_handbrake:
		brake = max_brake_force * 2.5
	elif throttle < 0.0 and forward_speed > 0.8:
		# Нажатие "назад" на скорости тормозит машину
		brake = max_brake_force * 1.5
		engine_force = 0.0
	else:
		brake = 0.0

	# Плавное авто-центрирование камеры при движении вперед
	if absf(throttle) > 0.1 and current_speed_kmh > 2.0:
		cam_yaw = lerp_angle(cam_yaw, 0.0, 2.5 * delta)

	_update_chase_camera(delta)
	_update_dashboard_ui(throttle, forward_speed, is_handbrake)

	if Input.is_action_just_pressed("interact"):
		exit_vehicle()

func _input(event: InputEvent) -> void:
	if not is_driven:
		return

	# Обзор мышью во время вождения
	if event is InputEventMouseMotion:
		cam_yaw -= event.relative.x * 0.003
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.003, deg_to_rad(-45.0), deg_to_rad(15.0))

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if vehicle_radio and vehicle_radio.has_method("cycle_station"):
				vehicle_radio.call("cycle_station")
				_refresh_radio_text()

func _update_chase_camera(delta: float) -> void:
	if not spring_arm or not chase_camera:
		return

	spring_arm.rotation.y = cam_yaw
	spring_arm.rotation.x = cam_pitch

	# Динамическая дистанция и FOV от скорости
	var target_dist := base_cam_distance + clampf(current_speed_kmh * 0.04, 0.0, 2.5)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_dist, 5.0 * delta)

	var target_fov := 80.0 + clampf(current_speed_kmh * 0.25, 0.0, 15.0)
	chase_camera.fov = lerpf(chase_camera.fov, target_fov, 6.0 * delta)

func snap_crate(crate: RigidBody3D) -> bool:
	if not is_instance_valid(crate):
		return false
	if secured_crates.size() >= CARGO_SLOTS.size():
		return false
	if crate in secured_crates:
		return false

	var slot_idx: int = secured_crates.size()
	var slot_pos := CARGO_SLOTS[slot_idx]

	crate.freeze = true
	crate.reparent(self)
	crate.transform.origin = slot_pos
	crate.rotation = Vector3.ZERO
	crate.set("is_secured", true)
	secured_crates.append(crate)

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "grab", -1.0, 0.85)

	_update_cargo_mass()
	cargo_count_changed.emit(secured_crates.size(), CARGO_SLOTS.size())
	LogManager.info("Ящик закреплен в кузове фургона (Слот %d/%d)" % [secured_crates.size(), CARGO_SLOTS.size()], "VEHICLE")
	return true

func _update_cargo_mass() -> void:
	var total_cargo: float = 0.0
	for c in secured_crates:
		if is_instance_valid(c):
			total_cargo += c.mass

	if cargo_area:
		var bodies := cargo_area.get_overlapping_bodies()
		for b in bodies:
			if b is RigidBody3D and b != self and not (b in secured_crates):
				total_cargo += (b as RigidBody3D).mass

	current_cargo_mass = total_cargo

func get_cargo_crates() -> Array[RigidBody3D]:
	var crates: Array[RigidBody3D] = []
	for c in secured_crates:
		if is_instance_valid(c) and not (c in crates):
			crates.append(c)

	if cargo_area:
		for b in cargo_area.get_overlapping_bodies():
			if b is RigidBody3D and b != self and (b.name.begins_with("ColaCrate") or b.is_in_group("cargo")):
				if not (b in crates):
					crates.append(b as RigidBody3D)

	return crates

func _build_dashboard_ui() -> void:
	dashboard_canvas = CanvasLayer.new()
	dashboard_canvas.name = "DashboardHUD"
	dashboard_canvas.visible = false
	add_child(dashboard_canvas)

	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 24.0
	panel.offset_top = -140.0
	panel.offset_right = 320.0
	panel.offset_bottom = -24.0
	dashboard_canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var hbox_top := HBoxContainer.new()
	vbox.add_child(hbox_top)

	speed_label = Label.new()
	speed_label.text = "0 КМ/Ч"
	speed_label.add_theme_font_size_override("font_size", 28)
	speed_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hbox_top.add_child(speed_label)

	gear_label = Label.new()
	gear_label.text = " [P]"
	gear_label.add_theme_font_size_override("font_size", 24)
	gear_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	hbox_top.add_child(gear_label)

	cargo_label = Label.new()
	cargo_label.text = "Груз: 0/3 ящиков (0.0 кг)"
	cargo_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(cargo_label)

	radio_label = Label.new()
	radio_label.text = "Радио: ВЫКЛ [R]"
	radio_label.add_theme_font_size_override("font_size", 13)
	radio_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(radio_label)

	var hint := Label.new()
	hint.text = "[W/S] Газ/Тормоз | [A/D] Руль | [Space] Ручник | [E] Выйти"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(hint)

func _update_dashboard_ui(_throttle: float, forward_speed: float, is_handbrake: bool) -> void:
	if not dashboard_canvas or not dashboard_canvas.visible:
		return

	if speed_label:
		speed_label.text = "%d КМ/Ч" % int(round(current_speed_kmh))

	if gear_label:
		if is_handbrake or (current_speed_kmh < 1.0 and _throttle == 0.0):
			gear_label.text = " [P]"
			gear_label.modulate = Color(1.0, 0.4, 0.4)
		elif forward_speed < -0.5:
			gear_label.text = " [R]"
			gear_label.modulate = Color(1.0, 0.7, 0.2)
		else:
			gear_label.text = " [D]"
			gear_label.modulate = Color(0.2, 0.9, 1.0)

	if cargo_label:
		cargo_label.text = "Груз: %d/3 ящиков (%.1f кг)" % [get_cargo_crates().size(), current_cargo_mass]

func _refresh_radio_text() -> void:
	if not radio_label:
		return
	if vehicle_radio and vehicle_radio.has_method("get_current_station_name"):
		var st_name: String = str(vehicle_radio.call("get_current_station_name"))
		radio_label.text = "Радио: %s [R]" % st_name
		radio_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
