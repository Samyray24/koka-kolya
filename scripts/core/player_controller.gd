class_name PlayerController
extends CharacterBody3D

# First-Person Character Controller for «Кока-Коля»
# Features: Плавная кинестетика, присед (Crouch), покачивание головы (Headbob),
# наклон камеры при стрейфах, амортизация приземления, динамический FOV и отзывчивый HUD.

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 7.5
@export var crouch_speed: float = 2.4
@export var jump_velocity: float = 5.2
@export var mouse_sensitivity: float = 0.0025
@export var gamepad_look_sensitivity: float = 2.5
@export var push_force: float = 2.2

# Camera & Head
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var inventory_label: Label = get_node_or_null("HUD/InventoryLabel")
@onready var crosshair: ColorRect = get_node_or_null("HUD/Crosshair")
@onready var grabber: Node3D = $Head/Camera3D/PhysicsGrabber
@onready var inventory_manager: Node = get_node_or_null("InventoryManager")

# Physics state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var mouse_captured: bool = true

# Crouch state
var is_crouching: bool = false
const STAND_HEIGHT: float = 1.65
const CROUCH_HEIGHT: float = 1.05
const STAND_CAPSULE_HEIGHT: float = 1.8
const CROUCH_CAPSULE_HEIGHT: float = 1.0

# Headbob & Camera tilt
var bob_timer: float = 0.0
var landing_dip: float = 0.0
var base_fov: float = 85.0

# Input buffering & Coyote time
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
const COYOTE_TIME: float = 0.15
const JUMP_BUFFER_TIME: float = 0.12

var was_on_floor: bool = true
var footstep_distance: float = 0.0
const FOOTSTEP_INTERVAL: float = 2.2

func _ready() -> void:
	capture_mouse(true)
	if camera:
		base_fov = camera.fov

	if grabber and prompt_label and grabber.has_signal("prompt_updated"):
		grabber.connect("prompt_updated", func(txt: String) -> void:
			prompt_label.text = txt
		)

	if grabber and grabber.has_signal("target_state_changed"):
		grabber.connect("target_state_changed", _on_target_state_changed)

	if inventory_manager:
		inventory_manager.call("setup", self, camera, grabber)
		if inventory_label:
			inventory_manager.connect("slot_changed", func(slot_idx: int, slot_name: String) -> void:
				inventory_label.text = "Слот [%d]: %s" % [slot_idx + 1, slot_name]
			)

func _on_target_state_changed(state: String) -> void:
	if not crosshair:
		return
	match state:
		"grabbable":
			crosshair.color = Color(1.0, 0.85, 0.2, 0.95)
			crosshair.size = Vector2(8, 8)
			crosshair.position = (crosshair.get_viewport_rect().size * 0.5) - Vector2(4, 4)
		"interactable", "vehicle":
			crosshair.color = Color(0.2, 0.9, 1.0, 0.95)
			crosshair.size = Vector2(8, 8)
			crosshair.position = (crosshair.get_viewport_rect().size * 0.5) - Vector2(4, 4)
		"cargo_snap":
			crosshair.color = Color(0.3, 1.0, 0.4, 1.0)
			crosshair.size = Vector2(10, 10)
			crosshair.position = (crosshair.get_viewport_rect().size * 0.5) - Vector2(5, 5)
		"holding":
			crosshair.color = Color(1.0, 0.5, 0.2, 0.9)
			crosshair.size = Vector2(6, 6)
			crosshair.position = (crosshair.get_viewport_rect().size * 0.5) - Vector2(3, 3)
		_:
			crosshair.color = Color(1, 1, 1, 0.75)
			crosshair.size = Vector2(4, 4)
			crosshair.position = (crosshair.get_viewport_rect().size * 0.5) - Vector2(2, 2)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		# Если игрок не вращает удерживаемый предмет правой кнопкой мыши
		var is_rotating_item := false
		if grabber and grabber.get("is_rotating_held") == true:
			is_rotating_item = true

		if not is_rotating_item:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))

	if event is InputEventMouseButton and event.pressed:
		if not mouse_captured:
			capture_mouse(true)

	if event.is_action_just_pressed("ui_cancel"):
		capture_mouse(not mouse_captured)

