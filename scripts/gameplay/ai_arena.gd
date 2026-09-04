extends Node3D

# AI Arena Controller for «Кока-Коля» (v0.2.0)
# Тестовый полигон для проверки честного зрения, слуха и поведения патруля

@onready var lbl_guard_state: Label = $DebugUI/MarginContainer/VBoxContainer/LblGuardState
@onready var lbl_awareness: Label = $DebugUI/MarginContainer/VBoxContainer/LblAwareness
@onready var lbl_fps: Label = $DebugUI/MarginContainer/VBoxContainer/LblFPS
@onready var guard: CharacterBody3D = $GuardAI as CharacterBody3D

func _ready() -> void:
	LogManager.info("AI Arena сцена инициализирована.", "AI_ARENA")
	var p: Node3D = $Player as Node3D
	if p and not p.is_in_group("player"):
		p.add_to_group("player")

	if guard:
		var vis: Node = guard.get_node_or_null("AISensorVision")
		if vis and vis.has_signal("awareness_changed"):
			vis.connect("awareness_changed", func(pct: float) -> void:
				if lbl_awareness:
					lbl_awareness.text = "Уровень тревоги зрения: %3.0f%%" % pct
			)

func _process(_delta: float) -> void:
	if lbl_fps:
		lbl_fps.text = "FPS: %d | Frame Time: %.2f ms" % [Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second())]
	if guard and lbl_guard_state:
		var state_val: int = guard.get("current_state")
		var state_names := ["ПАТРУЛЬ (IDLE)", "ПОДОЗРЕНИЕ (SUSPICIOUS)", "РАССЛЕДОВАНИЕ (INVESTIGATING)", "ТРЕВОГА (ALERT)", "ПОИСК (SEARCHING)"]
		var state_str: String = state_names[state_val] if state_val < state_names.size() else "НЕИЗВЕСТНО"
		lbl_guard_state.text = "Состояние AI: %s" % state_str

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
