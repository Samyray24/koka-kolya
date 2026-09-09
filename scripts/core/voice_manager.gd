extends Node

# Менеджер русской озвучки и кинематографичных субтитров игры «Кока-Коля»
# Управляет репликами Коли, Саши V, охраны и выводит динамические стильные субтитры.

signal voice_started(line_id: String, text: String)
signal voice_finished(line_id: String)

static var instance: Node = null

var voice_player: AudioStreamPlayer = null
var subtitle_canvas: CanvasLayer = null
var subtitle_label: RichTextLabel = null
var subtitle_panel: PanelContainer = null
var current_tween: Tween = null
var last_played_line: String = ""
var voice_cache: Dictionary = {}

const VOICE_DIR: String = "res://assets/audio/voice/"

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	_setup_audio()
	_setup_ui()
	LogManager.info("VoiceManager инициализирован. Русская озвучка готова.", "VOICE")

func _setup_audio() -> void:
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoiceAudioPlayer"
	voice_player.bus = "Master"
	add_child(voice_player)
	voice_player.finished.connect(_on_voice_finished)

func _setup_ui() -> void:
	subtitle_canvas = CanvasLayer.new()
	subtitle_canvas.name = "SubtitleCanvas"
	subtitle_canvas.layer = 20
	add_child(subtitle_canvas)

	subtitle_panel = PanelContainer.new()
	subtitle_panel.name = "SubtitlePanel"
	subtitle_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	subtitle_panel.anchor_left = 0.5
	subtitle_panel.anchor_top = 1.0
	subtitle_panel.anchor_right = 0.5
	subtitle_panel.anchor_bottom = 1.0
	subtitle_panel.offset_left = -380.0
	subtitle_panel.offset_top = -110.0
	subtitle_panel.offset_right = 380.0
	subtitle_panel.offset_bottom = -35.0
	subtitle_panel.visible = false
	subtitle_canvas.add_child(subtitle_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.88)
	style.border_color = Color(0.15, 0.85, 1.0, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	subtitle_panel.add_theme_stylebox_override("panel", style)

	subtitle_label = RichTextLabel.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.bbcode_enabled = true
	subtitle_label.fit_content = true
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_panel.add_child(subtitle_label)

func play_voice(line_id: String, subtitle_text: String = "", pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		LogManager.debug("Voice (headless): [%s] %s" % [line_id, subtitle_text], "VOICE")
		voice_started.emit(line_id, subtitle_text)
		return

	var stream: AudioStream = _get_voice_stream(line_id)
	if not stream:
		LogManager.debug("Аудиодорожка голоса не найдена: %s" % line_id, "VOICE")
		return

	last_played_line = line_id
	if voice_player:
		voice_player.stream = stream
		voice_player.pitch_scale = pitch
		voice_player.volume_db = volume_db
		voice_player.play()

	_show_subtitles(subtitle_text, stream.get_length() if stream is AudioStreamWAV else 3.5)
	voice_started.emit(line_id, subtitle_text)

func _get_voice_stream(line_id: String) -> AudioStream:
	if voice_cache.has(line_id):
		return voice_cache[line_id]

	var file_path := VOICE_DIR + line_id + ".wav"
	if ResourceLoader.exists(file_path):
		var res := load(file_path) as AudioStream
		if res:
			voice_cache[line_id] = res
			return res

	if FileAccess.file_exists(file_path):
		var f := FileAccess.open(file_path, FileAccess.READ)
		if f:
			var bytes := f.get_buffer(f.get_length())
			f.close()
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.mix_rate = 22050
			wav.stereo = false
			if bytes.size() > 44:
				wav.data = bytes.slice(44)
				voice_cache[line_id] = wav
				return wav

	return null

func _show_subtitles(text: String, duration: float) -> void:
	if not subtitle_panel or not subtitle_label or text.is_empty():
		return

	if current_tween:
		current_tween.kill()

	subtitle_label.text = "[center]%s[/center]" % text
	subtitle_panel.visible = true
	subtitle_panel.modulate.a = 0.0

	current_tween = create_tween()
	current_tween.tween_property(subtitle_panel, "modulate:a", 1.0, 0.15)
	current_tween.tween_interval(maxf(duration, 2.5))
	current_tween.tween_property(subtitle_panel, "modulate:a", 0.0, 0.4)
	current_tween.tween_callback(func() -> void: subtitle_panel.visible = false)

func _on_voice_finished() -> void:
	voice_finished.emit(last_played_line)

func speak_kolya(line_id: String, text: String, pitch: float = 0.92) -> void:
	play_voice(line_id, "[color=#ffcc00][b]КОЛЯ:[/b][/color] " + text, pitch, 2.0)

func speak_sasha(line_id: String, text: String, pitch: float = 1.08) -> void:
	play_voice(line_id, "[color=#33ddff][b]САША V (Радио):[/b][/color] " + text, pitch, 1.5)

func speak_guard(line_id: String, text: String, pitch: float = 0.82) -> void:
	play_voice(line_id, "[color=#ff4444][b]ОХРАНА MERIDIAN:[/b][/color] " + text, pitch, 1.0)
