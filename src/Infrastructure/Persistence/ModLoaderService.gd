# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/ModLoaderService.gd
# Description: Infrastructure service responsible for scanning user://mods/,
#              parsing external mod manifests, and dynamically injecting recipes
#              and localization packs into core registries (OCP).
# SOLID COMPLIANCE: Class limits set < 150 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 12 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ModLoaderService
extends RefCounted

const MODS_BASE_DIR: String = "user://mods/"
const MANIFEST_FILE_NAME: String = "mod.json"


static func scan_and_load_mods() -> void:
	_ensure_mods_directory_exists()
	_scan_mods_directory()


static func _ensure_mods_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(MODS_BASE_DIR):
		DirAccess.make_dir_recursive_absolute(MODS_BASE_DIR)


static func _scan_mods_directory() -> void:
	var dir := DirAccess.open(MODS_BASE_DIR)
	if dir == null:
		push_error("[ModLoader ERROR] Failed to access mods directory.")
		return
		
	dir.list_dir_begin()
	_iterate_mods_directory(dir)
	dir.list_dir_end()


static func _iterate_mods_directory(dir: DirAccess) -> void:
	var file_name: String = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_process_mod_folder(file_name)
		file_name = dir.get_next()


static func _process_mod_folder(folder_name: String) -> void:
	var mod_path: String = MODS_BASE_DIR + folder_name + "/"
	var manifest_path: String = mod_path + MANIFEST_FILE_NAME
	
	if FileAccess.file_exists(manifest_path):
		_load_mod_manifest(manifest_path, mod_path)
		ModPluginLoader.load_block_plugins(mod_path)


static func _load_mod_manifest(manifest_path: String, mod_dir_path: String) -> void:
	var manifest := _parse_manifest_json(manifest_path)
	if manifest.is_empty(): return
		
	_parse_mod_translations(manifest, mod_dir_path)
	_parse_mod_recipes(manifest)


static func _parse_manifest_json(manifest_path: String) -> Dictionary:
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null: return {}
		
	var json_string: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("[ModLoader ERROR] Failed to parse JSON at %s. Error: %s" % [manifest_path, json.get_error_message()])
		return {}
		
	return json.data as Dictionary


static func _parse_mod_translations(manifest: Dictionary, mod_dir_path: String) -> void:
	if not manifest.has("translations") or not (manifest["translations"] is Dictionary):
		return
		
	var trans_dict: Dictionary = manifest["translations"] as Dictionary
	for locale_code: String in trans_dict.keys():
		var relative_file_path: String = trans_dict[locale_code] as String
		var absolute_path: String = mod_dir_path + relative_file_path
		
		if FileAccess.file_exists(absolute_path):
			TranslationRegistry._load_translation_pack(absolute_path, locale_code)


static func _parse_mod_recipes(manifest: Dictionary) -> void:
	if not manifest.has("recipes") or not (manifest["recipes"] is Array):
		return
		
	var recipes_array: Array = manifest["recipes"] as Array
	for recipe_any: Variant in recipes_array:
		if recipe_any is Dictionary:
			_register_recipe_from_data(recipe_any as Dictionary)


static func _register_recipe_from_data(r_data: Dictionary) -> void:
	var r := Recipe.new()
	r.recipe_id = r_data.get("recipe_id", "") as String
	r.recipe_name = r_data.get("recipe_name", "") as String
	r.output_item_index = r_data.get("output_item_index", -1) as int
	r.output_quantity = r_data.get("output_quantity", 1) as int
	r.inputs = _parse_recipe_inputs(r_data.get("inputs", {}) as Dictionary)
	
	register_mod_recipe_proxy(r)


static func _parse_recipe_inputs(inputs_dict: Dictionary) -> Dictionary:
	var typed_inputs: Dictionary = {}
	for slot_key: String in inputs_dict.keys():
		typed_inputs[slot_key.to_int()] = inputs_dict[slot_key] as int
	return typed_inputs


static func register_mod_recipe_proxy(recipe: Recipe) -> void:
	if is_instance_valid(recipe) and recipe.recipe_id != "":
		RecipeRegistry._recipes[recipe.recipe_id] = recipe