func capture_mouse(captured: bool) -> void:
	mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	# 1. Присед (Crouch)
	is_crouching = Input.is_action_pressed("crouch")
	var target_head_y := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	head.position.y = lerpf(head.position.y, target_head_y + landing_dip, 14.0 * delta)

	# Плавная амортизация приземления
	landing_dip = lerpf(landing_dip, 0.0, 10.0 * delta)

	# Настройка коллизии капсулы под присед
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var cap := collision_shape.shape as CapsuleShape3D
		var target_h := CROUCH_CAPSULE_HEIGHT if is_crouching else STAND_CAPSULE_HEIGHT
		cap.height = lerpf(cap.height, target_h, 12.0 * delta)
		collision_shape.position.y = cap.height * 0.5

	# 2. Гравитация и проверка касания земли
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		if not was_on_floor:
			landing_dip = -0.14
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				am.call("play_sfx", "land", -5.0)
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		velocity.y -= gravity * delta
	was_on_floor = is_on_floor()

	# 3. Прыжок с буферизацией ввода
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and not is_crouching:
		velocity.y = jump_velocity
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "jump", -4.0)

	# 4. Геймпад
	if mouse_captured:
		var look_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var look_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if absf(look_x) > 0.15 or absf(look_y) > 0.15:
			rotate_y(-look_x * gamepad_look_sensitivity * delta)
			head.rotate_x(-look_y * gamepad_look_sensitivity * delta)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))

	# 5. Вектор движения и скорости
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting := Input.is_action_pressed("sprint") and not is_crouching and input_dir.y < -0.1
	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed

	var accel := 32.0 if is_on_floor() else 14.0
	if direction.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 36.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 36.0 * delta)

	# 6. Физическое перемещение
	move_and_slide()

	# 7. Физическое расталкивание легких RigidBody3D
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			var rb := collider as RigidBody3D
			# Не толкаем предмет, если сами его сейчас держим
			if grabber and grabber.get("held_body") == rb:
				continue
			var push_dir := -collision.get_normal()
			push_dir.y = 0.0
			push_dir = push_dir.normalized()
			rb.apply_central_impulse(push_dir * push_force)

	# 8. Headbob (покачивание головы при ходьбе) и наклон камеры
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		var bob_speed := 10.0 if is_sprinting else 7.0
		bob_timer += delta * bob_speed
		var bob_x := cos(bob_timer * 0.5) * (0.025 if is_sprinting else 0.015)
		var bob_y := sin(bob_timer) * (0.035 if is_sprinting else 0.02)
		camera.position.x = lerpf(camera.position.x, bob_x, 14.0 * delta)
		camera.position.y = lerpf(camera.position.y, bob_y, 14.0 * delta)

		# Звуки шагов (в приседе в 2 раза тише и реже)
		var interval := FOOTSTEP_INTERVAL * 1.6 if is_crouching else FOOTSTEP_INTERVAL
		footstep_distance += horizontal_speed * delta
		if footstep_distance >= interval:
			footstep_distance = 0.0
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				var vol := -18.0 if is_crouching else -9.0
				am.call("play_sfx", "footstep", vol, randf_range(0.9, 1.1))
	else:
		camera.position.x = lerpf(camera.position.x, 0.0, 10.0 * delta)
		camera.position.y = lerpf(camera.position.y, 0.0, 10.0 * delta)
		footstep_distance = minf(footstep_distance, FOOTSTEP_INTERVAL * 0.5)

	# 9. Наклон камеры при стрейфах (Roll tilt)
	var target_tilt := -input_dir.x * deg_to_rad(1.8)
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, 8.0 * delta)

	# 10. Динамический FOV
	var target_fov := base_fov
	if is_sprinting and direction.length_squared() > 0.01:
		target_fov = base_fov + 8.0
	elif is_crouching:
		target_fov = base_fov - 5.0
	camera.fov = lerpf(camera.fov, target_fov, 8.0 * delta)
