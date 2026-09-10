class_name LogisticsHub
extends Node3D

# Район: «Логистический Хаб Меридиана»
# Особенности:
# - Стеки грузовых контейнеров (PBR металл и ржавчина)
# - Тяжелые погрузочные краны и промышленные платформы
# - Защитная лазерная сетка и охранные турели
# - Захват контейнеров с сиропом и погрузка в фургон

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const LoreTerminalScript = preload("res://scripts/interaction/lore_terminal.gd")
const LootContainerScript = preload("res://scripts/interaction/loot_container.gd")
const ExplosiveBarrelScript = preload("res://scripts/physics/explosive_barrel.gd")
const DestructibleCrateScript = preload("res://scripts/physics/destructible_crate.gd")
const VendingMachineScript = preload("res://scripts/interaction/vending_machine.gd")

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var van: VehicleBody3D = get_node_or_null("DeliveryVan")
@onready var quest_label: Label = get_node_or_null("HUD/QuestPanel/Margin/VBox/ObjectiveLabel")
@onready var radio_panel: PanelContainer = get_node_or_null("HUD/RadioPanel")
@onready var radio_speaker: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/SpeakerLabel")
@onready var radio_text: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/MessageLabel")
@onready var victory_panel: PanelContainer = get_node_or_null("HUD/VictoryPanel")

var mission_mgr: Node = null
var dialogue_mgr: Node = null
var stage: int = 1

var waypoint_node: Node3D = null
var waypoint_label: Label3D = null
var current_target_pos: Vector3 = Vector3.ZERO
var current_target_name: String = ""

var laser_barrier: Node3D = null
var laser_light: OmniLight3D = null

func _ready() -> void:
	mission_mgr = MissionManagerScript.new()
	mission_mgr.name = "MissionManager"
	add_child(mission_mgr)

	dialogue_mgr = DialogueManagerScript.new()
	dialogue_mgr.name = "DialogueManager"
	add_child(dialogue_mgr)

	dialogue_mgr.connect("message_displayed", _on_radio_message)
	dialogue_mgr.connect("dialogue_finished", _on_radio_finished)

	mission_mgr.connect("objective_added", func(_id: String, _t: String) -> void: _update_quest_ui())
	mission_mgr.connect("objective_updated", func(_id: String, _c: int, _t: int) -> void: _update_quest_ui())
	mission_mgr.connect("objective_completed", func(_id: String, _t: String) -> void: _update_quest_ui())
	mission_mgr.connect("mission_completed", _on_mission_victory)

	_build_container_terminal()
	_build_laser_security()
	_spawn_road_exit_gates()
	_create_waypoint_beacon()
	_start_mission()
	_update_waypoint()

