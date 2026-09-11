class_name PlayerController
extends CharacterBody3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# First-Person Character Controller for «Кока-Коля»
# Features: Плавная кинестетика, присед (Crouch), покачивание головы (Headbob),
# наклон камеры при стрейфах, амортизация приземления, динамический FOV и отзывчивый HUD.

@export var walk_speed: float = 4.8
@export var sprint_speed: float = 7.5
@export var crouch_speed: float = 2.4
@export var jump_velocity: float = 5.2
@export var mouse_sensitivity: float = 0.0025
@export var gamepad_look_sensitivity: float = 2.5
@export var push_force: float = 2.2

# Camera & Head
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var inventory_label: Label = get_node_or_null("HUD/InventoryLabel")
@onready var crosshair: ColorRect = get_node_or_null("HUD/Crosshair")
@onready var grabber: Node3D = $Head/Camera3D/PhysicsGrabber
@onready var inventory_manager: Node = get_node_or_null("InventoryManager")

@onready var interaction_badge: PanelContainer = get_node_or_null("HUD/InteractionBadge")
@onready var action_label: Label = get_node_or_null("HUD/InteractionBadge/Margin/VBox/HBoxMain/ActionLabel")
@onready var key_label: Label = get_node_or_null("HUD/InteractionBadge/Margin/VBox/HBoxMain/KeyLabel")
@onready var sub_hint_label: Label = get_node_or_null("HUD/InteractionBadge/Margin/VBox/SubHintLabel")
@onready var step_banner: PanelContainer = get_node_or_null("HUD/StepBanner")
@onready var step_title: Label = get_node_or_null("HUD/StepBanner/Margin/VBox/StepTitle")
@onready var step_detail: Label = get_node_or_null("HUD/StepBanner/Margin/VBox/StepDetail")

# Physics state
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var mouse_captured: bool = true

# Crouch state
var is_crouching: bool = false
const STAND_HEIGHT: float = 1.65
const CROUCH_HEIGHT: float = 1.05
const STAND_CAPSULE_HEIGHT: float = 1.8
const CROUCH_CAPSULE_HEIGHT: float = 1.0

# Headbob & Camera tilt
var bob_timer: float = 0.0
var landing_dip: float = 0.0
var base_fov: float = 85.0
var mouse_delta_accum: Vector2 = Vector2.ZERO
var current_target_state: String = ""

# Input buffering & Coyote time
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
const COYOTE_TIME: float = 0.15

# Health & Vitals
var health: float = 100.0
var max_health: float = 100.0
var low_hp_warned: bool = false
const JUMP_BUFFER_TIME: float = 0.12

var was_on_floor: bool = true
var footstep_distance: float = 0.0
const FOOTSTEP_INTERVAL: float = 2.2

var radial_wheel: Node = null
var hud_radar: Node = null
var hotbar: Node = null

