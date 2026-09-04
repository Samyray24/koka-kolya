extends Node3D

# Vehicle Lab Controller for «Кока-Коля» (v0.2.0)
# Тестовый полигон для проверки физики фургона доставки на Jolt Physics 3D

@onready var lbl_status: Label = $DebugUI/MarginContainer/VBoxContainer/LblStatus
@onready var lbl_speed: Label = $DebugUI/MarginContainer/VBoxContainer/LblSpeed
@onready var lbl_cargo: Label = $DebugUI/MarginContainer/VBoxContainer/LblCargo
@onready var lbl_fps: Label = $DebugUI/MarginContainer/VBoxContainer/LblFPS
@onready var van: VehicleBody3D = $DeliveryVan as VehicleBody3D

func _ready() -> void:
	LogManager.info("Vehicle Lab сцена инициализирована.", "VEHICLE_LAB")
	if van:
		van.connect("player_entered", func() -> void:
			if lbl_status: lbl_status.text = "Статус: ЗА РУЛЕМ (Режим вождения)"
		)
		van.connect("player_exited", func() -> void:
			if lbl_status: lbl_status.text = "Статус: ПЕШЕХОД (Нажмите [E] у двери водителя)"
		)

func _process(_delta: float) -> void:
	if lbl_fps:
		lbl_fps.text = "FPS: %d | Frame Time: %.2f ms" % [Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second())]
	if van and lbl_speed and lbl_cargo:
		var speed_kmh: float = van.linear_velocity.length() * 3.6
		var is_driven: bool = van.get("is_driven")
		lbl_speed.text = "Скорость фургона: %.1f км/ч (%s)" % [speed_kmh, "В движении" if is_driven else "Паркинг"]
		var cargo_m: float = van.get("current_cargo_mass")
		lbl_cargo.text = "Масса груза в кузове: %.1f кг" % cargo_m

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("test_hub"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/testlabs/test_hub.tscn")
