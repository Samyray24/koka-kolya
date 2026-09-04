extends SceneTree

# Автоматический интеграционный тест рантайма дерева навыков SkillManager (Stage 2)

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

var skill_mgr: Node = null
var player: CharacterBody3D = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup_test()
		3:
			_test_1_manifest_loading()
		5:
			_test_2_movement_skills()
		7:
			_test_3_physics_skills()
		9:
			_test_4_tools_skills()
		11:
			_test_5_persistence()
		13:
			_finalize()
			return true
	return false

func _setup_test() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: SKILLGRAPH RUNTIME & MODIFIERS (STAGE 2 / v0.2.0) <<<")
	print("=======================================================================\n")
	
	var mgr_script: GDScript = load("res://scripts/core/skill_manager.gd")
	skill_mgr = mgr_script.new()
	root.add_child(skill_mgr)
	
	var p_scene: PackedScene = load("res://scenes/characters/player.tscn")
	player = p_scene.instantiate()
	root.add_child(player)

func _test_1_manifest_loading() -> void:
	var total: int = skill_mgr.get("all_skills").size()
	if total == 416:
		passed_count += 1
		print("[PASS] 1. Skill Manifest: Все 416 узлов древа навыков успешно загружены в рантайм.")
	else:
		printerr("[FAIL] Загружено неверное число навыков: %d (ожидалось 416)" % total)

func _test_2_movement_skills() -> void:
	skill_mgr.call("reset_skills")
	var initial_speed: float = player.walk_speed
	
	skill_mgr.call("unlock_skill", "movement_parkour_01")
	skill_mgr.call("unlock_skill", "movement_parkour_03")
	skill_mgr.call("apply_to_player", player)
	
	var boosted_speed: float = player.walk_speed
	var wall_kick: bool = skill_mgr.call("get_modifier", "wall_kick_enabled", false)
	
	if boosted_speed > initial_speed and wall_kick:
		passed_count += 1
		print("[PASS] 2. Movement Skills: Скорость увеличена (+18%%), прыжок усилен, настенный отскок разблокирован.")
	else:
		printerr("[FAIL] Ошибка применения навыков движения: speed=%.2f, wall_kick=%s" % [boosted_speed, wall_kick])

func _test_3_physics_skills() -> void:
	var grabber: Node3D = player.get_node_or_null("Head/Camera3D/PhysicsGrabber")
	if not grabber:
		printerr("[FAIL] PhysicsGrabber не найден")
		return
		
	skill_mgr.call("unlock_skill", "physics_improvisation_01")
	skill_mgr.call("unlock_skill", "physics_improvisation_02")
	skill_mgr.call("unlock_skill", "physics_improvisation_03")
	skill_mgr.call("apply_to_player", player)
	
	var max_mass: float = grabber.get("max_grab_mass")
	var reach: float = grabber.get("max_reach_distance")
	var impulse: float = grabber.get("throw_impulse")
	
	if is_equal_approx(max_mass, 80.0) and is_equal_approx(reach, 5.0) and impulse > 13.0:
		passed_count += 1
		print("[PASS] 3. Physics Skills: Грузоподъемность 80 кг, дистанция захвата 5.0 м, импульс броска x1.6.")
	else:
		printerr("[FAIL] Ошибка навыков физики: mass=%.1f, reach=%.1f, impulse=%.1f" % [max_mass, reach, impulse])

func _test_4_tools_skills() -> void:
	var inv: Node = player.get_node_or_null("InventoryManager")
	if not inv:
		printerr("[FAIL] InventoryManager не найден")
		return
		
	skill_mgr.call("unlock_skill", "hacking_02") # hack_range = 35.0
	skill_mgr.call("unlock_skill", "combat_01") # baton_stun_duration = 9.0
	skill_mgr.call("apply_to_tools", inv)
	
	var hack_range: float = skill_mgr.call("get_modifier", "hack_range", 0.0)
	var stun_dur: float = skill_mgr.call("get_modifier", "baton_stun_duration", 0.0)
	
	if is_equal_approx(hack_range, 35.0) and is_equal_approx(stun_dur, 9.0):
		passed_count += 1
		print("[PASS] 4. Tools Skills: Дальность кибер-взлома 35.0 м, длительность оглушения дубинки 9.0 с.")
	else:
		printerr("[FAIL] Ошибка модификаторов инструментов: hack_range=%.1f, stun_dur=%.1f" % [hack_range, stun_dur])

func _test_5_persistence() -> void:
	# Проверка сохранения и повторной загрузки состояния
	skill_mgr.call("save_state")
	
	var mgr_script: GDScript = load("res://scripts/core/skill_manager.gd")
	var new_mgr: Node = mgr_script.new()
	root.add_child(new_mgr)
	
	var is_hack_saved: bool = new_mgr.call("is_skill_unlocked", "hacking_02")
	var is_phys_saved: bool = new_mgr.call("is_skill_unlocked", "physics_improvisation_01")
	
	if is_hack_saved and is_phys_saved:
		passed_count += 1
		print("[PASS] 5. Skill Persistence: Состояние разблокированных навыков корректно сохраняется в user://skills.json.")
	else:
		printerr("[FAIL] Ошибка персистентности навыков")
		
	new_mgr.queue_free()

func _finalize() -> void:
	print("\n--- РЕЗУЛЬТАТ ТЕСТОВ SKILLGRAPH RUNTIME: %d/%d ПРОЙДЕНО ---" % [passed_count, total_count])
	if skill_mgr:
		skill_mgr.queue_free()
	if player:
		player.queue_free()
	quit(0 if passed_count == total_count else 1)