func _ready() -> void:
	floor_snap_length = 0.35
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(46.0)
	capture_mouse(true)
	if camera:
		camera.make_current()
		base_fov = camera.fov

	# Загрузка чувствительности мыши из настроек
	if has_node("/root/SettingsManager"):
		var sm: Node = get_node("/root/SettingsManager")
		mouse_sensitivity = float(sm.call("get_val", "controls", "mouse_sensitivity", mouse_sensitivity))
		sm.connect("settings_changed", func(cat: String) -> void:
			if cat == "controls" or cat == "all":
				mouse_sensitivity = float(sm.call("get_val", "controls", "mouse_sensitivity", mouse_sensitivity))
		)

	if grabber and grabber.has_signal("prompt_updated"):
		grabber.connect("prompt_updated", func(txt: String) -> void:
			if prompt_label:
				prompt_label.text = txt
			_update_interaction_badge(txt)
		)

	if grabber and grabber.has_signal("target_state_changed"):
		grabber.connect("target_state_changed", _on_target_state_changed)

	if inventory_manager:
		inventory_manager.call("setup", self, camera, grabber)
		if inventory_label:
			inventory_label.visible = false

	# Инициализация адаптивного киберпанк-хотбара в HUD
	var hotbar_script = load("res://scripts/ui/cyberpunk_hotbar.gd")
	if hotbar_script:
		var hud_node = get_node_or_null("HUD")
		if hud_node:
			hotbar = hotbar_script.new()
			hud_node.add_child(hotbar)
			if hotbar.has_method("setup") and inventory_manager:
				hotbar.call("setup", inventory_manager)

	if has_node("/root/CyberdeckManager"):
		var cdm: Node = get_node("/root/CyberdeckManager")
		if "purchased_upgrades" in cdm:
			apply_cyberdeck_upgrades(cdm.purchased_upgrades)
		if cdm.has_signal("upgrade_purchased"):
			cdm.connect("upgrade_purchased", func(_id: String) -> void:
				apply_cyberdeck_upgrades(cdm.purchased_upgrades)
			)

	var rw_script = load("res://scripts/ui/weapon_radial_wheel.gd")
	if rw_script:
		radial_wheel = CanvasLayer.new()
		radial_wheel.set_script(rw_script)
		add_child(radial_wheel)
		if radial_wheel.has_method("setup"):
			radial_wheel.call("setup", self, inventory_manager)

	var radar_script = load("res://scripts/ui/hud_radar.gd")
	if radar_script:
		hud_radar = CanvasLayer.new()
		hud_radar.set_script(radar_script)
		add_child(hud_radar)
		if hud_radar.has_method("setup"):
			hud_radar.call("setup", self, camera)

func _on_target_state_changed(state: String) -> void:
	current_target_state = state
	if not crosshair:
		return
	match state:
		"grabbable":
			crosshair.color = Color(1.0, 0.85, 0.2, 0.95)
		"interactable", "vehicle":
			crosshair.color = Color(0.2, 0.9, 1.0, 0.95)
		"cargo_snap":
			crosshair.color = Color(0.3, 1.0, 0.4, 1.0)
		"holding":
			crosshair.color = Color(1.0, 0.5, 0.2, 0.9)
		_:
			crosshair.color = Color(1, 1, 1, 0.75)

func _update_interaction_badge(txt: String) -> void:
	if not interaction_badge:
		return
	if txt.is_empty():
		interaction_badge.visible = false
		return

	interaction_badge.visible = true
	var is_holding: bool = (grabber and grabber.get("held_body") != null)
	if sub_hint_label:
		sub_hint_label.visible = is_holding

	if action_label:
		var clean_text := txt
		if clean_text.begins_with("Нажмите [E] — "):
			clean_text = clean_text.substr(14)
			if key_label:
				key_label.text = "[ E ]"
				key_label.visible = true
		elif clean_text.begins_with("[E]"):
			clean_text = clean_text.substr(3).strip_edges()
			if key_label:
				key_label.text = "[ E ]"
				key_label.visible = true
		action_label.text = clean_text

func set_step_guidance(title: String, detail: String) -> void:
	if step_banner:
		step_banner.visible = true
	if step_title:
		step_title.text = title.to_upper()
	if step_detail:
		step_detail.text = detail
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "hint", -4.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_Q:
		if event.pressed and not event.echo:
			if is_instance_valid(radial_wheel) and radial_wheel.has_method("open_wheel"):
				radial_wheel.call("open_wheel")
				return
		elif not event.pressed:
			if is_instance_valid(radial_wheel) and radial_wheel.has_method("close_wheel"):
				radial_wheel.call("close_wheel")
				return

	var is_wheel_open: bool = is_instance_valid(radial_wheel) and radial_wheel.get("is_wheel_open") == true
	if is_wheel_open:
		return

	if event is InputEventMouseMotion and mouse_captured:
		# Если игрок не вращает удерживаемый предмет правой кнопкой мыши
		var is_rotating_item := false
		if grabber and grabber.get("is_rotating_held") == true:
			is_rotating_item = true

		if not is_rotating_item:
			mouse_delta_accum += event.relative
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))

	if event is InputEventMouseButton and event.pressed:
		if not mouse_captured:
			capture_mouse(true)

	if event.is_action_just_pressed("ui_cancel"):
		capture_mouse(not mouse_captured)

