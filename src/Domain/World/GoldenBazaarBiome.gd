# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing rules for Golden Bazaar plains.
#              UPDATED: Added scatter blueprint routing to spawn common Oaks
#              and the new Cherry Blossom Sakura Trees polimorphically.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/GoldenBazaarBiome.gd
# ==============================================================================
class_name GoldenBazaarBiome
extends IBiome

func get_biome_id() -> int:
	return 2

func get_biome_name() -> String:
	return "Golden Bazaar (Village Plains)"

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

## Override: Spawns 80% common Oaks and 20% magical Sakura trees organically!
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 60 == 5:
		# Sakura tree has ID 10, Oak has ID 1
		return 10 if (scatter_hash % 5 == 0) else 1
	return 0
