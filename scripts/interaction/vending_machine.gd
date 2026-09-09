class_name VendingMachine
extends Node3D

# Интерактивный торговый автомат «Кока-Коля»
# По нажатию [E] выдает банку газировки, восстанавливающей здоровье игрока.

signal soda_dispensed(player: Node)

@export var drink_cost: int = 0 # Бесплатно для борцов сопротивления
@export var heals_amount: float = 25.0
@export var max_uses: int = 10
var remaining_uses: int = 10

var interactable: Interactable = null
var dispenser_light: OmniLight3D = null

func _ready() -> void:
	remaining_uses = max_uses
	_build_visuals()
	_setup_interactable()

func _build_visuals() -> void:
	# Корпус автомата
	var body_mesh := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.9, 1.8, 0.75)
	body_mesh.mesh = b_box
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.85, 0.12, 0.15) # Фирменный красный цвет Кока-Коли
	mat_body.roughness = 0.35
	mat_body.metallic = 0.4
	body_mesh.material_override = mat_body
	body_mesh.position = Vector3(0, 0.9, 0)
	add_child(body_mesh)

	# Светящаяся вывеска
	var sign_mesh := MeshInstance3D.new()
	var s_quad := QuadMesh.new()
	s_quad.size = Vector2(0.7, 0.6)
	sign_mesh.mesh = s_quad
	var mat_sign := StandardMaterial3D.new()
	mat_sign.albedo_color = Color(1.0, 0.9, 0.8)
	mat_sign.emission_enabled = true
	mat_sign.emission = Color(1.0, 0.85, 0.75)
	mat_sign.emission_energy_multiplier = 2.0
	sign_mesh.material_override = mat_sign
	sign_mesh.position = Vector3(0, 1.35, 0.38)
	add_child(sign_mesh)

	var label := Label3D.new()
	label.text = "КОКА-КОЛЯ\nЛЕДЯНАЯ"
	label.font_size = 18
	label.modulate = Color(0.85, 0.1, 0.15)
	label.position = Vector3(0, 1.35, 0.39)
	add_child(label)

	# Окно выдачи товара
	var slot := MeshInstance3D.new()
	var slot_mesh := BoxMesh.new()
	slot_mesh.size = Vector3(0.5, 0.3, 0.1)
	slot.mesh = slot_mesh
	var mat_slot := StandardMaterial3D.new()
	mat_slot.albedo_color = Color(0.1, 0.1, 0.12)
	slot.material_override = mat_slot
	slot.position = Vector3(0, 0.3, 0.35)
	add_child(slot)

	# Подсветка окна
	dispenser_light = OmniLight3D.new()
	dispenser_light.light_color = Color(1.0, 0.3, 0.3)
	dispenser_light.light_energy = 1.2
	dispenser_light.omni_range = 2.5
	dispenser_light.position = Vector3(0, 0.3, 0.45)
	add_child(dispenser_light)

	# Статический коллайдер для физики
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(0.9, 1.8, 0.75)
	col.shape = col_shape
	col.position = Vector3(0, 0.9, 0)
	sb.add_child(col)
	add_child(sb)

func _setup_interactable() -> void:
	interactable = Interactable.new()
	interactable.prompt_message = "Взять банку «Кока-Коля» [E]"
	interactable.interacted.connect(_on_interacted)
	add_child(interactable)

func _on_interacted(instigator: Node) -> void:
	if remaining_uses <= 0:
		if interactable:
			interactable.prompt_message = "Автомат пуст"
		return

	remaining_uses -= 1
	_play_dispense_sfx()
	_spawn_physics_can()

	if instigator and instigator.has_method("heal"):
		instigator.call("heal", heals_amount)

	soda_dispensed.emit(instigator)
	LogManager.info("Автомат выдал банку «Кока-Коля»! Здоровье восстановлено на %.0f HP." % heals_amount, "Interaction")

func _play_dispense_sfx() -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", -4.0)

func _spawn_physics_can() -> void:
	var can := RigidBody3D.new()
	can.name = "SodaCan_%d" % remaining_uses
	can.mass = 0.35
	can.collision_layer = 1 | 4
	can.collision_mask = 1 | 2 | 4

	var c_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.07
	cyl.height = 0.18
	c_shape.shape = cyl
	can.add_child(c_shape)

	var c_mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.07
	cm.height = 0.18
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.15, 0.2)
	mat.metallic = 0.7
	mat.roughness = 0.25
	c_mesh.mesh = cm
	c_mesh.material_override = mat
	can.add_child(c_mesh)

	can.position = global_position + Vector3(0, 0.3, 0.55)
	get_parent().add_child(can)
	can.apply_central_impulse(global_transform.basis.z * 1.5 + Vector3(0, 0.8, 0))
