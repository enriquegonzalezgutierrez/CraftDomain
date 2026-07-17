# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Rendering / Asset Registry)
# Class: TextureRegistry
# Description: Pure Infrastructure static registry managing the preloading, 
#              caching, and querying of 2D block textures from disk.
# SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively disk-bound 
#                texture lookups and RAM caching.
#              - Bootstrap Sync Fix: Forces BlockLibrary lazy initialization 
#                before compiling the texture cache, preventing empty-cache errors.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name TextureRegistry
extends RefCounted

const TEXTURE_DIR := "res://assets/textures/"

## Static in-memory database caching preloaded block textures: int (block_id) -> Texture2D
static var _textures_cache: Dictionary = {}

## Prevents duplicate initialization sequences
static var _initialized: bool = false


## Public Initializer API: Scans the registered BlockLibrary, loads their declared 
## textures from disk, and caches them in RAM.
## Called safely by the Bootstrap composition root during game startup.
static func initialize_textures() -> void:
	if _initialized:
		return
	_initialized = true
	
	# Symmetrical Bootstrap Fix: Force BlockLibrary to scan and load all block
	# scripts into RAM first, ensuring the definitions dictionary is populated.
	var _air_fallback := BlockLibrary.get_definition(0) as BlockDefinition
	
	# Iterate dynamically through all registered block definitions (OCP compliant)
	for b_id: int in BlockLibrary._definitions.keys():
		var def := BlockLibrary.get_definition(b_id) as BlockDefinition
		if def == null or def.texture_file_name == "":
			continue
			
		var path := TEXTURE_DIR + def.texture_file_name
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_textures_cache[b_id] = tex


## Public Reader API: Queries and returns the cached 2D texture for any given Block ID.
## Returns null if the block is unregistered or does not declare a valid texture file.
static func get_block_texture(block_id: int) -> Texture2D:
	if _textures_cache.has(block_id):
		return _textures_cache[block_id] as Texture2D
	return null


## Public OCP Extension API: Registers a custom texture dynamically at runtime.
## Enables custom blocks, mods, or DLC loaders to inject textures directly into cache.
static func register_custom_texture(block_id: int, texture: Texture2D) -> void:
	if texture != null:
		_textures_cache[block_id] = texture
