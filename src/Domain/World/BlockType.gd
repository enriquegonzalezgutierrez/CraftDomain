# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Value Object defining all supported voxel block types.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Encapsulates exclusively the raw block
#   ID enum type mappings.
# - Open-Closed Principle (OCP): No longer hardcodes physical properties (solidity,
#   transparency) inside static tables. These parameters are dynamically retrieved 
#   from the centralized, data-driven `BlockLibrary` definitions, making this class
#   completely closed to modifications when adding new block types.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockType.gd
# ==============================================================================
class_name BlockType
extends RefCounted

## Enumeration of all raw block IDs supported by the voxel meshing engine.
enum Type {
	AIR = 0,
	STONE = 1,
	DIRT = 2,
	GRASS = 3,
	WOOD = 4,
	LEAVES = 5,
	WATER = 6,
	SAND = 7,
	RED_SAND = 8,
	SNOW = 9,
	ICE = 10,
	MUD = 11,
	NEON_CYAN = 12,
	NEON_MAGENTA = 13,
	CLOUD = 14,
	LAVA = 15,
	
	# Agricultural Stages
	CROP_SEED = 18,
	CROP_GROWING = 19,
	CROP_RIPE = 20,
	
	# Extended structural blocks
	COAL_ORE = 21,
	BRICKS = 22,
	GLASS = 23,
	BIRCH_LOG = 24,
	
	# Scenery Highway Blocks
	ROAD = 25,
	
	# Slabs / Half-height Blocks
	STONE_SLAB_BOTTOM = 26,
	STONE_SLAB_TOP = 27,
	
	# Caves & Desert Expansion
	DIAMOND_ORE = 28,
	OAK_PLANKS = 29,
	GLOWSTONE = 30
}


## Returns true if the block type occupies physical space (is solid).
## Sourced dynamically from the data-driven BlockLibrary.
static func is_solid(type: Type) -> bool:
	# DIP Inversion: Query the central library definitions instead of hardcoding match cases
	var def := BlockLibrary.get_definition(type)
	return def.is_solid if def != null else false


## Returns true if the block type is transparent or semi-transparent.
## Sourced dynamically from the data-driven BlockLibrary.
static func is_transparent(type: Type) -> bool:
	# DIP Inversion: Query the central library definitions instead of hardcoding match cases
	var def := BlockLibrary.get_definition(type)
	return def.is_transparent if def != null else false
