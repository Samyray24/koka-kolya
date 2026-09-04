class_name ConveyorBelt
extends AnimatableBody3D

# Физический конвейер завода «Красная Линия» на Jolt Physics 3D
# Перемещает тела за счет constant_linear_velocity на физическом тике

@export var belt_speed: float = 2.4
@export var belt_direction: Vector3 = Vector3(0, 0, -1)

func _ready() -> void:
	sync_to_physics = true
	var dir_norm := belt_direction.normalized()
	constant_linear_velocity = dir_norm * belt_speed
	LogManager.debug("Конвейер запущен со скоростью %.1f м/с" % belt_speed, "CONVEYOR")
