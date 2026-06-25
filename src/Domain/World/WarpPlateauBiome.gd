# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the vertical step-platform region (Warp Plateau - Mario style).
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WarpPlateauBiome.gd
# ==============================================================================
class_name WarpPlateauBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Warp Plateau (ID 1)
func get_biome_id() -> int:
	return 1

## Concrete Implementation: Returns the HUD friendly name
func get_biome_name() -> String:
	return "Warp Plateau (Mario Steps)"

## Concrete Implementation: Returns the vibrant emerald green color for the minimap
func get_minimap_color() -> Color:
	return Color(0.38, 0.85, 0.28)

## Concrete Implementation: Mario-style staircase verticality using step-function math
func get_base_height(noise_value: float) -> int:
	var raw_h := 8.0 + (noise_value + 1.0) * 12.0
	return int(round(raw_h / 4.0) * 4.0) # Snap heights to 4-block increments

## Concrete Implementation: Maps grass on top steps and dirt layers on vertical walls
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT

## Concrete Implementation: Evaluates laderas for green vertical warp pipe structures
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Warp pipe structure is represented by ID 2 (matches LandmarkType.WARP_PIPE_STRUCTURE)
	if spawn_hash % 150 == 42:
		return 2
	return 0
