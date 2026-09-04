extends Node

# NoiseManager — Шина акустических стимулов для честного AI «Кока-Коля»
# Любой физический удар, шаги или брошенные предметы генерируют звук с физическим радиусом

signal noise_emitted(origin: Vector3, radius: float, instigator: Node, noise_type: String)

func emit_noise(origin: Vector3, radius: float, instigator: Node = null, noise_type: String = "general") -> void:
	noise_emitted.emit(origin, radius, instigator, noise_type)
	LogManager.debug("Шум эмитирован: тип=%s, радиус=%.1f м в %s" % [noise_type, radius, origin], "ACOUSTICS")
