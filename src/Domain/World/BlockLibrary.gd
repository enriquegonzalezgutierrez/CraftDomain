# ==============================================================================
# Pathfile: res://src/Domain/World/BlockLibrary.gd
# Description: Pure Domain registry managing the definitions, physical traits, 
#              and spawning behaviors of all block types in the game world.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages block definitions.
# - SOLID OCP: Declares the fallback Air definition as is_air = true at domain level.
# - Explicit Scope Bindings: Prefixes all static calls with the class name 
#   to prevent Godot 4.7+ parser scope resolution bugs.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BlockLibrary
extends RefCounted

const BLOCKS_DIR := "res://src/Domain/World/Blocks/"

static var _definitions: Dictionary = {}


## Public Reader API: Retrieves the block definition strategy for a given ID.
static func get_definition(type: int) -> BlockDefinition:
	BlockLibrary._ensure_initialized()
	if BlockLibrary._definitions.has(type):
		return BlockLibrary._definitions[type] as BlockDefinition
		
	if BlockLibrary._definitions.has(0):
		return BlockLibrary._definitions[0] as BlockDefinition
		
	return null


## Public Writer API: Registers a custom block definition dynamically.
static func register_definition(definition: BlockDefinition) -> void:
	if definition != null:
		BlockLibrary._definitions[definition.type] = definition


static func _ensure_initialized() -> void:
	if BlockLibrary._definitions.is_empty():
		BlockLibrary._scan_and_compile_blocks_directory()


static func _scan_and_compile_blocks_directory() -> void:
	if not DirAccess.dir_exists_absolute(BLOCKS_DIR):
		DirAccess.make_dir_recursive_absolute(BLOCKS_DIR)
		BlockLibrary._register_air_fallback()
		return
		
	var dir := DirAccess.open(BLOCKS_DIR)
	if dir == null:
		BlockLibrary._register_air_fallback()
		return
		
	dir.list_dir_begin()
	BlockLibrary._compile_blocks_in_dir(dir)
	dir.list_dir_end()
	
	if not BlockLibrary._definitions.has(0):
		BlockLibrary._register_air_fallback()


static func _compile_blocks_in_dir(dir: DirAccess) -> void:
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var sanitized_name: String = file_name.replace(".remap", "").replace(".gdc", ".gd")
			if sanitized_name.ends_with(".gd"):
				var full_path: String = BLOCKS_DIR + sanitized_name
				BlockLibrary._load_and_register_block(full_path)
		file_name = dir.get_next()


static func _load_and_register_block(full_path: String) -> void:
	if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
		var script_res := load(full_path) as GDScript
		if script_res != null:
			var block_instance := script_res.new() as BlockDefinition
			if block_instance != null:
				BlockLibrary.register_definition(block_instance)


static func _register_air_fallback() -> void:
	var air := BlockDefinition.new()
	air.type = 0 
	air.translation_key = "BLOCK_AIR"
	air.is_solid = false
	air.is_transparent = true
	air.is_air = true # SOLID OOP definition
	
	# SOLID OCP Spawning properties configuration
	air.is_spawn_surface = false
	air.is_spawn_penetrable = true 
	
	air.color_top = Color(0, 0, 0, 0)
	air.color_side = Color(0, 0, 0, 0)
	air.color_bottom = Color(0, 0, 0, 0)
	
	BlockLibrary._definitions[0] = air
