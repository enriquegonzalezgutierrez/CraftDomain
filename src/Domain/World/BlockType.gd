# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Value Object defining all available block types.
#              SOLID COMPLIANCE: Adheres to the Single Responsibility Principle (SRP)
#              by encapsulating only the block types classification.
#              FASE A UPGRADE: Added dynamic agricultural voxel types:
#              - CROP_SEED (Planted wheat seed)
#              - CROP_GROWING (Sprouting green stem)
#              - CROP_RIPE (Mature golden wheat crop ready for harvest)
#              Crops are flagged as non-solid so players and NPCs can walk through fields.
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
	# FASE A: Crop growth voxel block stages
	CROP_SEED = 18,
	CROP_GROWING = 19,
	CROP_RIPE = 20
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
		Type.CROP_SEED, Type.CROP_GROWING, Type.CROP_RIPE:
			return true
		_:
			return false
