class_name GuardAI
extends CharacterBody3D

# Охранник сети MERIDIAN с честным AI и конечным автоматом (FSM)
# Состояния: IDLE -> SUSPICIOUS -> INVESTIGATING -> ALERT -> SEARCHING

enum AIState { IDLE, SUSPICIOUS, INVESTIGATING, ALERT, SEARCHING }

@export var walk_speed: float = 2.4
@export var run_speed: float = 4.8
@export var patrol_point_a: Vector3 = Vector3(-6, 0, -6)
@export var patrol_point_b: Vector3 = Vector3(6, 0, -6)

var current_state: AIState = AIState.IDLE
var target_pos: Vector3 = Vector3.ZERO
var last_known_pos: Vector3 = Vector3.ZERO
var target_player: Node3D = null
var search_timer: float = 0.0
var patrol_target_b: bool = true

@onready var vision_sensor: Node3D = get_node_or_null("AISensorVision")
@onready var hearing_sensor: Node3D = get_node_or_null("AISensorHearing")
@onready var state_label: Label3D = get_node_or_null("StateIndicator")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	target_pos = patrol_point_a
	_update_state_indicator()

	if vision_sensor:
		vision_sensor.awareness_changed.connect(_on_awareness_changed)
		vision_sensor.target_spotted.connect(_on_target_spotted)
		vision_sensor.target_lost.connect(_on_target_lost)

	if hearing_sensor:
		hearing_sensor.noise_heard.connect(_on_noise_heard)

func _physics_process(delta: float) -> void:
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

	move_and_slide()

func _process_patrol(delta: float) -> void:
	var target := patrol_point_b if patrol_target_b else patrol_point_a
	var dir := (target - global_position)
	dir.y = 0.0
	if dir.length() < 0.8:
		patrol_target_b = not patrol_target_b
	else:
		_move_towards(dir.normalized(), walk_speed, delta)

func _process_suspicious(delta: float) -> void:
	# Охранник замер и поворачивается к источнику шума/подозрения
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

func _process_alert(delta: float) -> void:
	if target_player:
		last_known_pos = target_player.global_position

	var dir := (last_known_pos - global_position)
	dir.y = 0.0
	if dir.length() > 2.0:
		_move_towards(dir.normalized(), run_speed, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		_look_at_pos(last_known_pos, delta)

func _process_searching(delta: float) -> void:
	search_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	
	# Медленно оглядывается по сторонам
	rotate_y(0.8 * delta)

	if search_timer <= 0.0:
		LogManager.info("Охранник не обнаружил целей и вернулся к патрулю.", "AI")
		_transition_to(AIState.IDLE)

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

func _transition_to(new_state: AIState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	_update_state_indicator()

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

func _on_awareness_changed(pct: float) -> void:
	if current_state == AIState.ALERT:
		return
	if pct >= 100.0:
		_transition_to(AIState.ALERT)
	elif pct >= 40.0 and current_state != AIState.INVESTIGATING:
		_transition_to(AIState.SUSPICIOUS)

func _on_target_spotted(target: Node3D, pos: Vector3) -> void:
	target_player = target
	last_known_pos = pos
	_transition_to(AIState.ALERT)
	LogManager.warn("AI обнаружил игрока в прямой видимости!", "AI")

func _on_target_lost(pos: Vector3) -> void:
	last_known_pos = pos
	search_timer = 5.5
	_transition_to(AIState.SEARCHING)
	LogManager.info("AI потерял цель из вида, начат секторный поиск.", "AI")

func _on_noise_heard(origin: Vector3, _intensity: float, noise_type: String) -> void:
	if current_state == AIState.ALERT:
		return
	last_known_pos = origin
	LogManager.info("AI среагировал на акустический стимул [%s] и идет на проверку." % noise_type, "AI")
	_transition_to(AIState.INVESTIGATING)
