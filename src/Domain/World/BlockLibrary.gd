# ==============================================================================
# Pathfile: res://src/Domain/World/BlockLibrary.gd
# Description: Pure Domain registry managing the definitions, physical traits, 
#              and visual attributes of all block types in the game world.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 20 lines.
#              Corrected: Purged all print logs for silent and fast initialization.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BlockLibrary
extends RefCounted

const BLOCKS_DIR := "res://src/Domain/World/Blocks/"

static var _definitions: Dictionary = {}


static func _static_init() -> void:
	_definitions.clear()
	_scan_and_compile_blocks_directory()


static func _scan_and_compile_blocks_directory() -> void:
	if not DirAccess.dir_exists_absolute(BLOCKS_DIR):
		DirAccess.make_dir_recursive_absolute(BLOCKS_DIR)
		_register_air_fallback()
		return
		
	var dir := DirAccess.open(BLOCKS_DIR)
	if dir == null:
		_register_air_fallback()
		return
		
	dir.list_dir_begin()
	_compile_blocks_in_dir(dir)
	dir.list_dir_end()
	
	if not _definitions.has(0):
		_register_air_fallback()


static func _compile_blocks_in_dir(dir: DirAccess) -> void:
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var sanitized_name := file_name.replace(".remap", "").replace(".gdc", ".gd")
			if sanitized_name.ends_with(".gd"):
				var full_path := BLOCKS_DIR + sanitized_name
				_load_and_register_block(full_path)
		file_name = dir.get_next()


static func _load_and_register_block(full_path: String) -> void:
	if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
		var script_res := load(full_path) as GDScript
		if script_res != null:
			var block_instance := script_res.new() as BlockDefinition
			if block_instance != null:
				register_definition(block_instance)


static func register_definition(definition: BlockDefinition) -> void:
	if definition != null:
		_definitions[definition.type] = definition


static func get_definition(type: int) -> BlockDefinition:
	if _definitions.has(type):
		return _definitions[type] as BlockDefinition
		
	if _definitions.has(0):
		return _definitions[0] as BlockDefinition
		
	return null


static func _register_air_fallback() -> void:
	var air := BlockDefinition.new()
	air.type = 0 
	air.translation_key = "BLOCK_AIR"
	air.is_solid = false
	air.is_transparent = true
	air.color_top = Color(0, 0, 0, 0)
	air.color_side = Color(0, 0, 0, 0)
	air.color_bottom = Color(0, 0, 0, 0)
	register_definition(air)
