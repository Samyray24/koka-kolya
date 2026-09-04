class_name ScalabilityManager
extends Node

# Менеджер профилей производительности и графической масштабируемости (RX 550 Focused)
# Пресеты: LOW (60+ FPS), MEDIUM (Баланс 45-60 FPS), HIGH (Максимальное качество)

signal preset_applied(preset_idx: int, preset_name: String)

enum Preset {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2
}

const PRESET_NAMES: Array[String] = [
	"Низкие (RX 550 Fast / 60+ FPS)",
	"Средние (Сбалансированные / 50 FPS)",
	"Высокие (Кинематографичные)"
]

var current_preset: Preset = Preset.MEDIUM

func _ready() -> void:
	LogManager.info("ScalabilityManager загружен. Текущий пресет по умолчанию: %s" % PRESET_NAMES[current_preset], "GRAPHICS")

func apply_preset(preset: Preset, target_viewport: Viewport = null, target_env: Environment = null) -> void:
	current_preset = preset
	var vp := target_viewport if target_viewport else get_viewport()
	
	match preset:
		Preset.LOW:
			_apply_low(vp, target_env)
		Preset.MEDIUM:
			_apply_medium(vp, target_env)
		Preset.HIGH:
			_apply_high(vp, target_env)
			
	preset_applied.emit(int(preset), PRESET_NAMES[preset])
	LogManager.info("Применен профиль масштабируемости: [%d] %s" % [int(preset), PRESET_NAMES[preset]], "GRAPHICS")

func _apply_low(vp: Viewport, env: Environment) -> void:
	if vp:
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.77
		vp.positional_shadow_atlas_size = 1024
		
	RenderingServer.directional_shadow_atlas_set_size(1024, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	
	if env:
		env.ssao_enabled = false
		env.ssr_enabled = false
		env.glow_enabled = false
		env.volumetric_fog_enabled = false

func _apply_medium(vp: Viewport, env: Environment) -> void:
	if vp:
		vp.msaa_3d = Viewport.MSAA_2X
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.85
		vp.positional_shadow_atlas_size = 2048
		
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	
	if env:
		env.ssao_enabled = true
		env.ssr_enabled = false
		env.glow_enabled = true
		env.volumetric_fog_enabled = false

func _apply_high(vp: Viewport, env: Environment) -> void:
	if vp:
		vp.msaa_3d = Viewport.MSAA_4X
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.positional_shadow_atlas_size = 4096
		
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	
	if env:
		env.ssao_enabled = true
		env.ssr_enabled = true
		env.glow_enabled = true
		env.volumetric_fog_enabled = false

func get_preset_name(preset: Preset) -> String:
	if preset >= 0 and preset < PRESET_NAMES.size():
		return PRESET_NAMES[preset]
	return "Пользовательские"