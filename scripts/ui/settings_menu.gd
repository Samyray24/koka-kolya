class_name SettingsMenu
extends Control

# Расширенное меню настроек и управления игры «Кока-Коля»
# Поддерживает тонкую настройку графики, звука, чувствительности мыши и наглядный гид по управлению.

signal closed

@onready var tab_container: TabContainer = get_node_or_null("Center/Panel/Margin/VBox/TabContainer")

# Display Controls
@onready var opt_window_mode: OptionButton = find_child("OptWindowMode", true, false)
@onready var check_vsync: CheckButton = find_child("CheckVSync", true, false)
@onready var slider_fov: HSlider = find_child("SliderFOV", true, false)
@onready var label_fov_val: Label = find_child("LabelFOVVal", true, false)
@onready var opt_msaa: OptionButton = find_child("OptMSAA", true, false)

# Audio Controls
@onready var slider_master: HSlider = find_child("SliderMaster", true, false)
@onready var label_master_val: Label = find_child("LabelMasterVal", true, false)
@onready var slider_sfx: HSlider = find_child("SliderSFX", true, false)
@onready var label_sfx_val: Label = find_child("LabelSFXVal", true, false)
@onready var slider_music: HSlider = find_child("SliderMusic", true, false)
@onready var label_music_val: Label = find_child("LabelMusicVal", true, false)
@onready var btn_test_sound: Button = find_child("BtnTestSound", true, false)

# Controls
@onready var slider_sensitivity: HSlider = find_child("SliderSens", true, false)
@onready var label_sens_val: Label = find_child("LabelSensVal", true, false)
@onready var check_invert_y: CheckButton = find_child("CheckInvertY", true, false)

