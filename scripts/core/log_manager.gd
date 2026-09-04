extends Node

# LogManager — Структурированное логирование для «Кока-Коля»
# Поддерживает уровни логов, вывод в консоль и запись в файл user://game.log

enum LogLevel { DEBUG, INFO, WARN, ERROR }

var current_level: LogLevel = LogLevel.DEBUG
var log_file_path: String = "user://game.log"
var _file: FileAccess = null

func _ready() -> void:
	_init_log_file()
	info("LogManager инициализирован. Уровень: %s" % LogLevel.keys()[current_level])

func _init_log_file() -> void:
	_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if _file:
		_file.store_line("=== «КОКА-КОЛЯ» СЕССИЯ ЛОГОВ: %s ===" % Time.get_datetime_string_from_system())
		_file.flush()

func _format_message(level: LogLevel, message: String, context: String = "") -> String:
	var time_str: String = Time.get_time_string_from_system()
	var level_str: String = LogLevel.keys()[level]
	if context.is_empty():
		return "[%s] [%s] %s" % [time_str, level_str, message]
	return "[%s] [%s] [%s] %s" % [time_str, level_str, context, message]

func debug(message: String, context: String = "") -> void:
	if current_level <= LogLevel.DEBUG:
		var formatted: String = _format_message(LogLevel.DEBUG, message, context)
		print(formatted)
		_write_to_file(formatted)

func info(message: String, context: String = "") -> void:
	if current_level <= LogLevel.INFO:
		var formatted: String = _format_message(LogLevel.INFO, message, context)
		print(formatted)
		_write_to_file(formatted)

func warn(message: String, context: String = "") -> void:
	if current_level <= LogLevel.WARN:
		var formatted: String = _format_message(LogLevel.WARN, message, context)
		print_rich("[color=yellow]%s[/color]" % formatted)
		_write_to_file(formatted)

func error(message: String, context: String = "") -> void:
	if current_level <= LogLevel.ERROR:
		var formatted: String = _format_message(LogLevel.ERROR, message, context)
		printerr(formatted)
		_write_to_file(formatted)

func _write_to_file(line: String) -> void:
	if _file:
		_file.store_line(line)
		_file.flush()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _file:
			_file.close()