func _build_container_terminal() -> void:
	var mat_cont: Material = load("res://assets/materials/mat_metal_corrugated_slum.tres")
	var mat_rust: Material = load("res://assets/materials/mat_metal_rust_plates.tres")
	var mat_titanium: Material = load("res://assets/materials/mat_meridian_titanium_wall.tres")
	var mat_diamond: Material = load("res://assets/materials/mat_metal_industrial_diamond.tres")

	# Контейнерные лабиринты (20 контейнеров в рядах и стеках)
	var container_positions = [
		Vector3(-18, 0, 50), Vector3(-18, 2.8, 50), Vector3(-18, 0, 36),
		Vector3(18, 0, 50), Vector3(18, 2.8, 50), Vector3(18, 0, 36),
		Vector3(-24, 0, 10), Vector3(-24, 2.8, 10), Vector3(-24, 5.6, 10),
		Vector3(24, 0, 10), Vector3(24, 2.8, 10),
		Vector3(-12, 0, -20), Vector3(-12, 2.8, -20),
		Vector3(12, 0, -20), Vector3(12, 2.8, -20), Vector3(12, 5.6, -20),
		Vector3(-20, 0, -60), Vector3(20, 0, -60),
		Vector3(0, 0, -70), Vector3(0, 2.8, -70)
	]

	for i in range(container_positions.size()):
		var c_pos = container_positions[i]
		var c_node := StaticBody3D.new()
		c_node.name = "ShippingContainer_%d" % i
		c_node.position = c_pos + Vector3(0, 1.4, 0)

		var col := CollisionShape3D.new()
		var c_box := BoxShape3D.new()
		c_box.size = Vector3(6.0, 2.8, 12.0)
		col.shape = c_box
		c_node.add_child(col)

		var mesh := MeshInstance3D.new()
		var m_box := BoxMesh.new()
		m_box.size = c_box.size
		mesh.mesh = m_box
		mesh.material_override = mat_cont if (i % 2 == 0) else mat_rust
		c_node.add_child(mesh)
		add_child(c_node)

	# Стальные платформы кранов (Diamond plate)
	var crane_platform := StaticBody3D.new()
	crane_platform.name = "CranePlatform"
	crane_platform.position = Vector3(0, 10.0, -10.0)
	var cp_col := CollisionShape3D.new()
	var cp_shape := BoxShape3D.new()
	cp_shape.size = Vector3(28.0, 0.8, 8.0)
	cp_col.shape = cp_shape
	crane_platform.add_child(cp_col)
	var cp_mesh := MeshInstance3D.new()
	var cpm := BoxMesh.new()
	cpm.size = cp_shape.size
	cp_mesh.mesh = cpm
	if mat_diamond:
		cp_mesh.material_override = mat_diamond
	crane_platform.add_child(cp_mesh)
	add_child(crane_platform)

	# Опоры крана
	for k_x in [-13.0, 13.0]:
		var leg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.8
		cyl.height = 10.0
		leg.mesh = cyl
		leg.position = Vector3(k_x, 5.0, -10.0)
		add_child(leg)

	# Промышленные прожекторы на вышках
	for light_x in [-25.0, 25.0]:
		for light_z in [60.0, -30.0]:
			var flood := SpotLight3D.new()
			flood.position = Vector3(light_x, 14.0, light_z)
			flood.rotation_degrees = Vector3(-65, 45 if light_x < 0 else -45, 0)
			flood.light_color = Color(1.0, 0.85, 0.6)
			flood.light_energy = 5.0
			flood.spot_range = 35.0
			flood.spot_angle = 50.0
			add_child(flood)

	# Интерактивные лутаемые контейнеры
	var loot1: Node3D = LootContainerScript.new()
	loot1.name = "TerminalLoot1"
	loot1.set("container_title", "Контейнер запчастей Меридиана")
	loot1.set("credits_reward", 120)
	loot1.position = Vector3(-15.0, 0.5, 40.0)
	add_child(loot1)

	var loot2: Node3D = LootContainerScript.new()
	loot2.name = "TerminalLoot2"
	loot2.set("container_title", "Сейф с крипто-чипами")
	loot2.set("credits_reward", 200)
	loot2.set("is_locked", true)
	loot2.position = Vector3(15.0, 0.5, -15.0)
	add_child(loot2)

	# Взрывные бочки
	for b_idx in range(6):
		var barrel := ExplosiveBarrelScript.new()
		barrel.name = "HubBarrel_%d" % b_idx
		barrel.position = Vector3(randf_range(-8, 8), 0.6, randf_range(-5, 45))
		add_child(barrel)

