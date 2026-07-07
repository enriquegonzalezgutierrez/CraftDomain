# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the murky swamp region (Swamp of Sighs).
#              Fully encapsulated and OCP compliant.
#              - i18n Localization: Replaced hardcoded name string with localized `tr()` 
#              translation keys to maintain strict multi-language support.
# GEOGRAPHICAL SENSING (Phase 4):
#              - Implements `is_coordinate_inside()` to encapsulate its own 
#                spawning boundaries (polar angle slice >= 2.748 or < -2.748 rad).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/SwampOfSighsBiome.gd
# ==============================================================================
class_name SwampOfSighsBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Swamp of Sighs (ID 8)
func get_biome_id() -> int:
	return 8


## Concrete Implementation: Returns the HUD localized friendly name of the biome
func get_biome_name() -> String:
	return tr("BIOME_SWAMP_OF_SIGHS")


## Concrete Implementation: Returns the dark swampy mud brown color for the minimap
func get_minimap_color() -> Color:
	return Color(0.28, 0.22, 0.15)


## Concrete Implementation: Wet and depressed valleys topography calculations
func get_base_height(noise_value: float) -> int:
	return int(2.0 + (noise_value + 1.0) * 1.0)


## Concrete Implementation: Maps sticky mud blocks on surface and solid stone core underground
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.MUD


## Concrete Implementation: Natural swamp biome with no rigid structural landmarks
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the western misty mud sector slice
func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 2.748 or angle_rad < -2.748
