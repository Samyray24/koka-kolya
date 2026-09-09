class_name LootContainer
extends Node3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# Детализированный армейский контейнер снабжения с объёмными уголками, ручками и замком
signal container_opened(loot_data: Dictionary)

@export var container_title: String = "Ящик снабжения"
@export var credits_reward: int = 50
@export var is_locked: bool = false
@export var is_opened: bool = false

var lid_node: Node3D = null
var interactable: Interactable = null
var lock_indicator: MeshInstance3D = null

func _ready() -> void:
	_build_visuals()
	_setup_interactable()

func _build_visuals() -> void:
	var mat_base := StandardMaterial3D.new()
	mat_base.albedo_color = Color(0.24, 0.27, 0.3)
	mat_base.roughness = 0.55
	mat_base.metallic = 0.6

	var mat_steel := StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.15, 0.16, 0.18)
	mat_steel.roughness = 0.35
	mat_steel.metallic = 0.85

	# 1. Основной корпус ящика
	var base := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.82, 0.48, 0.52)
	base.mesh = b_box
	base.material_override = mat_base
	base.position = Vector3(0, 0.24, 0)
	add_child(base)

	# Объёмные стальные уголки корпуса
	for x_c in [-0.41, 0.41]:
		for z_c in [-0.26, 0.26]:
			var corner := MeshInstance3D.new()
			var c_box := BoxMesh.new()
			c_box.size = Vector3(0.08, 0.48, 0.08)
			corner.mesh = c_box
			corner.material_override = mat_steel
			corner.position = Vector3(x_c, 0.24, z_c)
			add_child(corner)

	# Боковые стальные ручки для переноски
	for x_side in [-0.42, 0.42]:
		var handle := MeshInstance3D.new()
		var h_mesh := BoxMesh.new()
		h_mesh.size = Vector3(0.04, 0.08, 0.22)
		handle.mesh = h_mesh
		handle.material_override = mat_steel
		handle.position = Vector3(x_side, 0.28, 0)
		add_child(handle)

	# 2. Откидная крышка ящика на петлях
	lid_node = Node3D.new()
	lid_node.name = "Lid"
	lid_node.position = Vector3(0, 0.48, -0.26)

	var lid_mesh := MeshInstance3D.new()
	var l_box := BoxMesh.new()
	l_box.size = Vector3(0.84, 0.08, 0.54)
	lid_mesh.mesh = l_box
	var mat_lid := StandardMaterial3D.new()
	mat_lid.albedo_color = Color(0.95, 0.55, 0.1) # Сигнальный оранжевый цвет
	mat_lid.roughness = 0.4
	mat_lid.metallic = 0.65
	lid_mesh.material_override = mat_lid
	lid_mesh.position = Vector3(0, 0.04, 0.27)
	lid_node.add_child(lid_mesh)

	# Рёбра жесткости на крышке
	for x_rib in [-0.25, 0.0, 0.25]:
		var rib := MeshInstance3D.new()
		var r_box := BoxMesh.new()
		r_box.size = Vector3(0.06, 0.03, 0.48)
		rib.mesh = r_box
		rib.material_override = mat_steel
		rib.position = Vector3(x_rib, 0.09, 0.27)
		lid_node.add_child(rib)

	add_child(lid_node)

	# 3. Механический/электронный замок на фасаде
	var latch := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.12, 0.16, 0.04)
	latch.mesh = lm
	latch.material_override = mat_steel
	latch.position = Vector3(0, 0.42, 0.27)
	add_child(latch)

	lock_indicator = MeshInstance3D.new()
	var ind_quad := QuadMesh.new()
	ind_quad.size = Vector2(0.05, 0.05)
	lock_indicator.mesh = ind_quad
	var ind_mat := StandardMaterial3D.new()
	ind_mat.albedo_color = Color.RED if is_locked else Color.GREEN
	ind_mat.emission_enabled = true
	ind_mat.emission = Color.RED if is_locked else Color.GREEN
	ind_mat.emission_energy_multiplier = 3.0
	lock_indicator.material_override = ind_mat
	lock_indicator.position = Vector3(0, 0.45, 0.292)
	add_child(lock_indicator)

	# Коллайдер
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(0.84, 0.56, 0.54)
	col.shape = s
	col.position = Vector3(0, 0.28, 0)
	sb.add_child(col)
	add_child(sb)

func _setup_interactable() -> void:
	interactable = Interactable.new()
	interactable.prompt_message = "Открыть %s [E]" % container_title if not is_locked else "Взломать замок [4]"
	interactable.interacted.connect(_on_interacted)
	add_child(interactable)

func hack_bypass() -> void:
	is_locked = false
	if lock_indicator and lock_indicator.material_override:
		var mat := lock_indicator.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color.GREEN
			mat.emission = Color.GREEN
	open_container(null)

func _on_interacted(instigator: Node) -> void:
	if is_opened:
		return
	if is_locked:
		LogManager.info("Контейнер заперт на электронный замок. Используйте кибер-деку [4].", "Interaction")
		return
	open_container(instigator)

func open_container(instigator: Node) -> void:
	if is_opened:
		return
	is_opened = true

	if interactable:
		interactable.is_enabled = false
		interactable.prompt_message = "Пусто"

	if lock_indicator and lock_indicator.material_override:
		var mat := lock_indicator.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color.GRAY
			mat.emission_enabled = false

	if lid_node:
		var tw := create_tween()
		tw.tween_property(lid_node, "rotation_degrees:x", -80.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var root_n = get_parent() if get_parent() else self
	ImpactFX.spawn_sparks(root_n, global_position + Vector3(0, 0.45, 0), Vector3.UP, 10)
	ImpactFX.spawn_dust(root_n, global_position + Vector3(0, 0.45, 0), 6)

	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("add_credits", credits_reward)

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", -5.0)

	var loot := {
		"credits": credits_reward,
		"title": container_title
	}
	container_opened.emit(loot)
	LogManager.info("Открыт %s! Получено: +%d КР." % [container_title, credits_reward], "Loot")
