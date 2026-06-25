# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the flat trading plains (Golden Bazaar).
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/GoldenBazaarBiome.gd
# ==============================================================================
class_name GoldenBazaarBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Golden Bazaar (ID 2)
func get_biome_id() -> int:
	return 2

## Concrete Implementation: Returns the HUD friendly name
func get_biome_name() -> String:
	return "Golden Bazaar (Village Plains)"

## Concrete Implementation: Returns the warm golden/yellow color for the minimap
func get_minimap_color() -> Color:
	return Color(0.92, 0.85, 0.35)

## Concrete Implementation: Flat and smooth plains topography calculations
func get_base_height(noise_value: float) -> int:
	return int(5.0 + (noise_value + 1.0) * 1.0)

## Concrete Implementation: Maps grass on surface and solid stone core underground
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT

## Concrete Implementation: Evaluates plains for market stall placements
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Village market cabin is represented by ID 3 (matches LandmarkType.VILLAGE_MARKET_CABIN)
	if spawn_hash % 180 == 15:
		return 3
	return 0
