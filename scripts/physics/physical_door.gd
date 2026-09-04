class_name PhysicalDoor
extends Node3D

# Физическая дверь на HingeJoint3D с ручкой Interactable для Jolt Physics

signal door_opened()
signal door_closed()

@export var open_impulse: float = 6.0
@export var is_locked: bool = false

@onready var door_leaf: RigidBody3D = get_node_or_null("DoorLeaf")
@onready var hinge: HingeJoint3D = get_node_or_null("HingeJoint3D")
@onready var handle_interactable: Node = get_node_or_null("DoorLeaf/Handle/Interactable")

var is_open: bool = false

func _ready() -> void:
	if handle_interactable:
		handle_interactable.connect("interacted", _on_handle_interacted)

func _on_handle_interacted(instigator: Node) -> void:
	if is_locked:
		LogManager.info("Дверь заперта на электронный замок.", "DOOR")
		return

	var push_direction: float = 1.0
	if instigator is Node3D:
		var to_instigator: Vector3 = (instigator as Node3D).global_position - door_leaf.global_position
		# Определение с какой стороны стоит персонаж, чтобы толкать дверь ОТ него
		var local_dir: Vector3 = door_leaf.global_transform.basis.inverse() * to_instigator
		if local_dir.z > 0:
			push_direction = -1.0

	door_leaf.apply_torque_impulse(Vector3(0, push_direction * open_impulse, 0))
	is_open = not is_open
	if is_open:
		door_opened.emit()
	else:
		door_closed.emit()
	LogManager.debug("Дверь активирована (импульс: %.1f)" % (push_direction * open_impulse), "DOOR")

func unlock_and_open() -> void:
	is_locked = false
	if door_leaf:
		door_leaf.apply_torque_impulse(Vector3(0, open_impulse, 0))
	is_open = true
	door_opened.emit()
	LogManager.info("Дверь взломана и открыта.", "DOOR")

func hack_bypass() -> void:
	unlock_and_open()

