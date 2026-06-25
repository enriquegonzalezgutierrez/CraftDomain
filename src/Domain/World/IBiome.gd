# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Interface defining the strategic contract for any
#              procedural biome. Decouples physical, visual, and landmark
#              rules into independent, extensible classes.
#              Warnings resolved by prefixing unused abstract parameters with underscores.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IBiome.gd
# ==============================================================================
class_name IBiome
extends RefCounted

## Abstract contract: Returns the unique integer identifier representing this biome.
func get_biome_id() -> int:
	assert(false, "[IBiome] get_biome_id() must be implemented by concrete subclass.")
	return 0

## Abstract contract: Returns the user-friendly name of the biome for GPS HUD overlay.
func get_biome_name() -> String:
	assert(false, "[IBiome] get_biome_name() must be implemented by concrete subclass.")
	return ""

## Abstract contract: Returns the color representation to render on the circular Minimap.
func get_minimap_color() -> Color:
	assert(false, "[IBiome] get_minimap_color() must be implemented by concrete subclass.")
	return Color.BLACK

## Abstract contract: Calculates the maximum solid ground height for this coordinate column.
func get_base_height(_noise_value: float) -> int:
	assert(false, "[IBiome] get_base_height() must be implemented by concrete subclass.")
	return 0

## Abstract contract: Evaluates and returns the appropriate block type for a given vertical depth.
func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	assert(false, "[IBiome] get_block_for_depth() must be implemented by concrete subclass.")
	return BlockType.Type.AIR

## Abstract contract: Evaluates deterministically if a landmark spawns on this coordinate column.
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	assert(false, "[IBiome] get_landmark_type() must be implemented by concrete subclass.")
	return 0
