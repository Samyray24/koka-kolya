class_name CyberpunkMenuBackground
extends Control

# CyberpunkMenuBackground — Процедурный анимированный неоновый фон для меню
# Включает:
# - Перспективную бегущую неоновую 3D-сетку (Synthwave Perspective Grid)
# - Парящие неоновые цифровые частицы (Cyber Embers / Data Particles)
# - Горизонт с неоновым свечением и виньетированием
# - Легкие CRT-сканлинии терминала без нагрузки на видеокарту

var time: float = 0.0
var grid_speed: float = 0.45

var particles: Array[Dictionary] = []
const NUM_PARTICLES: int = 40

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_init_particles()

func _init_particles() -> void:
	particles.clear()
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0:
		vp_size = Vector2(1920, 1080)
		
	var colors := [
		Color(0.15, 0.85, 1.0, 0.7),  # Неоновый Циан
		Color(1.0, 0.82, 0.2, 0.75),  # Золотой
		Color(1.0, 0.22, 0.55, 0.65), # Маджента
		Color(0.25, 1.0, 0.5, 0.6)   # Кислотно-зеленый
	]
	
	for i in range(NUM_PARTICLES):
		particles.append({
			"x": randf_range(0, vp_size.x),
			"y": randf_range(0, vp_size.y),
			"speed": randf_range(18.0, 48.0),
			"radius": randf_range(1.5, 3.2),
			"phase": randf_range(0, PI * 2.0),
			"color": colors[i % colors.size()]
		})

func _process(delta: float) -> void:
	time += delta
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 0:
		vp_size = Vector2(1920, 1080)

	# Обновление парящих частиц
	for p in particles:
		p["y"] -= p["speed"] * delta
		p["x"] += sin(time * 0.8 + p["phase"]) * 14.0 * delta
		if p["y"] < -10.0:
			p["y"] = vp_size.y + 10.0
			p["x"] = randf_range(0, vp_size.x)
		if p["x"] < -10.0:
			p["x"] = vp_size.x + 10.0
		elif p["x"] > vp_size.x + 10.0:
			p["x"] = -10.0

	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 10 or h <= 10:
		return

	# 1. Глубокий градиентный киберпанк-фон
	var top_col := Color(0.015, 0.025, 0.05, 1.0)
	var horiz_col := Color(0.06, 0.03, 0.09, 1.0)
	var bottom_col := Color(0.02, 0.04, 0.07, 1.0)

	var horizon_y := h * 0.52

	# Верхняя половина (небо над Красноградом)
	draw_rect(Rect2(0, 0, w, horizon_y), top_col)
	# Мягкое неоновое зарево у горизонта
	var glow_rect := Rect2(0, horizon_y - 90, w, 100)
	draw_rect(glow_rect, Color(0.85, 0.15, 0.35, 0.12))
	var glow_rect2 := Rect2(0, horizon_y - 40, w, 50)
	draw_rect(glow_rect2, Color(0.15, 0.8, 1.0, 0.14))

	# Нижняя половина (земля / перспективная сетка)
	draw_rect(Rect2(0, horizon_y, w, h - horizon_y), bottom_col)

	# 2. Перспективная сетка (Synthwave Grid)
	var vp_x := w * 0.5
	var vp_y := horizon_y
	var grid_color := Color(0.15, 0.75, 1.0, 0.45)
	var grid_sub := Color(0.9, 0.2, 0.45, 0.35)

	# Лучи, уходящие в перспективу
	var num_rays := 24
	for i in range(-num_rays, num_rays + 1):
		var bot_x := vp_x + float(i) * (w / float(num_rays)) * 0.85
		var col := grid_color if i % 2 == 0 else grid_sub
		draw_line(Vector2(vp_x, vp_y), Vector2(bot_x, h), col, 1.2, true)

	# Горизонтальные бегущие полосы (перспективное сжатие к горизонту)
	var num_horiz := 14
	var t_offset := fmod(time * grid_speed, 1.0)
	for j in range(num_horiz):
		var linear_t := (float(j) + t_offset) / float(num_horiz)
		var exp_t := pow(linear_t, 2.4) # Квадратичное отдаление к горизонту
		var line_y := lerpf(vp_y, h, exp_t)
		var alpha := clampf(exp_t * 0.85, 0.05, 0.75)
		var line_col := Color(0.2, 0.85, 1.0, alpha)
		var width := lerpf(0.8, 2.2, exp_t)
		draw_line(Vector2(0, line_y), Vector2(w, line_y), line_col, width, true)

	# Линия горизонта
	draw_line(Vector2(0, horizon_y), Vector2(w, horizon_y), Color(0.3, 0.95, 1.0, 0.9), 2.0, true)

	# 3. Отрисовка парящих неоновых частиц (Cyber Embers)
	for p in particles:
		var pos := Vector2(p["x"], p["y"])
		var col: Color = p["color"]
		var pulse := (sin(time * 3.0 + p["phase"]) * 0.25 + 0.75)
		var c_alpha := Color(col.r, col.g, col.b, col.a * pulse)
		draw_circle(pos, p["radius"], c_alpha)
		# Свечение ореола вокруг крупных частиц
		if p["radius"] > 2.2:
			var c_glow := Color(col.r, col.g, col.b, col.a * 0.25 * pulse)
			draw_circle(pos, p["radius"] * 2.2, c_glow)

	# 4. Кинематографическая виньетка по краям экрана
	var vignette_w := 140.0
	var v_col_edge := Color(0.01, 0.015, 0.03, 0.75)
	# Левый и правый край
	draw_rect(Rect2(0, 0, vignette_w, h), v_col_edge)
	draw_rect(Rect2(w - vignette_w, 0, vignette_w, h), v_col_edge)
	# Верхняя полоса
	draw_rect(Rect2(0, 0, w, 60), Color(0.01, 0.015, 0.03, 0.6))
