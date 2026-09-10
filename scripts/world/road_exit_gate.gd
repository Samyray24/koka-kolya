class_name RoadExitGate
extends Node3D

# RoadExitGate — Физический дорожный портал перехода между районами Краснограда
# Устанавливается на границах дорог, автомагистралей и тоннелей.
# Включает:
# - Процедурную неоновую арку с голографическими информационными табло
# - Триггер Area3D для фургона и Коли
# - Регистрацию в группе exit_gate для отображения на тактическом GPS-радаре

@export var target_district_id: String = "city_highway"
@export var gate_title: String = "СКОРОСТНОЕ ШОССЕ"
@export var direction_hint: String = "Выезд на скоростную автомагистраль и КПП №2"
@export var gate_width: float = 18.0
@export var gate_height: float = 7.0

var trigger_area: Area3D = null
var is_transitioning: bool = false
var prompt_label_3d: Label3D = null
var active_body_in_zone: Node = null
var zone_timer: float = 0.0
const AUTO_TRANSITION_DELAY: float = 0.6

func _ready() -> void:
	add_to_group("exit_gate")
	_build_visual_arch()
	_build_trigger_area()
	set_process_unhandled_input(true)
	set_process(true)

func _process(delta: float) -> void:
	if is_transitioning:
		return
	if is_instance_valid(active_body_in_zone):
		zone_timer += delta
		if zone_timer >= AUTO_TRANSITION_DELAY:
			execute_transition()

func _build_visual_arch() -> void:
	# 1. Материалы опор и неона
	var mat_frame := StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.12, 0.14, 0.18)
	mat_frame.metallic = 0.85
	mat_frame.roughness = 0.25

	var mat_neon := StandardMaterial3D.new()
	mat_neon.albedo_color = Color(0.1, 0.85, 1.0)
	mat_neon.emission_enabled = true
	mat_neon.emission = Color(0.15, 0.9, 1.0)
	mat_neon.emission_energy_multiplier = 3.5

	var mat_hazard := StandardMaterial3D.new()
	mat_hazard.albedo_color = Color(1.0, 0.8, 0.1)
	mat_hazard.emission_enabled = true
	mat_hazard.emission = Color(1.0, 0.75, 0.1)
	mat_hazard.emission_energy_multiplier = 2.0

	var half_w := gate_width * 0.5

	# 2. Левая и правая несущие колонны
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(1.2, gate_height, 1.2)
		pillar.mesh = p_mesh
		pillar.material_override = mat_frame
		pillar.position = Vector3(side * half_w, gate_height * 0.5, 0)
		add_child(pillar)

		# Неоновая полоса на колонне
		var neon_strip := MeshInstance3D.new()
		var n_mesh := BoxMesh.new()
		n_mesh.size = Vector3(0.3, gate_height * 0.9, 0.3)
		neon_strip.mesh = n_mesh
		neon_strip.material_override = mat_neon
		neon_strip.position = Vector3(side * half_w - (side * 0.5), gate_height * 0.5, 0.5)
		add_child(neon_strip)

		# Сигнальный маячок на верхушке
		var beacon := OmniLight3D.new()
		beacon.light_color = Color(0.2, 0.9, 1.0)
		beacon.light_energy = 2.2
		beacon.omni_range = 10.0
		beacon.position = Vector3(side * half_w, gate_height + 0.6, 0)
		add_child(beacon)

	# 3. Верхняя горизонтальная перекладина (ферма)
	var crossbar := MeshInstance3D.new()
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(gate_width + 1.2, 1.4, 1.4)
	crossbar.mesh = c_mesh
	crossbar.material_override = mat_frame
	crossbar.position = Vector3(0, gate_height, 0)
	add_child(crossbar)

	# Неоновый карниз под перекладиной
	var neon_bar := MeshInstance3D.new()
	var nb_mesh := BoxMesh.new()
	nb_mesh.size = Vector3(gate_width - 1.0, 0.25, 0.25)
	neon_bar.mesh = nb_mesh
	neon_bar.material_override = mat_neon
	neon_bar.position = Vector3(0, gate_height - 0.7, 0.6)
	add_child(neon_bar)

	# 4. Центральное световое пятно на дороге
	var road_light := SpotLight3D.new()
	road_light.light_color = Color(0.2, 0.85, 1.0)
	road_light.light_energy = 3.0
	road_light.spot_range = 18.0
	road_light.spot_angle = 50.0
	road_light.rotation_degrees = Vector3(-90, 0, 0)
	road_light.position = Vector3(0, gate_height, 0)
	add_child(road_light)

	# 5. Главное 3D-табло направления
	var title_3d := Label3D.new()
	title_3d.text = "═══ %s → ═══" % gate_title.to_upper()
	title_3d.font_size = 32
	title_3d.modulate = Color(0.2, 1.0, 0.9)
	title_3d.outline_modulate = Color(0.0, 0.2, 0.4)
	title_3d.outline_size = 8
	title_3d.position = Vector3(0, gate_height + 0.3, 0.8)
	add_child(title_3d)

	# Подсказка направления и взаимодействия
	prompt_label_3d = Label3D.new()
	prompt_label_3d.text = "%s\n[ ВЪЕХАТЬ В РАЙОН: НАЖМИТЕ E ИЛИ ПЕРЕСЕКИТЕ ЧЕРТУ ]" % direction_hint
	prompt_label_3d.font_size = 18
	prompt_label_3d.modulate = Color(1.0, 0.88, 0.3)
	prompt_label_3d.outline_modulate = Color(0.2, 0.15, 0.0)
	prompt_label_3d.outline_size = 6
	prompt_label_3d.position = Vector3(0, gate_height - 1.4, 0.8)
	add_child(prompt_label_3d)

