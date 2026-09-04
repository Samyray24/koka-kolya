class_name AISensorHearing
extends Node3D

# Сенсор честного слуха для AI «Кока-Коля» (Section 14)
# Реагирует на акустические волны в физическом радиусе с учетом расстояния

signal noise_heard(origin: Vector3, intensity: float, noise_type: String)

@export var hearing_sensitivity: float = 1.0

func _ready() -> void:
	var nm: Node = get_node_or_null("/root/NoiseManager")
	if nm and nm.has_signal("noise_emitted"):
		nm.connect("noise_emitted", _on_noise_emitted)

func _on_noise_emitted(origin: Vector3, radius: float, _instigator: Node, noise_type: String) -> void:
	var dist: float = global_position.distance_to(origin)
	var effective_radius: float = radius * hearing_sensitivity
	if dist <= effective_radius:
		var intensity: float = clampf(1.0 - (dist / effective_radius), 0.1, 1.0)
		LogManager.debug("AI услышал звук [%s] на дистанции %.1f м (сила: %.2f)" % [noise_type, dist, intensity], "AI_HEARING")
		noise_heard.emit(origin, intensity, noise_type)
