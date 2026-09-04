class_name GraphicsLab
extends Node3D

# Интерактивная сцена-тест графических технологий, шейдеров и PBR-материалов

const ScalabilityManagerScript = preload("res://scripts/core/scalability_manager.gd")

@onready var world_env: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var fps_label: Label = get_node_or_null("HUD/Margin/VBox/FPSLabel")
@onready var preset_label: Label = get_node_or_null("HUD/Margin/VBox/PresetLabel")
@onready var details_label: Label = get_node_or_null("HUD/Margin/VBox/DetailsLabel")

var scalability: Node = null
var current_preset: int = 1 # Medium by default

func _ready() -> void:
	scalability = ScalabilityManagerScript.new()
	add_child(scalability)
	
	if world_env and world_env.environment:
		scalability.call("apply_preset", current_preset, get_viewport(), world_env.environment)
		_update_hud()
		
	LogManager.info("Graphics Lab запущена. Тестирование PBR, SSR, SSAO и Glow активно.", "GRAPHICS_LAB")

func _process(_delta: float) -> void:
	if fps_label:
		var fps := Engine.get_frames_per_second()
		fps_label.text = "FPS: %d (Кадр: %.2f мс)" % [fps, 1000.0 / maxf(1.0, float(fps))]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_preset(0) # LOW
			KEY_2:
				_set_preset(1) # MEDIUM
			KEY_3:
				_set_preset(2) # HIGH
				
	if event.is_action_pressed("test_hub"):
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")

func _set_preset(idx: int) -> void:
	current_preset = idx
	if scalability and world_env and world_env.environment:
		scalability.call("apply_preset", current_preset, get_viewport(), world_env.environment)
		_update_hud()

func _update_hud() -> void:
	if preset_label and scalability:
		preset_label.text = "Профиль: %s" % scalability.call("get_preset_name", current_preset)
	if details_label and world_env and world_env.environment:
		var env: Environment = world_env.environment
		var vp: Viewport = get_viewport()
		var msaa_str := "Выкл" if vp.msaa_3d == Viewport.MSAA_DISABLED else ("2X" if vp.msaa_3d == Viewport.MSAA_2X else "4X")
		var fsr_str := "100% (Native)" if vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR else ("%.0f%% FSR" % (vp.scaling_3d_scale * 100))
		details_label.text = "Разрешение: %s | MSAA: %s | SSAO: %s | SSR: %s | Glow: %s" % [
			fsr_str,
			msaa_str,
			"ВКЛ" if env.ssao_enabled else "ВЫКЛ",
			"ВКЛ" if env.ssr_enabled else "ВЫКЛ",
			"ВКЛ" if env.glow_enabled else "ВЫКЛ"
		]