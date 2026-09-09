class_name VendingMachine
extends Node3D

# Интерактивный торговый автомат «Кока-Коля» с детализированной объёмной 3D-моделью
# По нажатию [E] выдает банку газировки с честной физикой Jolt, восстанавливающей здоровье игрока.

signal soda_dispensed(player: Node)

@export var drink_cost: int = 0
@export var heals_amount: float = 25.0
@export var max_uses: int = 10
var remaining_uses: int = 10

const FLAVORS = [
	{
		"name": "Классика",
		"color": Color(0.9, 0.15, 0.2),
		"emission": Color(0.9, 0.1, 0.1),
		"heal": 25.0,
		"voice": "kolya_taste",
		"line": "Пшшш... Вот это свежесть, аж искры из глаз! Заряжен на все сто процентов!"
	},
	{
		"name": "Черри-Бунт",
		"color": Color(0.72, 0.08, 0.32),
		"emission": Color(0.85, 0.1, 0.4),
		"heal": 45.0,
		"voice": "kolya_cherry",
		"line": "О-о, Черри-Бунт! Вот это забористый вкус, теперь держитесь!"
	},
	{
		"name": "Неон-Лайм",
		"color": Color(0.15, 0.9, 0.35),
		"emission": Color(0.2, 1.0, 0.4),
		"heal": 20.0,
		"voice": "kolya_taste",
		"line": "Ух ты, Неон-Лайм! Кислинка пробивает до мурашек, полная перезагрузка!"
	}
]
var current_flavor_idx: int = 0

var interactable: Interactable = null
var dispenser_light: OmniLight3D = null

func _ready() -> void:
	remaining_uses = max_uses
	_build_visuals()
	_setup_interactable()

func _build_visuals() -> void:
	# 1. Основной корпус автомата
	var body_mesh := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.9, 1.8, 0.75)
	body_mesh.mesh = b_box
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.85, 0.12, 0.15) # Фирменный красный цвет Кока-Коли
	mat_body.roughness = 0.3
	mat_body.metallic = 0.5
	body_mesh.material_override = mat_body
	body_mesh.position = Vector3(0, 0.9, 0)
	add_child(body_mesh)

	# 2. Нижний стальной цоколь с ножками
	var plinth := MeshInstance3D.new()
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.94, 0.1, 0.78)
	plinth.mesh = p_box
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.18, 0.2, 0.22)
	mat_metal.metallic = 0.85
	mat_metal.roughness = 0.35
	plinth.material_override = mat_metal
	plinth.position = Vector3(0, 0.05, 0)
	add_child(plinth)

	# 3. Верхний световой козырёк
	var canopy := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(0.92, 0.16, 0.78)
	canopy.mesh = c_box
	canopy.material_override = mat_metal
	canopy.position = Vector3(0, 1.76, 0)
	add_child(canopy)

	# Светящаяся вывеска
	var sign_mesh := MeshInstance3D.new()
	var s_quad := QuadMesh.new()
	s_quad.size = Vector2(0.78, 0.35)
	sign_mesh.mesh = s_quad
	var mat_sign := StandardMaterial3D.new()
	mat_sign.albedo_color = Color(1.0, 0.95, 0.88)
	mat_sign.emission_enabled = true
	mat_sign.emission = Color(1.0, 0.88, 0.75)
	mat_sign.emission_energy_multiplier = 2.4
	sign_mesh.material_override = mat_sign
	sign_mesh.position = Vector3(0, 1.5, 0.38)
	add_child(sign_mesh)

	var label := Label3D.new()
	label.text = "★ КОКА-КОЛЯ ★\nЛЕДЯНАЯ"
	label.font_size = 20
	label.modulate = Color(0.85, 0.1, 0.15)
	label.position = Vector3(0, 1.5, 0.39)
	add_child(label)

	# 4. Утопленная витрина с защитным стеклом и видимыми 3D-банками
	var display_cavity := MeshInstance3D.new()
	var dc_mesh := BoxMesh.new()
	dc_mesh.size = Vector3(0.74, 0.65, 0.08)
	display_cavity.mesh = dc_mesh
	var mat_cavity := StandardMaterial3D.new()
	mat_cavity.albedo_color = Color(0.08, 0.08, 0.1)
	display_cavity.material_override = mat_cavity
	display_cavity.position = Vector3(0, 0.95, 0.36)
	add_child(display_cavity)

	# 3D-банки газировки на полочках витрины (3 вкуса: Классика, Черри-Бунт, Неон-Лайм)
	var mat_can_classic := StandardMaterial3D.new()
	mat_can_classic.albedo_color = Color(0.9, 0.15, 0.18)
	mat_can_classic.metallic = 0.8
	mat_can_classic.roughness = 0.2

	var mat_can_cherry := StandardMaterial3D.new()
	mat_can_cherry.albedo_color = Color(0.72, 0.08, 0.32)
	mat_can_cherry.metallic = 0.8
	mat_can_cherry.roughness = 0.2

	var mat_can_lime := StandardMaterial3D.new()
	mat_can_lime.albedo_color = Color(0.15, 0.9, 0.35)
	mat_can_lime.metallic = 0.8
	mat_can_lime.roughness = 0.2

	for row in range(2):
		for col_idx in range(4):
			var can_vis := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.04
			cyl.bottom_radius = 0.04
			cyl.height = 0.14
			can_vis.mesh = cyl
			if col_idx < 2:
				can_vis.material_override = mat_can_classic
			elif col_idx == 2:
				can_vis.material_override = mat_can_cherry
			else:
				can_vis.material_override = mat_can_lime
			var x_c := -0.24 + col_idx * 0.16
			var y_c := 0.8 + row * 0.24
			can_vis.position = Vector3(x_c, y_c, 0.35)
			add_child(can_vis)

	# Прозрачное фасадное стекло витрины
	var glass := MeshInstance3D.new()
	var g_quad := QuadMesh.new()
	g_quad.size = Vector2(0.76, 0.68)
	glass.mesh = g_quad
	var mat_glass := StandardMaterial3D.new()
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_glass.albedo_color = Color(0.7, 0.85, 1.0, 0.25)
	mat_glass.metallic = 0.95
	mat_glass.roughness = 0.05
	glass.material_override = mat_glass
	glass.position = Vector3(0, 0.95, 0.38)
	add_child(glass)

	# 5. Кнопочная консоль выбора товара (3 фирменных вкуса)
	var btn_glows := [Color(1.0, 0.2, 0.2), Color(0.95, 0.1, 0.5), Color(0.2, 1.0, 0.4)]
	for b_i in range(3):
		var btn := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.024
		bm.bottom_radius = 0.024
		bm.height = 0.03
		btn.mesh = bm
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = btn_glows[b_i]
		b_mat.emission_enabled = true
		b_mat.emission = btn_glows[b_i]
		b_mat.emission_energy_multiplier = 2.4
		btn.material_override = b_mat
		btn.rotation_degrees = Vector3(90, 0, 0)
		btn.position = Vector3(0.38, 1.05 - b_i * 0.1, 0.38)
		add_child(btn)

	# 6. Монетоприемник со стальной накладкой
	var coin_plate := MeshInstance3D.new()
	var cp_mesh := BoxMesh.new()
	cp_mesh.size = Vector3(0.08, 0.12, 0.02)
	coin_plate.mesh = cp_mesh
	coin_plate.material_override = mat_metal
	coin_plate.position = Vector3(0.38, 0.72, 0.38)
	add_child(coin_plate)

	# 7. Ниша лотка выдачи товара
	var slot := MeshInstance3D.new()
	var slot_mesh := BoxMesh.new()
	slot_mesh.size = Vector3(0.54, 0.32, 0.14)
	slot.mesh = slot_mesh
	var mat_slot := StandardMaterial3D.new()
	mat_slot.albedo_color = Color(0.06, 0.06, 0.08)
	slot.material_override = mat_slot
	slot.position = Vector3(0, 0.32, 0.34)
	add_child(slot)

	# Подсветка окна выдачи
	dispenser_light = OmniLight3D.new()
	dispenser_light.light_color = Color(1.0, 0.3, 0.3)
	dispenser_light.light_energy = 1.6
	dispenser_light.omni_range = 2.8
	dispenser_light.position = Vector3(0, 0.32, 0.48)
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
	_update_prompt()
	interactable.interacted.connect(_on_interacted)
	add_child(interactable)

