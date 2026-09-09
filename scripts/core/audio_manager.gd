extends Node

# Менеджер процедурного звука и SFX шин игры «Кока-Коля»
# Генерирует процедурные аудиосэмплы в реальном времени без внешних аудиофайлов.

var sfx_library: Dictionary = {}
var active_players_2d: Array[AudioStreamPlayer] = []
var active_players_3d: Array[AudioStreamPlayer3D] = []

const SAMPLE_RATE: int = 22050

func _ready() -> void:
	_generate_sound_library()
	_setup_audio_buses()
	LogManager.info("AudioManager инициализирован. Сгенерировано %d процедурных SFX." % sfx_library.size(), "AUDIO")

func _exit_tree() -> void:
	for p in active_players_2d:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for p in active_players_3d:
		if is_instance_valid(p):
			p.stop()
			p.stream = null

func _setup_audio_buses() -> void:
	# Инициализация пулов проигрывателей
	for i in range(8):
		var p2d := AudioStreamPlayer.new()
		p2d.name = "Player2D_%d" % i
		add_child(p2d)
		active_players_2d.append(p2d)

	for i in range(12):
		var p3d := AudioStreamPlayer3D.new()
		p3d.name = "Player3D_%d" % i
		p3d.max_distance = 35.0
		p3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3d)
		active_players_3d.append(p3d)

func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sfx_library.has(sound_name):
		LogManager.debug("SFX не найден: %s" % sound_name, "AUDIO")
		return

	# В headless-режиме dummy аудиодрайвер не крутит микшер, избегаем зависания буферов
	if DisplayServer.get_name() == "headless":
		return

	var stream: AudioStreamWAV = sfx_library[sound_name]
	for player in active_players_2d:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch_scale
			player.play()
			return

	if not active_players_2d.is_empty():
		var p: AudioStreamPlayer = active_players_2d[0]
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch_scale
		p.play()

func play_sfx_3d(sound_name: String, pos: Vector3, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sfx_library.has(sound_name):
		return

	if DisplayServer.get_name() == "headless":
		return

	var stream: AudioStreamWAV = sfx_library[sound_name]
	for player in active_players_3d:
		if not player.playing:
			player.global_position = pos
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch_scale
			player.play()
			return

	if not active_players_3d.is_empty():
		var p: AudioStreamPlayer3D = active_players_3d[0]
		p.global_position = pos
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch_scale
		p.play()

# Генерация процедурных звуков через PCM
func _generate_sound_library() -> void:
	sfx_library["click"] = _create_click_sound()
	sfx_library["ui_click"] = sfx_library["click"]
	sfx_library["ui_hover"] = _create_hover_sound()
	sfx_library["hint"] = _create_hint_sound()
	sfx_library["footstep"] = _create_footstep_sound()
	sfx_library["jump"] = _create_jump_sound()
	sfx_library["land"] = _create_land_sound()
	sfx_library["grab"] = _create_grab_sound()
	sfx_library["throw"] = _create_throw_sound()
	sfx_library["radio_chime"] = _create_radio_chime_sound()
	sfx_library["stun"] = _create_stun_sound()
	sfx_library["foam"] = _create_foam_sound()
	sfx_library["hack"] = _create_hack_sound()
	sfx_library["alarm"] = _create_alarm_sound()
	sfx_library["victory"] = _create_victory_sound()
	sfx_library["laser_shot"] = _create_laser_shot_sound()
	sfx_library["repeater_shot"] = _create_repeater_shot_sound()
	sfx_library["axe_swing"] = _create_axe_swing_sound()
	sfx_library["impact"] = _create_impact_sound()

func _create_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false

	var byte_array := PackedByteArray()
	byte_array.resize(samples.size() * 2)

	for i in range(samples.size()):
		var val: float = clampf(samples[i], -1.0, 1.0)
		var int_val: int = int(round(val * 32767.0))
		if int_val < 0:
			int_val += 65536
		byte_array[i * 2] = int_val & 0xFF
		byte_array[i * 2 + 1] = (int_val >> 8) & 0xFF

	wav.data = byte_array
	return wav

func _create_click_sound() -> AudioStreamWAV:
	# Мягкий тактильный щелчок (warm wooden pop ~480Hz) без режущего уши писка 1800Hz
	var count := int(SAMPLE_RATE * 0.035) # 35ms
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 110.0)
		var f1 := sin(t * TAU * 480.0) * 0.4
		var f2 := sin(t * TAU * 240.0) * 0.25
		samples[i] = (f1 + f2) * env
	return _create_wav(samples)

