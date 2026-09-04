class_name VehicleRadio
extends Node3D

# Автомобильная радиостанция «Колямобиля»
# Позволяет переключать волны радиовещания Краснограда во время поездки на фургоне.

signal station_changed(station_name: String)

var stations: Array[String] = [
	"Выключено",
	"Радио Красноград — 104.2 FM (Хиты Сопротивления)",
	"MERIDIAN Corporate Wave (Корпоративный эфир)",
	"Пиратская Волна СашиV (Сводки подполья)"
]

var current_station_idx: int = 0
var is_playing: bool = false
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("RadioAudio")

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "RadioAudio"
		audio_player.max_distance = 25.0
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(audio_player)

func cycle_station() -> String:
	current_station_idx = (current_station_idx + 1) % stations.size()
	var station_name: String = stations[current_station_idx]
	is_playing = current_station_idx > 0

	station_changed.emit(station_name)
	LogManager.info("[АВТО-РАДИО]: Волна переключена на «%s»" % station_name, "RADIO")

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "click", -4.0)

	return station_name

func get_current_station() -> String:
	return stations[current_station_idx]