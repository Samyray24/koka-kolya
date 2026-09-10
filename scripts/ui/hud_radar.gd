class_name HUDRadar
extends CanvasLayer

# HUDRadar — Круговой тактический GPS-радар Краснограда в нижнем левом углу HUD
# Проецирует положение фургона, дрона BUBBLE, противников и сюжетных целей
# с вращением сетки по направлению взгляда игрока.

@export var radar_radius: float = 78.0
@export var max_world_range: float = 110.0 # Метров до границы радара

var player_node: Node3D = null
var camera_node: Camera3D = null

var radar_root: Control = null
var radar_canvas: Control = null
var cardinal_label: Label = null
var distance_rings: Array[float] = [35.0, 70.0]

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func setup(player: Node3D, cam: Camera3D) -> void:
	player_node = player
	camera_node = cam

func _build_ui() -> void:
	radar_root = Control.new()
	radar_root.name = "RadarRoot"
	radar_root.anchors_preset = Control.PRESET_BOTTOM_LEFT
	radar_root.anchor_top = 1.0
	radar_root.anchor_bottom = 1.0
	radar_root.offset_left = 24.0
	radar_root.offset_bottom = -24.0
	radar_root.offset_right = 204.0
	radar_root.offset_top = -204.0
	add_child(radar_root)

	# Отрисовка элементов радара через кастомный Control._draw
	radar_canvas = RadarDrawControl.new()
	radar_canvas.name = "RadarCanvas"
	radar_canvas.radar_ref = self
	radar_canvas.anchors_preset = Control.PRESET_FULL_RECT
	radar_root.add_child(radar_canvas)

	cardinal_label = Label.new()
	cardinal_label.name = "CardinalLabel"
	cardinal_label.text = "GPS [100м]"
	cardinal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cardinal_label.add_theme_font_size_override("font_size", 10)
	cardinal_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 0.8))
	cardinal_label.position = Vector2(0, 162)
	cardinal_label.size = Vector2(180, 20)
	radar_root.add_child(cardinal_label)

func _process(_delta: float) -> void:
	if not player_node:
		_find_player()
	if radar_canvas:
		radar_canvas.queue_redraw()

func _find_player() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p) and p is Node3D:
		player_node = p as Node3D
		camera_node = player_node.get_node_or_null("Head/Camera3D") as Camera3D
		if not camera_node:
			camera_node = get_viewport().get_camera_3d()

