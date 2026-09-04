class_name PlayerController
extends CharacterBody3D

# First-Person Character Controller for «Кока-Коля»
# Features: Jolt 3D Physics compatibility, Coyote time, Jump buffering, Gamepad + Mouse/KB input.

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 7.5
@export var jump_velocity: float = 5.2
@export var mouse_sensitivity: float = 0.0025
@export var gamepad_look_sensitivity: float = 2.5
@export var push_force: float = 1.8

# Camera & Head
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var inventory_label: Label = get_node_or_null("HUD/InventoryLabel")
@onready var grabber: Node3D = $Head/Camera3D/PhysicsGrabber
@onready var inventory_manager: Node = get_node_or_null("InventoryManager")

# Physics state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var mouse_captured: bool = true

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
	if grabber and prompt_label and grabber.has_signal("prompt_updated"):
		grabber.connect("prompt_updated", func(txt: String) -> void:
			prompt_label.text = txt
		)
	if inventory_manager:
		inventory_manager.call("setup", self, camera, grabber)
		if inventory_label:
			inventory_manager.connect("slot_changed", func(slot_idx: int, slot_name: String) -> void:
				inventory_label.text = "Слот [%d]: %s" % [slot_idx + 1, slot_name]
			)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
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
	# 1. Gravity and Grounding
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		if not was_on_floor:
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				am.call("play_sfx", "land", -6.0)
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		velocity.y -= gravity * delta
	was_on_floor = is_on_floor()

	# 2. Jump input buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "jump", -4.0)

	# Footsteps audio
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		footstep_distance += horizontal_speed * delta
		if footstep_distance >= FOOTSTEP_INTERVAL:
			footstep_distance = 0.0
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				am.call("play_sfx", "footstep", -10.0, randf_range(0.9, 1.1))
	else:
		footstep_distance = minf(footstep_distance, FOOTSTEP_INTERVAL * 0.5)

	# 3. Gamepad look handling
	if mouse_captured:
		var look_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var look_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if absf(look_x) > 0.15 or absf(look_y) > 0.15:
			rotate_y(-look_x * gamepad_look_sensitivity * delta)
			head.rotate_x(-look_y * gamepad_look_sensitivity * delta)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))

	# 4. Movement vector
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting := Input.is_action_pressed("sprint")
	var target_speed := sprint_speed if is_sprinting else walk_speed

	if direction.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, 28.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, 28.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 32.0 * delta)

	# 5. Move and slide with Jolt contact processing
	move_and_slide()

	# 6. Physical interaction: push RigidBody3D objects
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			var push_dir := -collision.get_normal()
			push_dir.y = 0.0
			push_dir = push_dir.normalized()
			collider.apply_central_impulse(push_dir * push_force)
