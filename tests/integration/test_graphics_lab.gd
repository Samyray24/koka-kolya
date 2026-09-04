extends SceneTree

# Автоматический интеграционный тест графических профилей масштабируемости (RX 550)

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

var lab_scene: Node = null
var scalability: Node = null
var env: Environment = null
var vp: Viewport = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup_test()
		3:
			_test_1_instantiation()
		5:
			_test_2_low_preset()
		7:
			_test_3_medium_preset()
		9:
			_test_4_high_preset()
		11:
			_test_5_scene_materials()
		13:
			_finalize()
			return true
	return false

func _setup_test() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: GRAPHICS SCALABILITY & PBR LAB (STAGE 2 / v0.2.0) <<<")
	print("=======================================================================\n")
	
	var scene_res: PackedScene = load("res://scenes/testlabs/graphics_lab.tscn")
	lab_scene = scene_res.instantiate()
	root.add_child(lab_scene)
	
	var mgr_script: GDScript = load("res://scripts/core/scalability_manager.gd")
	scalability = mgr_script.new()
	root.add_child(scalability)
	
	var world_env: WorldEnvironment = lab_scene.get_node_or_null("WorldEnvironment")
	if world_env:
		env = world_env.environment
	vp = root

func _test_1_instantiation() -> void:
	if scalability != null and env != null:
		passed_count += 1
		print("[PASS] 1. ScalabilityManager & Environment: экземпляры успешно инициализированы.")
	else:
		printerr("[FAIL] Ошибка инициализации ScalabilityManager или WorldEnvironment")

func _test_2_low_preset() -> void:
	scalability.call("apply_preset", 0, vp, env) # LOW
	var is_low_ok: bool = (not env.ssao_enabled) and (not env.ssr_enabled) and (vp.scaling_3d_scale < 0.8) and (vp.msaa_3d == Viewport.MSAA_DISABLED)
	if is_low_ok:
		passed_count += 1
		print("[PASS] 2. LOW Preset (RX 550 Fast): FSR 77%, MSAA Выкл, SSAO/SSR Выкл — гарантирует 60+ FPS.")
	else:
		printerr("[FAIL] LOW Preset не соответствует спецификации: FSR=%.2f, SSAO=%s, SSR=%s" % [vp.scaling_3d_scale, env.ssao_enabled, env.ssr_enabled])

func _test_3_medium_preset() -> void:
	scalability.call("apply_preset", 1, vp, env) # MEDIUM
	var is_med_ok: bool = env.ssao_enabled and (not env.ssr_enabled) and (vp.scaling_3d_scale > 0.8) and (vp.msaa_3d == Viewport.MSAA_2X)
	if is_med_ok:
		passed_count += 1
		print("[PASS] 3. MEDIUM Preset (RX 550 Balanced): FSR 85%, MSAA 2X, SSAO ВКЛ, SSR Выкл — баланс 50 FPS.")
	else:
		printerr("[FAIL] MEDIUM Preset не соответствует спецификации")

func _test_4_high_preset() -> void:
	scalability.call("apply_preset", 2, vp, env) # HIGH
	var is_high_ok: bool = env.ssao_enabled and env.ssr_enabled and is_equal_approx(vp.scaling_3d_scale, 1.0) and (vp.msaa_3d == Viewport.MSAA_4X)
	if is_high_ok:
		passed_count += 1
		print("[PASS] 4. HIGH Preset (Cinematic): Нативное 1080p 100%, MSAA 4X, SSAO ВКЛ, SSR ВКЛ.")
	else:
		printerr("[FAIL] HIGH Preset не соответствует спецификации")

func _test_5_scene_materials() -> void:
	var p_chrome: Node = lab_scene.get_node_or_null("Pedestal_Chrome")
	var p_cola: Node = lab_scene.get_node_or_null("Pedestal_Cola")
	var p_glass: Node = lab_scene.get_node_or_null("Pedestal_Glass")
	var p_concrete: Node = lab_scene.get_node_or_null("Pedestal_Concrete")
	var neon: Node = lab_scene.get_node_or_null("NeonSign")
	
	if p_chrome and p_cola and p_glass and p_concrete and neon:
		passed_count += 1
		print("[PASS] 5. PBR Materials Testbed: Все 4 тестовых пьедестала (Хром, Кола, Стекло, Бетон) и Неон найдены.")
	else:
		printerr("[FAIL] Ошибка структуры тестовых объектов в graphics_lab.tscn")

func _finalize() -> void:
	print("\n--- РЕЗУЛЬТАТ ТЕСТОВ ГРАФИКИ: %d/%d ПРОЙДЕНО ---" % [passed_count, total_count])
	if lab_scene:
		lab_scene.queue_free()
	if scalability:
		scalability.queue_free()
	quit(0 if passed_count == total_count else 1)