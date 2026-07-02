# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the celestial floating clouds region (Cloud Kingdom).
#              Fully encapsulated and OCP compliant.
#              BUG FIX (i18n): Replaced hardcoded name string with localized `tr()` 
#              translation keys to maintain strict multi-language support.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/CloudKingdomBiome.gd
# ==============================================================================
class_name CloudKingdomBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Cloud Kingdom (ID 9)
func get_biome_id() -> int:
	return 9

## Concrete Implementation: Returns the HUD localized friendly name of the biome
func get_biome_name() -> String:
	return tr("BIOME_CLOUD_KINGDOM")

## Concrete Implementation: Returns the pure white cloud color for the minimap
func get_minimap_color() -> Color:
	return Color(1.0, 1.0, 1.0)

## Concrete Implementation: Sky isles have no ground base level (returns 0)
func get_base_height(_noise_value: float) -> int:
	return 0

## Concrete Implementation: Floating sky isles have air beneath their altitude steps
func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	return BlockType.Type.AIR

## Concrete Implementation: Sky islands have no land-level structural landmarks
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0
