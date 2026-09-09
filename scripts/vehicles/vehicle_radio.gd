class_name VehicleRadio
extends Node3D

# Автомобильная радиостанция «Колямобиля»
# Позволяет переключать волны радиовещания Краснограда во время поездки на фургоне.

signal station_changed(station_name: String)
signal track_changed(track_title: String)

var stations: Array[String] = [
	"Выключено",
	"Радио Красноград — 98.4 FM (Синтвейв)",
	"Радио Меридиан — 103.8 FM (Техно-Андерграунд)",
	"Радио Гараж Коли — 106.6 FM (Бунтарский Рок)",
	"Голос Краснограда — 89.1 FM (Новости & Сатира)"
]

const STATION_PLAYLISTS: Dictionary = {
	1: [
		"res://assets/audio/radio/synthwave_neon_run.wav",
		"res://assets/audio/radio/synthwave_cyber_drive.wav",
		"res://assets/audio/radio/synthwave_midnight_escape.wav"
	],
	2: [
		"res://assets/audio/radio/techno_industrial_pulse.wav",
		"res://assets/audio/radio/techno_meridian_protocol.wav",
		"res://assets/audio/radio/techno_acid_rebellion.wav"
	],
	3: [
		"res://assets/audio/radio/rock_syrup_overdrive.wav",
		"res://assets/audio/radio/rock_delivery_rush.wav",
		"res://assets/audio/radio/rock_krasnograd_riot.wav"
	],
	4: [
		"res://assets/audio/radio/radio_news_meridian_tax.wav",
		"res://assets/audio/radio/radio_commercial_syrup.wav",
		"res://assets/audio/radio/radio_meridian_warning.wav"
	]
}

var current_station_idx: int = 0
var current_track_idx: int = 0
var is_playing: bool = false
@onready var audio_player: AudioStreamPlayer3D = get_node_or_null("RadioAudio")

func _ready() -> void:
	if not audio_player:
		audio_player = AudioStreamPlayer3D.new()
		audio_player.name = "RadioAudio"
		audio_player.max_distance = 35.0
		audio_player.unit_size = 10.0
		audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(audio_player)
	
	if not audio_player.finished.is_connected(_on_audio_finished):
		audio_player.finished.connect(_on_audio_finished)

func cycle_station() -> String:
	current_station_idx = (current_station_idx + 1) % stations.size()
	var station_name: String = stations[current_station_idx]
	is_playing = current_station_idx > 0
	current_track_idx = 0

	station_changed.emit(station_name)
	LogManager.info("[АВТО-РАДИО]: Волна переключена на «%s»" % station_name, "RADIO")

	if has_node("/root/AudioManager"):
		var am: Node = get_node("/root/AudioManager")
		am.call("play_sfx", "click", -4.0)

	_play_current_station_track()
	return station_name

func _play_current_station_track() -> void:
	if not audio_player:
		return

	if current_station_idx == 0 or not STATION_PLAYLISTS.has(current_station_idx):
		audio_player.stop()
		return

	var playlist: Array = STATION_PLAYLISTS[current_station_idx]
	if playlist.is_empty():
		audio_player.stop()
		return

	if current_track_idx >= playlist.size():
		current_track_idx = 0

	var track_path: String = playlist[current_track_idx]
	if ResourceLoader.exists(track_path):
		var stream: AudioStream = load(track_path)
		if stream:
			audio_player.stream = stream
			audio_player.volume_db = -3.0
			audio_player.play()
			track_changed.emit(track_path.get_file().get_basename())
			LogManager.info("[АВТО-РАДИО]: Воспроизведение трека «%s»" % track_path.get_file(), "RADIO")
	else:
		LogManager.warn("[АВТО-РАДИО]: Файл трека не найден: %s" % track_path, "RADIO")

func _on_audio_finished() -> void:
	if current_station_idx > 0 and STATION_PLAYLISTS.has(current_station_idx):
		var playlist: Array = STATION_PLAYLISTS[current_station_idx]
		current_track_idx = (current_track_idx + 1) % playlist.size()
		_play_current_station_track()

func get_current_station() -> String:
	return stations[current_station_idx]

func get_current_station_name() -> String:
	return stations[current_station_idx]