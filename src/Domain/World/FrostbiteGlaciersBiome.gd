# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the frozen polar glaciers region (Frostbite Glaciers).
#              Fully encapsulated and OCP compliant.
#              - i18n Localization: Added `tr()` wrapper to the biome name 
#                to ensure dynamic translation parsing across the GPS HUD.
# GEOGRAPHICAL SENSING (Phase 4):
#              - Implements `is_coordinate_inside()` to encapsulate its own 
#                spawning boundaries (merging the North Polar Cap core and the 
#                northern glacial shelf sector slice).
#              - FIXED COMPILER ERROR: Explicitly typed boundary checks as `bool` 
#                to satisfy Godot's strict static type analyzer.
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant):
#              - Overrides `get_streetlight_theme()` to polimorphically supply 
#                its own Frost/Ice theme parameters (frozen blue ice, snow-white poles).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/FrostbiteGlaciersBiome.gd
# ==============================================================================
class_name FrostbiteGlaciersBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Frostbite Glaciers (ID 4)
func get_biome_id() -> int:
	return 4


## Concrete Implementation: Returns the HUD friendly name using dynamic i18n lookup
func get_biome_name() -> String:
	return tr("BIOME_FROSTBITE_GLACIERS")


## Concrete Implementation: Returns the pristine polar white color for the minimap
func get_minimap_color() -> Color:
	return Color(0.98, 0.98, 0.98)


## Concrete Implementation: High altitude glacial shelves topography calculations
func get_base_height(noise_value: float) -> int:
	return int(10.0 + (noise_value + 1.0) * 3.0)


## Concrete Implementation: Maps snow on surface steps and frozen blue ice beneath
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.SNOW
	return BlockType.Type.ICE


## Concrete Implementation: Evaluates polar coordinates for ice temple tower placements
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Ice temple structure is represented by ID 5 (matches LandmarkType.ICE_TEMPLE)
	if spawn_hash % 220 == 9:
		return 5
	return 0


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the North Cap core or Northern sector shelf
func is_coordinate_inside(pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	# A. North Polar Cap Core Boundary check (Z < -420.0 and X within 180.0)
	var is_north_polar_cap: bool = pos_flat.y < -420.0 and abs(pos_flat.x) < 180.0
	
	# B. Northern sector slice check (between -1.963 and -1.178 radians)
	var is_north_glacial_shelf: bool = angle_rad >= -1.963 and angle_rad < -1.178
	
	return is_north_polar_cap or is_north_glacial_shelf


# ==============================================================================
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant)
# ==============================================================================

## Concrete Override: Returns the custom Frost/Ice theme parameters for glacial streetlights
func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.62, 0.88, 0.95),       # Frozen ice blue base
		"stone_light": Color(0.48, 0.75, 0.85),      # Frosted blue-ice shaft
		"wood_pole": Color(0.98, 0.98, 0.98),        # Cold snow-white post
		"iron_black": Color(0.12, 0.12, 0.15),       # Wrought iron cap
		"lantern_glow": Color(0.75, 0.85, 1.0),      # Silver-blue ice bulb emission
		"light_tint": Color(0.75, 0.85, 1.0)         # Cold silver-blue OmniLight3D color
	}
