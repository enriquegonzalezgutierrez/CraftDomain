# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/ModLoaderService.gd
# Description: Infrastructure service responsible for scanning user://mods/,
#              parsing external mod manifests, and dynamically injecting recipes
#              and localization packs into core registries (OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ModLoaderService
extends RefCounted

# Persistent OS directory configuration
const MODS_BASE_DIR: String = "user://mods/"
const MANIFEST_FILE_NAME: String = "mod.json"


## Scans the user's local mods directory and compiles all valid mod structures.
## Called by the Bootstrap composition root during startup initialization.
static func scan_and_load_mods() -> void:
	print("[ModLoader] Initiating external mod scan at: ", MODS_BASE_DIR)
	_ensure_mods_directory_exists()
	_scan_mods_directory()


static func _ensure_mods_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(MODS_BASE_DIR):
		DirAccess.make_dir_recursive_absolute(MODS_BASE_DIR)
		print("[ModLoader] Created missing mods directory: ", MODS_BASE_DIR)


## Iterates through folders inside user://mods/ seeking valid mod manifests
static func _scan_mods_directory() -> void:
	var dir := DirAccess.open(MODS_BASE_DIR)
	if dir == null:
		push_error("[ModLoader ERROR] Failed to access mods directory.")
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_mods_count := 0
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			var mod_path := MODS_BASE_DIR + file_name + "/"
			var manifest_path := mod_path + MANIFEST_FILE_NAME
			
			if FileAccess.file_exists(manifest_path):
				_load_mod_manifest(manifest_path, mod_path)
				# Dynamically compile and register custom block plugins inside this mod (OCP)
				ModPluginLoader.load_block_plugins(mod_path)
				loaded_mods_count += 1
				
		file_name = dir.get_next()
		
	dir.list_dir_end()
	print("[ModLoader] Mod scan finished. Total external mods loaded: ", loaded_mods_count)


## Parses an individual mod.json manifest and registers its recipes and locales.
static func _load_mod_manifest(manifest_path: String, mod_dir_path: String) -> void:
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[ModLoader ERROR] Failed to parse JSON at %s. Error: %s" % [manifest_path, json.get_error_message()])
		return
		
	var manifest := json.data as Dictionary
	if manifest == null:
		return
		
	var mod_name := str(manifest.get("name", "Unnamed Mod"))
	var mod_version := str(manifest.get("version", "1.0.0"))
	print("[ModLoader] Loading Mod: '%s' [v%s]" % [mod_name, mod_version])
	
	# Parse and inject data categories
	_parse_mod_translations(manifest, mod_dir_path)
	_parse_mod_recipes(manifest)


## Parses translation blocks and binds them directly to the engine Server (Section 3.2).
static func _parse_mod_translations(manifest: Dictionary, mod_dir_path: String) -> void:
	if not manifest.has("translations") or not (manifest["translations"] is Dictionary):
		return
		
	var trans_dict := manifest["translations"] as Dictionary
	for locale_code: String in trans_dict.keys():
		var relative_file_path: String = trans_dict[locale_code] as String
		var absolute_path := mod_dir_path + relative_file_path
		
		if FileAccess.file_exists(absolute_path):
			TranslationRegistry._load_translation_pack(absolute_path, locale_code)


## Parses external custom recipes and registers them in the Domain in-memory DB.
static func _parse_mod_recipes(manifest: Dictionary) -> void:
	if not manifest.has("recipes") or not (manifest["recipes"] is Array):
		return
		
	var recipes_array := manifest["recipes"] as Array
	for recipe_any: Variant in recipes_array:
		if not (recipe_any is Dictionary):
			continue
			
		var r_data := recipe_any as Dictionary
		var r := Recipe.new()
		
		r.recipe_id = r_data.get("recipe_id", "") as String
		r.recipe_name = r_data.get("recipe_name", "") as String
		r.output_item_index = r_data.get("output_item_index", -1) as int
		r.output_quantity = r_data.get("output_quantity", 1) as int
		
		var inputs_dict := r_data.get("inputs", {}) as Dictionary
		var typed_inputs: Dictionary = {}
		for slot_key: String in inputs_dict.keys():
			typed_inputs[slot_key.to_int()] = inputs_dict[slot_key] as int
			
		r.inputs = typed_inputs
		
		# Symmetrical trigger to register the parsed recipe safely in RAM (OCP)
		register_mod_recipe_proxy(r)


# ==============================================================================
# PROXIES DE REGISTROS DE DOMINIO (Para enlazar datos inyectados)
# ==============================================================================

## Symmetrical Extension: Enlaces external custom recipes to the Domain Registry.
static func register_mod_recipe_proxy(recipe: Recipe) -> void:
	if is_instance_valid(recipe) and recipe.recipe_id != "":
		RecipeRegistry._recipes[recipe.recipe_id] = recipe
