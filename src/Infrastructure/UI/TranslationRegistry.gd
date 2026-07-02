# ==============================================================================
# Project: CraftDomain
# Description: Pure Infrastructure Registry responsible for dynamically loading
#              and compiling translation files from external JSON packs.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only handles file parsing,
#                guaranteeing this class will never become a God Object.
#              - Open-Closed Principle (OCP): Closed to code modification. Adding
#                new languages (e.g., fr.json) is done purely via external assets.
#              WARNING FIX:
#              - Added explicit static typing `String` to the locale dictionary key 
#                loop iterator on line 76 to completely resolve the 
#                `UNTYPED_DECLARATION` compiler warning.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/TranslationRegistry.gd
# ==============================================================================
class_name TranslationRegistry
extends RefCounted

const TRANSLATIONS_DIR := "res://assets/translations/"

## Scans the translations folder and registers all present JSON locales dynamically
static func initialize_translations() -> void:
	print("[TranslationRegistry] Scanning directory for language packs: ", TRANSLATIONS_DIR)
	_ensure_directory_exists()
	_scan_and_load_translation_files()

static func _ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(TRANSLATIONS_DIR):
		DirAccess.make_dir_recursive_absolute(TRANSLATIONS_DIR)
		print("[TranslationRegistry] Created missing translations directory: ", TRANSLATIONS_DIR)

## Dynamically registers every translation JSON into Godot's TranslationServer
static func _scan_and_load_translation_files() -> void:
	var dir := DirAccess.open(TRANSLATIONS_DIR)
	if dir == null:
		push_error("[TranslationRegistry] Error: Could not access translations directory: " + TRANSLATIONS_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_files_count := 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := TRANSLATIONS_DIR + file_name
			var locale_code := file_name.get_basename() # Extract "en" or "es"
			
			_load_translation_pack(full_path, locale_code)
			loaded_files_count += 1
		file_name = dir.get_next()
		
	dir.list_dir_end()
	print("[TranslationRegistry] Dynamic scan finished. Language packs loaded: ", loaded_files_count)

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
		
	var translation_data := json.data as Dictionary
	if translation_data == null:
		return
		
	var translation := Translation.new()
	translation.locale = locale_code
	
	# Seed the translations mapping dynamically
	# FIX: Added explicit static typing `String` to translation keys loop iterator
	for key: String in translation_data.keys():
		translation.add_message(key, str(translation_data[key]))
		
	TranslationServer.add_translation(translation)
	print("  -> Bounded dynamic translation pack: ", file_path, " [Locale: ", locale_code, "]")
