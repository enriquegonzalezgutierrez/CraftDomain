# ==============================================================================
# Project: CraftDomain
# Description: Domain registry holding immutable definitions of all block types 
#              present in the game.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockLibrary.gd
# ==============================================================================
class_name BlockLibrary
extends RefCounted

## Stores the dictionary of registered block definitions.
static var _definitions: Dictionary = {}

## Static constructor. Runs automatically when the class is first loaded.
static func _static_init() -> void:
	# Air
	_register(BlockType.Type.AIR, "Air", Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	
	# Stone (Shades of grey)
	_register(BlockType.Type.STONE, "Stone", Color(0.5, 0.5, 0.5), Color(0.45, 0.45, 0.45), Color(0.4, 0.4, 0.4))
	
	# Dirt (Shades of brown)
	_register(BlockType.Type.DIRT, "Dirt", Color(0.5, 0.35, 0.25), Color(0.45, 0.3, 0.2), Color(0.4, 0.25, 0.15))
	
	# Grass (Green top, dirt sides, dirt bottom)
	_register(BlockType.Type.GRASS, "Grass", Color(0.35, 0.65, 0.25), Color(0.45, 0.3, 0.2), Color(0.4, 0.25, 0.15))
	
	# Wood trunk (Warm brown, circular pattern logic represented by lighter top/bottom)
	_register(BlockType.Type.WOOD, "Wood", Color(0.65, 0.5, 0.35), Color(0.4, 0.25, 0.15), Color(0.65, 0.5, 0.35))
	
	# Leaves (Vibrant green shades)
	_register(BlockType.Type.LEAVES, "Leaves", Color(0.2, 0.55, 0.2), Color(0.15, 0.45, 0.15), Color(0.12, 0.4, 0.12))

static func _register(type: BlockType.Type, block_name: String, top: Color, side: Color, bottom: Color) -> void:
	_definitions[type] = BlockDefinition.new(type, block_name, top, side, bottom)

## Returns the definition corresponding to a specific BlockType.
static func get_definition(type: BlockType.Type) -> BlockDefinition:
	if _definitions.has(type):
		return _definitions[type]
	return _definitions[BlockType.Type.AIR]
