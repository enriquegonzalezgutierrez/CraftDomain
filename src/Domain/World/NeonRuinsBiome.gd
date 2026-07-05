# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing rules for Neon Ruins.
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Open-Closed Principle (OCP): Returns specialized Cyber Citizens (106)
#                and Guards (102) for its outposts.
#              DESIGN UPGRADE (ATMOSPHERIC TECH-NOIR):
#              - Replaced eye-searing neon ground terrain with a carbon paved surface 
#                (ROAD) and deep volcanic coal bedrock (COAL_ORE).
#              - Spawns mystical glowing giant fungi (UnderworldFungus) and 
#                neon stepped pyramids (NeonPyramid) to create elegant contrast.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/NeonRuinsBiome.gd
# ==============================================================================
class_name NeonRuinsBiome
extends IBiome

func get_biome_id() -> int:
	return 7


## Concrete Implementation: Returns the HUD localized friendly name of the biome
func get_biome_name() -> String:
	return tr("BIOME_NEON_RUINS")


## Concrete Implementation: Returns the deep charcoal slate color for the minimap
func get_minimap_color() -> Color:
	return Color(0.12, 0.12, 0.16)


## Concrete Implementation: Standard basin hills topography calculations
func get_base_height(noise_value: float) -> int:
	return int(8.0 + (noise_value + 1.0) * 2.0)


## Concrete Implementation: Maps paved tech-noir surface (ROAD) and deep dark carbon coal bedrock (COAL_ORE)
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.ROAD
	return BlockType.Type.COAL_ORE


func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Stepped Neon Pyramid is represented by ID 6
	if spawn_hash % 240 == 33:
		return 6
	return 0


## Override: Spawns magical Glowing Giant Fungi in the cyber basin
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 70 == 9:
		return 11 # Giant Underworld Fungus (ID 11)
	return 0


## Concrete Override: Spawns specialized Cyber Citizens (106) and Guards (102).
func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [106, 102]
	return specialized_population
