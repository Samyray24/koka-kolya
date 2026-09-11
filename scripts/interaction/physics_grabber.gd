class_name PhysicsGrabber
extends Node3D

# Система физического захвата и взаимодействия от первого лица
# Позволяет брать, переносить, вращать и бросать RigidBody3D, а также активировать Interactable.
# Предотвращает коллизии удерживаемого предмета с телом игрока, устраняя дергание и застревания.

signal prompt_updated(prompt_text: String)
signal target_state_changed(state: String) # "none", "grabbable", "interactable", "vehicle", "cargo_snap", "holding"

@export var max_reach_distance: float = 4.8
@export var grab_spring_force: float = 32.0
@export var grab_damping: float = 6.0
@export var throw_impulse: float = 9.5:
	set(val):
		throw_impulse = val
		base_throw_impulse = val * 0.7
		max_throw_impulse = val * 1.9
@export var base_throw_impulse: float = 7.0
@export var max_throw_impulse: float = 18.0
@export var max_grab_mass: float = 55.0
@export var default_hold_distance: float = 1.9

@onready var raycast: RayCast3D = get_node_or_null("RayCast3D")
@onready var hold_point: Marker3D = get_node_or_null("HoldPoint")

var shapecast: ShapeCast3D = null
var held_body: RigidBody3D = null
var original_angular_damp: float = 0.0
var player_body: CharacterBody3D = null

# Состояние удержания
var current_hold_distance: float = 1.9
var is_rotating_held: bool = false
var throw_charge: float = 0.0
var is_charging_throw: bool = false
var held_rotation_offset: Basis = Basis.IDENTITY

func _ready() -> void:
	current_hold_distance = default_hold_distance
	if hold_point:
		hold_point.position = Vector3(0.0, -0.2, -current_hold_distance)
	
	if raycast:
		raycast.target_position = Vector3(0.0, 0.0, -max_reach_distance)
		raycast.collision_mask = 7 # Слой 1 (Мир), 2 (Игрок), 3 (Объекты)

	# Инициализация объемного ShapeCast для комфортного подбора предметов
	shapecast = ShapeCast3D.new()
	shapecast.name = "GrabShapeCast3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shapecast.shape = sphere
	shapecast.target_position = Vector3(0.0, 0.0, -max_reach_distance)
	shapecast.collision_mask = 7
	shapecast.collide_with_bodies = true
	shapecast.collide_with_areas = true
	add_child(shapecast)
	
	# Находим владельца игрока
	var cur: Node = get_parent()
	while cur:
		if cur is CharacterBody3D:
			player_body = cur as CharacterBody3D
			shapecast.add_exception(player_body)
			if raycast:
				raycast.add_exception(player_body)
			break
		cur = cur.get_parent()

func _physics_process(delta: float) -> void:
	if held_body:
		_process_held_body(delta)
	else:
		_process_raycast()

func _process_raycast() -> void:
	var target_node := _get_target_node()
	if not target_node:
		prompt_updated.emit("")
		target_state_changed.emit("none")
		return

	var info := _resolve_interaction_info(target_node)
	match info["type"]:
		"vehicle":
			prompt_updated.emit("Нажмите [E] — %s" % info["label"])
			target_state_changed.emit("vehicle")
		"interactable":
			prompt_updated.emit("Нажмите [E] — %s" % info["label"])
			target_state_changed.emit("interactable")
		"grabbable":
			prompt_updated.emit("Нажмите [E] / [ЛКМ] — %s" % info["label"])
			target_state_changed.emit("grabbable")
		"heavy":
			prompt_updated.emit(info["label"])
			target_state_changed.emit("none")
		_:
			prompt_updated.emit("")
			target_state_changed.emit("none")

func _get_target_node() -> Node:
	# 1. Проверяем прямой рейкаст
	if raycast and raycast.is_colliding():
		var c = raycast.get_collider()
		if c and c != player_body:
			return c as Node

	# 2. Проверяем объемный shapecast для комфортного наведения
	if shapecast and shapecast.is_colliding():
		for i in range(shapecast.get_collision_count()):
			var c = shapecast.get_collider(i)
			if c and c != player_body:
				return c as Node

	return null