func capture_mouse(captured: bool) -> void:
	mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	# 1. Присед (Crouch)
	is_crouching = Input.is_action_pressed("crouch")
	var target_head_y := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	head.position.y = lerpf(head.position.y, target_head_y + landing_dip, 14.0 * delta)

	# Плавная амортизация приземления
	landing_dip = lerpf(landing_dip, 0.0, 10.0 * delta)

	# Настройка коллизии капсулы под присед
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var cap := collision_shape.shape as CapsuleShape3D
		var target_h := CROUCH_CAPSULE_HEIGHT if is_crouching else STAND_CAPSULE_HEIGHT
		cap.height = lerpf(cap.height, target_h, 12.0 * delta)
		collision_shape.position.y = cap.height * 0.5

	# 2. Гравитация и проверка касания земли
	if is_on_floor():
		coyote_timer = COYOTE_TIME
		if not was_on_floor:
			landing_dip = -0.14
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				am.call("play_sfx", "land", -5.0)
			var root_n = get_parent() if get_parent() else self
			ImpactFX.spawn_dust(root_n, global_position + Vector3(0, 0.05, 0), 10)
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		velocity.y -= gravity * delta
	was_on_floor = is_on_floor()

	# 3. Прыжок с буферизацией ввода
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0 and not is_crouching:
		velocity.y = jump_velocity
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "jump", -4.0)

	# 4. Геймпад
	if mouse_captured:
		var look_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var look_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if absf(look_x) > 0.15 or absf(look_y) > 0.15:
			rotate_y(-look_x * gamepad_look_sensitivity * delta)
			head.rotate_x(-look_y * gamepad_look_sensitivity * delta)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))

	# 5. Вектор движения и скорости
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var is_sprinting := Input.is_action_pressed("sprint") and not is_crouching and input_dir.y < -0.1
	var target_speed := walk_speed
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed

	var accel := 32.0 if is_on_floor() else 3.8
	if direction.length_squared() > 0.001:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, accel * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, accel * delta)
	else:
		var decel := 36.0 if is_on_floor() else 1.2
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
		velocity.z = move_toward(velocity.z, 0.0, decel * delta)

	# 6. Физическое перемещение
	move_and_slide()

	# 7. Физическое расталкивание RigidBody3D с учетом массы и точки контакта
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is RigidBody3D:
			var rb := collider as RigidBody3D
			# Не толкаем предмет, если сами его сейчас держим
			if grabber and grabber.get("held_body") == rb:
				continue
			var push_dir := -collision.get_normal()
			push_dir.y = 0.0
			if push_dir.length_squared() > 0.001:
				push_dir = push_dir.normalized()
				var player_mass: float = 75.0
				var obj_mass: float = maxf(rb.mass, 1.0)
				var effective_mass: float = (player_mass * obj_mass) / (player_mass + obj_mass)
				var player_speed: float = Vector2(velocity.x, velocity.z).length()
				var impulse_mag: float = effective_mass * maxf(player_speed, 1.2) * 0.14 * push_force
				var rel_contact: Vector3 = collision.get_position() - rb.global_position
				rb.apply_impulse(push_dir * impulse_mag, rel_contact)

	# 8. Headbob (покачивание головы при ходьбе) и наклон камеры
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal_speed > 0.5:
		var bob_speed := 10.0 if is_sprinting else 7.0
		bob_timer += delta * bob_speed
		var bob_x := cos(bob_timer * 0.5) * (0.025 if is_sprinting else 0.015)
		var bob_y := sin(bob_timer) * (0.035 if is_sprinting else 0.02)
		camera.position.x = lerpf(camera.position.x, bob_x, 14.0 * delta)
		camera.position.y = lerpf(camera.position.y, bob_y, 14.0 * delta)

		# Звуки шагов (в приседе в 2 раза тише и реже)
		var interval := FOOTSTEP_INTERVAL * 1.6 if is_crouching else FOOTSTEP_INTERVAL
		footstep_distance += horizontal_speed * delta
		if footstep_distance >= interval:
			footstep_distance = 0.0
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				var vol := -18.0 if is_crouching else -9.0
				am.call("play_sfx", "footstep", vol, randf_range(0.9, 1.1))
	else:
		camera.position.x = lerpf(camera.position.x, 0.0, 10.0 * delta)
		camera.position.y = lerpf(camera.position.y, 0.0, 10.0 * delta)
		footstep_distance = minf(footstep_distance, FOOTSTEP_INTERVAL * 0.5)

	# 9. Наклон камеры при стрейфах (Roll tilt)
	var target_tilt := -input_dir.x * deg_to_rad(1.8)
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, 8.0 * delta)

	# 10. Динамический FOV
	var target_fov := base_fov
	if is_sprinting and direction.length_squared() > 0.01:
		target_fov = base_fov + 8.0
	elif is_crouching:
		target_fov = base_fov - 5.0
	camera.fov = lerpf(camera.fov, target_fov, 8.0 * delta)

	# 11. Плавный динамический прицел (Dynamic Crosshair Spread)
	if crosshair:
		var spread_bonus := clampf(horizontal_speed * 0.75, 0.0, 4.0)
		var base_sz: float = 4.0
		match current_target_state:
			"grabbable", "interactable", "vehicle":
				base_sz = 8.0
			"cargo_snap":
				base_sz = 10.0
			"holding":
				base_sz = 6.0
			_:
				base_sz = 4.0
		var target_sz := base_sz + spread_bonus
		var half_sz := target_sz * 0.5
		crosshair.offset_left = -half_sz
		crosshair.offset_top = -half_sz
		crosshair.offset_right = half_sz
		crosshair.offset_bottom = half_sz

	# 12. Инерция и покачивание манипулятора (Weapon Sway)
	if grabber:
		var sway_x := -mouse_delta_accum.x * 0.0003 - input_dir.x * 0.012
		var sway_y := mouse_delta_accum.y * 0.0003 - (0.015 if is_sprinting else 0.0)
		grabber.position.x = lerpf(grabber.position.x, sway_x, 10.0 * delta)
		grabber.position.y = lerpf(grabber.position.y, sway_y, 10.0 * delta)
	mouse_delta_accum = mouse_delta_accum.lerp(Vector2.ZERO, 10.0 * delta)


func take_damage(amount: float, impulse_dir: Vector3 = Vector3.ZERO, impulse_force: float = 0.0) -> void:
	health = maxf(0.0, health - amount)
	LogManager.info("Коля получил урон: %.1f. Текущее HP: %.1f" % [amount, health], "PLAYER")
	if impulse_force > 0.0:
		velocity += impulse_dir.normalized() * impulse_force
	if health <= 30.0 and not low_hp_warned:
		low_hp_warned = true
		if has_node("/root/VoiceManager"):
			var vm: Node = get_node("/root/VoiceManager")
			vm.call("speak_kolya", "kolya_low_hp", "Чёрт, броня трещит... Надо срочно бахнуть баночку ледяной колы!")

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	if health > 40.0:
		low_hp_warned = false

func apply_cyberdeck_upgrades(upgrades: Dictionary) -> void:
	if upgrades.get("player_suit", false):
		max_health = 150.0
		health = max_health
		sprint_speed = 8.5
		walk_speed = 5.2
	LogManager.info("[АПГРЕЙД]: Применены улучшения КПК к Коле (Max HP: %.0f, Sprint: %.1f)" % [max_health, sprint_speed], "PLAYER")
