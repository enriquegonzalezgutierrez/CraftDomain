# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the high stone mountains and subterranean cave structures
#              (Craggy Peaks & Caves). Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/CraggyMinesBiome.gd
# ==============================================================================
class_name CraggyMinesBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Craggy Mines (ID 3)
func get_biome_id() -> int:
	return 3

## Concrete Implementation: Returns the HUD friendly name
func get_biome_name() -> String:
	return "Craggy Peaks & Caves"

## Concrete Implementation: Returns the dark grey peaks color for the minimap
func get_minimap_color() -> Color:
	return Color(0.48, 0.48, 0.48)

## Concrete Implementation: Jagged and vertical mountain peaks topography calculations
func get_base_height(noise_value: float) -> int:
	return int(6.0 + (noise_value + 1.0) * 8.0)

## Concrete Implementation: Maps dark stone blocks for both surface and deep core
func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	return BlockType.Type.STONE

## Concrete Implementation: Evaluates peaks for mine support pillars structures
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Mine support pillar is represented by ID 4 (matches LandmarkType.MINE_SUPPORT_PILLAR)
	if spawn_hash % 160 == 7:
		return 4
	return 0