# Bottom Buttons
@onready var btn_apply: Button = find_child("BtnApply", true, false)
@onready var btn_close: Button = find_child("BtnClose", true, false)
@onready var btn_top_close: Button = find_child("BtnTopClose", true, false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if tab_container:
		tab_container.set_tab_title(0, "🖥️ ГРАФИКА")
		tab_container.set_tab_title(1, "🔊 ЗВУК")
		tab_container.set_tab_title(2, "🎮 УПРАВЛЕНИЕ")
		tab_container.set_tab_title(3, "📖 РУКОВОДСТВО")
	_setup_signals()
	_load_current_values()

func _setup_signals() -> void:
	if btn_apply:
		btn_apply.pressed.connect(_on_apply_pressed)
		_hook_button_sounds(btn_apply)
	if btn_close:
		btn_close.pressed.connect(close_menu)
		_hook_button_sounds(btn_close)
	if btn_top_close:
		btn_top_close.pressed.connect(close_menu)
		_hook_button_sounds(btn_top_close)
	if btn_test_sound:
		btn_test_sound.pressed.connect(_on_test_sound_pressed)
		_hook_button_sounds(btn_test_sound)

	if slider_fov:
		slider_fov.value_changed.connect(func(v: float) -> void:
			if label_fov_val:
				label_fov_val.text = "%d°" % int(v)
		)
	if slider_master:
		slider_master.value_changed.connect(func(v: float) -> void:
			if label_master_val:
				label_master_val.text = "%d%%" % int(v * 100.0)
		)
	if slider_sfx:
		slider_sfx.value_changed.connect(func(v: float) -> void:
			if label_sfx_val:
				label_sfx_val.text = "%d%%" % int(v * 100.0)
		)
	if slider_music:
		slider_music.value_changed.connect(func(v: float) -> void:
			if label_music_val:
				label_music_val.text = "%d%%" % int(v * 100.0)
		)
	if slider_sensitivity:
		slider_sensitivity.value_changed.connect(func(v: float) -> void:
			if label_sens_val:
				label_sens_val.text = "%.1fx" % (v * 1000.0)
		)

func _hook_button_sounds(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void:
		_play_sfx("ui_hover", -12.0)
	)

func _load_current_values() -> void:
	if not has_node("/root/SettingsManager"):
		return
	var sm: Node = get_node("/root/SettingsManager")

	# 1. Display
	if opt_window_mode:
		var wm: int = int(sm.call("get_val", "display", "window_mode", DisplayServer.WINDOW_MODE_WINDOWED))
		opt_window_mode.selected = 1 if wm == DisplayServer.WINDOW_MODE_FULLSCREEN else 0

	if check_vsync:
		var vsync: int = int(sm.call("get_val", "display", "vsync_mode", DisplayServer.VSYNC_ENABLED))
		check_vsync.button_pressed = (vsync == DisplayServer.VSYNC_ENABLED)

	if slider_fov:
		var fov: float = float(sm.call("get_val", "display", "fov", 85.0))
		slider_fov.value = fov
		if label_fov_val:
			label_fov_val.text = "%d°" % int(fov)

	if opt_msaa:
		var msaa: int = int(sm.call("get_val", "graphics", "msaa_3d", RenderingServer.VIEWPORT_MSAA_2X))
		opt_msaa.selected = clampi(msaa, 0, 2)

	# 2. Audio
	if slider_master:
		var m_vol: float = float(sm.call("get_val", "audio", "master_volume", 0.85))
		slider_master.value = m_vol
		if label_master_val:
			label_master_val.text = "%d%%" % int(m_vol * 100.0)

	if slider_sfx:
		var s_vol: float = float(sm.call("get_val", "audio", "sfx_volume", 0.9))
		slider_sfx.value = s_vol
		if label_sfx_val:
			label_sfx_val.text = "%d%%" % int(s_vol * 100.0)

	if slider_music:
		var mu_vol: float = float(sm.call("get_val", "audio", "music_volume", 0.7))
		slider_music.value = mu_vol
		if label_music_val:
			label_music_val.text = "%d%%" % int(mu_vol * 100.0)

	# 3. Controls
	if slider_sensitivity:
		var sens: float = float(sm.call("get_val", "controls", "mouse_sensitivity", 0.0022))
		slider_sensitivity.value = sens
		if label_sens_val:
			label_sens_val.text = "%.1fx" % (sens * 1000.0)

	if check_invert_y:
		var inv: bool = bool(sm.call("get_val", "controls", "invert_y", false))
		check_invert_y.button_pressed = inv

func _on_apply_pressed() -> void:
	if not has_node("/root/SettingsManager"):
		return
	var sm: Node = get_node("/root/SettingsManager")

	# Save Display
	if opt_window_mode:
		var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if opt_window_mode.selected == 1 else DisplayServer.WINDOW_MODE_WINDOWED
		sm.call("set_val", "display", "window_mode", mode)
	if check_vsync:
		var vsync: int = DisplayServer.VSYNC_ENABLED if check_vsync.button_pressed else DisplayServer.VSYNC_DISABLED
		sm.call("set_val", "display", "vsync_mode", vsync)
	if slider_fov:
		sm.call("set_val", "display", "fov", slider_fov.value)
	if opt_msaa:
		sm.call("set_val", "graphics", "msaa_3d", opt_msaa.selected)

	# Save Audio
	if slider_master:
		sm.call("set_val", "audio", "master_volume", slider_master.value)
	if slider_sfx:
		sm.call("set_val", "audio", "sfx_volume", slider_sfx.value)
	if slider_music:
		sm.call("set_val", "audio", "music_volume", slider_music.value)

	# Save Controls
	if slider_sensitivity:
		sm.call("set_val", "controls", "mouse_sensitivity", slider_sensitivity.value)
	if check_invert_y:
		sm.call("set_val", "controls", "invert_y", check_invert_y.button_pressed)

	sm.call("apply_all_settings")
	_play_sfx("ui_click")

func _on_test_sound_pressed() -> void:
	_play_sfx("hint", -2.0)

func open_tab(tab_idx: int) -> void:
	if tab_container and tab_idx >= 0 and tab_idx < tab_container.get_tab_count():
		tab_container.current_tab = tab_idx

func open_menu(tab_idx: int = 0) -> void:
	visible = true
	_load_current_values()
	open_tab(tab_idx)
	_play_sfx("ui_click", -4.0)

func close_menu() -> void:
	visible = false
	closed.emit()
	_play_sfx("ui_click", -6.0)

func _play_sfx(sound_name: String, vol: float = 0.0) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", sound_name, vol)
