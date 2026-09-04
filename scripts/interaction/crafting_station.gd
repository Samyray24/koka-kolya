class_name CraftingStation
extends Node3D

# Верстак крафтинга и синтеза авторской рецептуры «Кока-Коля»
# Позволяет расшифровать чип формулы и синтезировать концентрат сиропа.

signal craft_started()
signal craft_completed(item_name: String)

var is_crafted: bool = false
@onready var interactable: Node = get_node_or_null("Interactable")
@onready var light_glow: OmniLight3D = get_node_or_null("OmniLight3D")

func _ready() -> void:
	if interactable and interactable.has_signal("interacted"):
		interactable.connect("interacted", _on_interact)

func _on_interact(_user: Node) -> void:
	if is_crafted:
		LogManager.info("Партия концентрата уже синтезирована.", "CRAFTING")
		return
		
	start_synthesis()

func start_synthesis() -> void:
	is_crafted = true
	craft_started.emit()
	LogManager.info("Начат синтез концентрата «Кока-Коля Экстра-Шипучая»...", "CRAFTING")
	
	if light_glow:
		var tw := create_tween()
		tw.tween_property(light_glow, "light_energy", 6.0, 0.4)
		tw.tween_property(light_glow, "light_energy", 2.0, 0.6)
		
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(_on_synthesis_finished)

func _on_synthesis_finished() -> void:
	craft_completed.emit("SyrupCanister")
	if interactable:
		interactable.set("prompt_message", "Синтез завершен (Концентрат готов)")
	LogManager.info("Синтез успешно завершен! Канистра концентрата готова к загрузке.", "CRAFTING")