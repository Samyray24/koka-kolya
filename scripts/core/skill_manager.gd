class_name SkillManager
extends Node

# Менеджер дерева навыков и рантайм-модификаторов для Коли (SkillGraph Runtime)
# Реализует 28 активных навыков ранней игры (Tier 1-2) с физическими и геймплейными эффектами.

signal skill_unlocked(skill_id: String, skill_info: Dictionary)
signal skill_reset()

const MANIFEST_PATH: String = "res://data/skills/skills_manifest.json"
const SAVE_PATH: String = "user://skills.json"

var all_skills: Dictionary = {}
var unlocked_skills: Dictionary = {}

# Активные рантайм-модификаторы
var modifiers: Dictionary = {
	"speed_multiplier": 1.0,
	"jump_multiplier": 1.0,
	"coyote_multiplier": 1.0,
	"grab_mass_max": 40.0,
	"throw_impulse_multiplier": 1.0,
	"reach_distance": 3.0,
	"footstep_noise_multiplier": 1.0,
	"jump_noise_multiplier": 1.0,
	"detection_delay_multiplier": 1.0,
	"baton_stun_duration": 6.0,
	"baton_knockback_multiplier": 1.0,
	"foam_duration_multiplier": 1.0,
	"foam_max_blocks": 16,
	"hack_cooldown_multiplier": 1.0,
	"hack_range": 22.0,
	"hack_energy_cost_multiplier": 1.0,
	"drone_speed_multiplier": 1.0,
	"drone_light_multiplier": 1.0,
	"drone_scan_radius": 12.0,
	"vehicle_power_multiplier": 1.0,
	"vehicle_cargo_penalty_multiplier": 1.0,
	"energy_recovery_multiplier": 1.0,
	"wall_kick_enabled": false,
	"slide_boost_enabled": false,
	"bullet_time_reflex_enabled": false
}

func _ready() -> void:
	load_manifest()
	load_state()

func load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		printerr("[SkillManager] Файл манифеста не найден: %s" % MANIFEST_PATH)
		return
		
	var f := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not f:
		return
		
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		var list: Array = json.data.get("skills", [])
		for s in list:
			if s is Dictionary and s.has("id"):
				all_skills[s["id"]] = s
		LogManager.info("SkillManager: Загружено %d навыков из древа." % all_skills.size(), "SKILLS")

func unlock_skill(skill_id: String) -> bool:
	if not all_skills.has(skill_id):
		printerr("[SkillManager] Неизвестный навык: %s" % skill_id)
		return false
		
	if unlocked_skills.has(skill_id):
		return true
		
	var skill_data: Dictionary = all_skills[skill_id]
	unlocked_skills[skill_id] = true
	
	_recalculate_modifiers()
	save_state()
	
	skill_unlocked.emit(skill_id, skill_data)
	LogManager.info("Навык разблокирован: [%s] %s" % [skill_id, skill_data.get("display_name", "")], "SKILLS")
	return true

func is_skill_unlocked(skill_id: String) -> bool:
	return unlocked_skills.has(skill_id)

func reset_skills() -> void:
	unlocked_skills.clear()
	_recalculate_modifiers()
	save_state()
	skill_reset.emit()
	LogManager.info("SkillManager: все навыки сброшены.", "SKILLS")