func _resolve_interaction_info(raw_node: Node) -> Dictionary:
	if not raw_node:
		return {"type": "none", "node": null, "label": ""}

	# 1. Проверка на фургон доставки
	var van_cand: Node = raw_node
	while van_cand:
		if van_cand is DeliveryVan or van_cand.name == "DeliveryVan" or (van_cand.owner is DeliveryVan):
			var final_van: Node = van_cand if van_cand is DeliveryVan else van_cand.owner
			return {"type": "vehicle", "node": final_van, "label": "Сесть за руль фургона"}
		van_cand = van_cand.get_parent()

	# 2. Проверка на компонент Interactable
	var inter: Node = _find_interactable(raw_node)
	if inter:
		var msg: String = String(inter.get("prompt_message")) if "prompt_message" in inter else "Использовать"
		return {"type": "interactable", "node": inter, "label": msg}

	# 3. Проверка на физический объект (RigidBody3D)
	var rb_cand: Node = raw_node
	while rb_cand:
		if rb_cand is RigidBody3D and not (rb_cand is DeliveryVan):
			var rb := rb_cand as RigidBody3D
			if rb.mass <= max_grab_mass:
				var title: String = "Ящик «Кока-Коля»" if (rb.name.begins_with("ColaCrate") or rb is ColaCrate) else "Предмет"
				return {"type": "grabbable", "node": rb, "label": "Поднять %s (%.1f кг)" % [title, rb.mass]}
			else:
				return {"type": "heavy", "node": rb, "label": "Слишком тяжелый (%.1f кг)" % rb.mass}
		rb_cand = rb_cand.get_parent()

	return {"type": "none", "node": null, "label": ""}

func _input(event: InputEvent) -> void:
	# Если держим предмет — расширенное управление (дистанция, вращение, бросок)
	if held_body:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				_adjust_hold_distance(-0.2)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				_adjust_hold_distance(0.2)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				is_rotating_held = event.pressed
				return
			elif event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					is_charging_throw = true
					throw_charge = 0.0
				else:
					if is_charging_throw:
						_execute_charged_throw()
						get_viewport().set_input_as_handled()
				return

		if event is InputEventMouseMotion and is_rotating_held:
			var mm := event as InputEventMouseMotion
			var rot_y: float = -mm.relative.x * 0.015
			var rot_x: float = -mm.relative.y * 0.015
			held_rotation_offset = held_rotation_offset.rotated(Vector3.UP, rot_y)
			held_rotation_offset = held_rotation_offset.rotated(Vector3.RIGHT, rot_x)
			get_viewport().set_input_as_handled()
			return

		if event.is_action_just_pressed("interact"):
			if _can_snap_to_van():
				_snap_held_to_van()
			else:
				drop_object()
			get_viewport().set_input_as_handled()
			return

	else:
		# Когда руки свободны
		if event.is_action_just_pressed("interact"):
			try_interact_or_grab()

func _adjust_hold_distance(delta_dist: float) -> void:
	current_hold_distance = clampf(current_hold_distance + delta_dist, 1.2, max_reach_distance)
	if hold_point:
		hold_point.position.z = -current_hold_distance

func _can_snap_to_van() -> bool:
	if not held_body:
		return false
	if not (held_body.is_in_group("cargo") or held_body.name.begins_with("ColaCrate") or held_body is ColaCrate):
		return false
	var van: DeliveryVan = _find_nearest_van()
	if van and is_instance_valid(van):
		var dist: float = global_position.distance_to(van.global_position)
		if dist < 5.5:
			return true
	return false

func _find_nearest_van() -> DeliveryVan:
	var nodes := get_tree().get_nodes_in_group("vehicle")
	for n in nodes:
		if n is DeliveryVan:
			return n as DeliveryVan
	if has_node("/root/OldDistrict/DeliveryVan"):
		return get_node("/root/OldDistrict/DeliveryVan") as DeliveryVan
	return null

func _snap_held_to_van() -> void:
	var van: DeliveryVan = _find_nearest_van()
	if van and is_instance_valid(van) and van.has_method("snap_crate"):
		var crate := held_body
		drop_object()
		var ok: bool = van.call("snap_crate", crate)
		if ok:
			prompt_updated.emit("Ящик надежно зафиксирован в кузове фургона!")
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				am.call("play_sfx", "click", -2.0, 1.4)
			return

	drop_object()

func _find_interactable(target: Node) -> Node:
	if not target:
		return null
	if target.has_node("Interactable"):
		return target.get_node("Interactable")
	var p: Node = target.get_parent()
	if p and p.has_node("Interactable"):
		return p.get_node("Interactable")
	if target.owner and target.owner.has_node("Interactable"):
		return target.owner.get_node("Interactable")
	return null

func try_interact_or_grab() -> void:
	var target_node := _get_target_node()
	if not target_node:
		return

	var info := _resolve_interaction_info(target_node)
	match info["type"]:
		"vehicle":
			var dv: DeliveryVan = info["node"] as DeliveryVan
			if dv and dv.has_method("enter_vehicle") and player_body:
				dv.enter_vehicle(player_body)
		"interactable":
			var inter: Node = info["node"]
			if inter and inter.has_method("trigger_interaction"):
				inter.call("trigger_interaction", owner if owner else player_body)
		"grabbable":
			var rb: RigidBody3D = info["node"] as RigidBody3D
			if rb:
				grab_object(rb)