func _build_trigger_area() -> void:
	trigger_area = Area3D.new()
	trigger_area.name = "ExitTriggerArea"
	trigger_area.collision_layer = 0
	trigger_area.collision_mask = 15 # Слой 1 (World/Rigid), 2 (Player), 4 (Van), 8 (Drone)
	add_child(trigger_area)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(gate_width, gate_height, 14.0)
	col.shape = box
	col.position = Vector3(0, gate_height * 0.5, 0)
	trigger_area.add_child(col)

	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if is_transitioning:
		return
	if body.is_in_group("player") or body.is_in_group("vehicle"):
		active_body_in_zone = body
		zone_timer = 0.0
		body.set_meta("in_exit_gate", true)
		LogManager.info("[ДОРОЖНЫЙ ПОРТАЛ]: Объект вошел в зону выезда в район «%s»" % gate_title, "WORLD")
		if prompt_label_3d:
			prompt_label_3d.modulate = Color(0.3, 1.0, 0.4)
			prompt_label_3d.text = ">>> [E] ВЪЕХАТЬ В «%s» (ИЛИ ДВИГАЙТЕСЬ ДАЛЬШЕ) <<<" % gate_title.to_upper()
		_show_hud_toast("🛣️ ВЫЕЗД: «%s» — проезжайте в створ или нажмите [E]" % gate_title)

func _on_body_exited(body: Node) -> void:
	if body == active_body_in_zone:
		body.set_meta("in_exit_gate", false)
		active_body_in_zone = null
		zone_timer = 0.0
		if prompt_label_3d:
			prompt_label_3d.modulate = Color(1.0, 0.88, 0.3)
			prompt_label_3d.text = "%s\n[ ВЪЕХАТЬ В РАЙОН: НАЖМИТЕ E ИЛИ ПЕРЕСЕКИТЕ ЧЕРТУ ]" % direction_hint

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning or not active_body_in_zone:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			execute_transition()

func execute_transition() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	LogManager.info("[ДОРОЖНЫЙ ПОРТАЛ]: Активирован переход в район «%s» (%s)" % [gate_title, target_district_id], "WORLD")

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "ui_click", 0.0)

	_show_hud_toast("🚀 Переход в район «%s»..." % gate_title)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("change_district"):
		gm.call("change_district", target_district_id, true)
	else:
		get_tree().change_scene_to_file("res://scenes/levels/%s.tscn" % target_district_id)

func _show_hud_toast(text: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("show_interaction_badge"):
		player.call("show_interaction_badge", text, "E", "Выезд из района")
	elif is_instance_valid(player) and player.has_method("set_step_guidance"):
		player.call("set_step_guidance", "ДОРОЖНЫЙ ПЕРЕХОД", text)
