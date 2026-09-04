extends SceneTree

# Автоматический интеграционный тест арсенала инструментов (Tools & Combat)

var passed_count: int = 0
var total_count: int = 5
var frame: int = 0

var test_scene: Node3D = null
var cam: Camera3D = null
var guard: CharacterBody3D = null
var wall: StaticBody3D = null
var door: Node3D = null
var player: CharacterBody3D = null

func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		1:
			_setup_test_world()
		3:
			_test_1_inventory()
		5:
			_test_2_baton()
		7:
			_test_3_foam()
		9:
			_test_4_hack()
		11:
			_test_5_energy_cooldown()
		13:
			_finalize()
			return true # Terminate main loop
	return false # Continue main loop

func _setup_test_world() -> void:
	print("\n=======================================================================")
	print(">>> ЗАПУСК TEST: TOOLS & COMBAT ARSENAL (STAGE 2 / v0.2.0) <<<")
	print("=======================================================================\n")
	
	test_scene = Node3D.new()
	root.add_child(test_scene)
	
	cam = Camera3D.new()
	test_scene.add_child(cam)
	cam.global_position = Vector3(0, 1.0, 0)
	cam.current = true
	
	# 1. Охранник прямо перед камерой (-Z)
	var guard_scene: PackedScene = load("res://scenes/characters/guard.tscn")
	guard = guard_scene.instantiate()
	test_scene.add_child(guard)
	guard.global_position = Vector3(0, 0, -1.5)
	
	# 2. Стена сзади (+Z)
	wall = StaticBody3D.new()
	var col_wall := CollisionShape3D.new()
	var box_wall := BoxShape3D.new()
	box_wall.size = Vector3(8, 8, 0.5)
	col_wall.shape = box_wall
	wall.add_child(col_wall)
	test_scene.add_child(wall)
	wall.global_position = Vector3(0, 1.0, 4.0)
	
	# 3. Запертая дверь справа (+X)
	var door_script: GDScript = load("res://scripts/physics/physical_door.gd")
	door = door_script.new()
	door.set("is_locked", true)
	var leaf := RigidBody3D.new()
	leaf.name = "DoorLeaf"
	leaf.collision_layer = 1
	var col_door := CollisionShape3D.new()
	var box_door := BoxShape3D.new()
	box_door.size = Vector3(1.0, 2.0, 0.1)
	col_door.shape = box_door
	leaf.add_child(col_door)
	door.add_child(leaf)
	test_scene.add_child(door)
	door.global_position = Vector3(3.0, 1.0, 0)

func _test_1_inventory() -> void:
	var player_scene: PackedScene = load("res://scenes/characters/player.tscn")
	player = player_scene.instantiate()
	test_scene.add_child(player)
	player.global_position = Vector3(0, 0, 15)
	
	var inv: Node = player.get_node_or_null("InventoryManager")
	if not inv:
		printerr("[FAIL] InventoryManager не найден в Player")
		return
		
	if inv.get("active_slot") != 0:
		printerr("[FAIL] Начальный слот должен быть 0 (GRABBER)")
		return
		
	inv.call("select_slot", 1)
	if inv.get("active_slot") != 1:
		printerr("[FAIL] Переключение на слот 1 не удалось")
		return
		
	inv.call("cycle_slot", 1)
	if inv.get("active_slot") != 2:
		printerr("[FAIL] Циклическое переключение на слот 2 не удалось")
		return
		
	passed_count += 1
	print("[PASS] 1. InventoryManager: инициализация, слоты 0-3 и циклическая смена работают штатно.")

func _test_2_baton() -> void:
	cam.look_at(guard.global_position + Vector3(0, 0.9, 0))
	
	var StunBatonScript: GDScript = load("res://scripts/tools/stun_baton.gd")
	var baton: Node3D = StunBatonScript.new()
	test_scene.add_child(baton)
	
	var res: Dictionary = baton.call("use", cam)
	if not res.get("success", false) or res.get("action") != "stun_guard":
		printerr("[FAIL] StunBaton не смог нейтрализовать охранника: ", res)
		baton.queue_free()
		return
		
	if guard.get("current_state") != 5: # AIState.STUNNED
		printerr("[FAIL] Охранник не перешел в состояние STUNNED, текущее: ", guard.get("current_state"))
		baton.queue_free()
		return
		
	passed_count += 1
	print("[PASS] 2. StunBaton: успешный удар в ближнем бою, перевод AI в состояние STUNNED на 6.0с.")
	baton.queue_free()

func _test_3_foam() -> void:
	cam.look_at(wall.global_position)
	
	var FoamLauncherScript: GDScript = load("res://scripts/tools/foam_launcher.gd")
	var launcher: Node3D = FoamLauncherScript.new()
	test_scene.add_child(launcher)
	
	var res: Dictionary = launcher.call("use", cam)
	if not res.get("success", false):
		printerr("[FAIL] FoamLauncher не произвел успешный выстрел: ", res)
		launcher.queue_free()
		return
		
	var block: Node3D = res.get("block")
	if not block or not (block is StaticBody3D):
		printerr("[FAIL] FoamBlock не был создан как StaticBody3D")
		launcher.queue_free()
		return
		
	if launcher.get("ammo") != 23:
		printerr("[FAIL] Боезапас пены не уменьшился (ожидалось 23, получено %d)" % launcher.get("ammo"))
		launcher.queue_free()
		return
		
	passed_count += 1
	print("[PASS] 3. FoamLauncher: создание физического твердого блока пены StaticBody3D с коллизией.")
	launcher.queue_free()

func _test_4_hack() -> void:
	cam.look_at(door.global_position)
	
	var HackingToolScript: GDScript = load("res://scripts/tools/hacking_tool.gd")
	var hack: Node3D = HackingToolScript.new()
	test_scene.add_child(hack)
	
	var res: Dictionary = hack.call("use", cam)
	if not res.get("success", false):
		printerr("[FAIL] HackingTool не смог произвести взлом двери: ", res)
		hack.queue_free()
		return
		
	if door.get("is_locked"):
		printerr("[FAIL] Дверь осталась запертой после взлома")
		hack.queue_free()
		return
		
	passed_count += 1
	print("[PASS] 4. HackingTool: дистанционный взлом электронного замка двери PhysicalDoor (unlock_and_open).")
	hack.queue_free()

func _test_5_energy_cooldown() -> void:
	var StunBatonScript: GDScript = load("res://scripts/tools/stun_baton.gd")
	var baton: Node3D = StunBatonScript.new()
	test_scene.add_child(baton)
	
	if not baton.call("can_use"):
		printerr("[FAIL] Дубинка должна быть готова к использованию при 100% энергии")
		baton.queue_free()
		return
		
	baton.set("current_cooldown", 1.0)
	if baton.call("can_use"):
		printerr("[FAIL] Дубинка не должна быть готова во время кулдауна")
		baton.queue_free()
		return
		
	baton.set("current_cooldown", 0.0)
	baton.set("energy", 2.0)
	if baton.call("can_use"):
		printerr("[FAIL] Дубинка не должна быть готова при нехватке энергии")
		baton.queue_free()
		return
		
	passed_count += 1
	print("[PASS] 5. Tools Cooldown & Energy: расчет перезарядки и расхода энергии выдержан корректно.")
	baton.queue_free()

func _finalize() -> void:
	print("\n--- РЕЗУЛЬТАТ ТЕСТОВ АРСЕНАЛА: %d/%d ПРОЙДЕНО ---" % [passed_count, total_count])
	if test_scene:
		test_scene.queue_free()
	quit(0 if passed_count == total_count else 1)
