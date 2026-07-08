# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Biomes)
# Description: Concrete Biome Strategy implementing rules for Whispering Redwood Forest.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Open-Closed Principle (OCP): Registers specialized Forest Druids (104) 
#                and Guards (102) for its outposts, and polymorphically scatters
#                decayed architectural temple ruins alongside its massive trees.
# GEOGRAPHICAL SENSING (Phase 4):
#              - Implements `is_coordinate_inside()` to encapsulate its own 
#                spawning boundaries (polar angle slice between 0.392 and 1.178 rad).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RedwoodForestBiome.gd
# ==============================================================================
class_name RedwoodForestBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Redwood Forest (ID 5)
func get_biome_id() -> int:
	return 5


## Concrete Implementation: Returns the HUD localized friendly name of the biome
func get_biome_name() -> String:
	return tr("BIOME_REDWOOD_FOREST")


## Concrete Implementation: Returns the forest green color for the minimap
func get_minimap_color() -> Color:
	return Color(0.18, 0.45, 0.15)


## Concrete Implementation: Calculates the base height for conifer valley hills
func get_base_height(noise_value: float) -> int:
	return int(6.0 + (noise_value + 1.0) * 2.5)


## Concrete Implementation: Maps layers of grass and stone cores underground
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT


## Concrete Implementation: Natural forest with no rigid structural landmarks
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


## Concrete Override: Organically scatters common Oak, colossal Redwood trees,
## and rare procedural Decayed Temple ruins (ID 15) that adapt to terrain slopes.
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 300 == 15:
		return 15 # Ancient Decayed Temple Ruin (Adaptive Dungeons - Case B)
	elif scatter_hash % 60 == 5:
		return 1  # Oak Tree (ID 1)
	elif scatter_hash % 120 == 12:
		return 2  # Colossal Redwood Conifer (ID 2)
	return 0


## Concrete Override: Spawns specialized Forest Druids (104) and Guards (102) at village outposts.
func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [104, 102]
	return specialized_population


## Concrete Override (OCP): Spawns Foxes (204), Flying Yellow Birds (205), Raccoons (211), and Monkeys (213).
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [204, 205, 211, 213]
	return local_wildlife


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the southeastern forest slice
func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 0.392 and angle_rad < 1.178
