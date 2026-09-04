class_name AutomationTerminal
extends Node3D

# Терминал управления промышленной автоматизацией завода «Красная Линия»
# Позволяет перехватить контроль над конвейерами и запустить розлив партии Коли.

signal plant_overridden()

var is_overridden: bool = false
@onready var interactable: Node = get_node_or_null("Interactable")
@onready var status_light: OmniLight3D = get_node_or_null("StatusLight")

func _ready() -> void:
	if interactable and interactable.has_signal("interacted"):
		interactable.connect("interacted", _on_interacted)

func _on_interacted(_user: Node) -> void:
	override_plant()

func hack_bypass() -> void:
	override_plant()

func override_plant() -> void:
	if is_overridden:
		return
	is_overridden = true
	plant_overridden.emit()
	
	if status_light:
		status_light.light_color = Color(1.0, 0.15, 0.2) # Красный фирменный цвет Коли
		status_light.light_energy = 5.0
		
	if has_node("/root/NoiseManager"):
		var nm: Node = get_node("/root/NoiseManager")
		nm.call("emit_noise", global_position, 30.0, self, "factory_horn")
		
	LogManager.info("АВТОМАТИЗАЦИЯ ЗАВОДА ПЕРЕХВАЧЕНА: Запущен розлив «Кока-Коля»!", "FACTORY")