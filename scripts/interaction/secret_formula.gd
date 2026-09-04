class_name SecretFormula
extends Node3D

# Секретный рецептурный чип-картридж корпорации MERIDIAN
# Ключевой квестовый предмет миссии «Операция: Шипучка»

signal formula_collected()

var is_collected: bool = false
@onready var interactable: Node = get_node_or_null("Interactable")

func _ready() -> void:
	if interactable and interactable.has_signal("interacted"):
		interactable.connect("interacted", _on_interacted)

func _on_interacted(_instigator: Node) -> void:
	if is_collected:
		return
	is_collected = true
	formula_collected.emit()
	LogManager.info("Секретный рецептурный чип MERIDIAN захвачен!", "QUEST")
	
	# Анимация растворения/взятия
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(queue_free)