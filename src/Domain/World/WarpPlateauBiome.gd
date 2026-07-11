# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing rules for Warp Plateau.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Fully implements IBiome interface.
#              - Single Responsibility Principle (SRP): Only manages plateau topography, 
#                and localized plant scattering rules.
#              - Open-Closed Principle (OCP): Overrides wilderness wildlife to 
#                spawn livestock and fire-puppy Growlithes (212) on grass terraces.
# GEOGRAPHICAL SENSING (Phase 4):
#              - Implements `is_coordinate_inside()` to encapsulate its own 
#                spawning boundaries (polar angle slice between 1.178 and 1.963 rad).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WarpPlateauBiome.gd
# ==============================================================================
class_name WarpPlateauBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Warp Plateau (ID 1)
func get_biome_id() -> int:
	return 1


## Concrete Implementation: Returns the HUD localized friendly name of the biome
func get_biome_name() -> String:
	return tr("BIOME_WARP_PLATEAU")


## Concrete Implementation: Returns the bright green color for the minimap
func get_minimap_color() -> Color:
	return Color(0.38, 0.85, 0.28)


## Concrete Implementation: Step-snapped mountain terraces topography calculations
func get_base_height(noise_value: float) -> int:
	var raw_h := 8.0 + (noise_value + 1.0) * 12.0
	return int(round(raw_h / 4.0) * 4.0)


## Concrete Implementation: Maps grass on top terraces and dirt/stone beneath
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT


## Concrete Implementation: Warp Plateau has no rigid stone landmarks
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Village cabin is represented by ID 3 (matches LandmarkType.VILLAGE_CABIN)
	if spawn_hash % 150 == 42:
		return 2
	return 0


## Concrete Override: Spawns Giant Red-Spotted Mario Mushrooms
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 90 == 8:
		return 3 # Giant Mushroom (ID 3)
	return 0


## Concrete Override (OCP): Spawns livestock [0, 1, 3] and Growlithes (212) on the grass terraces.
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 3, 212]
	return local_wildlife


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the southern sector step slice
func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 1.178 and angle_rad < 1.963


# ==============================================================================
# PROCEDURAL WORLD GENERATION RULES (OCP Compliant)
# ==============================================================================

func requires_terrain_smoothing() -> bool:
	return false # Uses rigid math steps for plateaus, blurring ruins the effect!

func get_water_level() -> int:
	return -1 # No sea-level water in high plateaus
