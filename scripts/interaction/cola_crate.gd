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

func unstrap() -> void:
	if not is_secured:
		return
	is_secured = false
	freeze = false
	var p := get_parent()
	if p is DeliveryVan:
		var van := p as DeliveryVan
		if self in van.secured_crates:
			van.secured_crates.erase(self)
		if van.get_parent():
			reparent(van.get_parent())
		van._update_cargo_mass()
