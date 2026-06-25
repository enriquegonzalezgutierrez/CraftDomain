# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the ancient technological ruins (Neon Ruins).
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/NeonRuinsBiome.gd
# ==============================================================================
class_name NeonRuinsBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Neon Ruins (ID 7)
func get_biome_id() -> int:
	return 7

## Concrete Implementation: Returns the HUD friendly name
func get_biome_name() -> String:
	return "Neon Ruins (Cyber Basin)"

## Concrete Implementation: Returns the electric cyan color for the minimap
func get_minimap_color() -> Color:
	return Color(0.0, 0.85, 0.85)

## Concrete Implementation: Ancient plateau ruins topography calculations
func get_base_height(noise_value: float) -> int:
	return int(8.0 + (noise_value + 1.0) * 2.0)

## Concrete Implementation: Maps glowing cybernetic neon cyan and magenta block layers
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.NEON_CYAN
	return BlockType.Type.NEON_MAGENTA

## Concrete Implementation: Evaluates coordinates for ancient neon pyramid structures
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Neon pyramid structure is represented by ID 6 (matches LandmarkType.NEON_PYRAMID)
	if spawn_hash % 240 == 33:
		return 6
	return 0
