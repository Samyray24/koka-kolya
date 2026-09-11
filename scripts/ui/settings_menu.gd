class_name SettingsMenu
extends Control

# Расширенное меню настроек и управления игры «Кока-Коля»
# Поддерживает тонкую настройку графики, звука, чувствительности мыши и наглядный гид по управлению.

signal closed

@onready var tab_container: TabContainer = get_node_or_null("Center/Panel/Margin/VBox/TabContainer")

# Display & Graphics Controls
@onready var opt_window_mode: OptionButton = find_child("OptWindowMode", true, false)
@onready var check_vsync: CheckButton = find_child("CheckVSync", true, false)
@onready var slider_fov: HSlider = find_child("SliderFOV", true, false)
@onready var label_fov_val: Label = find_child("LabelFOVVal", true, false)
@onready var opt_msaa: OptionButton = find_child("OptMSAA", true, false)
@onready var opt_color_filter: OptionButton = find_child("OptColorFilter", true, false)
@onready var check_motion_blur: CheckButton = find_child("CheckMotionBlur", true, false)
@onready var btn_preset_perf: Button = find_child("BtnPresetPerf", true, false)
@onready var btn_preset_bal: Button = find_child("BtnPresetBal", true, false)
@onready var btn_preset_ultra: Button = find_child("BtnPresetUltra", true, false)

# Audio Controls
@onready var slider_master: HSlider = find_child("SliderMaster", true, false)
@onready var label_master_val: Label = find_child("LabelMasterVal", true, false)
@onready var slider_sfx: HSlider = find_child("SliderSFX", true, false)
@onready var label_sfx_val: Label = find_child("LabelSFXVal", true, false)
@onready var slider_music: HSlider = find_child("SliderMusic", true, false)
@onready var label_music_val: Label = find_child("LabelMusicVal", true, false)
@onready var slider_radio: HSlider = find_child("SliderRadio", true, false)
@onready var label_radio_val: Label = find_child("LabelRadioVal", true, false)
@onready var opt_default_radio: OptionButton = find_child("OptDefaultRadio", true, false)
@onready var btn_test_sound: Button = find_child("BtnTestSound", true, false)

# Controls & Gameplay
@onready var slider_sensitivity: HSlider = find_child("SliderSens", true, false)
@onready var label_sens_val: Label = find_child("LabelSensVal", true, false)
@onready var check_invert_y: CheckButton = find_child("CheckInvertY", true, false)
@onready var slider_shake: HSlider = find_child("SliderShake", true, false)
@onready var label_shake_val: Label = find_child("LabelShakeVal", true, false)
@onready var opt_steering: OptionButton = find_child("OptSteering", true, false)
@onready var check_dynamic_cam: CheckButton = find_child("CheckDynamicCam", true, false)
@onready var opt_crosshair_color: OptionButton = find_child("OptCrosshairColor", true, false)
@onready var check_damage_numbers: CheckButton = find_child("CheckDamageNumbers", true, false)

