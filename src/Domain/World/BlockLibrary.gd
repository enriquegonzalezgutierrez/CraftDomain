# ==============================================================================
# Project: CraftDomain
# Description: Domain registry holding immutable definitions, colors, and 
#              shading parameters of all block types present in the game.
#              UPDATED: Registered the glowing, high-contrast LAVA block colors.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockLibrary.gd
# ==============================================================================
class_name BlockLibrary
extends RefCounted

## Stores the dictionary of registered block definitions.
static var _definitions: Dictionary = {}

## Static constructor. Runs automatically when the class is first loaded.
static func _static_init() -> void:
	# 1. Air (Transparent empty space)
	_register(BlockType.Type.AIR, "Air", Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	
	# 2. Stone (Classic dark shades of grey for caves)
	_register(BlockType.Type.STONE, "Stone", Color(0.48, 0.48, 0.48), Color(0.42, 0.42, 0.42), Color(0.38, 0.38, 0.38))
	
	# 3. Dirt (Warm brown for subterranean soils)
	_register(BlockType.Type.DIRT, "Dirt", Color(0.45, 0.32, 0.22), Color(0.4, 0.28, 0.18), Color(0.35, 0.25, 0.15))
	
	# 4. Grass (Standard meadow green top with dirt sides)
	_register(BlockType.Type.GRASS, "Grass", Color(0.38, 0.68, 0.28), Color(0.4, 0.28, 0.18), Color(0.35, 0.25, 0.15))
	
	# 5. Wood (Warm oak pattern logic for tree trunks and piers)
	_register(BlockType.Type.WOOD, "Wood", Color(0.62, 0.45, 0.32), Color(0.48, 0.35, 0.22), Color(0.62, 0.45, 0.32))
	
	# 6. Leaves (Standard soft green shades for foliage)
	_register(BlockType.Type.LEAVES, "Leaves", Color(0.18, 0.52, 0.18), Color(0.15, 0.45, 0.15), Color(0.12, 0.4, 0.12))
	
	# 7. Water (Deep, vibrant tropical blue)
	_register(BlockType.Type.WATER, "Water", Color(0.12, 0.55, 0.82, 0.8), Color(0.1, 0.48, 0.75, 0.8), Color(0.08, 0.42, 0.68, 0.8))
	
	# 8. Sand (Warm light cream beach sands)
	_register(BlockType.Type.SAND, "Sand", Color(0.92, 0.85, 0.65), Color(0.88, 0.8, 0.6), Color(0.82, 0.75, 0.55))
	
	# 9. Red Sand (Intense red/orange terracotta for badlands)
	_register(BlockType.Type.RED_SAND, "Red Sand", Color(0.85, 0.38, 0.22), Color(0.78, 0.32, 0.18), Color(0.7, 0.28, 0.15))
	
	# 10. Snow (Pristine, high-contrast white)
	_register(BlockType.Type.SNOW, "Snow", Color(0.98, 0.98, 0.98), Color(0.92, 0.94, 0.96), Color(0.88, 0.9, 0.92))
	
	# 11. Ice (Translucent, frozen neon blue)
	_register(BlockType.Type.ICE, "Ice", Color(0.62, 0.88, 0.95, 0.75), Color(0.55, 0.82, 0.9, 0.75), Color(0.48, 0.75, 0.85, 0.75))
	
	# 12. Mud (Dark swampy brown)
	_register(BlockType.Type.MUD, "Mud", Color(0.28, 0.22, 0.15), Color(0.22, 0.18, 0.12), Color(0.18, 0.15, 0.1))
	
	# 13. Neon Cyan (Glowing cybernetic highlights)
	_register(BlockType.Type.NEON_CYAN, "Neon Cyan", Color(0.0, 0.95, 0.95), Color(0.0, 0.8, 0.8), Color(0.0, 0.6, 0.6))
	
	# 14. Neon Magenta (Vibrant pink techno-glowing highlights)
	_register(BlockType.Type.NEON_MAGENTA, "Neon Magenta", Color(0.95, 0.0, 0.95), Color(0.8, 0.0, 0.8), Color(0.6, 0.0, 0.6))
	
	# 15. Cloud (Fluffy, semi-transparent pure white)
	_register(BlockType.Type.CLOUD, "Cloud", Color(1.0, 1.0, 1.0, 0.65), Color(0.95, 0.95, 0.95, 0.65), Color(0.9, 0.9, 0.9, 0.65))

	# 16. Lava (Vibrant, high-contrast flowing orange-red liquid)
	_register(BlockType.Type.LAVA, "Lava", Color(1.0, 0.35, 0.0), Color(0.9, 0.25, 0.0), Color(0.8, 0.2, 0.0))

static func _register(type: BlockType.Type, block_name: String, top: Color, side: Color, bottom: Color) -> void:
	_definitions[type] = BlockDefinition.new(type, block_name, top, side, bottom)

## Returns the definition corresponding to a specific BlockType.
static func get_definition(type: BlockType.Type) -> BlockDefinition:
	if _definitions.has(type):
		return _definitions[type]
	return _definitions[BlockType.Type.AIR]
