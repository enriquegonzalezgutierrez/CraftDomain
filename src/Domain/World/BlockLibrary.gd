# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Registries)
# Class: BlockLibrary
# Description: Pure Domain registry managing the definitions, physical traits, 
#              and visual attributes of all block types in the game world.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Responsible exclusively for scanning, 
#   instantiating, and caching BlockDefinition resources.
# - Open-Closed Principle (OCP): Completely closed to modifications. Monolithic 
#   initializers and hardcoded register arrays have been purged. Voxel blocks are 
#   now loaded dynamically from their own independent files on startup.
# - Liskov Substitution Principle (LSP): Dynamically falls back to a safe Air block
#   to prevent engine crashes if an unregistered or corrupt ID is queried.
# - Dependency Inversion Principle (DIP): Relies on polymorphic BlockDefinition 
#   contracts, isolating domain storage from direct hardware or rendering knowledge.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name BlockLibrary
extends RefCounted

## Dynamic OCP Directory containing independent block scripts
const BLOCKS_DIR := "res://src/Domain/World/Blocks/"

## Static database mapping unique block IDs (ints) to their custom BlockDefinition instances
static var _definitions: Dictionary = {}


## Static Constructor: Executed automatically by Godot on engine boot
static func _static_init() -> void:
	_definitions.clear()
	_scan_and_compile_blocks_directory()


## Scans the directory, sanitizes production file paths, and instantiates each block subclass
static func _scan_and_compile_blocks_directory() -> void:
	if not DirAccess.dir_exists_absolute(BLOCKS_DIR):
		DirAccess.make_dir_recursive_absolute(BLOCKS_DIR)
		print("[BlockLibrary] Created missing blocks directory: ", BLOCKS_DIR)
		_register_air_fallback()
		return
		
	var dir := DirAccess.open(BLOCKS_DIR)
	if dir == null:
		push_error("[BlockLibrary ERROR] Could not open blocks directory: " + BLOCKS_DIR)
		_register_air_fallback()
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_blocks := 0
	
	while file_name != "":
		if not dir.current_is_dir():
			# ==================================================================
			# GODOT 4 EXPORT-SAFE FILENAME SANITIZATION
			# In exported production builds, Godot encrypts and compiles scripts,
			# renaming them to .gdc or creating .gd.remap redirects. We strip 
			# these suffixes to guarantee smooth runtime loading across all platforms.
			# ==================================================================
			var sanitized_name := file_name.replace(".remap", "").replace(".gdc", ".gd")
			
			if sanitized_name.ends_with(".gd"):
				var full_path := BLOCKS_DIR + sanitized_name
				if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
					var script_res := load(full_path) as GDScript
					if script_res != null:
						var block_instance: BlockDefinition = script_res.new() as BlockDefinition
						if block_instance != null:
							register_definition(block_instance)
							loaded_blocks += 1
							
		file_name = dir.get_next()
		
	dir.list_dir_end()
	print("[BlockLibrary] Dynamic boot finished. Successfully loaded and registered: ", loaded_blocks, " blocks.")
	
	# Guarantee AIR block is always loaded as the baseline fallback
	if not _definitions.has(0):
		_register_air_fallback()


## Public OCP Expansion API: Registers a custom block definition dynamically at runtime (Mods/Plugin safe)
static func register_definition(definition: BlockDefinition) -> void:
	if definition != null:
		_definitions[definition.type] = definition


## Public Reader API: Queries and retrieves a registered block definition.
## Falls back to AIR (0) if the requested ID is not registered, preventing voxel crashes.
static func get_definition(type: int) -> BlockDefinition:
	if _definitions.has(type):
		return _definitions[type] as BlockDefinition
		
	# Bulletproof baseline fallback
	if _definitions.has(0):
		return _definitions[0] as BlockDefinition
		
	return null


## Baseline Fallback Setup: Forces a safe default Air block in case of directory failure
static func _register_air_fallback() -> void:
	var air := BlockDefinition.new()
	air.type = 0 # BlockType.Type.AIR
	air.translation_key = "BLOCK_AIR"
	air.is_solid = false
	air.is_transparent = true
	air.color_top = Color(0, 0, 0, 0)
	air.color_side = Color(0, 0, 0, 0)
	air.color_bottom = Color(0, 0, 0, 0)
	register_definition(air)
