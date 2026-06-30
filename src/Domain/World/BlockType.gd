# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Value Object defining all supported voxel block types.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by encapsulating only the block classification maps.
#              BLOCK OVERHAUL UPGRADE: 
#              - Added COAL_ORE (21), BRICKS (22), and GLASS (23) block types.
#              - Configured physical solid and light-transparent properties 
#                (Glass is solid but transparent).
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
	
	# New structural blocks
	COAL_ORE = 21,
	BRICKS = 22,
	GLASS = 23
}


## Returns true if the block type occupies physical space (is solid).
## Non-solid blocks like liquids and crops allow player/NPC passage and culling.
static func is_solid(type: Type) -> bool:
	match type:
		Type.AIR, Type.WATER, Type.LAVA, \
		Type.CROP_SEED, Type.CROP_GROWING, Type.CROP_RIPE:
			return false
		_:
			return true


## Returns true if the block type is transparent or semi-transparent.
## Transparent blocks allow light to pass through and trigger rendering face culling.
static func is_transparent(type: Type) -> bool:
	match type:
		Type.AIR, Type.LEAVES, Type.WATER, Type.ICE, Type.CLOUD, Type.LAVA, \
		Type.CROP_SEED, Type.CROP_GROWING, Type.CROP_RIPE, \
		Type.GLASS: # Glass is a solid transparent block!
			return true
		_:
			return false