func grab_object(rb: RigidBody3D) -> void:
	if not is_instance_valid(rb):
		return
		
	held_body = rb
	held_body.sleeping = false
	held_body.freeze = false
	held_body.linear_velocity = Vector3.ZERO
	held_body.angular_velocity = Vector3.ZERO
	original_angular_damp = rb.angular_damp
	rb.angular_damp = 18.0
	held_rotation_offset = Basis.IDENTITY
	
	# Исключаем коллизию между телом игрока и удерживаемым предметом!
	if player_body and is_instance_valid(player_body):
		player_body.add_collision_exception_with(held_body)
		held_body.add_collision_exception_with(player_body)

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "grab", -3.0)

	target_state_changed.emit("holding")

func drop_object() -> void:
	if not held_body:
		return

	if player_body and is_instance_valid(player_body) and is_instance_valid(held_body):
		player_body.remove_collision_exception_with(held_body)
		held_body.remove_collision_exception_with(player_body)

	held_body.sleeping = false
	held_body.angular_damp = original_angular_damp
	var player_v := player_body.velocity if player_body and is_instance_valid(player_body) else Vector3.ZERO
	held_body.linear_velocity = held_body.linear_velocity * 0.4 + player_v * 0.75
	held_body = null
	is_charging_throw = false
	throw_charge = 0.0
	is_rotating_held = false
	prompt_updated.emit("")
	target_state_changed.emit("none")

func throw_object() -> void:
	_execute_charged_throw(1.0)

func _execute_charged_throw(force_mult: float = -1.0) -> void:
	if not held_body:
		return

	var ratio := throw_charge if force_mult < 0.0 else force_mult
	var final_impulse := lerpf(base_throw_impulse, max_throw_impulse, ratio)

	if player_body and is_instance_valid(player_body) and is_instance_valid(held_body):
		player_body.remove_collision_exception_with(held_body)
		held_body.remove_collision_exception_with(player_body)

	var forward := -global_transform.basis.z.normalized()
	held_body.sleeping = false
	held_body.angular_damp = original_angular_damp
	var p_vel := player_body.velocity if player_body and is_instance_valid(player_body) else Vector3.ZERO
	var throw_vec: Vector3 = forward * final_impulse + p_vel * 0.8
	held_body.apply_central_impulse(throw_vec)
	held_body.apply_torque_impulse(global_transform.basis.x * (final_impulse * 0.4))

	held_body = null
	is_charging_throw = false
	throw_charge = 0.0
	is_rotating_held = false
	prompt_updated.emit("")
	target_state_changed.emit("none")

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		var pitch := lerpf(0.9, 1.25, ratio)
		am.call("play_sfx", "throw", -3.0, pitch)

func _process_held_body(delta: float) -> void:
	if not is_instance_valid(held_body):
		held_body = null
		target_state_changed.emit("none")
		return

	held_body.sleeping = false

	# Накопление заряда броска при зажатой ЛКМ
	if is_charging_throw:
		throw_charge = minf(1.0, throw_charge + delta * 2.2)
		var pct := int(round(throw_charge * 100.0))
		prompt_updated.emit("Заряд броска: %d%% (Отпустите ЛКМ для броска)" % pct)
	else:
		if _can_snap_to_van():
			prompt_updated.emit("Рядом кузов фургона: [E] — Закрепить ящик | [ЛКМ] — Бросить")
			target_state_changed.emit("cargo_snap")
		elif is_rotating_held:
			prompt_updated.emit("Поворот предмета (двигайте мышь) | Отпустите ПКМ для фиксации")
		else:
			prompt_updated.emit("[E] Отпустить | [ПКМ] Вращать | [Колесо] Дистанция | [ЛКМ] Зарядить бросок")
			target_state_changed.emit("holding")

	var target_pos := hold_point.global_position
	var curr_pos := held_body.global_position
	var dist_vec := target_pos - curr_pos

	if dist_vec.length() > max_reach_distance * 1.8:
		drop_object()
		return

	var desired_vel := dist_vec * grab_spring_force
	held_body.linear_velocity = held_body.linear_velocity.lerp(desired_vel, 0.45)

	if not is_rotating_held:
		var target_quat := (global_transform.basis * held_rotation_offset).get_rotation_quaternion()
		var curr_quat := held_body.global_transform.basis.get_rotation_quaternion()
		var next_quat := curr_quat.slerp(target_quat, 10.0 * delta)
		held_body.global_transform.basis = Basis(next_quat)
