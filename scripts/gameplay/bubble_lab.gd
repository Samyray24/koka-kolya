extends Node3D

# BUBBLE Lab Controller for «Кока-Коля» (v0.2.0)
# Тестовый полигон для проверки дрона BUBBLE (автономный ховер, 6-DOF полет, сканер, фонарь)

@onready var lbl_mode: Label = $DebugUI/MarginContainer/VBoxContainer/LblMode
@onready var lbl_light: Label = $DebugUI/MarginContainer/VBoxContainer/LblLight
@onready var lbl_alt: Label = $DebugUI/MarginContainer/VBoxContainer/LblAlt
@onready var lbl_fps: Label = $DebugUI/MarginContainer/VBoxContainer/LblFPS
@onready var drone: CharacterBody3D = $BubbleDrone as CharacterBody3D

func _ready() -> void:
	LogManager.info("BUBBLE Lab сцена инициализирована.", "BUBBLE_LAB")
	var p: Node3D = $Player as Node3D
	if p and not p.is_in_group("player"):
		p.add_to_group("player")

	if drone and drone.has_signal("mode_changed"):
		drone.connect("mode_changed", func(m_idx: int) -> void:
			if lbl_mode:
				lbl_mode.text = "Режим BUBBLE: %s" % ("СЛЕДОВАНИЕ (FOLLOW)" if m_idx == 0 else "РУЧНОЙ ПОЛЕТ (RC 6-DOF)")
		)

func _process(_delta: float) -> void:
	if lbl_fps:
		lbl_fps.text = "FPS: %d | Frame Time: %.2f ms" % [Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second())]
	if drone and lbl_alt and lbl_light:
		lbl_alt.text = "Высота дрона: %.2f м | Скорость: %.1f км/ч" % [drone.global_position.y, drone.velocity.length() * 3.6]
		var light_on: bool = drone.get("is_flashlight_on")
		lbl_light.text = "Фонарь дрона: %s" % ("ВКЛЮЧЕН" if light_on else "ВЫКЛЮЧЕН")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
