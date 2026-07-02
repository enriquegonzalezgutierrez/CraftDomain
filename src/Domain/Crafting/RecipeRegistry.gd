# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Registry responsible for parsing and storing crafting
#              recipes from external JSON files.
#              SOLID COMPLIANCE: Adheres to the Open-Closed Principle (OCP) by
#              dynamically loading data without modifying GDScript source code.
#              STRICT MODE: Utilizes safe type casting to prevent Variant warnings.
#              WARNING FIX:
#              - Added explicit static typing to all loop iterators (`item`, 
#                `slot_key`, and `key`) to completely resolve `UNTYPED_DECLARATION` 
#                compiler warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Crafting/RecipeRegistry.gd
# ==============================================================================
class_name RecipeRegistry
extends RefCounted

const RECIPE_DIR := "res://assets/recipes/"

## In-memory database mapping recipe_id (String) to Recipe instances
static var _recipes: Dictionary = {}

## Scans the directory and loads all present JSON recipe files (OCP compliant)
static func initialize_recipes() -> void:
	print("[RecipeRegistry] Initializing crafting database...")
	_recipes.clear()
	_ensure_directory_exists()
	_scan_and_load_all_recipe_files()

static func _ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(RECIPE_DIR):
		DirAccess.make_dir_recursive_absolute(RECIPE_DIR)
		print("[RecipeRegistry] Created missing recipes directory: ", RECIPE_DIR)

## Scans the recipe directory and parses every .json file present
static func _scan_and_load_all_recipe_files() -> void:
	var dir := DirAccess.open(RECIPE_DIR)
	if dir == null:
		push_error("[RecipeRegistry] Error: Could not access recipes directory: " + RECIPE_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_files_count := 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := RECIPE_DIR + file_name
			_load_recipes_from_file(full_path)
			loaded_files_count += 1
		file_name = dir.get_next()
		
	dir.list_dir_end()
	print("[RecipeRegistry] Dynamic scan finished. Total recipe files loaded: ", loaded_files_count, " | Total recipes: ", _recipes.size())

## Parses a specific JSON file and registers its instantiated Recipes
static func _load_recipes_from_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[RecipeRegistry] Error: Could not read recipe file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[RecipeRegistry] Error parsing JSON " + file_path + ". Line: " + str(json.get_error_line()) + " | Error: " + json.get_error_message())
		return
		
	# STRICT MODE: Safely cast the root Variant to an Array
	var recipe_array := json.data as Array
	if recipe_array == null:
		return
		
	# FIX: Added explicit static typing `Dictionary` to the JSON recipe objects loop iterator
	for r_data: Dictionary in recipe_array:
		var r := Recipe.new()
		
		r.recipe_id = r_data["recipe_id"] as String
		r.recipe_name = r_data["recipe_name"] as String
		
		# Parse inputs (JSON keys are always strings, we must convert them to integer slots)
		var inputs_dict := r_data["inputs"] as Dictionary
		var typed_inputs: Dictionary = {}
		
		# FIX: Added explicit static typing `String` to the JSON inputs loop iterator
		for slot_key: String in inputs_dict.keys():
			var slot_index := slot_key.to_int()
			var required_qty := inputs_dict[slot_key] as int
			typed_inputs[slot_index] = required_qty
			
		r.inputs = typed_inputs
		
		r.output_item_index = r_data["output_item_index"] as int
		r.output_quantity = r_data["output_quantity"] as int
		
		_recipes[r.recipe_id] = r

## Returns a registered recipe by its ID
static func get_recipe(recipe_id: String) -> Recipe:
	if _recipes.has(recipe_id):
		return _recipes[recipe_id] as Recipe
	return null

## Returns all loaded recipes (useful for populating the UI crafting menu)
static func get_all_recipes() -> Array[Recipe]:
	var list: Array[Recipe] = []
	# FIX: Added explicit static typing `String` to key loop iterator
	for key: String in _recipes.keys():
		list.append(_recipes[key] as Recipe)
	return list
