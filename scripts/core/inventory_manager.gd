class_name InventoryManager
extends Node

# Менеджер снаряжения и селектор инструментов игрока (Hotbar 1-4)

signal slot_changed(slot_idx: int, slot_name: String)
signal tool_acted(action_name: String, details: Dictionary)

enum ToolSlot {
	GRABBER = 0,
	BATON = 1,
	FOAM = 2,
	HACK = 3
}

const StunBatonScript = preload("res://scripts/tools/stun_baton.gd")
const FoamLauncherScript = preload("res://scripts/tools/foam_launcher.gd")
const HackingToolScript = preload("res://scripts/tools/hacking_tool.gd")

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
	
	_update_tool_visibilities()

func _unhandled_input(event: InputEvent) -> void:
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
				
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_slot(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_slot(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			use_active_tool()

func cycle_slot(direction: int) -> void:
	var new_slot: int = (int(active_slot) + direction) % 4
	if new_slot < 0:
		new_slot += 4
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
		_:
			return "Неизвестно"

func use_active_tool() -> Dictionary:
	var result := {}
	match active_slot:
		ToolSlot.GRABBER:
			if grabber:
				if grabber.get("held_body") != null:
					grabber.call("throw_object")
					result = {"action": "throw"}
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
				
	tool_acted.emit(get_active_tool_name(), result)
	return result

func _update_tool_visibilities() -> void:
	for slot: ToolSlot in tools:
		var tool_node: Node3D = tools[slot]
		if is_instance_valid(tool_node):
			tool_node.visible = (slot == active_slot)
