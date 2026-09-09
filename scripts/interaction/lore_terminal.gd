class_name LoreTerminal
extends Node3D

# Информационный планшет / терминал с лором и данными Сопротивления

signal lore_read(entry_title: String)

@export var terminal_title: String = "Планшет разведки"
@export var lore_header: String = "ПЕРЕХВАЧЕННЫЕ ДАННЫЕ MERIDIAN"
@export_multiline var lore_text: String = "Синдикат подменил сахар на синтетический наркотик С-9. Настоящая рецептура хранится только у СашиV и на сервере Цитадели."

var is_read: bool = false
var interactable: Interactable = null
var screen_light: OmniLight3D = null

func _ready() -> void:
	_build_visuals()
	_setup_interactable()

func _build_visuals() -> void:
	var base := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.5, 0.35, 0.05)
	base.mesh = b_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.16)
	base.material_override = mat
	add_child(base)

	var scr := MeshInstance3D.new()
	var s_mesh := QuadMesh.new()
	s_mesh.size = Vector2(0.44, 0.3)
	scr.mesh = s_mesh
	var scr_mat := StandardMaterial3D.new()
	scr_mat.albedo_color = Color(0.1, 0.7, 0.9)
	scr_mat.emission_enabled = true
	scr_mat.emission = Color(0.15, 0.85, 1.0)
	scr_mat.emission_energy_multiplier = 2.0
	scr.material_override = scr_mat
	scr.position = Vector3(0, 0, 0.026)
	add_child(scr)

	screen_light = OmniLight3D.new()
	screen_light.light_color = Color(0.2, 0.9, 1.0)
	screen_light.light_energy = 1.4
	screen_light.omni_range = 2.0
	screen_light.position = Vector3(0, 0, 0.15)
	add_child(screen_light)

	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.35, 0.1)
	col.shape = box
	sb.add_child(col)
	add_child(sb)

func _setup_interactable() -> void:
	interactable = Interactable.new()
	interactable.prompt_message = "Прочитать %s [E]" % terminal_title
	interactable.interacted.connect(_on_interacted)
	add_child(interactable)

func _on_interacted(_instigator: Node) -> void:
	is_read = true
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "laser_shot", -8.0)

	LogManager.info("[%s] %s" % [lore_header, lore_text], "Lore")
	lore_read.emit(terminal_title)