# Bottom Buttons
@onready var btn_apply: Button = find_child("BtnApply", true, false)
@onready var btn_reset: Button = find_child("BtnReset", true, false)
@onready var btn_close: Button = find_child("BtnClose", true, false)
@onready var btn_top_close: Button = find_child("BtnTopClose", true, false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 50
	z_as_relative = false
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
	if btn_reset:
		btn_reset.pressed.connect(_on_reset_pressed)
		_hook_button_sounds(btn_reset)
	if btn_close:
		btn_close.pressed.connect(close_menu)
		_hook_button_sounds(btn_close)
	if btn_top_close:
		btn_top_close.pressed.connect(close_menu)
		_hook_button_sounds(btn_top_close)
	if btn_test_sound:
		btn_test_sound.pressed.connect(_on_test_sound_pressed)
		_hook_button_sounds(btn_test_sound)

	# Presets
	if btn_preset_perf:
		btn_preset_perf.pressed.connect(func() -> void: _apply_quick_preset("performance"))
		_hook_button_sounds(btn_preset_perf)
	if btn_preset_bal:
		btn_preset_bal.pressed.connect(func() -> void: _apply_quick_preset("balanced"))
		_hook_button_sounds(btn_preset_bal)
	if btn_preset_ultra:
		btn_preset_ultra.pressed.connect(func() -> void: _apply_quick_preset("ultra"))
		_hook_button_sounds(btn_preset_ultra)

	# Live Slider Labels
	if slider_fov:
		slider_fov.value_changed.connect(func(v: float) -> void:
			if label_fov_val: label_fov_val.text = "%d°" % int(v)
		)
	if slider_master:
		slider_master.value_changed.connect(func(v: float) -> void:
			if label_master_val: label_master_val.text = "%d%%" % int(v * 100.0)
		)
	if slider_sfx:
		slider_sfx.value_changed.connect(func(v: float) -> void:
			if label_sfx_val: label_sfx_val.text = "%d%%" % int(v * 100.0)
		)
	if slider_music:
		slider_music.value_changed.connect(func(v: float) -> void:
			if label_music_val: label_music_val.text = "%d%%" % int(v * 100.0)
		)
	if slider_radio:
		slider_radio.value_changed.connect(func(v: float) -> void:
			if label_radio_val: label_radio_val.text = "%d%%" % int(v * 100.0)
		)
	if slider_sensitivity:
		slider_sensitivity.value_changed.connect(func(v: float) -> void:
			if label_sens_val: label_sens_val.text = "%.1fx" % (v * 1000.0)
		)
	if slider_shake:
		slider_shake.value_changed.connect(func(v: float) -> void:
			if label_shake_val: label_shake_val.text = "%d%%" % int(v * 100.0)
		)

func _hook_button_sounds(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void:
		_play_sfx("ui_hover", -12.0)
	)

func _load_current_values() -> void:
	if not has_node("/root/SettingsManager"):
		return
	var sm: Node = get_node("/root/SettingsManager")

	# 1. Display & Graphics
	if opt_window_mode:
		var wm: int = int(sm.call("get_val", "display", "window_mode", DisplayServer.WINDOW_MODE_WINDOWED))
		opt_window_mode.selected = 1 if wm == DisplayServer.WINDOW_MODE_FULLSCREEN else 0

	if check_vsync:
		var vsync: int = int(sm.call("get_val", "display", "vsync_mode", DisplayServer.VSYNC_ENABLED))
		check_vsync.button_pressed = (vsync == DisplayServer.VSYNC_ENABLED)

	if slider_fov:
		var fov: float = float(sm.call("get_val", "display", "fov", 85.0))
		slider_fov.value = fov
		if label_fov_val: label_fov_val.text = "%d°" % int(fov)

	if opt_msaa:
		var msaa: int = int(sm.call("get_val", "graphics", "msaa_3d", RenderingServer.VIEWPORT_MSAA_2X))
		opt_msaa.selected = clampi(msaa, 0, 2)

	if opt_color_filter:
		var cf: int = int(sm.call("get_val", "graphics", "color_filter", 0))
		opt_color_filter.selected = clampi(cf, 0, 3)

	if check_motion_blur:
		var mb: bool = bool(sm.call("get_val", "graphics", "motion_blur", true))
		check_motion_blur.button_pressed = mb

	# 2. Audio
	if slider_master:
		var m_vol: float = float(sm.call("get_val", "audio", "master_volume", 0.85))
		slider_master.value = m_vol
		if label_master_val: label_master_val.text = "%d%%" % int(m_vol * 100.0)

	if slider_sfx:
		var s_vol: float = float(sm.call("get_val", "audio", "sfx_volume", 0.9))
		slider_sfx.value = s_vol
		if label_sfx_val: label_sfx_val.text = "%d%%" % int(s_vol * 100.0)

	if slider_music:
		var mu_vol: float = float(sm.call("get_val", "audio", "music_volume", 0.7))
		slider_music.value = mu_vol
		if label_music_val: label_music_val.text = "%d%%" % int(mu_vol * 100.0)

	if slider_radio:
		var r_vol: float = float(sm.call("get_val", "audio", "radio_volume", 0.85))
		slider_radio.value = r_vol
		if label_radio_val: label_radio_val.text = "%d%%" % int(r_vol * 100.0)

	if opt_default_radio:
		var dr: int = int(sm.call("get_val", "audio", "default_radio_station", 0))
		opt_default_radio.selected = clampi(dr, 0, 2)

	# 3. Controls & Gameplay
	if slider_sensitivity:
		var sens: float = float(sm.call("get_val", "controls", "mouse_sensitivity", 0.0022))
		slider_sensitivity.value = sens
		if label_sens_val: label_sens_val.text = "%.1fx" % (sens * 1000.0)

	if check_invert_y:
		var inv: bool = bool(sm.call("get_val", "controls", "invert_y", false))
		check_invert_y.button_pressed = inv

	if slider_shake:
		var sh: float = float(sm.call("get_val", "accessibility", "camera_shake_scale", 1.0))
		slider_shake.value = sh
		if label_shake_val: label_shake_val.text = "%d%%" % int(sh * 100.0)

	if opt_steering:
		var st: int = int(sm.call("get_val", "controls", "vehicle_steering_mode", 1))
		opt_steering.selected = clampi(st, 0, 2)

	if check_dynamic_cam:
		var dc: bool = bool(sm.call("get_val", "controls", "dynamic_vehicle_cam", true))
		check_dynamic_cam.button_pressed = dc

	if opt_crosshair_color:
		var ch: int = int(sm.call("get_val", "controls", "crosshair_color_index", 0))
		opt_crosshair_color.selected = clampi(ch, 0, 3)

	if check_damage_numbers:
		var dn: bool = bool(sm.call("get_val", "controls", "damage_numbers", true))
		check_damage_numbers.button_pressed = dn

func _apply_quick_preset(preset_name: String) -> void:
	if has_node("/root/SettingsManager"):
		var sm: Node = get_node("/root/SettingsManager")
		sm.call("apply_preset", preset_name)
		_load_current_values()
		_play_sfx("ui_click")

func _on_reset_pressed() -> void:
	if has_node("/root/SettingsManager"):
		var sm: Node = get_node("/root/SettingsManager")
		sm.call("reset_to_defaults")
		_load_current_values()
		_play_sfx("ui_click")

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
	if opt_color_filter:
		sm.call("set_val", "graphics", "color_filter", opt_color_filter.selected)
	if check_motion_blur:
		sm.call("set_val", "graphics", "motion_blur", check_motion_blur.button_pressed)

	# Save Audio
	if slider_master:
		sm.call("set_val", "audio", "master_volume", slider_master.value)
	if slider_sfx:
		sm.call("set_val", "audio", "sfx_volume", slider_sfx.value)
	if slider_music:
		sm.call("set_val", "audio", "music_volume", slider_music.value)
	if slider_radio:
		sm.call("set_val", "audio", "radio_volume", slider_radio.value)
	if opt_default_radio:
		sm.call("set_val", "audio", "default_radio_station", opt_default_radio.selected)

	# Save Controls & Gameplay
	if slider_sensitivity:
		sm.call("set_val", "controls", "mouse_sensitivity", slider_sensitivity.value)
	if check_invert_y:
		sm.call("set_val", "controls", "invert_y", check_invert_y.button_pressed)
	if slider_shake:
		sm.call("set_val", "accessibility", "camera_shake_scale", slider_shake.value)
	if opt_steering:
		sm.call("set_val", "controls", "vehicle_steering_mode", opt_steering.selected)
	if check_dynamic_cam:
		sm.call("set_val", "controls", "dynamic_vehicle_cam", check_dynamic_cam.button_pressed)
	if opt_crosshair_color:
		sm.call("set_val", "controls", "crosshair_color_index", opt_crosshair_color.selected)
	if check_damage_numbers:
		sm.call("set_val", "controls", "damage_numbers", check_damage_numbers.button_pressed)

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

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_menu()
		get_viewport().set_input_as_handled()

func close_menu() -> void:
	visible = false
	closed.emit()
	_play_sfx("ui_click", -6.0)

func _play_sfx(sound_name: String, vol: float = 0.0) -> void:
	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", sound_name, vol)
