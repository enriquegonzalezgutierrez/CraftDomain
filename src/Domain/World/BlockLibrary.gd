# ==============================================================================
# Project: CraftDomain
# Description: Domain registry holding immutable definitions, colors, and 
#              shading parameters of all block types present in the game.
#              UPDATED: Re-calibrated all RGB color values to be highly saturated, 
#              warm, and vibrant, matching the classic "Minecraft RTX" aesthetic.
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
	
	# 2. Stone (Cleaner, lighter grey for better SDFGI light bouncing)
	_register(BlockType.Type.STONE, "Stone", Color(0.55, 0.55, 0.55), Color(0.48, 0.48, 0.48), Color(0.42, 0.42, 0.42))
	
	# 3. Dirt (Rich, warm, chocolate brown soil)
	_register(BlockType.Type.DIRT, "Dirt", Color(0.55, 0.38, 0.25), Color(0.48, 0.32, 0.20), Color(0.42, 0.28, 0.18))
	
	# 4. Grass (Vibrant, highly saturated bright green top!)
	_register(BlockType.Type.GRASS, "Grass", Color(0.42, 0.78, 0.25), Color(0.48, 0.32, 0.20), Color(0.42, 0.28, 0.18))
	
	# 5. Wood (Warm, golden-oak trunk colors)
	_register(BlockType.Type.WOOD, "Wood", Color(0.72, 0.55, 0.35), Color(0.55, 0.42, 0.28), Color(0.72, 0.55, 0.35))
	
	# 6. Leaves (Rich, vibrant forest green for lush canopies)
	_register(BlockType.Type.LEAVES, "Leaves", Color(0.25, 0.65, 0.18), Color(0.20, 0.55, 0.15), Color(0.15, 0.45, 0.12))
	
	# 7. Water (Deep, crystal clear tropical blue - great for SSR reflections)
	_register(BlockType.Type.WATER, "Water", Color(0.15, 0.45, 0.85, 0.85), Color(0.12, 0.40, 0.75, 0.85), Color(0.10, 0.35, 0.65, 0.85))
	
	# 8. Sand (Warm, sunny beach yellow/cream)
	_register(BlockType.Type.SAND, "Sand", Color(0.95, 0.90, 0.65), Color(0.88, 0.82, 0.58), Color(0.82, 0.75, 0.52))
	
	# 9. Red Sand (Intense red/orange terracotta for badlands)
	_register(BlockType.Type.RED_SAND, "Red Sand", Color(0.88, 0.42, 0.25), Color(0.82, 0.35, 0.20), Color(0.75, 0.30, 0.15))
	
	# 10. Snow (Pristine, high-contrast white)
	_register(BlockType.Type.SNOW, "Snow", Color(0.98, 0.98, 0.98), Color(0.92, 0.94, 0.96), Color(0.88, 0.9, 0.92))
	
	# 11. Ice (Translucent, frozen neon blue)
	_register(BlockType.Type.ICE, "Ice", Color(0.62, 0.88, 0.95, 0.75), Color(0.55, 0.82, 0.9, 0.75), Color(0.48, 0.75, 0.85, 0.75))
	
	# 12. Mud (Dark swampy brown)
	_register(BlockType.Type.MUD, "Mud", Color(0.32, 0.25, 0.18), Color(0.28, 0.22, 0.15), Color(0.22, 0.18, 0.12))
	
	# 13. Neon Cyan (Glowing cybernetic highlights)
	_register(BlockType.Type.NEON_CYAN, "Neon Cyan", Color(0.0, 0.95, 0.95), Color(0.0, 0.8, 0.8), Color(0.0, 0.6, 0.6))
	
	# 14. Neon Magenta (Vibrant pink techno-glowing highlights)
	_register(BlockType.Type.NEON_MAGENTA, "Neon Magenta", Color(0.95, 0.0, 0.95), Color(0.8, 0.0, 0.8), Color(0.6, 0.0, 0.6))
	
	# 15. Cloud (Fluffy, semi-transparent pure white)
	_register(BlockType.Type.CLOUD, "Cloud", Color(1.0, 1.0, 1.0, 0.65), Color(0.95, 0.95, 0.95, 0.65), Color(0.9, 0.9, 0.9, 0.65))

	# 16. Lava (Vibrant, high-contrast flowing orange-red liquid)
	_register(BlockType.Type.LAVA, "Lava", Color(1.0, 0.45, 0.0), Color(0.9, 0.35, 0.0), Color(0.8, 0.25, 0.0))

static func _register(type: BlockType.Type, block_name: String, top: Color, side: Color, bottom: Color) -> void:
	_definitions[type] = BlockDefinition.new(type, block_name, top, side, bottom)

## Returns the definition corresponding to a specific BlockType.
static func get_definition(type: BlockType.Type) -> BlockDefinition:
	if _definitions.has(type):
		return _definitions[type]
	return _definitions[BlockType.Type.AIR]
