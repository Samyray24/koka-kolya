class_name InventoryManager
extends Node

# Менеджер снаряжения и селектор инструментов игрока (Hotbar 1-7)

signal slot_changed(slot_idx: int, slot_name: String)
signal tool_acted(action_name: String, details: Dictionary)

enum ToolSlot {
	GRABBER = 0,
	BATON = 1,
	FOAM = 2,
	HACK = 3,
	AXE = 4,
	BLASTER = 5,
	REPEATER = 6,
	CROSSBOW = 7,
	DAGGER = 8
}

const StunBatonScript = preload("res://scripts/tools/stun_baton.gd")
const FoamLauncherScript = preload("res://scripts/tools/foam_launcher.gd")
const HackingToolScript = preload("res://scripts/tools/hacking_tool.gd")
const TacticalAxeScript = preload("res://scripts/weapons/tactical_axe.gd")
const BlasterWeaponScript = preload("res://scripts/weapons/blaster_weapon.gd")
const RepeaterWeaponScript = preload("res://scripts/weapons/repeater_weapon.gd")
const EnergyCrossbowScript = preload("res://scripts/weapons/energy_crossbow.gd")
const CombatDaggerScript = preload("res://scripts/weapons/combat_dagger.gd")

@export var default_slot: ToolSlot = ToolSlot.GRABBER

var active_slot: ToolSlot = ToolSlot.GRABBER
var tools: Dictionary = {}

var player: CharacterBody3D = null
var camera: Camera3D = null
var grabber: Node3D = null

func setup(player_ref: CharacterBody3D, cam_ref: Camera3D, grabber_ref: Node3D) -> void:
	player = player_ref
	camera = cam_ref
	grabber = grabber_ref
	
	_init_tools()
	select_slot(default_slot)

