# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the red terracotta canyons (Red Sandstone Canyons).
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RedBadlandsBiome.gd
# ==============================================================================
class_name RedBadlandsBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Red Badlands (ID 6)
func get_biome_id() -> int:
	return 6

## Concrete Implementation: Returns the HUD friendly name
func get_biome_name() -> String:
	return "Red Sandstone Canyons"

## Concrete Implementation: Returns the burnt terracotta orange color for the minimap
func get_minimap_color() -> Color:
	return Color(0.85, 0.38, 0.22)

## Concrete Implementation: Terraced badlands canyons using step-function math
func get_base_height(noise_value: float) -> int:
	var raw_b := 4.0 + (noise_value + 1.0) * 8.0
	return int(round(raw_b / 3.0) * 3.0) # Snap heights to 3-block increments

## Concrete Implementation: Maps layers of red sand and sandstone blocks
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.RED_SAND

## Concrete Implementation: Natural desert canyons with no structural landmarks
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0
