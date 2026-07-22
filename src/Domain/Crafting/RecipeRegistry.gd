# ==============================================================================
# Pathfile: res://src/Domain/Crafting/RecipeRegistry.gd
# Description: Pure Domain Registry responsible for parsing and storing crafting
#              recipes dynamically from external JSON configuration files.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RecipeRegistry
extends RefCounted

const RECIPE_DIR := "res://assets/recipes/"

static var _recipes: Dictionary = {}


## Scans the directory and loads all present JSON recipe files on boot.
static func initialize_recipes() -> void:
	_recipes.clear()
	_ensure_directory_exists()
	_scan_and_load_all_recipe_files()


static func _ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(RECIPE_DIR):
		DirAccess.make_dir_recursive_absolute(RECIPE_DIR)


static func _scan_and_load_all_recipe_files() -> void:
	var dir := DirAccess.open(RECIPE_DIR)
	if dir == null:
		push_error("[RecipeRegistry] Error: Could not access recipes directory: " + RECIPE_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_recipes_from_file(RECIPE_DIR + file_name)
		file_name = dir.get_next()
		
	dir.list_dir_end()


static func _load_recipes_from_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[RecipeRegistry] Error: Could not read recipe file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) == OK and json.data is Array:
		for r_any: Variant in (json.data as Array):
			if r_any is Dictionary:
				_parse_and_register_recipe(r_any as Dictionary)


static func _parse_and_register_recipe(r_data: Dictionary) -> void:
	var r := Recipe.new()
	r.recipe_id = r_data.get("recipe_id", "") as String
	r.recipe_name = r_data.get("recipe_name", "") as String
	r.inputs = _parse_recipe_inputs(r_data.get("inputs", {}) as Dictionary)
	r.output_item_index = r_data.get("output_item_index", -1) as int
	r.output_quantity = r_data.get("output_quantity", 1) as int
	
	_recipes[r.recipe_id] = r


static func _parse_recipe_inputs(inputs_dict: Dictionary) -> Dictionary:
	var typed_inputs: Dictionary = {}
	for slot_key: String in inputs_dict.keys():
		var slot_index := slot_key.to_int()
		typed_inputs[slot_index] = inputs_dict[slot_key] as int
	return typed_inputs


## Returns a registered recipe by its unique ID.
static func get_recipe(recipe_id: String) -> Recipe:
	if _recipes.has(recipe_id):
		return _recipes[recipe_id] as Recipe
	return null


## Returns all loaded recipes for UI catalog population.
static func get_all_recipes() -> Array[Recipe]:
	var list: Array[Recipe] = []
	for key: String in _recipes.keys():
		list.append(_recipes[key] as Recipe)
	return list