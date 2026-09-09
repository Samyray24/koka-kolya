class_name CitadelPenthouseLevel
extends Node3D

# Уровень 4: Цитадель Синдиката (Финальная миссия кампании)
# Коля и СашаV штурмуют пентхаус Цитадели, нейтрализуют элитную охрану,
# взламывают квантовый мейнфрейм и эвакуируются через вертолётную площадку.

signal mission_completed()

var stage: int = 1
# Стадии миссии:
# 1: Проникновение в пентхаус (infiltrate_penthouse)
# 2: Нейтрализация элитного стража и взлом камеры (neutralize_guard)
# 3: Взлом квантового мейнфрейма (hack_mainframe)
# 4: Эвакуация на вертолётную площадку (helipad_extraction)

@onready var player: CharacterBody3D = $Player
@onready var drone: Node = $BubbleDrone
@onready var guard: CharacterBody3D = $EliteGuard
@onready var terminal: Node3D = $ServerRoom/MainframeTerminal
@onready var cctv: Node3D = $ServerRoom/CCTV_Penthouse
@onready var helipad_trigger: Area3D = $RooftopHelipad/HelipadTrigger
@onready var victory_panel: Control = $HUD/VictoryPanel
@onready var mission_label: Label = $HUD/MissionPanel/Margin/VBox/Objectives
@onready var radio_text: Label = $HUD/RadioPanel/Margin/VBox/Text
@onready var mission_mgr: Node = $MissionManager
@onready var dialogue_mgr: Node = $DialogueManager

var waypoint_node: Node3D = null
var waypoint_mesh: MeshInstance3D = null
var waypoint_light: OmniLight3D = null
var waypoint_label: Label3D = null
var current_target_pos: Vector3 = Vector3.ZERO
var current_target_name: String = ""
var beacon_time: float = 0.0

func _ready() -> void:
	if terminal and terminal.has_signal("plant_overridden"):
		terminal.connect("plant_overridden", _on_mainframe_hacked)

	if helipad_trigger:
		helipad_trigger.body_entered.connect(_on_helipad_entered)

	_create_waypoint_beacon()
	_spawn_penthouse_visuals()
	_start_mission_intro()
	_update_waypoint_for_stage()

