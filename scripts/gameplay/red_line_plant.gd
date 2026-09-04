class_name RedLinePlant
extends Node3D

# Контроллер Миссии 2 «Операция: Красная Линия» (Вертикальный срез / v0.5.0)
# Полноценный цикл: Синтез сиропа -> Транспортировка -> Проникновение на завод ->
# Заливка в сиропную башню -> Взлом диспетчерской -> Запуск конвейеров розлива «Кока-Коля»!

const MissionManagerScript = preload("res://scripts/core/mission_manager.gd")
const DialogueManagerScript = preload("res://scripts/core/dialogue_manager.gd")
const SyrupCanisterScript = preload("res://scripts/interaction/syrup_canister.gd")

@onready var player: CharacterBody3D = get_node_or_null("Player")
@onready var van: VehicleBody3D = get_node_or_null("DeliveryVan")
@onready var crafting_station: Node3D = get_node_or_null("Garage/CraftingStation")
@onready var syrup_canister: RigidBody3D = get_node_or_null("CanisterSpawnPoint/SyrupCanister")
@onready var plant_arrival: Area3D = get_node_or_null("Triggers/PlantArrivalArea")
@onready var tower_trigger: Area3D = get_node_or_null("Factory/SyrupTower/InjectionArea")
@onready var terminal: Node3D = get_node_or_null("Factory/DispatchTower/AutomationTerminal")
@onready var conveyor: AnimatableBody3D = get_node_or_null("Factory/BottlingLine/ConveyorBelt")

# UI элементы
@onready var quest_label: Label = get_node_or_null("HUD/QuestPanel/Margin/VBox/ObjectiveLabel")
@onready var radio_panel: PanelContainer = get_node_or_null("HUD/RadioPanel")
@onready var radio_speaker: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/SpeakerLabel")
@onready var radio_text: Label = get_node_or_null("HUD/RadioPanel/Margin/VBox/MessageLabel")
@onready var victory_panel: PanelContainer = get_node_or_null("HUD/VictoryPanel")

var mission_mgr: Node = null
var dialogue_mgr: Node = null

var stage: int = 1 # 1: Craft, 2: Load, 3: Drive, 4: Infiltrate, 5: Tower, 6: Terminal, 7: Victory

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

	if crafting_station and crafting_station.has_signal("craft_completed"):
		crafting_station.connect("craft_completed", _on_craft_done)

	if plant_arrival:
		plant_arrival.body_entered.connect(_on_plant_arrival)

	if tower_trigger:
		tower_trigger.body_entered.connect(_on_tower_injection)

	if terminal and terminal.has_signal("plant_overridden"):
		terminal.connect("plant_overridden", _on_terminal_hacked)

	_start_mission_intro()

func _start_mission_intro() -> void:
	mission_mgr.call("start_mission", "Операция: Красная Линия")
	mission_mgr.call("add_objective", "craft_syrup", "Синтезировать концентрат «Кока-Коля» на верстаке", 1)

	dialogue_mgr.call("queue_message", "СашаV", "Коля, данные с чипа расшифрованы! Рецепт идеален. Подойди к верстаку и начни синтез.", Color(0.3, 0.8, 1.0), 4.5)
	dialogue_mgr.call("queue_message", "Коля", "Займусь этим прямо сейчас. Пора вернуть настоящую газировку в город.", Color(1.0, 0.8, 0.2), 3.5)

func _on_craft_done(_item: String) -> void:
	if stage == 1:
		stage = 2
		mission_mgr.call("complete_objective", "craft_syrup")
		mission_mgr.call("add_objective", "load_canister", "Погрузить канистру концентрата в фургон", 1)
		dialogue_mgr.call("queue_message", "СашаV", "Концентрат готов! Загружай канистру в кузов фургона [E] и отправляйся на Завод «Красная Линия».", Color(0.3, 0.8, 1.0), 4.5)

func _physics_process(_delta: float) -> void:
	if stage == 2 and van:
		var has_canister: bool = false
		if van.has_method("get_cargo_crates"):
			for b in van.call("get_cargo_crates"):
				if b is RigidBody3D and (b.name.begins_with("SyrupCanister") or b.is_in_group("canister")):
					has_canister = true
					break
		if has_canister:
			stage = 3
			mission_mgr.call("complete_objective", "load_canister")
			mission_mgr.call("add_objective", "drive_to_plant", "Доехать на фургоне до Завода «Красная Линия»", 1)
			dialogue_mgr.call("queue_message", "СашаV", "Груз на борту! Заводи мотор и держи курс на промышленную зону.", Color(0.3, 0.8, 1.0), 4.0)

func _on_plant_arrival(body: Node) -> void:
	if stage == 3 and (body == van or body == player):
		stage = 4
		mission_mgr.call("complete_objective", "drive_to_plant")
		mission_mgr.call("add_objective", "inject_syrup", "Залить концентрат в Главную Сиропную Башню", 1)
		dialogue_mgr.call("queue_message", "СашаV", "Мы на заводе! Камеры на КПП можно взломать [4] или залепить пеной [3]. Поднимись к сиропной башне!", Color(0.3, 0.8, 1.0), 5.0)

func _on_tower_injection(body: Node) -> void:
	if stage == 4 and (body is SyrupCanisterScript or body.is_in_group("canister") or body == player):
		stage = 5
		mission_mgr.call("complete_objective", "inject_syrup")
		mission_mgr.call("add_objective", "override_automation", "Взломать терминал автоматизации в диспетчерской", 1)
		dialogue_mgr.call("queue_message", "СашаV", "Башня заправлена! Теперь поднимайся в диспетчерскую вышку и перехвати автоматику розлива!", Color(0.3, 1.0, 0.4), 4.5)

func _on_terminal_hacked() -> void:
	if stage == 5:
		stage = 6
		mission_mgr.call("complete_objective", "override_automation")
		
		# Запуск конвейера розлива
		if conveyor:
			conveyor.set("constant_linear_velocity", Vector3(2.5, 0, 0))
			
		LogManager.info("КОНВЕЙЕРЫ ЗАВОДА ЗАПУЩЕНЫ: РОЗЛИВ «КОКА-КОЛЯ» АКТИВЕН!", "FACTORY")

func _on_mission_victory(_title: String) -> void:
	if victory_panel:
		victory_panel.visible = true
	dialogue_mgr.call("queue_message", "Коля", "Линия розлива работает на полную мощность! Вся партия — наша «Кока-Коля». Мы сделали это!", Color(1.0, 0.8, 0.2), 6.0)
	LogManager.info(">>> ВЕРТИКАЛЬНЫЙ СРЕЗ (STAGE 4 / v0.5.0) ПОЛНОСТЬЮ ПРОЙДЕН! <<<", "VICTORY")

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")