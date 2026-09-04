extends Node3D

# Physics Lab Controller for «Кока-Коля» (v0.2.0)
# Тестовый стенд для физических петель дверей, конвейера розлива и разрушаемого стекла

@onready var lbl_fps: Label = $DebugUI/MarginContainer/VBoxContainer/LblFPS
@onready var lbl_door: Label = $DebugUI/MarginContainer/VBoxContainer/LblDoor
@onready var lbl_glass: Label = $DebugUI/MarginContainer/VBoxContainer/LblGlass
@onready var door: Node3D = $PhysicalDoor
@onready var glass: Node3D = $BreakableGlass

func _ready() -> void:
	LogManager.info("Physics Lab сцена инициализирована.", "PHYSICS_LAB")
	if door and door.has_signal("door_opened"):
		door.connect("door_opened", func() -> void:
			if lbl_door: lbl_door.text = "Дверь: ОТКРЫТА (физический импульс)"
		)
		door.connect("door_closed", func() -> void:
			if lbl_door: lbl_door.text = "Дверь: ЗАКРЫТА"
		)
	if glass and glass.has_signal("glass_cracked"):
		glass.connect("glass_cracked", func() -> void:
			if lbl_glass: lbl_glass.text = "Стекло: ТРЕЩИНЫ (50% целостности)"
		)
		glass.connect("glass_shattered", func() -> void:
			if lbl_glass: lbl_glass.text = "Стекло: РАЗБИТО (осколки рассеяны)"
		)

func _process(_delta: float) -> void:
	if lbl_fps:
		lbl_fps.text = "FPS: %d | Frame Time: %.2f ms" % [Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second())]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
