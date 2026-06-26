# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing rules for Warp Plateau.
#              UPDATED: Added scatter blueprint routing to spawn Giant Mushrooms.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WarpPlateauBiome.gd
# ==============================================================================
class_name WarpPlateauBiome
extends IBiome

func get_biome_id() -> int:
	return 1

func get_biome_name() -> String:
	return "Warp Plateau (Mario Steps)"

func get_minimap_color() -> Color:
	return Color(0.38, 0.85, 0.28)

func get_base_height(noise_value: float) -> int:
	var raw_h := 8.0 + (noise_value + 1.0) * 12.0
	return int(round(raw_h / 4.0) * 4.0)

func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT

func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 150 == 42:
		return 2
	return 0

## Override: Spawns Giant Red-Spotted Mario Mushrooms
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 90 == 8:
		return 3 # Giant Mushroom (ID 3)
	return 0
