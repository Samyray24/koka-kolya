extends Control

# Test Hub Controller for Development Builds

@onready var btn_graybox: Button = $MarginContainer/VBoxContainer/BtnGraybox
@onready var btn_physics: Button = $MarginContainer/VBoxContainer/BtnPhysics
@onready var btn_ai: Button = $MarginContainer/VBoxContainer/BtnAI
@onready var btn_bubble: Button = $MarginContainer/VBoxContainer/BtnBubble
@onready var btn_vehicle: Button = $MarginContainer/VBoxContainer/BtnVehicle
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
	if btn_bubble:
		btn_bubble.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/testlabs/bubble_lab.tscn")
		)
	if btn_vehicle:
		btn_vehicle.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/testlabs/vehicle_lab.tscn")
		)
	if has_node("MarginContainer/VBoxContainer/BtnTools"):
		var btn_tools: Button = get_node("MarginContainer/VBoxContainer/BtnTools")
		btn_tools.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/testlabs/tools_lab.tscn")
		)
	if has_node("MarginContainer/VBoxContainer/BtnGraphics"):
		var btn_gfx: Button = get_node("MarginContainer/VBoxContainer/BtnGraphics")
		btn_gfx.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/testlabs/graphics_lab.tscn")
		)
	if has_node("MarginContainer/VBoxContainer/BtnOldDistrict"):
		var btn_m1: Button = get_node("MarginContainer/VBoxContainer/BtnOldDistrict")
		btn_m1.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/levels/old_district.tscn")
		)
	if has_node("MarginContainer/VBoxContainer/BtnRedLine"):
		var btn_m2: Button = get_node("MarginContainer/VBoxContainer/BtnRedLine")
		btn_m2.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/levels/red_line_plant.tscn")
		)
	if btn_back:
		btn_back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		)