func _recalculate_modifiers() -> void:
	# Сброс к базовым значениям
	modifiers["speed_multiplier"] = 1.0
	modifiers["jump_multiplier"] = 1.0
	modifiers["coyote_multiplier"] = 1.0
	modifiers["grab_mass_max"] = 40.0
	modifiers["throw_impulse_multiplier"] = 1.0
	modifiers["reach_distance"] = 3.0
	modifiers["footstep_noise_multiplier"] = 1.0
	modifiers["jump_noise_multiplier"] = 1.0
	modifiers["detection_delay_multiplier"] = 1.0
	modifiers["baton_stun_duration"] = 6.0
	modifiers["baton_knockback_multiplier"] = 1.0
	modifiers["foam_duration_multiplier"] = 1.0
	modifiers["foam_max_blocks"] = 16
	modifiers["hack_cooldown_multiplier"] = 1.0
	modifiers["hack_range"] = 22.0
	modifiers["hack_energy_cost_multiplier"] = 1.0
	modifiers["drone_speed_multiplier"] = 1.0
	modifiers["drone_light_multiplier"] = 1.0
	modifiers["drone_scan_radius"] = 12.0
	modifiers["vehicle_power_multiplier"] = 1.0
	modifiers["vehicle_cargo_penalty_multiplier"] = 1.0
	modifiers["energy_recovery_multiplier"] = 1.0
	modifiers["wall_kick_enabled"] = false
	modifiers["slide_boost_enabled"] = false
	modifiers["bullet_time_reflex_enabled"] = false

	# 1-3. Ветка Передвижения
	if is_skill_unlocked("movement_parkour_01"):
		modifiers["speed_multiplier"] += 0.18
		modifiers["jump_multiplier"] += 0.12
	if is_skill_unlocked("movement_parkour_02"):
		modifiers["coyote_multiplier"] += 0.50
	if is_skill_unlocked("movement_parkour_03"):
		modifiers["wall_kick_enabled"] = true

	# 4-6. Ветка Физической импровизации
	if is_skill_unlocked("physics_improvisation_01"):
		modifiers["grab_mass_max"] = 80.0
	if is_skill_unlocked("physics_improvisation_02"):
		modifiers["throw_impulse_multiplier"] += 0.60
	if is_skill_unlocked("physics_improvisation_03"):
		modifiers["reach_distance"] = 5.0

	# 7-8. Ветка Скрытности
	if is_skill_unlocked("stealth_01"):
		modifiers["footstep_noise_multiplier"] *= 0.50
	if is_skill_unlocked("stealth_02"):
		modifiers["detection_delay_multiplier"] += 0.40

	# 9-11. Ветка Дрона BUBBLE
	if is_skill_unlocked("bubble_drone_01"):
		modifiers["drone_light_multiplier"] += 1.0
	if is_skill_unlocked("bubble_drone_02"):
		modifiers["drone_scan_radius"] = 24.0
	if is_skill_unlocked("bubble_drone_03"):
		modifiers["drone_speed_multiplier"] += 0.35

	# 12-14. Ветка Взлома
	if is_skill_unlocked("hacking_01"):
		modifiers["hack_cooldown_multiplier"] *= 0.70
	if is_skill_unlocked("hacking_02"):
		modifiers["hack_range"] = 35.0
	if is_skill_unlocked("hacking_03"):
		modifiers["hack_energy_cost_multiplier"] *= 0.60

	# 15-16. Ветка Боя
	if is_skill_unlocked("combat_01"):
		modifiers["baton_stun_duration"] = 9.0
	if is_skill_unlocked("combat_02"):
		modifiers["baton_knockback_multiplier"] = 2.0

	# 17-18. Ветка Вождения
	if is_skill_unlocked("driving_01"):
		modifiers["vehicle_power_multiplier"] += 0.25
	if is_skill_unlocked("driving_02"):
		modifiers["vehicle_cargo_penalty_multiplier"] *= 0.50

	# 19-20. Ветка Инженерии
	if is_skill_unlocked("engineering_01"):
		modifiers["foam_duration_multiplier"] += 0.50
		modifiers["foam_max_blocks"] = 24
	if is_skill_unlocked("engineering_02"):
		modifiers["energy_recovery_multiplier"] += 0.50

	# 21-22. Ветка Автомеханики
	if is_skill_unlocked("vehicle_engineering_01"):
		modifiers["vehicle_power_multiplier"] += 0.15

	# 23-24. Ветка Исследования и Базы
	if is_skill_unlocked("exploration_01"):
		modifiers["reach_distance"] += 0.5
	if is_skill_unlocked("base_logistics_01"):
		modifiers["grab_mass_max"] += 15.0

	# 25-28. Специальные ветки (Мастерство, Союзники, Меридиан, Легенда)
	if is_skill_unlocked("delivery_mastery_01"):
		modifiers["speed_multiplier"] += 0.08
	if is_skill_unlocked("tactics_allies_01"):
		modifiers["detection_delay_multiplier"] += 0.20
	if is_skill_unlocked("meridian_01"):
		modifiers["hack_range"] += 5.0
	if is_skill_unlocked("kolya_legend_01"):
		modifiers["speed_multiplier"] += 0.10
		modifiers["throw_impulse_multiplier"] += 0.25

func apply_to_player(player: CharacterBody3D) -> void:
	if not player:
		return
	player.walk_speed = 4.8 * modifiers["speed_multiplier"]
	player.sprint_speed = 7.5 * modifiers["speed_multiplier"]
	player.jump_velocity = 5.2 * modifiers["jump_multiplier"]
	
	var grabber: Node3D = player.get_node_or_null("Head/Camera3D/PhysicsGrabber")
	if grabber:
		grabber.set("max_grab_mass", modifiers["grab_mass_max"])
		grabber.set("max_reach_distance", modifiers["reach_distance"])
		grabber.set("throw_impulse", 8.5 * modifiers["throw_impulse_multiplier"])

func apply_to_tools(inventory: Node) -> void:
	if not inventory:
		return
	var tools_dict: Dictionary = inventory.get("tools")
	if not tools_dict:
		return
		
	if tools_dict.has(1):
		var baton: Node3D = tools_dict[1]
		baton.set("stun_duration", modifiers["baton_stun_duration"])
		
	if tools_dict.has(2):
		var foam: Node3D = tools_dict[2]
		foam.set("block_lifetime", 20.0 * modifiers["foam_duration_multiplier"])
		foam.set("max_active_blocks", modifiers["foam_max_blocks"])
		
	if tools_dict.has(3):
		var hack: Node3D = tools_dict[3]
		hack.set("max_range", modifiers["hack_range"])
		hack.set("cooldown", 0.5 * modifiers["hack_cooldown_multiplier"])
		hack.set("energy_cost", 20.0 * modifiers["hack_energy_cost_multiplier"])

func apply_to_vehicle(van: VehicleBody3D) -> void:
	if not van:
		return
	var base_torque: float = van.get("engine_torque") if "engine_torque" in van else 2800.0
	van.set("engine_torque", base_torque * modifiers["vehicle_power_multiplier"])

func apply_to_drone(drone: CharacterBody3D) -> void:
	if not drone:
		return
	drone.set("remote_speed", 7.0 * modifiers["drone_speed_multiplier"])
	drone.set("scan_radius", modifiers["drone_scan_radius"])

func get_modifier(name: String, default_val: Variant = null) -> Variant:
	return modifiers.get(name, default_val)

func save_state() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		var data := {
			"unlocked_skills": unlocked_skills.keys()
		}
		f.store_string(JSON.stringify(data, "  "))
		f.close()

func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_recalculate_modifiers()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var json := JSON.new()
		if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
			var list: Array = json.data.get("unlocked_skills", [])
			unlocked_skills.clear()
			for id in list:
				unlocked_skills[str(id)] = true
		f.close()
	_recalculate_modifiers()