func _spawn_penthouse_visuals() -> void:
	var mat_metal_ind: Material = load("res://assets/materials/mat_metal_industrial.tres")
	var mat_neon_cyan: Material = load("res://assets/materials/mat_neon_cyan.tres")
	var mat_neon_amber: Material = load("res://assets/materials/mat_neon_amber.tres")
	var mat_concrete: Material = load("res://assets/materials/mat_concrete.tres")

	# 1. Серверные стойки по бокам серверного зала
	for z_s in [8.0, 12.0, 16.0]:
		for x_s in [-6.0, 6.0]:
			var rack := MeshInstance3D.new()
			var r_box := BoxMesh.new()
			r_box.size = Vector3(1.2, 3.2, 2.0)
			rack.mesh = r_box
			if mat_metal_ind:
				rack.material_override = mat_metal_ind
			rack.position = Vector3(x_s, 1.6, z_s)
			add_child(rack)

			var led := MeshInstance3D.new()
			var l_quad := QuadMesh.new()
			l_quad.size = Vector2(0.8, 1.8)
			led.mesh = l_quad
			if mat_neon_cyan:
				led.material_override = mat_neon_cyan
			led.position = Vector3(x_s + (0.61 if x_s < 0 else -0.61), 1.6, z_s)
			led.rotation_degrees = Vector3(0, 90 if x_s < 0 else -90, 0)
			add_child(led)

	# 2. Небоскрёбы Краснограда внизу под окнами пентхауса
	var city_buildings = [
		{"type": "building_A", "pos": Vector3(-35.0, -40.0, -10.0), "scale": Vector3(6, 12, 6)},
		{"type": "building_B", "pos": Vector3(35.0, -40.0, -10.0), "scale": Vector3(6, 12, 6)},
		{"type": "building_E", "pos": Vector3(-35.0, -40.0, 25.0), "scale": Vector3(6, 14, 6)},
		{"type": "building_F", "pos": Vector3(35.0, -40.0, 25.0), "scale": Vector3(6, 14, 6)},
		{"type": "building_G", "pos": Vector3(0.0, -45.0, 55.0), "scale": Vector3(8, 15, 8)}
	]
	for b in city_buildings:
		var b_res: PackedScene = load("res://assets/scenes_3d/%s.tscn" % b["type"])
		if b_res:
			var inst: Node3D = b_res.instantiate()
			inst.name = "CitadelSkyline_%s" % b["type"]
			inst.position = b["pos"]
			inst.scale = b["scale"]
			if mat_concrete:
				_apply_material_recursive(inst, mat_concrete)
			add_child(inst)

	# 3. Неоновая голограмма Синдиката
	var holo := Label3D.new()
	holo.name = "SyndicateHologram"
	holo.position = Vector3(0.0, 4.5, 12.0)
	holo.text = "◆ МЕРИДИАН: ГЛОБАЛЬНЫЙ КОНТРОЛЬ ◆"
	holo.font_size = 28
	holo.modulate = Color(0.2, 0.9, 1.0)
	holo.outline_size = 8
	add_child(holo)


	# 4. Периметральные колонны и панорамное остекление пентхауса
	var col_positions = [
		Vector3(-19.0, 3.0, -20.0), Vector3(-19.0, 3.0, 0.0), Vector3(-19.0, 3.0, 20.0),
		Vector3(19.0, 3.0, -20.0), Vector3(19.0, 3.0, 0.0), Vector3(19.0, 3.0, 20.0),
		Vector3(-10.0, 3.0, 24.0), Vector3(10.0, 3.0, 24.0)
	]
	for pos in col_positions:
		var col := MeshInstance3D.new()
		var c_mesh := BoxMesh.new()
		c_mesh.size = Vector3(0.8, 6.5, 0.8)
		col.mesh = c_mesh
		if mat_metal_ind:
			col.material_override = mat_metal_ind
		col.position = pos
		add_child(col)

	# 5. Ограждения вертолётной площадки на крыше
	var wall_low_res: PackedScene = load("res://assets/scenes_3d/wall-low.tscn")
	if wall_low_res:
		var heli_edges = [
			Vector3(-9.2, 0.2, -32.0), Vector3(9.2, 0.2, -32.0),
			Vector3(0.0, 0.2, -41.2), Vector3(-6.0, 0.2, -41.2), Vector3(6.0, 0.2, -41.2)
		]
		for i in range(heli_edges.size()):
			var h_wall: Node3D = wall_low_res.instantiate()
			h_wall.name = "HelipadRailing_%d" % i
			h_wall.position = heli_edges[i]
			h_wall.scale = Vector3(1.6, 1.6, 1.6)
			if mat_concrete:
				_apply_material_recursive(h_wall, mat_concrete)
			add_child(h_wall)

	# 6. Угловые проблесковые огни вертолётной площадки
	var heli_lights = [
		Vector3(-8.5, 0.5, -23.5), Vector3(8.5, 0.5, -23.5),
		Vector3(-8.5, 0.5, -40.5), Vector3(8.5, 0.5, -40.5)
	]
	for i in range(heli_lights.size()):
		var hl := OmniLight3D.new()
		hl.name = "HelipadCornerLight_%d" % i
		hl.position = heli_lights[i]
		hl.light_color = Color(1.0, 0.65, 0.1)
		hl.light_energy = 2.4
		hl.omni_range = 6.0
		add_child(hl)

	# 7. Лазерные охранные лучи перед мейнфреймом
	for y_l in [0.8, 1.5, 2.2]:
		var beam := MeshInstance3D.new()
		var b_mesh := CylinderMesh.new()
		b_mesh.top_radius = 0.015
		b_mesh.bottom_radius = 0.015
		b_mesh.height = 10.0
		beam.mesh = b_mesh
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = Color(1.0, 0.1, 0.15)
		b_mat.emission_enabled = true
		b_mat.emission = Color(1.0, 0.1, 0.15)
		b_mat.emission_energy_multiplier = 4.0
		beam.material_override = b_mat
		beam.position = Vector3(0.0, y_l, 6.0)
		beam.rotation_degrees = Vector3(0, 0, 90)
		add_child(beam)

