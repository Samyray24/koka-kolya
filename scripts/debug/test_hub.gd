extends Control

# Test Hub Controller for Development Builds

@onready var btn_graybox: Button = $MarginContainer/VBoxContainer/BtnGraybox
@onready var btn_physics: Button = $MarginContainer/VBoxContainer/BtnPhysics
@onready var btn_ai: Button = $MarginContainer/VBoxContainer/BtnAI
@onready var btn_back: Button = $MarginContainer/VBoxContainer/BtnBack

func _ready() -> void:
	if btn_graybox:
		btn_graybox.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/testlabs/foundation_graybox.tscn")
		)
		btn_graybox.grab_focus()
	if btn_physics:
		btn_physics.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/testlabs/physics_lab.tscn")
		)
	if btn_ai:
		btn_ai.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/testlabs/ai_arena.tscn")
		)
	if btn_back:
		btn_back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		)
