class_name PhysicsGrabber
extends Node3D

# Система физического захвата и взаимодействия от первого лица
# Позволяет брать, переносить и бросать RigidBody3D, а также активировать Interactable

signal prompt_updated(prompt_text: String)

@export var max_reach_distance: float = 3.0
@export var grab_spring_force: float = 24.0
@export var grab_damping: float = 4.5
@export var throw_impulse: float = 8.5
@export var max_grab_mass: float = 40.0

@onready var raycast: RayCast3D = $RayCast3D
@onready var hold_point: Marker3D = $HoldPoint

var held_body: RigidBody3D = null
var original_angular_damp: float = 0.0

func _physics_process(delta: float) -> void:
	if held_body:
		_process_held_body(delta)
		prompt_updated.emit("Удерживать: [E] — Бросить / [ЛКМ] — Сильный бросок")
	else:
		_process_raycast()

func _process_raycast() -> void:
	if not raycast.is_colliding():
		prompt_updated.emit("")
		return

	var collider: Object = raycast.get_collider()
	if collider is RigidBody3D:
		var rb := collider as RigidBody3D
		if rb.mass <= max_grab_mass:
			prompt_updated.emit("Нажмите [E] чтобы поднять (Масса: %.1f кг)" % rb.mass)
		else:
			prompt_updated.emit("Слишком тяжелый объект (%.1f кг)" % rb.mass)
	elif collider is Node:
		var interactable: Node = _find_interactable(collider as Node)
		if interactable:
			var msg: String = String(interactable.get("prompt_message")) if "prompt_message" in interactable else "Использовать"
			prompt_updated.emit("Нажмите [E] — %s" % msg)
		else:
			prompt_updated.emit("")
	else:
		prompt_updated.emit("")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("interact"):
		if held_body:
			drop_object()
		else:
			try_interact_or_grab()
	elif event.is_action_just_pressed("ui_accept") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		if held_body:
			throw_object()

func _find_interactable(target: Node) -> Node:
	if not target:
		return null
	if target.has_node("Interactable"):
		return target.get_node("Interactable")
	var p: Node = target.get_parent()
	if p and p.has_node("Interactable"):
		return p.get_node("Interactable")
	return null

func try_interact_or_grab() -> void:
	if not raycast.is_colliding():
		return

	var collider: Object = raycast.get_collider()
	if collider is RigidBody3D:
		var rb := collider as RigidBody3D
		if rb.mass <= max_grab_mass:
			grab_object(rb)
	elif collider is Node:
		var interactable: Node = _find_interactable(collider as Node)
		if interactable and interactable.has_method("trigger_interaction"):
			interactable.call("trigger_interaction", owner)

func grab_object(rb: RigidBody3D) -> void:
	held_body = rb
	original_angular_damp = rb.angular_damp
	rb.angular_damp = 12.0

func drop_object() -> void:
	if not held_body:
		return
	held_body.angular_damp = original_angular_damp
	held_body = null
	prompt_updated.emit("")

func throw_object() -> void:
	if not held_body:
		return
	var forward := -global_transform.basis.z.normalized()
	held_body.angular_damp = original_angular_damp
	held_body.apply_central_impulse(forward * throw_impulse)
	held_body = null
	prompt_updated.emit("")

func _process_held_body(_delta: float) -> void:
	if not is_instance_valid(held_body):
		held_body = null
		return

	var target_pos := hold_point.global_position
	var curr_pos := held_body.global_position
	var dist_vec := target_pos - curr_pos

	# Если предмет слишком далеко (застрял за стеной), отпустить его
	if dist_vec.length() > max_reach_distance * 1.5:
		drop_object()
		return

	# Пружинно-демпфированная сила удержания для Jolt Physics
	var desired_vel := dist_vec * grab_spring_force
	held_body.linear_velocity = held_body.linear_velocity.lerp(desired_vel, 0.4)
