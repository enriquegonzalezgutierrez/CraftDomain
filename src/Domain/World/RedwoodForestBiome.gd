# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing rules for Whispering Redwood Forest.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Open-Closed Principle (OCP): Returns specialized Forest Druids (104)
#                and Guards (102) for its outposts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RedwoodForestBiome.gd
# ==============================================================================
class_name RedwoodForestBiome
extends IBiome

func get_biome_id() -> int:
	return 5

func get_biome_name() -> String:
	return "Whispering Redwood Forest"

func get_minimap_color() -> Color:
	return Color(0.18, 0.45, 0.15)

func get_base_height(noise_value: float) -> int:
	return int(6.0 + (noise_value + 1.0) * 2.5)

func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT

func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0

## Override: Spawns both common Oak and colossal Redwood trees
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 60 == 5:
		return 1 # Oak Tree (ID 1)
	elif scatter_hash % 120 == 12:
		return 2 # Redwood Tree (ID 2)
	return 0


## Concrete Override: Spawns specialized Forest Druids (104) and Guards (102).
func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [104, 102]
	return specialized_population
