class_name BubbleDrone
extends CharacterBody3D

# Дрон-компаньон BUBBLE для «Кока-Коля» (Section 10 & 15)
# Поддерживает режимы: FOLLOW (автономное следование), REMOTE_CONTROL (ручной полет 6-DOF),
# FLASHLIGHT (фонарь), SCANNER (сканер проводки/терминалов), TETHER (магнитный луч).

signal mode_changed(new_mode: DroneMode)
signal scan_triggered(detected_objects_count: int)

enum DroneMode { FOLLOW, REMOTE_CONTROL }

@export var follow_speed: float = 6.0
@export var rc_speed: float = 7.5
@export var hover_bob_amplitude: float = 0.08
@export var hover_bob_frequency: float = 2.2

var current_mode: DroneMode = DroneMode.FOLLOW
var target_follow_node: Node3D = null
var follow_offset: Vector3 = Vector3(0.5, 0.05, -1.6)
var bob_timer: float = 0.0

var is_flashlight_on: bool = false
var is_scanning: bool = false
var held_object: RigidBody3D = null

@onready var drone_camera: Camera3D = get_node_or_null("DroneCamera3D")
@onready var flashlight: SpotLight3D = get_node_or_null("SpotLight3D")
@onready var scanner_area: Area3D = get_node_or_null("ScannerArea3D")
@onready var tether_point: Marker3D = get_node_or_null("TetherPoint")

func _ready() -> void:
	LogManager.info("Дрон BUBBLE инициализирован. Режим: FOLLOW", "BUBBLE")

func set_follow_target(target: Node3D) -> void:
	target_follow_node = target

func toggle_remote_control() -> void:
	if current_mode == DroneMode.FOLLOW:
		current_mode = DroneMode.REMOTE_CONTROL
		if drone_camera:
			drone_camera.make_current()
		LogManager.info("BUBBLE: переход в режим ручного пилотирования (RC).", "BUBBLE")
	else:
		current_mode = DroneMode.FOLLOW
		if target_follow_node:
			var cam: Camera3D = target_follow_node.get_node_or_null("Camera3D") as Camera3D
			if cam: cam.make_current()
		LogManager.info("BUBBLE: возврат в режим следования (FOLLOW).", "BUBBLE")
	mode_changed.emit(current_mode)

func toggle_flashlight() -> void:
	is_flashlight_on = not is_flashlight_on
	if flashlight:
		flashlight.visible = is_flashlight_on
	LogManager.debug("BUBBLE: фонарь %s" % ("включен" if is_flashlight_on else "выключен"), "BUBBLE")

func trigger_scanner() -> int:
	var detected := 0
	if scanner_area:
		var bodies: Array[Node3D] = scanner_area.get_overlapping_bodies()
		for b in bodies:
			if b.is_in_group("scannable") or b.is_in_group("electronic"):
				detected += 1
	LogManager.info("BUBBLE: сканирование завершено. Найдено объектов: %d" % detected, "BUBBLE")
	scan_triggered.emit(detected)
	return detected

func _physics_process(delta: float) -> void:
	bob_timer += delta

	match current_mode:
		DroneMode.FOLLOW:
			_process_follow(delta)
		DroneMode.REMOTE_CONTROL:
			_process_remote_control(delta)

	_process_tether()
	move_and_slide()

func _process_follow(delta: float) -> void:
	if not target_follow_node:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var p: Node3D = players[0] as Node3D
			if p.has_node("Head"):
				target_follow_node = p.get_node("Head") as Node3D
			else:
				target_follow_node = p
		else:
			return

	var bob_y: float = sin(bob_timer * hover_bob_frequency) * hover_bob_amplitude
	var target_pos: Vector3 = target_follow_node.global_position + (target_follow_node.global_transform.basis * follow_offset)
	target_pos.y += bob_y

	var to_target: Vector3 = target_pos - global_position
	var dist: float = to_target.length()

	if dist > 0.05:
		var desired_vel: Vector3 = to_target.normalized() * minf(dist * follow_speed, follow_speed * 1.5)
		velocity = velocity.lerp(desired_vel, 8.0 * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, 6.0 * delta)

	# Плавный поворот в сторону взгляда игрока
	var look_target: Vector3 = target_follow_node.global_position + (-target_follow_node.global_transform.basis.z * 10.0)
	var dir_flat := (look_target - global_position)
	dir_flat.y = 0.0
	if dir_flat.length_squared() > 0.01:
		var target_yaw := atan2(-dir_flat.x, -dir_flat.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)

func _process_remote_control(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var vertical: float = 0.0
	if Input.is_action_pressed("jump"):
		vertical += 1.0
	if Input.is_action_pressed("crouch"):
		vertical -= 1.0

	var move_dir := (transform.basis * Vector3(input_vec.x, vertical, input_vec.y)).normalized()
	if move_dir.length_squared() > 0.01:
		velocity = velocity.lerp(move_dir * rc_speed, 12.0 * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, 10.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B: # Переключение дрона
			toggle_remote_control()
		elif event.keycode == KEY_F: # Фонарь
			toggle_flashlight()
		elif event.keycode == KEY_V: # Сканер
			trigger_scanner()

	# Вращение камеры дрона в RC-режиме
	if current_mode == DroneMode.REMOTE_CONTROL and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.003)
		if drone_camera:
			drone_camera.rotate_x(-event.relative.y * 0.003)
			drone_camera.rotation.x = clampf(drone_camera.rotation.x, deg_to_rad(-75.0), deg_to_rad(75.0))

func _process_tether() -> void:
	if held_object and tether_point:
		var target_pos := tether_point.global_position
		var to_pos := target_pos - held_object.global_position
		held_object.linear_velocity = held_object.linear_velocity.lerp(to_pos * 18.0, 0.35)
