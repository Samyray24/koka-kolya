extends Node

# InputManager — Абстракция устройств ввода и адаптация подсказок UI
# Определяет активное устройство (Клавиатура/Мышь vs Геймпад) и предоставляет подсказки действий

signal input_device_changed(is_gamepad: bool)

var is_gamepad_active: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not is_gamepad_active:
			is_gamepad_active = true
			input_device_changed.emit(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		if is_gamepad_active:
			is_gamepad_active = false
			input_device_changed.emit(false)

func get_action_prompt(action_name: String) -> String:
	if is_gamepad_active:
		match action_name:
			"interact": return "[X]"
			"jump": return "[A]"
			"sprint": return "[L3]"
			"crouch": return "[B]"
			"pause": return "[START]"
			_: return "[PAD]"
	else:
		match action_name:
			"interact": return "[E]"
			"jump": return "[ПРОБЕЛ]"
			"sprint": return "[SHIFT]"
			"crouch": return "[CTRL]"
			"pause": return "[ESC]"
			_: return "[КЛАВ]"
