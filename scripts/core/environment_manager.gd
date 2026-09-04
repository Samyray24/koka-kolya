extends Node

# EnvironmentManager — Менеджер динамического времени суток, погоды и атмосферы Краснограда
# Управляет углом солнца/луны, цветовой палитрой неба, туманом и погодными состояниями.

signal hour_passed(hour: int)
signal weather_changed(new_weather: String)

enum WeatherType { CLEAR, INDUSTRIAL_SMOG, NEON_RAIN }

var current_weather: WeatherType = WeatherType.CLEAR
var time_of_day: float = 14.0 # 21:30 — атмосферная неоновая ночь по умолчанию
var time_scale: float = 0.05 # 1 игровой час за ~20 реальных секунд (если включена симуляция)
var simulate_time: bool = false

var last_hour: int = 21

func _ready() -> void:
	LogManager.info("EnvironmentManager инициализирован. Время: %.1f:00, Погода: CLEAR." % time_of_day, "ATMOSPHERE")

func _process(delta: float) -> void:
	if not simulate_time:
		return

	time_of_day += delta * time_scale
	if time_of_day >= 24.0:
		time_of_day -= 24.0

	var cur_hour := int(time_of_day)
	if cur_hour != last_hour:
		last_hour = cur_hour
		hour_passed.emit(cur_hour)

func set_time(hour: float) -> void:
	time_of_day = clampf(hour, 0.0, 24.0)
	last_hour = int(time_of_day)
	hour_passed.emit(last_hour)
	LogManager.info("Установлено время суток: %02d:%02d" % [int(time_of_day), int(fmod(time_of_day, 1.0) * 60.0)], "ATMOSPHERE")

func set_weather(weather_name: String) -> void:
	match weather_name.to_upper():
		"CLEAR":
			current_weather = WeatherType.CLEAR
		"SMOG", "INDUSTRIAL_SMOG":
			current_weather = WeatherType.INDUSTRIAL_SMOG
		"RAIN", "NEON_RAIN":
			current_weather = WeatherType.NEON_RAIN
		_:
			LogManager.warn("Неизвестный тип погоды: %s" % weather_name, "ATMOSPHERE")
			return

	weather_changed.emit(weather_name)
	LogManager.info("Погода в Краснограде изменена на: %s" % weather_name, "ATMOSPHERE")

func get_ambient_light_color() -> Color:
	# Рассчитываем цвет амбиентного света от времени суток
	if time_of_day >= 6.0 and time_of_day < 10.0:
		return Color(0.85, 0.75, 0.65) # Утро / рассвет
	elif time_of_day >= 10.0 and time_of_day < 18.0:
		return Color(0.9, 0.92, 0.95) # Полдень
	elif time_of_day >= 18.0 and time_of_day < 22.0:
		return Color(0.85, 0.45, 0.35) # Закат
	else:
		return Color(0.35, 0.42, 0.55) # Ночь Краснограда