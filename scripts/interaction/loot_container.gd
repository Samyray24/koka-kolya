class_name LootContainer
extends Node3D

# Обыскиваемый контейнер / шкафчик / сейф / багажник авто
# Позволяет получать патроны, кредиты и аптечки при открытии [E] или взломе [4].

signal container_opened(loot_data: Dictionary)

@export var container_title: String = "Ящик снабжения"
@export var credits_reward: int = 50
@export var is_locked: bool = false
@export var is_opened: bool = false

var lid_node: Node3D = null
var interactable: Interactable = null

func _ready() -> void:
	_build_visuals()
	_setup_interactable()

func _build_visuals() -> void:
	# Корпус ящика
	var base := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.8, 0.5, 0.5)
	base.mesh = b_box
	var mat_base := StandardMaterial3D.new()
	mat_base.albedo_color = Color(0.25, 0.28, 0.32)
	mat_base.roughness = 0.6
	mat_base.metallic = 0.5
	base.material_override = mat_base
	base.position = Vector3(0, 0.25, 0)
	add_child(base)

	# Крышка ящика
	lid_node = Node3D.new()
	lid_node.name = "Lid"
	lid_node.position = Vector3(0, 0.5, -0.25)

	var lid_mesh := MeshInstance3D.new()
	var l_box := BoxMesh.new()
	l_box.size = Vector3(0.82, 0.08, 0.52)
	lid_mesh.mesh = l_box
	var mat_lid := StandardMaterial3D.new()
	mat_lid.albedo_color = Color(1.0, 0.6, 0.1) # Оранжевый акцент
	mat_lid.roughness = 0.4
	mat_lid.metallic = 0.6
	lid_mesh.material_override = mat_lid
	lid_mesh.position = Vector3(0, 0.04, 0.25)
	lid_node.add_child(lid_mesh)
	add_child(lid_node)

	# Коллайдер
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(0.8, 0.55, 0.5)
	col.shape = s
	col.position = Vector3(0, 0.27, 0)
	sb.add_child(col)
	add_child(sb)

func _setup_interactable() -> void:
	interactable = Interactable.new()
	interactable.prompt_message = "Открыть %s [E]" % container_title if not is_locked else "Взломать замок [4]"
	interactable.interacted.connect(_on_interacted)
	add_child(interactable)

func hack_bypass() -> void:
	is_locked = false
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

	if lid_node:
		var tw := create_tween()
		tw.tween_property(lid_node, "rotation_degrees:x", -75.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("add_credits", credits_reward)

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", -6.0)

	var loot := {
		"credits": credits_reward,
		"title": container_title
	}
	container_opened.emit(loot)
	LogManager.info("Открыт %s! Получено: +%d КР." % [container_title, credits_reward], "Loot")
