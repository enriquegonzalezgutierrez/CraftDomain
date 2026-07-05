# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the Golden Bazaar plains.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Open-Closed Principle (OCP): Overrides wilderness wildlife to 
#                spawn livestock, domestic house Cats (206), and scavenging Raccoons (211).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/GoldenBazaarBiome.gd
# ==============================================================================
class_name GoldenBazaarBiome
extends IBiome

func get_biome_id() -> int:
	return 2


func get_biome_name() -> String:
	return tr("BIOME_GOLDEN_BAZAAR")


func get_minimap_color() -> Color:
	return Color(0.92, 0.85, 0.35)


func get_base_height(noise_value: float) -> int:
	return int(5.0 + (noise_value + 1.0) * 1.0)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT


func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 180 == 15:
		return 3
	return 0


## Concrete Override: Organically scatters Oaks, Sakuras, Birches, and Rose Bushes.
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 45 == 3:
		return 12 
	elif scatter_hash % 70 == 5:
		return 1 
	elif scatter_hash % 90 == 8:
		return 13 
	elif scatter_hash % 150 == 12:
		return 10 
	return 0


## Concrete Override (OCP): Spawns livestock [0, 1, 2, 3], domestic Cats (206), and Raccoons (211) in the plains.
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 2, 3, 206, 211]
	return local_wildlife
