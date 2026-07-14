# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/SettingsRepository.gd
# Description: Infrastructure Repository responsible for serialization and persistence
#              of user configuration settings (volumes, language, render distance).
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 10 lines.
#              Corrected: Purged all print logs for silent, high-performance saving.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SettingsRepository
extends RefCounted

const SETTINGS_PATH: String = "user://settings.json"


static func save_settings(
	music_vol: float, 
	sfx_vol: float, 
	render_dist: int, 
	locale: String, 
	window_mode: int, 
	window_size: Vector2i
) -> void:
	var data: Dictionary = _pack_settings_data(music_vol, sfx_vol, render_dist, locale, window_mode, window_size)
	_write_settings_to_file(data)


static func _pack_settings_data(
	music_vol: float, 
	sfx_vol: float, 
	render_dist: int, 
	locale: String, 
	window_mode: int, 
	window_size: Vector2i
) -> Dictionary:
	return {
		"music_volume": music_vol,
		"sfx_volume": sfx_vol,
		"render_distance": render_dist,
		"locale": locale,
		"window_mode": window_mode,
		"window_size_x": window_size.x,
		"window_size_y": window_size.y
	}


static func _write_settings_to_file(data: Dictionary) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line(JSON.stringify(data))
		file.close()


static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
		
	var json_string: String = _read_settings_file()
	if json_string.is_empty():
		return {}
		
	return _parse_settings_json(json_string)


static func _read_settings_file() -> String:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var content: String = file.get_as_text()
	file.close()
	return content


static func _parse_settings_json(json_string: String) -> Dictionary:
	var json := JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("[SettingsRepository ERROR] Failed to parse JSON. Error: " + json.get_error_message())
		return {}
		
	var data: Dictionary = json.data as Dictionary
	if not data.is_empty():
		return data
		
	return {}
