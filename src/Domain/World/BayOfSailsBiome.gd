# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the tropical starter bay (Bay of Sails).
#              SOLID/i18n UPGRADE: Replaced hardcoded English biome name with a 
#              localized translation key (OCP compliant).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BayOfSailsBiome.gd
# ==============================================================================
class_name BayOfSailsBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Bay of Sails (ID 0)
func get_biome_id() -> int:
	return 0

## Concrete Implementation: Returns the dynamic localized name of the biome
func get_biome_name() -> String:
	return tr("BIOME_BAY_OF_SAILS")

## Concrete Implementation: Returns the vibrant tropical blue color for the minimap
func get_minimap_color() -> Color:
	return Color(0.12, 0.55, 0.82)

## Concrete Implementation: Standard flat sandy bay topography calculations
func get_base_height(noise_value: float) -> int:
	return int(3.0 + (noise_value + 1.0) * 1.5)

## Concrete Implementation: Maps sand beaches on surface and solid stone core underground
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.SAND

## Concrete Implementation: Evaluates sandy shores for harbor dock placements
func get_landmark_type(spawn_hash: int, base_height: int) -> int:
	# Port dock is represented by ID 1 (matches LandmarkType.PORT_DOCK)
	if base_height <= 4 and spawn_hash % 200 == 12:
		return 1 
	return 0