func _build_laser_security() -> void:
	# Лазерная охранная сетка перед хранилищем (Z = -45)
	laser_barrier = Node3D.new()
	laser_barrier.name = "LaserSecurityGrid"
	laser_barrier.position = Vector3(0, 1.5, -45.0)

	for b_i in range(5):
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 16.0
		beam.mesh = cyl
		beam.rotation_degrees = Vector3(0, 0, 90)
		beam.position = Vector3(0, float(b_i) * 0.7, 0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.1, 0.1)
		mat.emission_energy_multiplier = 4.0
		beam.material_override = mat
		laser_barrier.add_child(beam)

	laser_light = OmniLight3D.new()
	laser_light.light_color = Color(1.0, 0.1, 0.1)
	laser_light.light_energy = 4.0
	laser_light.omni_range = 10.0
	laser_barrier.add_child(laser_light)
	add_child(laser_barrier)

	# Терминал деактивации лазеров
	var hack_term: Node3D = LoreTerminalScript.new()
	hack_term.name = "LaserControlTerminal"
	hack_term.set("terminal_title", "Консоль управления лазерным периметром")
	hack_term.set("lore_header", "СИСТЕМА БЕЗОПАСНОСТИ ХАБА")
	hack_term.set("lore_text", "Лазерная блокировка активна. Взломайте консоль [4 / E], чтобы снять поле и открыть склад.")
	hack_term.position = Vector3(-11.0, 0.8, -40.0)
	hack_term.rotation_degrees = Vector3(0, 90, 0)
	add_child(hack_term)

	var trig := Area3D.new()
	trig.name = "LaserConsoleTrigger"
	trig.position = Vector3(-11.0, 1.0, -40.0)
	var t_col := CollisionShape3D.new()
	var t_box := BoxShape3D.new()
	t_box.size = Vector3(3.0, 2.0, 3.0)
	t_col.shape = t_box
	trig.add_child(t_col)
	trig.body_entered.connect(_on_laser_console_entered)
	add_child(trig)

	# Финальная зона эвакуации (Главные ворота, Z = -95)
	var exit_trig := Area3D.new()
	exit_trig.name = "HubExitTrigger"
	exit_trig.position = Vector3(0, 1.0, -95.0)
	var et_col := CollisionShape3D.new()
	var et_box := BoxShape3D.new()
	et_box.size = Vector3(18.0, 3.0, 8.0)
	et_col.shape = et_box
	exit_trig.add_child(et_col)
	exit_trig.body_entered.connect(_on_hub_exit_entered)
	add_child(exit_trig)

	# AAA РАСШИРЕНИЕ Хаб v2.0
	
	# небоскрёбы фона
	var bg_mat := StandardMaterial3D.new(); bg_mat.albedo_color = Color(0.12, 0.12, 0.18)
	for bi in range(5):
		var bg_b := MeshInstance3D.new()
		var bg_bm := BoxMesh.new(); bg_bm.size = Vector3(20, randf_range(40, 60), 20)
		bg_b.mesh = bg_bm; bg_b.material_override = bg_mat
		bg_b.position = Vector3(randf_range(-120, 120), bg_bm.size.y / 2, randf_range(-150, -100))
		add_child(bg_b)

	# лужи
	for pl in [Vector3(-15,0.02,20), Vector3(15,0.02,10), Vector3(0,0.02,-10), Vector3(-20,0.02,-30), Vector3(20,0.02,-50)]:
		var pd := MeshInstance3D.new()
		var pq := QuadMesh.new(); pq.size=Vector2(5.0,3.0); pq.orientation=PlaneMesh.FACE_Y
		var pm := StandardMaterial3D.new()
		pm.albedo_color=Color(0.15,0.15,0.15,0.8); pm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.metallic=0.85; pm.roughness=0.08
		pd.mesh=pq; pd.material_override=pm; pd.position=pl; add_child(pd)

	# граффити
	for gd in [{"p":Vector3(-17.9, 1.5, 40),"r":90,"t":"СВОБОДНАЯ ДОСТАВКА!"}, {"p":Vector3(17.9, 1.5, 30),"r":-90,"t":"ДОЛОЙ СИНДИКАТ!"}]:
		var g:=Label3D.new(); g.text=gd["t"]; g.font_size=28; g.modulate=Color(0.9,0.5,0.1); g.outline_size=6
		g.position=gd["p"]; g.rotation_degrees=Vector3(0,gd["r"],0); add_child(g)

	# 4 NPC грузчика
	var npc_h:PackedScene=load("res://scenes/characters/npc_character.tscn")
	if npc_h:
		for wp in [Vector3(-10,0,30), Vector3(10,0,20), Vector3(-5,0,-5), Vector3(12,0,-25)]:
			var n:Node3D=npc_h.instantiate(); n.position=wp; n.rotation_degrees=Vector3(0,randf_range(0,360),0); add_child(n)

	# трубы с дымом
	for sp in [Vector3(-25,10,-20), Vector3(25,10,-20), Vector3(-15,12,-70), Vector3(15,12,-70)]:
		var sm := CPUParticles3D.new()
		sm.position = sp; sm.amount = 25; sm.lifetime = 3.5
		sm.direction = Vector3(0.3,1,0); sm.spread = 12.0; sm.gravity = Vector3(0,1,0)
		sm.initial_velocity_min = 1.5; sm.initial_velocity_max = 3.5
		var sm_m := SphereMesh.new(); sm_m.radius = 1.2; sm_m.height = 2.4
		var sm_mat := StandardMaterial3D.new(); sm_mat.albedo_color = Color(0.3,0.3,0.3,0.5)
		sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm_m.material = sm_mat; sm.mesh = sm_m
		add_child(sm)

	# рекламные щиты логистики
	for rd in [{"p":Vector3(-18,5,15),"r":90,"t":"MERIDIAN LOGISTICS"}, {"p":Vector3(18,6,-5),"r":-90,"t":"GLOBAL CARGO"}]:
		var s:=Label3D.new(); s.text=rd["t"]; s.font_size=40; s.modulate=Color(0.2,0.6,1.0)
		s.position=rd["p"]; s.rotation_degrees=Vector3(0,rd["r"],0); s.outline_size=8; add_child(s)

