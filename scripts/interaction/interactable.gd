class_name Interactable
extends Node

# Базовый компонент интерактивности для объектов мира «Кока-Коля»

signal interacted(instigator: Node)

@export var prompt_message: String = "Использовать"
@export var is_enabled: bool = true

func can_interact(_instigator: Node) -> bool:
	return is_enabled

func trigger_interaction(instigator: Node) -> void:
	if not can_interact(instigator):
		return
	interacted.emit(instigator)
	_on_interacted(instigator)

func _on_interacted(_instigator: Node) -> void:
	pass