func _update_prompt() -> void:
	if not interactable:
		return
	if remaining_uses <= 0:
		interactable.prompt_message = "Автомат пуст"
	else:
		var flv: Dictionary = FLAVORS[current_flavor_idx]
		interactable.prompt_message = "Взять банку «%s» [E] (+%.0f HP)" % [flv.name, flv.heal]

func _on_interacted(instigator: Node) -> void:
	if remaining_uses <= 0:
		_update_prompt()
		return

	var flavor: Dictionary = FLAVORS[current_flavor_idx]
	remaining_uses -= 1

	_play_dispense_sfx(flavor)
	_spawn_physics_can(flavor)

	var heal_amt: float = float(flavor.heal)
	if instigator and instigator.has_method("heal"):
		instigator.call("heal", heal_amt)

	soda_dispensed.emit(instigator)
	LogManager.info("Автомат выдал банку «%s»! Здоровье восстановлено на %.0f HP." % [flavor.name, heal_amt], "Interaction")

	# Переключение на следующий вкус в очереди
	current_flavor_idx = (current_flavor_idx + 1) % FLAVORS.size()
	_update_prompt()

func _play_dispense_sfx(flavor: Dictionary) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "can_pop_fizz", 2.0)

	if has_node("/root/VoiceManager"):
		var vm: Node = get_node("/root/VoiceManager")
		var voice_id: String = flavor.voice
		var voice_txt: String = flavor.line
		vm.call("speak_kolya", voice_id, voice_txt)

	if dispenser_light:
		dispenser_light.light_color = flavor.emission
		var tw := create_tween()
		tw.tween_property(dispenser_light, "light_energy", 4.2, 0.08)
		tw.tween_property(dispenser_light, "light_energy", 1.6, 0.28)

func _spawn_physics_can(flavor: Dictionary) -> void:
	var can := RigidBody3D.new()
	can.name = "SodaCan_%d_%s" % [remaining_uses, flavor.name]
	can.mass = 0.35
	can.continuous_cd = true
	can.linear_damp = 0.4
	can.angular_damp = 0.6
	can.collision_layer = 1 | 4
	can.collision_mask = 1 | 2 | 4

	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.55
	pmat.bounce = 0.22
	can.physics_material_override = pmat

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
	mat.albedo_color = flavor.color
	mat.metallic = 0.8
	mat.roughness = 0.22
	mat.emission_enabled = true
	mat.emission = flavor.emission
	mat.emission_energy_multiplier = 0.6
	c_mesh.mesh = cm
	c_mesh.material_override = mat
	can.add_child(c_mesh)

	var root_parent = get_parent() if get_parent() else get_tree().root
	if root_parent:
		root_parent.add_child(can)
		can.global_position = global_position + global_transform.basis * Vector3(0, 0.32, 0.55)
		can.apply_impulse(global_transform.basis.z * 2.0 + Vector3(0, 1.1, 0), Vector3(0.01, 0.04, 0.01))
		can.apply_torque_impulse(Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)))

