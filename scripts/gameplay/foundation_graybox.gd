extends Node3D

# Foundation Graybox Controller for «Кока-Коля»

@onready var lbl_fps: Label = $DebugUI/MarginContainer/VBoxContainer/LblFPS
@onready var lbl_pos: Label = $DebugUI/MarginContainer/VBoxContainer/LblPos
@onready var lbl_speed: Label = $DebugUI/MarginContainer/VBoxContainer/LblSpeed
@onready var lbl_physics: Label = $DebugUI/MarginContainer/VBoxContainer/LblPhysics
@onready var player: CharacterBody3D = $Player as CharacterBody3D

func _ready() -> void:
	print("[FOUNDATION] Graybox scene loaded with Jolt Physics.")
	var engine_name: String = ProjectSettings.get_setting("physics/3d/physics_engine", "Default")
	if lbl_physics:
		lbl_physics.text = "Физика: %s (Активна)" % engine_name

func _process(_delta: float) -> void:
	if lbl_fps:
		lbl_fps.text = "FPS: %d (Frame Time: %.2f ms)" % [Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second())]

	if player and lbl_pos and lbl_speed:
		var pos: Vector3 = player.global_position
		lbl_pos.text = "Позиция: X: %.2f | Y: %.2f | Z: %.2f" % [pos.x, pos.y, pos.z]
		var horiz_vel: Vector2 = Vector2(player.velocity.x, player.velocity.z)
		var speed_kmh: float = horiz_vel.length() * 3.6
		lbl_speed.text = "Скорость: %.1f км/ч (%s)" % [speed_kmh, "Бег" if Input.is_action_pressed("sprint") else "Шаг"]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		print("[FOUNDATION] Returning to Test Hub...")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
