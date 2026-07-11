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
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant):
#              - Overrides `get_streetlight_theme()` to polimorphically supply 
#                its own Swamp theme parameters (mud-brown stone base, mossy green pole).
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

## Concrete Implementation: Returns true if within the western mucky mud sector slice
func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 2.748 or angle_rad < -2.748


# ==============================================================================
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant)
# ==============================================================================

## Concrete Override: Returns the custom Swamp/Moss theme parameters for swamp streetlights
func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.22, 0.18, 0.12),       # Mud-brown base stone
		"stone_light": Color(0.18, 0.28, 0.15),      # Mossy dark-wood shaft
		"wood_pole": Color(0.15, 0.45, 0.12),        # Foliage-green post
		"iron_black": Color(0.12, 0.12, 0.15),       # Wrought iron cap
		"lantern_glow": Color(0.42, 0.85, 0.25),      # Glowing poison-green bulb emission
		"light_tint": Color(0.42, 0.85, 0.25)         # Swampy green OmniLight3D color
	}


# ==============================================================================
# PROCEDURAL WORLD GENERATION RULES (OCP Compliant)
# ==============================================================================

func requires_terrain_smoothing() -> bool:
	return false # Swamps are flat lowlands, no smoothing required

func get_water_level() -> int:
	return 4 # Murky bay water levels out at Y = 4
