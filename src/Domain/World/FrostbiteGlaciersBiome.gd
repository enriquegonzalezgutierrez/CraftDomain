# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the frozen polar glaciers region (Frostbite Glaciers).
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/FrostbiteGlaciersBiome.gd
# ==============================================================================
class_name FrostbiteGlaciersBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Frostbite Glaciers (ID 4)
func get_biome_id() -> int:
	return 4

## Concrete Implementation: Returns the HUD friendly name
func get_biome_name() -> String:
	return "Frostbite Glaciers (North Cap)"

## Concrete Implementation: Returns the pristine polar white color for the minimap
func get_minimap_color() -> Color:
	return Color(0.98, 0.98, 0.98)

## Concrete Implementation: High altitude glacial shelves topography calculations
func get_base_height(noise_value: float) -> int:
	return int(10.0 + (noise_value + 1.0) * 3.0)

## Concrete Implementation: Maps snow on surface steps and frozen blue ice beneath
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.SNOW
	return BlockType.Type.ICE

## Concrete Implementation: Evaluates polar coordinates for ice temple tower placements
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Ice temple structure is represented by ID 5 (matches LandmarkType.ICE_TEMPLE)
	if spawn_hash % 220 == 9:
		return 5
	return 0
