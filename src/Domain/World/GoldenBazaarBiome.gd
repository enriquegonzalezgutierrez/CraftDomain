# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the Golden Bazaar plains.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Single Responsibility Principle (SRP): Only manages plains topography, 
#                soil blocks, and local plant scattering rules.
#              LANDSCAPE OVERHAUL:
#              - Integrated organic scattering selectors for Birch Trees (ID 13),
#                flowering Rose Bushes (ID 12).
#              CLEANUP:
#              - Removed the obsolete voxel-based StreetlightBlueprint scatter trigger (ID 15)
#                to avoid visual void glitches.
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
	# Village cabin is represented by ID 3 (matches LandmarkType.VILLAGE_CABIN)
	if spawn_hash % 180 == 15:
		return 3
	return 0


## Concrete Override: Organically scatters Oaks, Sakuras, Birches, and Rose Bushes.
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	# Small shrubs (Rose Bushes) can spawn slightly more frequently
	if scatter_hash % 45 == 3:
		return 12 # Rose Bush (ID 12)
		
	# Common Oak Trees (60% of all trees)
	elif scatter_hash % 70 == 5:
		return 1 # Oak Tree (ID 1)
		
	# Slender Birch Trees (30% of all trees)
	elif scatter_hash % 90 == 8:
		return 13 # Birch Tree (ID 13)
		
	# Cherry Blossom Sakura Trees (10% of all trees)
	elif scatter_hash % 150 == 12:
		return 10 # Sakura Tree (ID 10)
		
	return 0
