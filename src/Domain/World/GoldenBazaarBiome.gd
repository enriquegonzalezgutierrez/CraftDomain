# ==============================================================================
# Pathfile: res://src/Domain/World/GoldenBazaarBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              Golden Bazaar plains.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly Golden Bazaar parameters.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
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


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 2:
		return 223 # 3D Beach Grass
	elif type_roll < 4:
		return 220 # 3D Dandelion
	elif type_roll < 5:
		return 221 # 3D Poppy
	elif type_roll < 6:
		return 238 # 3D Sakura Blossom Shrub (NEW!)
	elif type_roll < 7:
		return 235 # 3D White Daisy
	elif type_roll < 8:
		return 230 # 3D Tulip Red
	elif type_roll < 9:
		return 231 # 3D Tulip Orange
	return 234     # 3D Cornflower


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 2, 3, 206, 211]
	return local_wildlife


# ==============================================================================
# SOLID OCP SCALED POPULATION CONFIGURATION (OCP Compliance)
# ==============================================================================

func get_spawn_probability() -> float:
	return 0.45


func get_max_group_size() -> int:
	return 6


func get_village_civilian_ids() -> Array[int]:
	var golden_bazaar_civilian_roster: Array[int] = [100, 101, 102, 103, 107]
	return golden_bazaar_civilian_roster


func get_village_population_density() -> int:
	return 8


# ==============================================================================
# METEOROLOGICAL & CLIMATE CONFIGURATION
# ==============================================================================

func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return -1


func get_climate_profile() -> IClimateProfile:
	return TemperateClimateProfile.new()
