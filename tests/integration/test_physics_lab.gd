extends SceneTree

# Integration & Verification Test for Physics Lab & SkillGraph Design System (v0.2.0)

var tested: bool = false

func _process(_delta: float) -> bool:
	if tested:
		return false
	tested = true
	run_tests()
	return true

func run_tests() -> void:
	print("=======================================================================")
	print(">>> ЗАПУСК TEST: PHYSICS LAB & SKILLGRAPH SYSTEM (STAGE 2 / v0.2.0) <<<")
	print("=======================================================================")

	var errors: int = 0

	# 1. Проверка ConveyorBelt
	print("[TEST 1/6] Проверка ConveyorBelt (Jolt constant_linear_velocity)...")
	var belt_script: Script = load("res://scripts/physics/conveyor_belt.gd")
	if belt_script:
		var belt: AnimatableBody3D = belt_script.new()
		belt.belt_speed = 3.0
		belt.belt_direction = Vector3(1, 0, 0)
		root.add_child(belt)
		if is_equal_approx(belt.constant_linear_velocity.x, 3.0):
			print("  [PASS] Конвейер корректно рассчитал constant_linear_velocity (3.0, 0, 0).")
		else:
			printerr("  [FAIL] Неверная скорость конвейера: %s" % belt.constant_linear_velocity)
			errors += 1
		belt.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить conveyor_belt.gd")
		errors += 1

	# 2. Проверка PhysicalDoor и HingeJoint3D
	print("[TEST 2/6] Проверка PhysicalDoor...")
	var door_script: Script = load("res://scripts/physics/physical_door.gd")
	if door_script:
		var door_inst: Node3D = door_script.new()
		var leaf := RigidBody3D.new()
		leaf.name = "DoorLeaf"
		door_inst.add_child(leaf)
		
		var handle := Node3D.new()
		handle.name = "Handle"
		leaf.add_child(handle)
		
		var interactable_script: Script = load("res://scripts/interaction/interactable.gd")
		var interactable: Node = interactable_script.new()
		interactable.name = "Interactable"
		handle.add_child(interactable)
		
		root.add_child(door_inst)
		door_inst.call("_on_handle_interacted", null)
		if door_inst.get("is_open") == true:
			print("  [PASS] PhysicalDoor успешно обработал импульс и перешел в состояние is_open.")
		else:
			printerr("  [FAIL] Дверь не открылась при активации.")
			errors += 1
		door_inst.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить physical_door.gd")
		errors += 1

	# 3. Проверка BreakableGlass
	print("[TEST 3/6] Проверка BreakableGlass (Стадии INTACT -> CRACKED -> SHATTERED)...")
	var glass_script: Script = load("res://scripts/physics/breakable_glass.gd")
	if glass_script:
		var glass: StaticBody3D = glass_script.new()
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		glass.add_child(col)
		var mesh := MeshInstance3D.new()
		mesh.name = "MeshInstance3D"
		glass.add_child(mesh)
		
		root.add_child(glass)
		glass.call("apply_damage", 16.0)
		var state_cracked: int = glass.get("state")
		glass.call("apply_damage", 20.0)
		var state_shattered: int = glass.get("state")
		
		if state_cracked == 1 and state_shattered == 2:
			print("  [PASS] Стекло корректно прошло стадии CRACKED (1) и SHATTERED (2).")
		else:
			printerr("  [FAIL] Некорректные стадии стекла: cracked=%d, shattered=%d" % [state_cracked, state_shattered])
			errors += 1
		glass.queue_free()
	else:
		printerr("  [FAIL] Не удалось загрузить breakable_glass.gd")
		errors += 1

	# 4. Проверка SkillValidator для 416 узлов
	print("[TEST 4/6] Проверка валидации манифеста дерева навыков (416 узлов)...")
	var val_script: Script = load("res://scripts/core/skill_validator.gd")
	if val_script:
		var rep: Dictionary = val_script.call("validate_skills_manifest", "res://data/skills/skills_manifest.json")
		if rep.get("is_valid") == true and rep.get("total_nodes") == 416 and rep.get("branches_count") == 16:
			print("  [PASS] Манифест навыков полностью валиден: 416 узлов в 16 ветках, 0 ошибок.")
		else:
			printerr("  [FAIL] Ошибки валидации навыков: %s" % rep.get("errors"))
			errors += 1
	else:
		printerr("  [FAIL] Не удалось загрузить skill_validator.gd")
		errors += 1

	# 5. Проверка синергий (минимум 64)
	print("[TEST 5/6] Проверка манифеста межветьевых синергий (64 синергии)...")
	if val_script:
		var rep_syn: Dictionary = val_script.call("validate_synergies_manifest", "res://data/skills/synergies_manifest.json")
		if rep_syn.get("is_valid") == true and rep_syn.get("total_synergies") >= 64:
			print("  [PASS] Манифест синергий валиден: %d синергий найдено (требовалось >= 64)." % rep_syn.get("total_synergies"))
		else:
			printerr("  [FAIL] Ошибки валидации синергий: %s" % rep_syn.get("errors"))
			errors += 1

	# 6. Проверка сцены PhysicsLab
	print("[TEST 6/6] Проверка полной загрузки сцены physics_lab.tscn...")
	var lab_res: PackedScene = load("res://scenes/testlabs/physics_lab.tscn")
	if lab_res:
		var lab_inst: Node3D = lab_res.instantiate()
		var p_door: Node = lab_inst.get_node_or_null("PhysicalDoor")
		var p_conv: Node = lab_inst.get_node_or_null("ConveyorBelt")
		var p_glass: Node = lab_inst.get_node_or_null("BreakableGlass")
		var p_player: Node = lab_inst.get_node_or_null("Player")
		
		if p_door and p_conv and p_glass and p_player:
			print("  [PASS] Сцена Physics Lab содержит все требуемые компоненты и контроллер игрока.")
		else:
			printerr("  [FAIL] В сцене physics_lab.tscn отсутствуют компоненты.")
			errors += 1
		lab_inst.free()
	else:
		printerr("  [FAIL] Не удалось загрузить scenes/testlabs/physics_lab.tscn")
		errors += 1

	print("=======================================================================")
	if errors == 0:
		print(">>> ВСЕ 6 ТЕСТОВ ЭТАПА 2 УСПЕШНО ПРОЙДЕНЫ (0 ОШИБОК) <<<")
		print("=======================================================================")
		quit(0)
	else:
		printerr(">>> ТЕСТЫ ЭТАПА 2 ЗАВЕРШИЛИСЬ С ОШИБКАМИ: %d <<<" % errors)
		print("=======================================================================")
		quit(1)