# Вспомогательный класс для отрисовки векторов на 2D холсте
class RadarDrawControl extends Control:
	var radar_ref: HUDRadar = null

	func _draw() -> void:
		if not radar_ref:
			return

		var center := size * 0.5
		var r: float = radar_ref.radar_radius

		# 1. Фоновый диск радара
		draw_circle(center, r, Color(0.02, 0.05, 0.09, 0.85))

		# 2. Концентрические дальномерные кольца
		draw_arc(center, r * 0.45, 0, TAU, 32, Color(0.1, 0.7, 0.9, 0.25), 1.0)
		draw_arc(center, r * 0.85, 0, TAU, 48, Color(0.1, 0.7, 0.9, 0.35), 1.0)

		# 3. Внешний обод (мигает сине-красным при розыске)
		var rim_color := Color(0.2, 0.9, 1.0, 0.7)
		var is_wanted := false
		if radar_ref.has_node("/root/ThreatManager"):
			var tm: Node = radar_ref.get_node("/root/ThreatManager")
			if tm.call("is_wanted"):
				is_wanted = true
				var t := Time.get_ticks_msec() * 0.006
				rim_color = Color(1.0, 0.2, 0.2, 0.9) if int(t) % 2 == 0 else Color(0.2, 0.4, 1.0, 0.9)

		draw_arc(center, r, 0, TAU, 64, rim_color, 2.5 if is_wanted else 1.5)

		# 4. Сетка перекрестия
		draw_line(Vector2(center.x - r, center.y), Vector2(center.x + r, center.y), Color(0.2, 0.9, 1.0, 0.15), 1.0)
		draw_line(Vector2(center.x, center.y - r), Vector2(center.x, center.y + r), Color(0.2, 0.9, 1.0, 0.15), 1.0)

		# 5. Вычисление угла обзора камеры
		var cam_yaw := 0.0
		var p_pos := Vector3.ZERO
		if is_instance_valid(radar_ref.player_node):
			p_pos = radar_ref.player_node.global_position
			if is_instance_valid(radar_ref.camera_node):
				cam_yaw = radar_ref.camera_node.global_rotation.y
			else:
				cam_yaw = radar_ref.player_node.global_rotation.y

		# 6. Стороны света по периметру
		var cardinals := [
			{"label": "С", "angle": 0.0, "col": Color(1.0, 0.3, 0.3)},
			{"label": "В", "angle": PI * 0.5, "col": Color(0.7, 0.8, 0.9)},
			{"label": "Ю", "angle": PI, "col": Color(0.7, 0.8, 0.9)},
			{"label": "З", "angle": PI * 1.5, "col": Color(0.7, 0.8, 0.9)}
		]
		var font := ThemeDB.fallback_font
		for card in cardinals:
			var ang: float = card["angle"] - cam_yaw - (PI * 0.5)
			var pos := center + Vector2(cos(ang), sin(ang)) * (r - 12.0)
			draw_string(font, pos + Vector2(-4, 4), card["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, card["col"])

		# 7. Центральный маркер игрока (бирюзовый треугольник направления)
		var p_pts: PackedVector2Array = [
			center + Vector2(0, -7),
			center + Vector2(-5, 5),
			center + Vector2(0, 3),
			center + Vector2(5, 5)
		]
		draw_colored_polygon(p_pts, Color(0.1, 0.95, 1.0, 0.95))

		# 8. Отрисовка сущностей (Фургон, Дрон, Враги, Квестовые цели)
		_draw_tracked_entities(center, r, p_pos, cam_yaw)

	func _draw_tracked_entities(center: Vector2, r: float, p_pos: Vector3, cam_yaw: float) -> void:
		# Фургон
		var van = get_tree().get_first_node_in_group("vehicle")
		if is_instance_valid(van) and van != radar_ref.player_node:
			var v_screen := _world_to_radar(van.global_position, p_pos, cam_yaw, center, r)
			draw_rect(Rect2(v_screen.x - 4, v_screen.y - 4, 8, 8), Color(0.2, 0.6, 1.0, 0.95))
			draw_rect(Rect2(v_screen.x - 4, v_screen.y - 4, 8, 8), Color(1, 1, 1, 0.8), false, 1.0)

		# Дрон BUBBLE
		var drone = get_tree().get_first_node_in_group("bubble_drone")
		if is_instance_valid(drone):
			var d_screen := _world_to_radar(drone.global_position, p_pos, cam_yaw, center, r)
			draw_circle(d_screen, 4.0, Color(0.2, 1.0, 0.5, 0.95))

		# Враги / Патрули
		var guards = get_tree().get_nodes_in_group("enemies")
		for g in guards:
			if is_instance_valid(g) and g is Node3D:
				var g_screen := _world_to_radar(g.global_position, p_pos, cam_yaw, center, r)
				draw_circle(g_screen, 3.5, Color(1.0, 0.2, 0.2, 0.9))

		# Квестовые цели
		var targets = get_tree().get_nodes_in_group("mission_target")
		for t in targets:
			if is_instance_valid(t) and t is Node3D:
				var t_screen := _world_to_radar(t.global_position, p_pos, cam_yaw, center, r)
				var diamond: PackedVector2Array = [
					t_screen + Vector2(0, -6),
					t_screen + Vector2(6, 0),
					t_screen + Vector2(0, 6),
					t_screen + Vector2(-6, 0)
				]
				draw_colored_polygon(diamond, Color(1.0, 0.85, 0.2, 0.95))

	func _world_to_radar(world_pos: Vector3, player_pos: Vector3, cam_yaw: float, center: Vector2, max_r: float) -> Vector2:
		var diff := world_pos - player_pos
		# Проекция на горизонтальную плоскость XZ
		var flat_dist := Vector2(diff.x, diff.z).length()
		var angle := atan2(diff.z, diff.x) - cam_yaw - (PI * 0.5)

		var range_ratio := flat_dist / radar_ref.max_world_range
		var rad_dist := clampf(range_ratio * max_r, 0.0, max_r - 4.0)

		return center + Vector2(cos(angle), sin(angle)) * rad_dist
