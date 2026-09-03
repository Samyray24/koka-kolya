extends Control

# Boot Scene Controller for «Кока-Коля»
# Initializes core systems, validates Jolt physics, and navigates to Main Menu or Test Hub.

@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

func _ready() -> void:
	print("[BOOT] Starting «Кока-Коля» initialization (v0.0.1 - Foundation)...")
	_log_system_info()
	_verify_physics_backend()
	_load_next_scene()

func _log_system_info() -> void:
	var os_name: String = OS.get_name()
	var processor: String = OS.get_processor_name()
	var video_adapter: String = RenderingServer.get_video_adapter_name()
	print("[BOOT] OS: %s | CPU: %s | GPU: %s" % [os_name, processor, video_adapter])

func _verify_physics_backend() -> void:
	var physics_engine: String = ProjectSettings.get_setting("physics/3d/physics_engine", "Default")
	print("[BOOT] Active 3D Physics Engine: %s" % physics_engine)
	if status_label:
		status_label.text = "Инициализация: Jolt Physics 3D (%s)..." % physics_engine

func _load_next_scene() -> void:
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
