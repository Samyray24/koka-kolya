class_name GuardAI
extends CharacterBody3D

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

# Охранник сети MERIDIAN с честным AI и конечным автоматом (FSM)
# Состояния: IDLE -> SUSPICIOUS -> INVESTIGATING -> ALERT -> SEARCHING

enum AIState { IDLE, SUSPICIOUS, INVESTIGATING, ALERT, SEARCHING, STUNNED }

@export var walk_speed: float = 2.4
@export var run_speed: float = 4.8
@export var patrol_point_a: Vector3 = Vector3(-6, 0, -6)
@export var patrol_point_b: Vector3 = Vector3(6, 0, -6)

var current_state: AIState = AIState.IDLE
var target_pos: Vector3 = Vector3.ZERO
var last_known_pos: Vector3 = Vector3.ZERO
var target_player: Node3D = null
var search_timer: float = 0.0
var stun_timer: float = 0.0
var patrol_target_b: bool = true
@export var max_health: float = 100.0
var current_health: float = 100.0

var tactical_flashlight: SpotLight3D = null
var search_voice_cooldown: float = 0.0
var idle_banter_timer: float = 30.0

@onready var vision_sensor: Node3D = get_node_or_null("AISensorVision")
@onready var hearing_sensor: Node3D = get_node_or_null("AISensorHearing")
@onready var state_label: Label3D = get_node_or_null("StateIndicator")
@onready var anim_player: AnimationPlayer = get_node_or_null("Model/AnimationPlayer")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	target_pos = patrol_point_a
	_setup_flashlight()
	_update_state_indicator()
	_play_anim("Idle")

	var mat_guard: Material = load("res://assets/materials/mat_guard_armor.tres")
	if mat_guard:
		var model_node: Node3D = get_node_or_null("Model")
		if model_node:
			for child in model_node.find_children("*", "MeshInstance3D", true, false):
				var mi := child as MeshInstance3D
				if mi:
					mi.material_override = mat_guard

	if vision_sensor:
		vision_sensor.awareness_changed.connect(_on_awareness_changed)
		vision_sensor.target_spotted.connect(_on_target_spotted)
		vision_sensor.target_lost.connect(_on_target_lost)

	if hearing_sensor:
		hearing_sensor.noise_heard.connect(_on_noise_heard)

func _play_anim(anim_name: String) -> void:
	if not anim_player:
		anim_player = get_node_or_null("Model/AnimationPlayer")
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)

