# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Repository responsible for serialization and persistence
#              of user configuration settings (volumes, language, render distance).
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively saving 
#                and loading the settings configuration file.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Persistence/SettingsRepository.gd
# ==============================================================================
class_name SettingsRepository
extends RefCounted

const SETTINGS_PATH := "user://settings.json"

## Saves global user preferences to disk.
static func save_settings(
	music_vol: float, 
	sfx_vol: float, 
	render_dist: int, 
	locale: String, 
	window_mode: int, 
	window_size: Vector2i
) -> void:
	var data := {
		"music_volume": music_vol,
		"sfx_volume": sfx_vol,
		"render_distance": render_dist,
		"locale": locale,
		"window_mode": window_mode,
		"window_size_x": window_size.x,
		"window_size_y": window_size.y
	}
	
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		var json_string := JSON.stringify(data)
		file.store_line(json_string)
		file.close()
		print("[SettingsRepository] Settings saved to disk successfully.")


## Loads user preferences from disk. Returns a dictionary of loaded settings or empty if none.
static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
		
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[SettingsRepository] Error parsing settings JSON. Line: " + str(json.get_error_line()) + " | Error: " + json.get_error_message())
		return {}
		
	var data := json.data as Dictionary
	if data != null:
		print("[SettingsRepository] Settings loaded from disk successfully.")
		return data
		
	return {}
