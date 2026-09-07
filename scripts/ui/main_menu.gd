extends Control

# Main Menu Controller for «Кока-Коля» (v1.0.0 Gold Master)

@onready var btn_play: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnPlay")
@onready var btn_settings: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnSettings")
@onready var btn_guide: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnGuide")
@onready var btn_testhub: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnTestHub")
@onready var btn_quit: Button = get_node_or_null("MarginContainer/VBoxContainer/BtnQuit")
@onready var settings_menu: Node = get_node_or_null("SettingsMenu")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
		_hook_btn(btn_play)
		btn_play.grab_focus()
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)
		_hook_btn(btn_settings)
	if btn_guide:
		btn_guide.pressed.connect(_on_guide_pressed)
		_hook_btn(btn_guide)
	if btn_testhub:
		btn_testhub.pressed.connect(_on_testhub_pressed)
		_hook_btn(btn_testhub)
	if btn_quit:
		btn_quit.pressed.connect(_on_quit_pressed)
		_hook_btn(btn_quit)

func _hook_btn(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void:
		_play_sfx("ui_hover", -12.0)
	)

func _play_sfx(sound_name: String, vol: float = 0.0) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", sound_name, vol)

func _on_play_pressed() -> void:
	_play_sfx("ui_click")
	print("[MENU] Launching First Playable (Old District: Mission 1)...")
	get_tree().change_scene_to_file("res://scenes/levels/old_district.tscn")

func _on_settings_pressed() -> void:
	_play_sfx("ui_click")
	if settings_menu:
		settings_menu.open_menu(0) # 0: Графика

func _on_guide_pressed() -> void:
	_play_sfx("ui_click")
	if settings_menu:
		settings_menu.open_menu(2) # 2: Управление / Клавиши

func _on_testhub_pressed() -> void:
	_play_sfx("ui_click")
	print("[MENU] Opening Test Hub...")
	get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")

func _on_quit_pressed() -> void:
	_play_sfx("ui_click")
	print("[MENU] Quitting application...")
	get_tree().quit()
