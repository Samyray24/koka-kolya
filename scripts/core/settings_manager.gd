extends Node

# SettingsManager — Управление настройками графики, звука, управления и доступности
# Сохраняет и загружает параметры из user://settings.json

signal settings_changed(category: String)

const SAVE_PATH: String = "user://settings.json"

var settings: Dictionary = {
	"display": {
		"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
		"resolution_width": 1920,
		"resolution_height": 1080,
		"vsync_mode": DisplayServer.VSYNC_ENABLED,
		"max_fps": 60,
		"fov": 85.0
	},
	"graphics": {
		"preset": "balanced", # performance, balanced, ultra, cyberpunk
		"msaa_3d": RenderingServer.VIEWPORT_MSAA_2X,
		"ssao_enabled": true,
		"glow_enabled": true,
		"color_filter": 0, # 0: Киберпанк, 1: Нуар, 2: Реализм, 3: Ретро
		"motion_blur": true,
		"shadow_quality": 2 # 0: Low, 1: Med, 2: High
	},
	"audio": {
		"master_volume": 0.85,
		"sfx_volume": 0.9,
		"music_volume": 0.7,
		"radio_volume": 0.85,
		"dialogue_volume": 1.0,
		"default_radio_station": 0 # 0: Радио Свободный Коля, 1: Синдикат FM, 2: Неоновый Дрифт
	},
	"accessibility": {
		"camera_shake_scale": 1.0, # 0.0 to 1.5
		"head_bob_scale": 1.0,
		"subtitle_scale": 1.0,
		"high_contrast_mode": false,
		"coyote_time_extended": false
	},
	"controls": {
		"mouse_sensitivity": 0.0022,
		"invert_y": false,
		"head_bob": true,
		"vehicle_steering_mode": 1, # 0: Мягкий круиз, 1: Спортивный, 2: Дрифт-мастер
		"dynamic_vehicle_cam": true,
		"crosshair_color_index": 0, # 0: Неоновый Cyan, 1: Токсичный Green, 2: Красный Red, 3: Желтый Gold
		"damage_numbers": true
	}
}

func _ready() -> void:
	load_settings()
	apply_all_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_settings()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result == OK and json.data is Dictionary:
		var loaded_data: Dictionary = json.data
		for cat: String in loaded_data.keys():
			if settings.has(cat) and loaded_data[cat] is Dictionary:
				for key: String in (loaded_data[cat] as Dictionary).keys():
					settings[cat][key] = loaded_data[cat][key]

func save_settings() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func apply_all_settings() -> void:
	apply_display_settings()
	apply_graphics_settings()
	apply_audio_settings()
	settings_changed.emit("all")

func apply_display_settings() -> void:
	var disp: Dictionary = settings["display"]
	var mode: int = int(disp.get("window_mode", DisplayServer.WINDOW_MODE_WINDOWED))
	DisplayServer.window_set_mode(mode as DisplayServer.WindowMode)
	
	var vsync: int = int(disp.get("vsync_mode", DisplayServer.VSYNC_ENABLED))
	DisplayServer.window_set_vsync_mode(vsync as DisplayServer.VSyncMode)
	
	var fps: int = int(disp.get("max_fps", 60))
	Engine.max_fps = fps

func apply_graphics_settings() -> void:
	var gfx: Dictionary = settings["graphics"]
	var msaa: int = int(gfx.get("msaa_3d", RenderingServer.VIEWPORT_MSAA_2X))
	RenderingServer.viewport_set_msaa_3d(get_viewport().get_viewport_rid(), msaa as RenderingServer.ViewportMSAA)

func apply_audio_settings() -> void:
	var aud: Dictionary = settings.get("audio", {})
	var master_vol: float = aud.get("master_volume", 0.85)
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_vol) if master_vol > 0.01 else -80.0)

func get_val(category: String, key: String, default_val: Variant = null) -> Variant:
	if settings.has(category) and settings[category].has(key):
		return settings[category][key]
	return default_val

func set_val(category: String, key: String, value: Variant) -> void:
	if not settings.has(category):
		settings[category] = {}
	settings[category][key] = value
	save_settings()
	settings_changed.emit(category)

func apply_preset(preset_name: String) -> void:
	match preset_name:
		"performance":
			settings["graphics"]["preset"] = "performance"
			settings["graphics"]["msaa_3d"] = RenderingServer.VIEWPORT_MSAA_DISABLED
			settings["graphics"]["ssao_enabled"] = false
			settings["graphics"]["glow_enabled"] = false
			settings["graphics"]["shadow_quality"] = 0
			settings["display"]["max_fps"] = 120
		"balanced":
			settings["graphics"]["preset"] = "balanced"
			settings["graphics"]["msaa_3d"] = RenderingServer.VIEWPORT_MSAA_2X
			settings["graphics"]["ssao_enabled"] = true
			settings["graphics"]["glow_enabled"] = true
			settings["graphics"]["shadow_quality"] = 1
			settings["display"]["max_fps"] = 60
		"ultra", "cyberpunk":
			settings["graphics"]["preset"] = "cyberpunk"
			settings["graphics"]["msaa_3d"] = RenderingServer.VIEWPORT_MSAA_4X
			settings["graphics"]["ssao_enabled"] = true
			settings["graphics"]["glow_enabled"] = true
			settings["graphics"]["shadow_quality"] = 2
			settings["display"]["max_fps"] = 144
	save_settings()
	apply_all_settings()

func reset_to_defaults() -> void:
	settings = {
		"display": {
			"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
			"resolution_width": 1920,
			"resolution_height": 1080,
			"vsync_mode": DisplayServer.VSYNC_ENABLED,
			"max_fps": 60,
			"fov": 85.0
		},
		"graphics": {
			"preset": "balanced",
			"msaa_3d": RenderingServer.VIEWPORT_MSAA_2X,
			"ssao_enabled": true,
			"glow_enabled": true,
			"color_filter": 0,
			"motion_blur": true,
			"shadow_quality": 2
		},
		"audio": {
			"master_volume": 0.85,
			"sfx_volume": 0.9,
			"music_volume": 0.7,
			"radio_volume": 0.85,
			"dialogue_volume": 1.0,
			"default_radio_station": 0
		},
		"accessibility": {
			"camera_shake_scale": 1.0,
			"head_bob_scale": 1.0,
			"subtitle_scale": 1.0,
			"high_contrast_mode": false,
			"coyote_time_extended": false
		},
		"controls": {
			"mouse_sensitivity": 0.0022,
			"invert_y": false,
			"head_bob": true,
			"vehicle_steering_mode": 1,
			"dynamic_vehicle_cam": true,
			"crosshair_color_index": 0,
			"damage_numbers": true
		}
	}
	save_settings()
	apply_all_settings()
