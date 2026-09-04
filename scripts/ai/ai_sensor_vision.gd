class_name AISensorVision
extends Node3D

# Сенсор честного зрения для AI «Кока-Коля» (Section 14)
# Реализует конус зрения, проверку прямой видимости через RayCast и плавное накопление тревоги

signal target_spotted(target: Node3D, last_pos: Vector3)
signal target_lost(last_pos: Vector3)
signal awareness_changed(current_pct: float)

@export var max_view_distance: float = 16.0
@export var field_of_view_deg: float = 110.0
@export var detection_rate: float = 80.0 # % в секунду на близкой дистанции
@export var decay_rate: float = 35.0     # % спада в секунду без контакта

var target_node: Node3D = null
var current_awareness: float = 0.0 # 0.0 .. 100.0%
var is_target_visible: bool = false
var last_known_pos: Vector3 = Vector3.ZERO

@onready var raycast: RayCast3D = get_node_or_null("RayCast3D")

func _ready() -> void:
	if not raycast:
		raycast = RayCast3D.new()
		raycast.name = "RayCast3D"
		add_child(raycast)
	raycast.collision_mask = 1 # Стены и статичные препятствия

func set_target(target: Node3D) -> void:
	target_node = target

func _physics_process(delta: float) -> void:
	if not target_node:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target_node = players[0] as Node3D
		else:
			return

	var can_see: bool = _check_line_of_sight()
	if can_see:
		is_target_visible = true
		last_known_pos = target_node.global_position
		
		var dist: float = global_position.distance_to(last_known_pos)
		var dist_factor: float = clampf(1.0 - (dist / max_view_distance), 0.2, 1.0)
		current_awareness = minf(100.0, current_awareness + detection_rate * dist_factor * delta)
		
		awareness_changed.emit(current_awareness)
		if current_awareness >= 100.0:
			target_spotted.emit(target_node, last_known_pos)
	else:
		if is_target_visible:
			is_target_visible = false
			target_lost.emit(last_known_pos)
		
		current_awareness = maxf(0.0, current_awareness - decay_rate * delta)
		awareness_changed.emit(current_awareness)

func _check_line_of_sight() -> bool:
	if not target_node:
		return false

	var to_target: Vector3 = target_node.global_position - global_position
	var dist: float = to_target.length()
	if dist > max_view_distance:
		return false

	# 1. Проверка угла конуса зрения
	var forward := -global_transform.basis.z.normalized()
	var dir_to_target := to_target.normalized()
	var angle_deg := rad_to_deg(forward.angle_to(dir_to_target))
	if angle_deg > field_of_view_deg * 0.5:
		return false

	# 2. Рейкаст на наличие укрытий/препятствий (честное зрение)
	if not raycast or not is_inside_tree():
		return true

	raycast.global_position = global_position
	raycast.target_position = raycast.to_local(target_node.global_position + Vector3(0, 0.9, 0))
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var col: Object = raycast.get_collider()
		# Если столкнулись с препятствием перед целью
		if col != target_node:
			return false

	return true
