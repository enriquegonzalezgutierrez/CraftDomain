# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Crafting System / Registries)
# Class: RecipeRegistry
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Pure Domain Registry responsible for parsing and storing crafting
#              recipes from external JSON files.
# SOLID COMPLIANCE: 
# - Open-Closed Principle (OCP): Adheres to OCP by dynamically loading data 
#   without modifying GDScript source code.
# - Strict Mode: Utilizes safe static typing and explicit type casting to prevent 
#   Variant compiler warnings.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# ==============================================================================
class_name RecipeRegistry
extends RefCounted

const RECIPE_DIR := "res://assets/recipes/"

## In-memory database mapping recipe_id (String) to Recipe instances
static var _recipes: Dictionary = {}


## Scans the directory and loads all present JSON recipe files (OCP compliant)
static func initialize_recipes() -> void:
	_recipes.clear()
	_ensure_directory_exists()
	_scan_and_load_all_recipe_files()


static func _ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(RECIPE_DIR):
		DirAccess.make_dir_recursive_absolute(RECIPE_DIR)


## Scans the recipe directory and parses every .json file present
static func _scan_and_load_all_recipe_files() -> void:
	var dir := DirAccess.open(RECIPE_DIR)
	if dir == null:
		push_error("[RecipeRegistry] Error: Could not access recipes directory: " + RECIPE_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := RECIPE_DIR + file_name
			_load_recipes_from_file(full_path)
		file_name = dir.get_next()
		
	dir.list_dir_end()


## Parses a specific JSON file and registers its instantiated Recipes
static func _load_recipes_from_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[RecipeRegistry] Error: Could not read recipe file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return
		
	var recipe_array := json.data as Array
	if recipe_array == null:
		return
		
	for r_any: Variant in recipe_array:
		if r_any is Dictionary:
			_parse_and_register_recipe(r_any as Dictionary)


static func _parse_and_register_recipe(r_data: Dictionary) -> void:
	var r := Recipe.new()
	r.recipe_id = r_data.get("recipe_id", "") as String
	r.recipe_name = r_data.get("recipe_name", "") as String
	
	var inputs_dict := r_data.get("inputs", {}) as Dictionary
	r.inputs = _parse_recipe_inputs(inputs_dict)
	
	r.output_item_index = r_data.get("output_item_index", -1) as int
	r.output_quantity = r_data.get("output_quantity", 1) as int
	
	_recipes[r.recipe_id] = r


static func _parse_recipe_inputs(inputs_dict: Dictionary) -> Dictionary:
	var typed_inputs: Dictionary = {}
	for slot_key: String in inputs_dict.keys():
		var slot_index := slot_key.to_int()
		var required_qty := inputs_dict[slot_key] as int
		typed_inputs[slot_index] = required_qty
	return typed_inputs


## Returns a registered recipe by its ID
static func get_recipe(recipe_id: String) -> Recipe:
	if _recipes.has(recipe_id):
		return _recipes[recipe_id] as Recipe
	return null


## Returns all loaded recipes (useful for populating the UI crafting menu)
static func get_all_recipes() -> Array[Recipe]:
	var list: Array[Recipe] = []
	for key: String in _recipes.keys():
		list.append(_recipes[key] as Recipe)
	return list
