# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the Red Terracotta Canyons.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Single Responsibility Principle (SRP): Only manages desert canyons 
#                topography, sandstone blocks, and local plant scattering rules.
#              - Open-Closed Principle (OCP): Overrides wilderness wildlife to 
#                spawn livestock and colossal Elephants (209) in the canyons.
# GEOGRAPHICAL SENSING (Phase 4):
#              - Implements `is_coordinate_inside()` to encapsulate its own 
#                spawning boundaries (polar angle slice between 1.963 and 2.748 rad).
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant):
#              - Overrides `get_streetlight_theme()` to polimorphically supply 
#                its own Badlands theme parameters (terracotta orange base, dry wood pole).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RedBadlandsBiome.gd
# ==============================================================================
class_name RedBadlandsBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Red Badlands (ID 6)
func get_biome_id() -> int:
	return 6


## Concrete Implementation: Returns the HUD friendly name.
func get_biome_name() -> String:
	return tr("BIOME_RED_BADLANDS")


## Concrete Implementation: Returns the burnt terracotta orange color for the minimap.
func get_minimap_color() -> Color:
	return Color(0.85, 0.38, 0.22)


## Concrete Implementation: Terraced badlands canyons using step-function mathematics.
func get_base_height(noise_value: float) -> int:
	var raw_b := 4.0 + (noise_value + 1.0) * 8.0
	return int(round(raw_b / 3.0) * 3.0) 


## Concrete Implementation: Maps layers of red sand and stone cores underground.
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.RED_SAND


## Concrete Implementation: Natural desert canyons with no structural landmarks.
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


## Concrete Override: Organically scatters dry, twisted Dead Shrubs (ID 14) across the sand steps.
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 50 == 4:
		return 14 
	return 0


## Concrete Override (OCP): Spawns livestock and colossal Elephants (209) in the canyons.
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 3, 209]
	return local_wildlife


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the southwestern badlands slice
func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 1.963 and angle_rad < 2.748


# ==============================================================================
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant)
# ==============================================================================

## Concrete Override: Returns the custom Desert Canyon theme parameters for badlands streetlights
func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.55, 0.32, 0.22),        # Terracotta dark-orange base stone
		"stone_light": Color(0.75, 0.48, 0.35),       # Sandstone light-orange shaft
		"wood_pole": Color(0.28, 0.18, 0.12),         # Dry dark-wood post
		"iron_black": Color(0.12, 0.12, 0.15),        # Wrought iron cap
		"lantern_glow": Color(1.0, 0.55, 0.0),         # Glowing amber-orange bulb emission
		"light_tint": Color(1.0, 0.55, 0.0)           # Warm amber-orange OmniLight3D color
	}