func _create_waypoint_beacon() -> void:
	waypoint_node = Node3D.new()
	waypoint_node.name = "HubWaypoint"
	add_child(waypoint_node)

	var mesh := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 0.7, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	mat.emission_energy_multiplier = 3.0
	prism.material = mat
	mesh.mesh = prism
	mesh.rotation_degrees = Vector3(180, 0, 0)
	waypoint_node.add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.1)
	light.light_energy = 3.0
	light.omni_range = 8.0
	waypoint_node.add_child(light)

	waypoint_label = Label3D.new()
	waypoint_label.position = Vector3(0, 0.8, 0)
	waypoint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint_label.font_size = 18
	waypoint_label.outline_size = 6
	waypoint_node.add_child(waypoint_label)

func _start_mission() -> void:
	mission_mgr.call("start_mission", "Логистический Перехват")
	mission_mgr.call("add_objective", "infiltrate_hub", "Проникнуть в центр контейнерного терминала", 1)
	mission_mgr.call("add_objective", "disable_lasers", "Взломать консоль и отключить лазерную сетку [4 / E]", 1)
	mission_mgr.call("add_objective", "retrieve_syrup", "Забрать концентрат сиропа из хранилища", 1)
	mission_mgr.call("add_objective", "escape_hub", "Прорвать главные ворота хаба на фургоне", 1)

	dialogue_mgr.call("queue_message", "СашаV", "Коля, в этом хабе хранится весь запас концентрата! Охрана вооружена, лазеры перекрывают склад. Действуй аккуратно!", Color(0.3, 0.8, 1.0), 5.5)

func _update_waypoint() -> void:
	match stage:
		1:
			current_target_pos = Vector3(0.0, 2.0, 10.0)
			current_target_name = "Центр контейнерного терминала"
		2:
			current_target_pos = Vector3(-11.0, 2.0, -40.0)
			current_target_name = "Консоль лазерной сетки [Взлом]"
		3:
			current_target_pos = Vector3(0.0, 2.0, -65.0)
			current_target_name = "Склад концентрата сиропа"
		4:
			current_target_pos = Vector3(0.0, 2.0, -95.0)
			current_target_name = "Главные ворота: Прорыв"
		_:
			if waypoint_node:
				waypoint_node.visible = false
			return

	if waypoint_node:
		waypoint_node.visible = true
		waypoint_node.position = current_target_pos

func _process(_delta: float) -> void:
	if waypoint_node and waypoint_node.visible:
		var t := Time.get_ticks_msec() / 1000.0
		waypoint_node.position = current_target_pos + Vector3(0, sin(t * 4.0) * 0.2, 0)
		if waypoint_label and player:
			var d := player.global_position.distance_to(current_target_pos)
			waypoint_label.text = "%s\n[ %.1f м ]" % [current_target_name, d]

	if stage == 1 and player:
		if player.global_position.distance_to(current_target_pos) < 10.0:
			stage = 2
			mission_mgr.call("complete_objective", "infiltrate_hub")
			dialogue_mgr.call("queue_message", "СашаV", "Мы внутри! Впереди лазерный барьер. Найди консоль управления слева между контейнерами.", Color(0.3, 1.0, 0.4), 5.0)
			_update_waypoint()

	if stage == 3 and player:
		if player.global_position.distance_to(current_target_pos) < 8.0:
			stage = 4
			mission_mgr.call("complete_objective", "retrieve_syrup")
			dialogue_mgr.call("queue_message", "Коля", "Концентрат у нас! Садись в фургон, жми нитро на [Shift] и сноси главные ворота!", Color(1.0, 0.8, 0.2), 5.0)
			_update_waypoint()

func _on_laser_console_entered(body: Node) -> void:
	if stage == 2 and (body == player or body == van):
		stage = 3
		mission_mgr.call("complete_objective", "disable_lasers")
		if laser_barrier:
			laser_barrier.visible = false
		dialogue_mgr.call("queue_message", "СашаV", "Лазерная сетка отключена! Доступ к контейнерам открыт!", Color(0.3, 1.0, 0.4), 4.5)
		_update_waypoint()

func _on_hub_exit_entered(body: Node) -> void:
	if stage == 4 and (body == player or body == van):
		stage = 5
		mission_mgr.call("complete_objective", "escape_hub")
		_update_waypoint()

