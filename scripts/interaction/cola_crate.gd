class_name ColaCrate
extends RigidBody3D

# Физический деревянный ящик с бутылками «Кока-Коля» для погрузки в фургон

@export var crate_id: int = 1
@export var is_secured: bool = false

func _ready() -> void:
	mass = 12.0
	collision_layer = 4 # Объекты / AI / Захват
	collision_mask = 7 # Мир, Игрок, Объекты
	add_to_group("cargo")
	
	# Настройка физического трения для кузова
	var mat := PhysicsMaterial.new()
	mat.friction = 0.85
	mat.rough = true
	physics_material_override = mat