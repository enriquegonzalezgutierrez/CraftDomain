# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (UI / Localization)
# Class: TranslationRegistry
# Description: Pure Infrastructure Registry responsible for dynamically loading
#              and compiling translation files from external JSON packs.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Only handles file parsing,
#   guaranteeing this class will never become a God Object.
# - Open-Closed Principle (OCP): Closed to code modification. Adding
#   new languages (e.g., fr.json) is done purely via external assets.
# - Safe Type Validation: Uses explicit type checks before casting to prevent
#   GDScript engine invalid cast crashes on unaligned files.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name TranslationRegistry
extends RefCounted

const TRANSLATIONS_DIR := "res://assets/translations/"

## Scans the translations folder and registers all present JSON locales dynamically
static func initialize_translations() -> void:
	_ensure_directory_exists()
	_scan_and_load_translation_files()


static func _ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(TRANSLATIONS_DIR):
		DirAccess.make_dir_recursive_absolute(TRANSLATIONS_DIR)


## Dynamically registers every translation JSON into Godot's TranslationServer
static func _scan_and_load_translation_files() -> void:
	var dir := DirAccess.open(TRANSLATIONS_DIR)
	if dir == null:
		push_error("[TranslationRegistry] Error: Could not access translations directory: " + TRANSLATIONS_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := TRANSLATIONS_DIR + file_name
			var locale_code := file_name.get_basename() # Extract "en" or "es"
			
			_load_translation_pack(full_path, locale_code)
		file_name = dir.get_next()
		
	dir.list_dir_end()


## Parses a specific JSON file and binds it to the engine translation service
static func _load_translation_pack(file_path: String, locale_code: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[TranslationRegistry] Error: Could not read translation file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[TranslationRegistry] Error parsing JSON " + file_path + ". Line: " + str(json.get_error_line()) + " | Error: " + json.get_error_message())
		return
		
	var raw_data: Variant = json.data
	if not (raw_data is Dictionary):
		push_warning("[TranslationRegistry] Skipping non-dictionary translation file: " + file_path)
		return
		
	var translation_data := raw_data as Dictionary
	var translation := Translation.new()
	translation.locale = locale_code
	
	# Seed the translations mapping dynamically
	for key: String in translation_data.keys():
		translation.add_message(key, str(translation_data[key]))
		
	TranslationServer.add_translation(translation)
