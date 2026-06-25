# ==============================================================================
# Project: CraftDomain
# Description: Domain enumeration and logical rules defining the physical 
#              and optical properties of all available blocks in the game.
#              UPDATED: Added LAVA block type (ID 15) to enable lava placement.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BlockType.gd
# ==============================================================================
class_name BlockType
extends RefCounted

## Enumeration of all domain-supported block types.
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
	LAVA = 15 # NEW: Buildable glowing liquid
}

## Returns true if the block type occupies physical space (is solid).
## Fluids like AIR, WATER, and LAVA are non-solid, allowing entities to move through them.
static func is_solid(type: Type) -> bool:
	match type:
		Type.AIR, Type.WATER, Type.LAVA:
			return false
		_:
			return true

## Returns true if the block type is transparent or semi-transparent.
## Transparent blocks allow light to pass through and trigger rendering face culling.
static func is_transparent(type: Type) -> bool:
	match type:
		Type.AIR, Type.LEAVES, Type.WATER, Type.ICE, Type.CLOUD, Type.LAVA:
			return true
		_:
			return false