func _init_tools() -> void:
	if not camera:
		return
		
	# 1. Дубинка
	var baton: Node3D = StunBatonScript.new()
	baton.name = "StunBatonTool"
	baton.position = Vector3(0.28, -0.25, -0.45)
	baton.rotation = Vector3(deg_to_rad(15), deg_to_rad(-10), deg_to_rad(-15))
	camera.add_child(baton)
	tools[ToolSlot.BATON] = baton
	
	# 2. Пена
	var foam: Node3D = FoamLauncherScript.new()
	foam.name = "FoamLauncherTool"
	foam.position = Vector3(0.25, -0.22, -0.42)
	foam.rotation = Vector3(deg_to_rad(5), deg_to_rad(-5), 0)
	camera.add_child(foam)
	tools[ToolSlot.FOAM] = foam
	
	# 3. Взломщик
	var hack: Node3D = HackingToolScript.new()
	hack.name = "HackingTool"
	hack.position = Vector3(0.24, -0.20, -0.38)
	hack.rotation = Vector3(deg_to_rad(20), deg_to_rad(-15), deg_to_rad(10))
	camera.add_child(hack)
	tools[ToolSlot.HACK] = hack

	# 4. Тактический топор
	var axe: Node3D = TacticalAxeScript.new()
	axe.name = "TacticalAxeTool"
	camera.add_child(axe)
	tools[ToolSlot.AXE] = axe

	# 5. Плазменный бластер
	var blaster: Node3D = BlasterWeaponScript.new()
	blaster.name = "BlasterWeaponTool"
	camera.add_child(blaster)
	tools[ToolSlot.BLASTER] = blaster

	# 6. Импульсный репитер
	var repeater: Node3D = RepeaterWeaponScript.new()
	repeater.name = "RepeaterWeaponTool"
	camera.add_child(repeater)
	tools[ToolSlot.REPEATER] = repeater

	# 7. Энергетический арбалет
	var crossbow: Node3D = EnergyCrossbowScript.new()
	crossbow.name = "EnergyCrossbowTool"
	camera.add_child(crossbow)
	tools[ToolSlot.CROSSBOW] = crossbow

	# 8. Боевой кинжал
	var dagger: Node3D = CombatDaggerScript.new()
	dagger.name = "CombatDaggerTool"
	camera.add_child(dagger)
	tools[ToolSlot.DAGGER] = dagger
	
	_update_tool_visibilities()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				select_slot(ToolSlot.GRABBER)
			KEY_2:
				select_slot(ToolSlot.BATON)
			KEY_3:
				select_slot(ToolSlot.FOAM)
			KEY_4:
				select_slot(ToolSlot.HACK)
			KEY_5:
				select_slot(ToolSlot.AXE)
			KEY_6:
				select_slot(ToolSlot.BLASTER)
			KEY_7:
				select_slot(ToolSlot.REPEATER)
			KEY_8:
				select_slot(ToolSlot.CROSSBOW)
			KEY_9:
				select_slot(ToolSlot.DAGGER)
				
	if event is InputEventMouseButton and event.pressed:
		if grabber and grabber.get("held_body") != null:
			return # Пока держим предмет, колесико мыши регулирует дистанцию
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_slot(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_slot(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			use_active_tool()

func cycle_slot(direction: int) -> void:
	var total_slots: int = ToolSlot.size()
	var new_slot: int = (int(active_slot) + direction) % total_slots
	if new_slot < 0:
		new_slot += total_slots
	select_slot(new_slot as ToolSlot)

func select_slot(new_slot: ToolSlot) -> void:
	active_slot = new_slot
	_update_tool_visibilities()
	var slot_title := get_active_tool_name()
	slot_changed.emit(int(active_slot), slot_title)
	LogManager.info("Снаряжен инструмент: [%d] %s" % [int(active_slot) + 1, slot_title], "Inventory")

func get_active_tool_name() -> String:
	match active_slot:
		ToolSlot.GRABBER:
			return "Физический захват / Руки"
		ToolSlot.BATON:
			return "Электродубинка"
		ToolSlot.FOAM:
			return "Пенный распылитель"
		ToolSlot.HACK:
			return "Кибер-дека взлома"
		ToolSlot.AXE:
			return "Тактический топор"
		ToolSlot.BLASTER:
			return "Плазменный бластер"
		ToolSlot.REPEATER:
			return "Импульсный репитер"
		ToolSlot.CROSSBOW:
			return "Энергетический арбалет"
		ToolSlot.DAGGER:
			return "Тактический кинжал"
		_:
			return "Неизвестно"

func use_active_tool() -> Dictionary:
	var result := {}
	match active_slot:
		ToolSlot.GRABBER:
			if grabber:
				if grabber.get("held_body") != null:
					result = {"action": "throw_handling"}
				else:
					grabber.call("try_interact_or_grab")
					result = {"action": "interact_or_grab"}
		ToolSlot.BATON:
			if tools.has(ToolSlot.BATON) and camera:
				result = tools[ToolSlot.BATON].use(camera)
		ToolSlot.FOAM:
			if tools.has(ToolSlot.FOAM) and camera:
				result = tools[ToolSlot.FOAM].use(camera)
		ToolSlot.HACK:
			if tools.has(ToolSlot.HACK) and camera:
				result = tools[ToolSlot.HACK].use(camera)
		ToolSlot.AXE:
			if tools.has(ToolSlot.AXE) and camera:
				result = tools[ToolSlot.AXE].use(camera)
		ToolSlot.BLASTER:
			if tools.has(ToolSlot.BLASTER) and camera:
				result = tools[ToolSlot.BLASTER].use(camera)
		ToolSlot.REPEATER:
			if tools.has(ToolSlot.REPEATER) and camera:
				result = tools[ToolSlot.REPEATER].use(camera)
		ToolSlot.CROSSBOW:
			if tools.has(ToolSlot.CROSSBOW) and camera:
				result = tools[ToolSlot.CROSSBOW].use(camera)
		ToolSlot.DAGGER:
			if tools.has(ToolSlot.DAGGER) and camera:
				result = tools[ToolSlot.DAGGER].use(camera)
				
	tool_acted.emit(get_active_tool_name(), result)
	return result

func _update_tool_visibilities() -> void:
	for slot: ToolSlot in tools:
		var tool_node: Node3D = tools[slot]
		if is_instance_valid(tool_node):
			tool_node.visible = (slot == active_slot)
