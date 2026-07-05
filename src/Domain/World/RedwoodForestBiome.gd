# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing rules for Whispering Redwood Forest.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Open-Closed Principle (OCP): Overrides wilderness wildlife to 
#                spawn Foxes (204), Flying Yellow Birds (205), Raccoons (211), 
#                and climbing Monkeys (213) organically in the woods.
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


## Concrete Implementation: Natural forest with no structural landmarks
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


## Concrete Override: Organically scatters common Oak and colossal Redwood trees.
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 60 == 5:
		return 1 
	elif scatter_hash % 120 == 12:
		return 2 
	return 0


## Concrete Override: Spawns specialized Forest Druids (104) and Guards (102) at village outposts.
func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [104, 102]
	return specialized_population


## Concrete Override (OCP): Spawns Foxes (204), Flying Yellow Birds (205), Raccoons (211), and Monkeys (213).
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [204, 205, 211, 213]
	return local_wildlife
