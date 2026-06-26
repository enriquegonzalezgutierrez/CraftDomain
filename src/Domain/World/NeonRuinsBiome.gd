# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing rules for Neon Ruins.
#              UPDATED: Added scatter blueprint routing to spawn glowing Giant Fungi.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/NeonRuinsBiome.gd
# ==============================================================================
class_name NeonRuinsBiome
extends IBiome

func get_biome_id() -> int:
	return 7

func get_biome_name() -> String:
	return "Neon Ruins (Cyber Basin)"

func get_minimap_color() -> Color:
	return Color(0.0, 0.85, 0.85)

func get_base_height(noise_value: float) -> int:
	return int(8.0 + (noise_value + 1.0) * 2.0)

func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.NEON_CYAN
	return BlockType.Type.NEON_MAGENTA

func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 240 == 33:
		return 6
	return 0

## Override: Spawns magical Glowing Giant Fungi in the cyber basin!
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 70 == 9:
		return 11 # Giant Underworld Fungus (ID 11)
	return 0