func _on_mission_victory(_title: String) -> void:
	if victory_panel:
		victory_panel.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup_victory_panel_buttons()
	if has_node("/root/GameManager"):
		var gm: Node = get_node("/root/GameManager")
		gm.call("mark_mission_completed", "mission_logistics_hub")
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "victory", 2.0)
	dialogue_mgr.call("queue_message", "СашаV", "Логистический хаб полностью под нашим контролем! Все поставки перенаправлены на наши базы!", Color(0.3, 1.0, 0.4), 6.0)
	LogManager.info(">>> ЛОГИСТИЧЕСКИЙ ХАБ УСПЕШНО ЗАХВАЧЕН! <<<", "VICTORY")

func _setup_victory_panel_buttons() -> void:
	if not victory_panel:
		return
	var vbox = victory_panel.get_node_or_null("Margin/VBox")
	if not vbox or vbox.has_node("BtnNextDistrict"):
		return

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_next := Button.new()
	btn_next.name = "BtnNextDistrict"
	btn_next.text = " ▶ СЛЕДУЮЩИЙ РАЙОН: ПОДЗЕМНЫЙ МЕТРОПОЛИТЕН "
	btn_next.custom_minimum_size = Vector2(0, 44)
	btn_next.add_theme_font_size_override("font_size", 15)
	btn_next.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	btn_next.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("change_district"):
			gm.call("change_district", "underground_metro", true)
		else:
			get_tree().change_scene_to_file("res://scenes/levels/underground_metro.tscn")
	)
	vbox.add_child(btn_next)

	var btn_map := Button.new()
	btn_map.name = "BtnOpenMap"
	btn_map.text = " 🗺️ КАРТА ГОРОДА (ВЫБОР РАЙОНА) "
	btn_map.custom_minimum_size = Vector2(0, 38)
	btn_map.pressed.connect(func() -> void:
		victory_panel.visible = false
		var cdm: Node = get_node_or_null("/root/CyberdeckManager")
		if cdm and cdm.has_method("open_pda"):
			cdm.call("open_pda")
	)
	vbox.add_child(btn_map)

	var btn_menu := Button.new()
	btn_menu.name = "BtnReturnMenu"
	btn_menu.text = " 🏠 В ГЛАВНОЕ МЕНЮ "
	btn_menu.custom_minimum_size = Vector2(0, 38)
	btn_menu.pressed.connect(func() -> void:
		var gm: Node = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("change_district"):
			gm.call("change_district", "main_menu", true)
		else:
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	vbox.add_child(btn_menu)

func _spawn_road_exit_gates() -> void:
	var gate_script = load("res://scripts/world/road_exit_gate.gd")
	if not gate_script:
		return

	# 1. Северный выезд в Подземный метрополитен (за воротами)
	var north_gate = Node3D.new()
	north_gate.set_script(gate_script)
	north_gate.name = "ExitGate_Metro"
	north_gate.set("target_district_id", "underground_metro")
	north_gate.set("gate_title", "ПОДЗЕМНЫЙ МЕТРОПОЛИТЕН")
	north_gate.set("direction_hint", "Спуск в сеть заброшенных тоннелей и секретный бункер")
	north_gate.position = Vector3(0, 0, -100)
	add_child(north_gate)

	# 2. Южный возврат на Завод Красной Линии
	var south_gate = Node3D.new()
	south_gate.set_script(gate_script)
	south_gate.name = "ExitGate_RedLinePlant"
	south_gate.set("target_district_id", "red_line_plant")
	south_gate.set("gate_title", "ЗАВОД КРАСНОЙ ЛИНИИ")
	south_gate.set("direction_hint", "Возврат к промышленному комплексу и сиропной башне")
	south_gate.position = Vector3(0, 0, 80)
	add_child(south_gate)

func _on_radio_message(speaker: String, text: String, col: Color) -> void:
	if radio_panel:
		radio_panel.visible = true
	if radio_speaker:
		radio_speaker.text = "[РАДИО: %s]" % speaker
		radio_speaker.modulate = col
	if radio_text:
		radio_text.text = text

func _on_radio_finished() -> void:
	if radio_panel:
		radio_panel.visible = false

func _update_quest_ui() -> void:
	if not quest_label or not mission_mgr:
		return
	var objectives: Dictionary = mission_mgr.get("objectives")
	var lines: Array[String] = []
	for id in objectives:
		var obj: Dictionary = objectives[id]
		var checkmark: String = "[X]" if obj["completed"] else "[ ]"
		lines.append("%s %s" % [checkmark, obj["title"]])
	quest_label.text = "\n".join(lines)