func _create_hover_sound() -> AudioStreamWAV:
	# Очень мягкий, приглушенный тик при наведении курсора на кнопку (320Hz, тихий)
	var count := int(SAMPLE_RATE * 0.018) # 18ms
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 180.0)
		samples[i] = sin(t * TAU * 340.0) * env * 0.15
	return _create_wav(samples)

func _create_hint_sound() -> AudioStreamWAV:
	# Приятный двухтоновый звуковой сигнал для подсказок и обновлений целей (523Hz -> 659Hz)
	var count := int(SAMPLE_RATE * 0.22)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var half := int(count * 0.45)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		if i < half:
			var env := exp(-t * 18.0)
			samples[i] = sin(t * TAU * 523.25) * env * 0.35
		else:
			var t2 := float(i - half) / float(SAMPLE_RATE)
			var env2 := exp(-t2 * 14.0)
			samples[i] = sin(t2 * TAU * 659.25) * env2 * 0.35
	return _create_wav(samples)

func _create_footstep_sound() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.09) # 90ms
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 35.0)
		var tone := sin(t * TAU * 120.0) * 0.5
		var noise := (randf() * 2.0 - 1.0) * 0.3
		samples[i] = (tone + noise) * env * 0.7
	return _create_wav(samples)

func _create_jump_sound() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.16) # 160ms
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var freq := 180.0 + t * 450.0 # Свип частоты вверх
		var env := (1.0 - t / 0.16)
		samples[i] = sin(t * TAU * freq) * env * 0.5
	return _create_wav(samples)

func _create_land_sound() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.14)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 22.0)
		var tone := sin(t * TAU * 80.0) * 0.7
		var noise := (randf() * 2.0 - 1.0) * 0.4
		samples[i] = (tone + noise) * env * 0.8
	return _create_wav(samples)

func _create_grab_sound() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.06)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 50.0)
		samples[i] = sin(t * TAU * 520.0) * env * 0.5
	return _create_wav(samples)

func _create_throw_sound() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.18)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(t / 0.18 * PI)
		var noise := (randf() * 2.0 - 1.0) * 0.6
		samples[i] = noise * env * 0.7
	return _create_wav(samples)

func _create_radio_chime_sound() -> AudioStreamWAV:
	# Двухтоновый мелодичный сигнал рации СашиV (523Hz C5 -> 659Hz E5)
	var count := int(SAMPLE_RATE * 0.28)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var half := int(count * 0.5)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		if i < half:
			var env := exp(-float(i) / float(SAMPLE_RATE) * 15.0)
			samples[i] = sin(t * TAU * 587.33) * env * 0.5
		else:
			var t2 := float(i - half) / float(SAMPLE_RATE)
			var env := exp(-t2 * 12.0)
			samples[i] = sin(t * TAU * 880.0) * env * 0.5
	return _create_wav(samples)

func _create_stun_sound() -> AudioStreamWAV:
	# Глубокий, плотный электрический импульс (120-240Hz с мягким насыщением) без противного визга и квадратных волн
	var count := int(SAMPLE_RATE * 0.20)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 9.0)
		var bass := sin(t * TAU * 130.0) * 0.5
		var sub := sin(t * TAU * 65.0) * 0.3
		var crackle := (randf() * 2.0 - 1.0) * 0.25 * exp(-t * 18.0)
		# Мягкое ограничение tanh для теплого эффекта перегруза
		var raw: float = bass + sub + crackle
		samples[i] = tanh(raw * 1.4) * env * 0.6
	return _create_wav(samples)

