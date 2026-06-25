# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the giant tree forest (Whispering Redwood Forest).
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RedwoodForestBiome.gd
# ==============================================================================
class_name RedwoodForestBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Redwood Forest (ID 5)
func get_biome_id() -> int:
	return 5

## Concrete Implementation: Returns the HUD friendly name
func get_biome_name() -> String:
	return "Whispering Redwood Forest"

## Concrete Implementation: Returns the deep dark forest green color for the minimap
func get_minimap_color() -> Color:
	return Color(0.18, 0.45, 0.15)

## Concrete Implementation: Forested valleys topography calculations
func get_base_height(noise_value: float) -> int:
	return int(6.0 + (noise_value + 1.0) * 2.5)

## Concrete Implementation: Maps rich mossy grass on surface and solid stone core underground
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT

## Concrete Implementation: Natural dense forest with no rigid structural landmarks
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0
