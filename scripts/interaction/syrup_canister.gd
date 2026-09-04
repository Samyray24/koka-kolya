class_name SyrupCanister
extends RigidBody3D

# Физическая канистра авторского концентрата «Кока-Коля Экстра-Шипучая»
# Вес: 15 кг. Используется для диверсии на заводе «Красная Линия».

signal canister_used()

var is_used: bool = false

func _ready() -> void:
	mass = 15.0
	collision_layer = 4 # Интерактивные объекты / AI / Захват
	collision_mask = 7 # Мир, Игрок, Объекты
	add_to_group("cargo")
	add_to_group("canister")

func inject_into_tower() -> void:
	if is_used:
		return
	is_used = true
	canister_used.emit()
	LogManager.info("Авторский концентрат успешно залит в главную сиропную башню!", "MISSION")
	
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(queue_free)