# ==============================================================================
# Project: CraftDomain
# Description: Domain registry holding immutable definitions, colors, and 
#              shading parameters of all block types present in the game.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating block definitions from rendering loops.
#              FASE A UPGRADE: Registered PBR albedo colors for:
#              - CROP_SEED (Sandy dirt brown)
#              - CROP_GROWING (Sprouting lime green)
#              - CROP_RIPE (Golden harvest wheat yellow)
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockLibrary.gd
# ==============================================================================
class_name BlockLibrary
extends RefCounted

## Stores the dictionary of registered block definitions.
static var _definitions: Dictionary = {}

## Static constructor. Runs automatically when the class is first loaded.
static func _static_init() -> void:
	# 0. Air (Transparent empty space)
	_register(BlockType.Type.AIR, "Air", Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	
	# 1. Stone (Cleaner, lighter grey for better SDFGI light bouncing)
	_register(BlockType.Type.STONE, "Stone", Color(0.55, 0.55, 0.55), Color(0.48, 0.48, 0.48), Color(0.42, 0.42, 0.42))
	
	# 2. Dirt (Rich, warm, chocolate brown soil)
	_register(BlockType.Type.DIRT, "Dirt", Color(0.55, 0.38, 0.25), Color(0.48, 0.32, 0.20), Color(0.42, 0.28, 0.18))
	
	# 3. Grass (Vibrant, highly saturated bright green top!)
	_register(BlockType.Type.GRASS, "Grass", Color(0.42, 0.78, 0.25), Color(0.48, 0.32, 0.20), Color(0.42, 0.28, 0.18))
	
	# 4. Wood (Warm, golden-oak trunk colors)
	_register(BlockType.Type.WOOD, "Wood", Color(0.72, 0.55, 0.35), Color(0.55, 0.42, 0.28), Color(0.72, 0.55, 0.35))
	
	# 5. Leaves (Rich, vibrant forest green for lush canopies)
	_register(BlockType.Type.LEAVES, "Leaves", Color(0.25, 0.65, 0.18), Color(0.20, 0.55, 0.15), Color(0.15, 0.45, 0.12))
	
	# 6. Water (Deep, crystal clear tropical blue - great for SSR reflections)
	_register(BlockType.Type.WATER, "Water", Color(0.15, 0.45, 0.85, 0.85), Color(0.12, 0.40, 0.75, 0.85), Color(0.10, 0.35, 0.65, 0.85))
	
	# 7. Sand (Warm, sunny beach yellow/cream)
	_register(BlockType.Type.SAND, "Sand", Color(0.95, 0.90, 0.65), Color(0.88, 0.82, 0.58), Color(0.82, 0.75, 0.52))
	
	# 8. Red Sand (Intense red/orange terracotta for badlands)
	_register(BlockType.Type.RED_SAND, "Red Sand", Color(0.88, 0.42, 0.25), Color(0.82, 0.35, 0.20), Color(0.75, 0.30, 0.15))
	
	# 9. Snow (Pristine, high-contrast white)
	_register(BlockType.Type.SNOW, "Snow", Color(0.98, 0.98, 0.98), Color(0.92, 0.94, 0.96), Color(0.88, 0.9, 0.92))
	
	# 10. Ice (Translucent, frozen neon blue)
	_register(BlockType.Type.ICE, "Ice", Color(0.62, 0.88, 0.95, 0.75), Color(0.55, 0.82, 0.9, 0.75), Color(0.48, 0.75, 0.85, 0.75))
	
	# 11. Mud (Dark swampy brown)
	_register(BlockType.Type.MUD, "Mud", Color(0.32, 0.25, 0.18), Color(0.28, 0.22, 0.15), Color(0.22, 0.18, 0.12))
	
	# 12. Neon Cyan (Glowing cybernetic highlights)
	_register(BlockType.Type.NEON_CYAN, "Neon Cyan", Color(0.0, 0.95, 0.95), Color(0.0, 0.8, 0.8), Color(0.0, 0.6, 0.6))
	
	# 13. Neon Magenta (Vibrant pink techno-glowing highlights)
	_register(BlockType.Type.NEON_MAGENTA, "Neon Magenta", Color(0.95, 0.0, 0.95), Color(0.8, 0.0, 0.8), Color(0.6, 0.0, 0.6))
	
	# 14. Cloud (Fluffy, semi-transparent pure white)
	_register(BlockType.Type.CLOUD, "Cloud", Color(1.0, 1.0, 1.0, 0.65), Color(0.95, 0.95, 0.95, 0.65), Color(0.9, 0.9, 0.9, 0.65))

	# 15. Lava (Vibrant, high-contrast flowing orange-red liquid)
	_register(BlockType.Type.LAVA, "Lava", Color(1.0, 0.45, 0.0), Color(0.9, 0.35, 0.0), Color(0.8, 0.25, 0.0))

	# 18. FASE A: Crop Seed (Planted seed, dry clay brown)
	_register(BlockType.Type.CROP_SEED, "Crop Seed", Color(0.48, 0.35, 0.22), Color(0.45, 0.32, 0.20), Color(0.42, 0.28, 0.18))

	# 19. FASE A: Crop Growing (Young sprout, vivid lime green)
	_register(BlockType.Type.CROP_GROWING, "Young Sprout", Color(0.65, 0.92, 0.15), Color(0.58, 0.85, 0.12), Color(0.52, 0.78, 0.10))

	# 20. FASE A: Crop Ripe (Mature wheat, golden harvest yellow/gold)
	_register(BlockType.Type.CROP_RIPE, "Ripe Wheat", Color(0.95, 0.78, 0.18), Color(0.88, 0.72, 0.15), Color(0.82, 0.65, 0.12))

static func _register(type: BlockType.Type, block_name: String, top: Color, side: Color, bottom: Color) -> void:
	_definitions[type] = BlockDefinition.new(type, block_name, top, side, bottom)

## Returns the definition corresponding to a specific BlockType.
static func get_definition(type: BlockType.Type) -> BlockDefinition:
	if _definitions.has(type):
		return _definitions[type]
	return _definitions[BlockType.Type.AIR]
