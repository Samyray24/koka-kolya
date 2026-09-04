class_name PauseMenu
extends Control

# Меню паузы и управления состоянием игры «Кока-Коля»
# Позволяет на лету сохранять, загружать прогресс, настраивать параметры и переходить в хаб.

@onready var btn_resume: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnResume")
@onready var btn_save: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnSave")
@onready var btn_load: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnLoad")
@onready var btn_testhub: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnTestHub")
@onready var btn_mainmenu: Button = get_node_or_null("Center/Panel/Margin/VBox/BtnMainMenu")
@onready var status_label: Label = get_node_or_null("Center/Panel/Margin/VBox/StatusLabel")

var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if btn_resume:
		btn_resume.pressed.connect(resume_game)
	if btn_save:
		btn_save.pressed.connect(_on_save_pressed)
	if btn_load:
		btn_load.pressed.connect(_on_load_pressed)
	if btn_testhub:
		btn_testhub.pressed.connect(_on_testhub_pressed)
	if btn_mainmenu:
		btn_mainmenu.pressed.connect(_on_mainmenu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_cancel"):
		toggle_pause()
	elif is_paused:
		return
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			_quick_save()
		elif event.keycode == KEY_F9:
			_quick_load()

func toggle_pause() -> void:
	set_paused(not is_paused)

func set_paused(paused: bool) -> void:
	is_paused = paused
	visible = is_paused
	get_tree().paused = is_paused

	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if btn_resume:
			btn_resume.grab_focus()
		if has_node("/root/AudioManager"):
			var am: Node = get_node("/root/AudioManager")
			am.call("play_sfx", "click")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func resume_game() -> void:
	set_paused(false)

func _on_save_pressed() -> void:
	_quick_save()

func _on_load_pressed() -> void:
	_quick_load()

func _quick_save() -> void:
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		var success: bool = sm.call("save_game", 0)
		if success:
			_set_status("ИГРА УСПЕШНО СОХРАНЕНА!", Color(0.3, 1.0, 0.4))
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				am.call("play_sfx", "click")
		else:
			_set_status("ОШИБКА СОХРАНЕНИЯ!", Color(1.0, 0.3, 0.3))

func _quick_load() -> void:
	if has_node("/root/SaveManager"):
		var sm: Node = get_node("/root/SaveManager")
		var data: Dictionary = sm.call("load_game", 0)
		if not data.is_empty():
			_set_status("СОХРАНЕНИЕ ЗАГРУЖЕНО!", Color(0.3, 0.8, 1.0))
			if has_node("/root/AudioManager"):
				var am: Node = get_node("/root/AudioManager")
				am.call("play_sfx", "click")
			resume_game()
		else:
			_set_status("ФАЙЛ СОХРАНЕНИЯ НЕ НАЙДЕН!", Color(1.0, 0.8, 0.2))

func _on_testhub_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")

func _on_mainmenu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _set_status(text: String, col: Color) -> void:
	if status_label:
		status_label.text = text
		status_label.modulate = col
		var tw := create_tween()
		tw.tween_property(status_label, "modulate:a", 1.0, 0.1)
		tw.tween_interval(1.8)
		tw.tween_property(status_label, "modulate:a", 0.0, 0.5)