func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "CitadelWaypoint"
	add_child(waypoint_node)

	waypoint_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.4, 0.6, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.85, 1.0)
	mat.emission_energy_multiplier = 3.0
	prism.material = mat
	waypoint_mesh.mesh = prism
	waypoint_mesh.rotation_degrees = Vector3(180, 0, 0)
	waypoint_node.add_child(waypoint_mesh)

	waypoint_light = OmniLight3D.new()
	waypoint_light.light_color = Color(0.2, 0.9, 1.0)
	waypoint_light.light_energy = 2.5
	waypoint_light.omni_range = 7.0
	waypoint_node.add_child(waypoint_light)

	waypoint_label = Label3D.new()
	waypoint_label.position = Vector3(0, 0.75, 0)
	waypoint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint_label.font_size = 18
	waypoint_label.outline_size = 6
	waypoint_label.modulate = Color(0.25, 0.95, 1.0)
	waypoint_label.outline_modulate = Color(0.05, 0.15, 0.3)
	waypoint_node.add_child(waypoint_label)

func _update_waypoint_for_stage() -> void:
	match stage:
		1:
			current_target_pos = Vector3(0.0, 1.5, 4.0)
			current_target_name = "Зал пентхауса: Обезвредить охрану"
		2:
			current_target_pos = Vector3(0.0, 1.8, 12.0)
			current_target_name = "Квантовый Мейнфрейм: Взлом данных [4]"
		3:
			current_target_pos = Vector3(0.0, 2.0, -32.0)
			current_target_name = "Вертолётная площадка: Эвакуация"
		_:
			if waypoint_node:
				waypoint_node.visible = false
			return

	if waypoint_node:
		waypoint_node.visible = true
		waypoint_node.position = current_target_pos

func _process(delta: float) -> void:
	if waypoint_node and waypoint_node.visible:
		var time := Time.get_ticks_msec() / 1000.0
		var hover_y: float = sin(time * 3.5) * 0.18
		waypoint_node.position = current_target_pos + Vector3(0, hover_y, 0)
		if waypoint_mesh:
			waypoint_mesh.rotation_degrees.y = fmod(time * 75.0, 360.0)
		if waypoint_label and player:
			var dist: float = player.global_position.distance_to(current_target_pos)
			waypoint_label.text = "%s\n[ %.1f м ]" % [current_target_name, dist]

func _start_mission_intro() -> void:
	if mission_label:
		mission_label.text = "[ ] Проникнуть в серверный зал Цитадели\n[ ] Обезвредить стража и систему охраны\n[ ] Взломать квантовый мейнфрейм [4]\n[ ] Эвакуироваться на вертолётную площадку"

	if radio_text:
		radio_text.text = "[СашаV]: Коля, мы на крыше Цитадели! Главный сервер прямо перед тобой. Взломай его!"

func _on_mainframe_hacked() -> void:
	if stage < 3:
		stage = 3
		_update_waypoint_for_stage()
		if radio_text:
			radio_text.text = "[СашаV]: ДАННЫЕ СКАЧАНЫ! Рецепт в безопасности! Беги к вертолёту на площадку крыши!"
		if mission_label:
			mission_label.text = "[X] Мейнфрейм взломан!\n[ ] Эвакуироваться на вертолёте"

func _on_helipad_entered(body: Node) -> void:
	if body == player and stage >= 3:
		_on_mission_victory()

func _on_mission_victory() -> void:
	stage = 4
	if waypoint_node:
		waypoint_node.visible = false
	if victory_panel:
		victory_panel.visible = true
	if radio_text:
		radio_text.text = "[СашаV]: Мы сделали это, Коля! Город свободен, Кока-Коля возвращается в каждый дом!"
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", 2.0)
	mission_completed.emit()
