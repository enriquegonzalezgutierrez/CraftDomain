# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Value Object defining all supported voxel block types.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by encapsulating only the block classification maps.
#              OCP EXTENSION:
#              - Added ROAD (25) block type to represent dedicated grey paved 
#                scenery highways.
#              - Added STONE_SLAB_BOTTOM (26) and STONE_SLAB_TOP (27) to support 
#                half-height horizontal structures.
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
	STONE_SLAB_TOP = 27
}


## Returns true if the block type occupies physical space (is solid).
static func is_solid(type: Type) -> bool:
	match type:
		Type.AIR, Type.WATER, Type.LAVA, \
		Type.CROP_SEED, Type.CROP_GROWING, Type.CROP_RIPE, \
		Type.LEAVES, Type.CLOUD: # Leaves and Clouds are non-solid traversable blocks!
			return false
		_:
			# Slabs are solid physical obstacles (return true under the default fallback)
			return true


## Returns true if the block type is transparent or semi-transparent.
## A block is also considered "transparent" for the mesher if it does not occupy 
## a full 1x1x1 cube, preventing incorrect face culling holes on adjacent blocks.
static func is_transparent(type: Type) -> bool:
	match type:
		Type.AIR, Type.LEAVES, Type.WATER, Type.ICE, Type.CLOUD, Type.LAVA, \
		Type.CROP_SEED, Type.CROP_GROWING, Type.CROP_RIPE, \
		Type.GLASS, \
		Type.STONE_SLAB_BOTTOM, Type.STONE_SLAB_TOP: # Slabs are transparent to prevent culling adjacent faces!
			return true
		_:
			return false
