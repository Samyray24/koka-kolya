extends Control

# Main Menu Controller for «Кока-Коля»

@onready var btn_play: Button = $MarginContainer/VBoxContainer/BtnPlay
@onready var btn_testhub: Button = $MarginContainer/VBoxContainer/BtnTestHub
@onready var btn_settings: Button = $MarginContainer/VBoxContainer/BtnSettings
@onready var btn_quit: Button = $MarginContainer/VBoxContainer/BtnQuit

func _ready() -> void:
	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
		btn_play.grab_focus()
	if btn_testhub:
		btn_testhub.pressed.connect(_on_testhub_pressed)
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)

func _on_play_pressed() -> void:
	print("[MENU] Launching Foundation Graybox Scene...")
	get_tree().change_scene_to_file("res://scenes/testlabs/foundation_graybox.tscn")

func _on_testhub_pressed() -> void:
	print("[MENU] Opening Test Hub...")
	get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")

func _on_settings_pressed() -> void:
	print("[MENU] Settings clicked (placeholder in v0.0.1)")

func _on_quit_pressed() -> void:
	print("[MENU] Quitting application...")
	get_tree().quit()
