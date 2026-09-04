class_name ToolsLab
extends Node3D

# Лаборатория проверки арсенала инструментов и боевых систем (Tools & Combat Lab)

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var guard: CharacterBody3D = get_node_or_null("GuardAI")
@onready var door: Node3D = get_node_or_null("PhysicalDoor")

func _ready() -> void:
	LogManager.info("Tools Lab инициализирована: стенд проверки оружия и гаджетов активен.", "TOOLS_LAB")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
