# ==============================================================================
# Project: CraftDomain
# Description: Domain enumeration and basic rules defining the available block 
#              types in the game.
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
	LEAVES = 5
}

## Returns true if the block type occupies physical space (is solid).
## This rule belongs to the domain logic layer.
static func is_solid(type: Type) -> bool:
	return type != Type.AIR

## Returns true if the block type is transparent or semi-transparent.
static func is_transparent(type: Type) -> bool:
	return type == Type.AIR or type == Type.LEAVES