func _physics_process(delta: float) -> void:
	search_voice_cooldown = maxf(0.0, search_voice_cooldown - delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	match current_state:
		AIState.IDLE:
			_process_patrol(delta)
		AIState.SUSPICIOUS:
			_process_suspicious(delta)
		AIState.INVESTIGATING:
			_process_investigating(delta)
		AIState.ALERT:
			_process_alert(delta)
		AIState.SEARCHING:
			_process_searching(delta)
		AIState.STUNNED:
			_process_stunned(delta)

	move_and_slide()

func _process_patrol(delta: float) -> void:
	idle_banter_timer -= delta
	if idle_banter_timer <= 0.0:
		idle_banter_timer = randf_range(40.0, 75.0)
		if has_node("/root/VoiceManager"):
			var vm: Node = get_node("/root/VoiceManager")
			vm.call("speak_guard", "guard_idle_banter", "Опять смена двенадцать часов... Хоть бы банку колы кто подогнал...")

	var target := patrol_point_b if patrol_target_b else patrol_point_a
	var dir := (target - global_position)
	dir.y = 0.0
	if dir.length() < 0.8:
		patrol_target_b = not patrol_target_b
		_play_anim("Idle")
	else:
		_move_towards(dir.normalized(), walk_speed, delta)
		_play_anim("Walking_A")

func _process_suspicious(delta: float) -> void:
	# Охранник замер и поворачивается к источнику шума/подозрения
	_play_anim("Idle")
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	_look_at_pos(last_known_pos, delta)

func _process_investigating(delta: float) -> void:
	var dir := (last_known_pos - global_position)
	dir.y = 0.0
	if dir.length() < 1.2:
		# Прибыл на место подозрения, начинаем осмотр
		_transition_to(AIState.SEARCHING)
	else:
		_move_towards(dir.normalized(), walk_speed * 1.2, delta)
		_play_anim("Walking_A")

func _process_alert(delta: float) -> void:
	if target_player:
		last_known_pos = target_player.global_position

	var dir := (last_known_pos - global_position)
	dir.y = 0.0
	if dir.length() > 2.0:
		_move_towards(dir.normalized(), run_speed, delta)
		_play_anim("Running_A")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_look_at_pos(last_known_pos, delta)
		_play_anim("1H_Melee_Attack_Chop" if anim_player and anim_player.has_animation("1H_Melee_Attack_Chop") else "Idle")

func _process_searching(delta: float) -> void:
	search_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	_play_anim("Walking_A")
	
	# Медленно оглядывается по сторонам
	rotate_y(0.8 * delta)

	if search_timer <= 0.0:
		LogManager.info("Охранник не обнаружил целей и вернулся к патрулю.", "AI")
		_transition_to(AIState.IDLE)

func _process_stunned(delta: float) -> void:
	_play_anim("Death_A")
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	stun_timer -= delta
	if stun_timer <= 0.0:
		LogManager.info("AI оправился от электрошока.", "AI")
		_transition_to(AIState.SEARCHING)
		search_timer = 4.0

func apply_stun(duration: float) -> void:
	stun_timer = duration
	_transition_to(AIState.STUNNED)
	LogManager.warn("AI оглушён электрошоком на %.1f с!" % duration, "AI")

func take_damage(amount: float, impulse_dir: Vector3 = Vector3.ZERO, impulse_force: float = 0.0) -> void:
	current_health -= amount

	# Применение физического импульса отдачи к скорости
	if impulse_force > 0.0:
		var push := impulse_dir.normalized() * impulse_force
		velocity.x += push.x
		velocity.z += push.z
		velocity.y += clampf(impulse_force * 0.22, 1.2, 5.5)

	_flash_hit()
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "shield_hit", -2.0, randf_range(0.95, 1.1))
		am.call("play_sfx", "impact", 0.0, randf_range(0.9, 1.1))

	var parent_node = get_parent() if get_parent() else self
	ImpactFX.spawn_shield_ripple(parent_node, global_position + Vector3(0, 1.2, 0), -impulse_dir)
	ImpactFX.spawn_sparks(parent_node, global_position + Vector3(0, 1.2, 0), -impulse_dir, 10)

	if impulse_force >= 14.0 or current_health <= 0.0:
		apply_stun(3.5 if current_health > 0.0 else 100.0)
		if current_health <= 0.0:
			_play_anim("Death_A")
			set_collision_layer_value(2, false)
	else:
		if current_state != AIState.STUNNED:
			_transition_to(AIState.ALERT)

func _flash_hit() -> void:
	for child in find_children("*", "MeshInstance3D", true, false):
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			var prev_mat = mi.material_override
			var flash_mat := StandardMaterial3D.new()
			flash_mat.albedo_color = Color(1.0, 0.2, 0.2)
			flash_mat.emission_enabled = true
			flash_mat.emission = Color(1.0, 0.1, 0.1)
			flash_mat.emission_energy_multiplier = 2.0
			mi.material_override = flash_mat
			var tw := mi.create_tween()
			tw.tween_interval(0.12)
			tw.tween_callback(func(): mi.material_override = prev_mat)
			break

func _move_towards(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, dir.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 18.0 * delta)
	_look_at_pos(global_position + dir * 5.0, delta)

func _look_at_pos(target: Vector3, delta: float) -> void:
	var target_flat := Vector3(target.x, global_position.y, target.z)
	var diff := target_flat - global_position
	if diff.length_squared() > 0.01:
		var target_yaw := atan2(-diff.x, -diff.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 6.0 * delta)