func _create_foam_sound() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.28)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 7.0)
		var noise := (randf() * 2.0 - 1.0) * 0.5
		samples[i] = noise * env * 0.5
	return _create_wav(samples)

func _create_hack_sound() -> AudioStreamWAV:
	# Мелодичный футуристический data-burst (G4 392Hz -> A4 440Hz -> C5 523Hz) с мягкими синусоидами
	var count := int(SAMPLE_RATE * 0.22)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var step := count / 3
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var seg := mini(i / step, 2)
		var freqs := [392.0, 440.0, 523.25]
		var f: float = freqs[seg]
		var t_sub := float(i % step) / float(SAMPLE_RATE)
		var env := exp(-t_sub * 16.0)
		samples[i] = sin(t * TAU * f) * env * 0.4
	return _create_wav(samples)

func _create_alarm_sound() -> AudioStreamWAV:
	# Кинематографичный низкий пульс тревоги (320-420Hz) без режущего ультразвукового свиста 880Hz
	var count := int(SAMPLE_RATE * 0.45)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var pulse := sin(t * TAU * 3.5) # Плавное дыхание сирены
		var freq := 320.0 + (pulse * 0.5 + 0.5) * 100.0
		var env := sin(t / 0.45 * PI)
		samples[i] = sin(t * TAU * freq) * env * 0.45
	return _create_wav(samples)

func _create_victory_sound() -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * 0.6)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var note_idx := int(t / 0.15)
		var notes := [523.25, 659.25, 783.99, 1046.5] # C - E - G - C
		var freq: float = notes[mini(note_idx, 3)]
		var env := exp(-fmod(t, 0.15) * 10.0)
		samples[i] = sin(t * TAU * freq) * env * 0.55
	return _create_wav(samples)

func _create_laser_shot_sound() -> AudioStreamWAV:
	# Энергетический плазменный выстрел (чистый нисходящий питч-глиссандо 750Hz -> 180Hz)
	var count := int(SAMPLE_RATE * 0.14)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var freq := 750.0 * exp(-t * 14.0) + 180.0
		var env := exp(-t * 12.0)
		var tone := sin(t * TAU * freq) * 0.5
		var sub := sin(t * TAU * (freq * 0.5)) * 0.3
		samples[i] = tanh((tone + sub) * 1.3) * env * 0.55
	return _create_wav(samples)

func _create_repeater_shot_sound() -> AudioStreamWAV:
	# Короткий резкий импульс автоматического плазмомета (620Hz -> 160Hz за 60ms)
	var count := int(SAMPLE_RATE * 0.07)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var freq := 620.0 * exp(-t * 22.0) + 160.0
		var env := exp(-t * 20.0)
		var tone := sin(t * TAU * freq) * 0.5
		var click := (randf() * 2.0 - 1.0) * 0.2 * exp(-t * 60.0)
		samples[i] = (tone + click) * env * 0.5
	return _create_wav(samples)

func _create_axe_swing_sound() -> AudioStreamWAV:
	# Мягкий свист рассекаемого воздуха при замахе тяжелого лезвия
	var count := int(SAMPLE_RATE * 0.18)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := sin(t / 0.18 * PI)
		var freq := 180.0 + sin(t * TAU * 3.0) * 60.0
		var noise := (randf() * 2.0 - 1.0) * 0.35
		var tone := sin(t * TAU * freq) * 0.3
		samples[i] = (tone + noise) * env * 0.4
	return _create_wav(samples)

func _create_impact_sound() -> AudioStreamWAV:
	# Кинетический удар лезвия или снаряда по преграде (глухой плотный щелчок 140Hz)
	var count := int(SAMPLE_RATE * 0.12)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 24.0)
		var bass := sin(t * TAU * 140.0) * 0.6
		var crunch := (randf() * 2.0 - 1.0) * 0.3 * exp(-t * 40.0)
		samples[i] = tanh((bass + crunch) * 1.5) * env * 0.6
	return _create_wav(samples)