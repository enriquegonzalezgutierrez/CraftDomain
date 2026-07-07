# ==============================================================================
# Project: CraftDomain
# Description: Domain registry holding immutable definitions, colors, geometries, 
#              and shading parameters of all block types present in the game.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Only manages static 
#   registrations of block definitions.
# - Open-Closed Principle (OCP): Extensible with new block registrations and 
#   custom geometries (like Slabs) without changing the core meshing engines.
# - i18n & Abstraction Integration: Mapped the raw block physics parameters 
#   (is_solid, is_transparent) directly into the register pipeline to break circular loops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockLibrary.gd
# ==============================================================================
class_name BlockLibrary
extends RefCounted

static var _definitions: Dictionary = {}


static func _static_init() -> void:
	# ==========================================================================
	# CENTRALIZED REGISTER COHESION (OCP Compliant)
	# Signature: Type, translation_key, is_solid, is_transparent, top, side, bottom, [geometry]
	# ==========================================================================
	
	# 0. Air
	_register(BlockType.Type.AIR, "BLOCK_AIR", false, true, Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	
	# 1. Stone
	_register(BlockType.Type.STONE, "BLOCK_STONE", true, false, Color(0.55, 0.55, 0.55), Color(0.48, 0.48, 0.48), Color(0.42, 0.42, 0.42))
	
	# 2. Dirt
	_register(BlockType.Type.DIRT, "BLOCK_DIRT", true, false, Color(0.55, 0.38, 0.25), Color(0.48, 0.32, 0.20), Color(0.42, 0.28, 0.18))
	
	# 3. Grass
	_register(BlockType.Type.GRASS, "BLOCK_GRASS", true, false, Color(0.42, 0.78, 0.25), Color(0.48, 0.32, 0.20), Color(0.42, 0.28, 0.18))
	
	# 4. Wood (Oak)
	_register(BlockType.Type.WOOD, "BLOCK_WOOD", true, false, Color(0.72, 0.55, 0.35), Color(0.55, 0.42, 0.28), Color(0.72, 0.55, 0.35))
	
	# 5. Leaves
	_register(BlockType.Type.LEAVES, "BLOCK_LEAVES", true, true, Color(0.25, 0.65, 0.18), Color(0.20, 0.55, 0.15), Color(0.15, 0.45, 0.12))
	
	# 6. Water
	_register(BlockType.Type.WATER, "BLOCK_WATER", false, true, Color(0.15, 0.45, 0.85, 0.85), Color(0.12, 0.40, 0.75, 0.85), Color(0.10, 0.35, 0.65, 0.85))
	
	# 7. Sand
	_register(BlockType.Type.SAND, "BLOCK_SAND", true, false, Color(0.95, 0.90, 0.65), Color(0.88, 0.82, 0.58), Color(0.82, 0.75, 0.52))
	
	# 8. Red Sand
	_register(BlockType.Type.RED_SAND, "BLOCK_RED_SAND", true, false, Color(0.88, 0.42, 0.25), Color(0.82, 0.35, 0.20), Color(0.75, 0.30, 0.15))
	
	# 9. Snow
	_register(BlockType.Type.SNOW, "BLOCK_SNOW", true, false, Color(0.98, 0.98, 0.98), Color(0.92, 0.94, 0.96), Color(0.88, 0.9, 0.92))
	
	# 10. Ice
	_register(BlockType.Type.ICE, "BLOCK_ICE", true, true, Color(0.62, 0.88, 0.95, 0.75), Color(0.55, 0.82, 0.9, 0.75), Color(0.48, 0.75, 0.85, 0.75))
	
	# 11. Mud
	_register(BlockType.Type.MUD, "BLOCK_MUD", true, false, Color(0.32, 0.25, 0.18), Color(0.28, 0.22, 0.15), Color(0.22, 0.18, 0.12))
	
	# 12. Neon Cyan (Tech-Noir Teal)
	_register(BlockType.Type.NEON_CYAN, "BLOCK_NEON_CYAN", true, false, Color(0.06, 0.38, 0.45), Color(0.04, 0.28, 0.35), Color(0.02, 0.18, 0.25))
	
	# 13. Neon Magenta (Deep Cyberpunk Grape/Violet)
	_register(BlockType.Type.NEON_MAGENTA, "BLOCK_NEON_MAGENTA", true, false, Color(0.24, 0.04, 0.32), Color(0.18, 0.02, 0.24), Color(0.12, 0.01, 0.16))
	
	# 14. Cloud
	_register(BlockType.Type.CLOUD, "BLOCK_CLOUD", false, true, Color(1.0, 1.0, 1.0, 0.65), Color(0.95, 0.95, 0.95, 0.65), Color(0.9, 0.9, 0.9, 0.65))

	# 15. Lava
	_register(BlockType.Type.LAVA, "BLOCK_LAVA", false, true, Color(1.0, 0.45, 0.0), Color(0.9, 0.35, 0.0), Color(0.8, 0.25, 0.0))

	# 18. Crop Seed
	_register(BlockType.Type.CROP_SEED, "BLOCK_CROP_SEED", false, true, Color(0.48, 0.35, 0.22), Color(0.45, 0.32, 0.20), Color(0.42, 0.28, 0.18))

	# 19. Crop Growing
	_register(BlockType.Type.CROP_GROWING, "BLOCK_CROP_GROWING", false, true, Color(0.65, 0.92, 0.15), Color(0.58, 0.85, 0.12), Color(0.52, 0.78, 0.10))

	# 20. Crop Ripe
	_register(BlockType.Type.CROP_RIPE, "BLOCK_CROP_RIPE", false, true, Color(0.95, 0.78, 0.18), Color(0.88, 0.72, 0.15), Color(0.82, 0.65, 0.12))

	# 21. Coal Ore
	_register(BlockType.Type.COAL_ORE, "BLOCK_COAL_ORE", true, false, Color(0.12, 0.12, 0.14), Color(0.08, 0.08, 0.10), Color(0.05, 0.05, 0.06))

	# 22. Red Bricks
	_register(BlockType.Type.BRICKS, "BLOCK_BRICKS", true, false, Color(0.65, 0.28, 0.22), Color(0.58, 0.22, 0.18), Color(0.52, 0.18, 0.15))

	# 23. Glass
	_register(BlockType.Type.GLASS, "BLOCK_GLASS", true, true, Color(0.85, 0.95, 1.0, 0.35), Color(0.80, 0.92, 0.98, 0.35), Color(0.75, 0.88, 0.95, 0.35))

	# 24. Birch Log
	_register(BlockType.Type.BIRCH_LOG, "BLOCK_BIRCH_LOG", true, false, Color(0.92, 0.92, 0.94), Color(0.88, 0.88, 0.90), Color(0.92, 0.92, 0.94))

	# 25. Paved Road
	_register(BlockType.Type.ROAD, "BLOCK_ROAD", true, false, Color(0.24, 0.24, 0.28), Color(0.18, 0.18, 0.22), Color(0.24, 0.24, 0.28))
	
	# 26. Stone Slab Bottom (Y: 0.0 - 0.5)
	_register(
		BlockType.Type.STONE_SLAB_BOTTOM, 
		"BLOCK_STONE_SLAB_BOTTOM", 
		true, true,
		Color(0.55, 0.55, 0.55), Color(0.48, 0.48, 0.48), Color(0.42, 0.42, 0.42), 
		BottomSlabGeometry.new()
	)
	
	# 27. Stone Slab Top (Y: 0.5 - 1.0)
	_register(
		BlockType.Type.STONE_SLAB_TOP, 
		"BLOCK_STONE_SLAB_TOP", 
		true, true,
		Color(0.55, 0.55, 0.55), Color(0.48, 0.48, 0.48), Color(0.42, 0.42, 0.42), 
		TopSlabGeometry.new()
	)
	
	# 28. Diamond Ore
	_register(BlockType.Type.DIAMOND_ORE, "BLOCK_DIAMOND_ORE", true, false, Color(0.35, 0.38, 0.40), Color(0.28, 0.30, 0.32), Color(0.25, 0.27, 0.28))

	# 29. Oak Planks
	_register(BlockType.Type.OAK_PLANKS, "BLOCK_OAK_PLANKS", true, false, Color(0.85, 0.65, 0.40), Color(0.75, 0.55, 0.30), Color(0.65, 0.45, 0.25))

	# 30. Glowstone
	_register(BlockType.Type.GLOWSTONE, "BLOCK_GLOWSTONE", true, false, Color(1.0, 0.92, 0.35), Color(0.95, 0.85, 0.25), Color(0.85, 0.75, 0.15))


static func _register(
	type: BlockType.Type, 
	key: String, 
	is_solid: bool, 
	is_transparent: bool, 
	top: Color, 
	side: Color, 
	bottom: Color, 
	geometry: IVoxelGeometry = null
) -> void:
	_definitions[type] = BlockDefinition.new(type, key, is_solid, is_transparent, top, side, bottom, geometry)


static func get_definition(type: BlockType.Type) -> BlockDefinition:
	if _definitions.has(type):
		return _definitions[type]
	return _definitions[BlockType.Type.AIR]