func _setup_flashlight() -> void:
	tactical_flashlight = SpotLight3D.new()
	tactical_flashlight.name = "TacticalFlashlight"
	tactical_flashlight.position = Vector3(0, 1.45, -0.3)
	tactical_flashlight.rotation_degrees = Vector3(0, 180, 0)
	tactical_flashlight.light_color = Color(0.85, 0.95, 1.0)
	tactical_flashlight.spot_range = 22.0
	tactical_flashlight.spot_angle = 32.0
	tactical_flashlight.light_energy = 2.4
	tactical_flashlight.visible = false
	add_child(tactical_flashlight)

func _update_flashlight() -> void:
	if not tactical_flashlight:
		return
	match current_state:
		AIState.IDLE:
			tactical_flashlight.visible = false
		AIState.SUSPICIOUS, AIState.INVESTIGATING, AIState.SEARCHING:
			tactical_flashlight.visible = true
			tactical_flashlight.light_color = Color(0.85, 0.95, 1.0)
			tactical_flashlight.light_energy = 2.4
			tactical_flashlight.spot_angle = 34.0
		AIState.ALERT:
			tactical_flashlight.visible = true
			tactical_flashlight.light_color = Color(1.0, 0.2, 0.2)
			tactical_flashlight.light_energy = 3.5
			tactical_flashlight.spot_angle = 40.0
		AIState.STUNNED:
			tactical_flashlight.visible = false

func _transition_to(new_state: AIState) -> void:
	if current_state == new_state:
		return
	var prev_state = current_state
	current_state = new_state
	_update_state_indicator()
	_update_flashlight()

	if new_state == AIState.ALERT and prev_state != AIState.ALERT:
		if has_node("/root/VoiceManager"):
			var vm: Node = get_node("/root/VoiceManager")
			vm.call("speak_guard", "guard_alert", "Внимание всем постам! Нарушитель на периметре, перекрыть все выходы и открыть огонь!")
	elif (new_state == AIState.SEARCHING or new_state == AIState.INVESTIGATING) and search_voice_cooldown <= 0.0:
		search_voice_cooldown = 25.0
		if has_node("/root/VoiceManager"):
			var vm: Node = get_node("/root/VoiceManager")
			vm.call("speak_guard", "guard_search", "Выходи по-хорошему! Всё равно все выходы перекрыты!")

func _update_state_indicator() -> void:
	if not state_label:
		return
	match current_state:
		AIState.IDLE:
			state_label.text = ""
			state_label.modulate = Color.WHITE
		AIState.SUSPICIOUS:
			state_label.text = "?"
			state_label.modulate = Color.YELLOW
		AIState.INVESTIGATING:
			state_label.text = "?!"
			state_label.modulate = Color.ORANGE
		AIState.ALERT:
			state_label.text = "!"
			state_label.modulate = Color.RED
		AIState.SEARCHING:
			state_label.text = "?"
			state_label.modulate = Color.CYAN
		AIState.STUNNED:
			state_label.text = "*_*⚡"
			state_label.modulate = Color.PURPLE

func _on_awareness_changed(pct: float) -> void:
	if current_state == AIState.ALERT or current_state == AIState.STUNNED:
		return
	if pct >= 100.0:
		_transition_to(AIState.ALERT)
	elif pct >= 40.0 and current_state != AIState.INVESTIGATING:
		_transition_to(AIState.SUSPICIOUS)

func _on_target_spotted(target: Node3D, pos: Vector3) -> void:
	if current_state == AIState.STUNNED:
		return
	target_player = target
	last_known_pos = pos
	_transition_to(AIState.ALERT)
	LogManager.warn("AI обнаружил игрока в прямой видимости!", "AI")

func _on_target_lost(pos: Vector3) -> void:
	if current_state == AIState.STUNNED:
		return
	last_known_pos = pos
	search_timer = 5.5
	_transition_to(AIState.SEARCHING)
	LogManager.info("AI потерял цель из вида, начат секторный поиск.", "AI")

func _on_noise_heard(origin: Vector3, _intensity: float, noise_type: String) -> void:
	if current_state == AIState.ALERT or current_state == AIState.STUNNED:
		return
	last_known_pos = origin
	LogManager.info("AI среагировал на акустический стимул [%s] и идет на проверку." % noise_type, "AI")
	_transition_to(AIState.INVESTIGATING)
