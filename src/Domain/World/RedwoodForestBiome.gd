# ==============================================================================
# Pathfile: res://src/Domain/World/RedwoodForestBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              dense, mysterious Whispering Redwood Forest.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RedwoodForestBiome
extends IBiome


func get_biome_id() -> int:
	return 5


func get_biome_name() -> String:
	return tr("BIOME_REDWOOD_FOREST")


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


func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 300 == 15:
		return 15 # Decayed Temple Ruins
	elif scatter_hash % 60 == 5:
		return 1  # Oak Tree
	elif scatter_hash % 120 == 12:
		return 2  # Giant Redwood Tree
	return 0


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 7:
		return 223   # Tall Grass/Ferns
	elif type_roll < 9:
		return 222   # Blue Orchid
	return 221       # Poppy


# ==============================================================================
# SOLID OCP SCALED POPULATION CONFIGURATION (OCP Compliance)
# ==============================================================================

func get_spawn_probability() -> float:
	return 0.65 # Highly lush, dense, and organic forest environment


func get_max_group_size() -> int:
	return 5 # Vibrant, medium-sized packs and flocks of woodland animals


func get_wilderness_wildlife_ids() -> Array[int]:
	# Specialized arboreal and woodland fauna!
	var woodland_wildlife_roster: Array[int] = [204, 206, 207, 211, 213] # Fox, Cat, Parrot, Raccoon, Monkey
	return woodland_wildlife_roster


func get_village_civilian_ids() -> Array[int]:
	# Magical woodland settlement roster: Druids, Farmers, and Guards
	var woodland_outpost_roster: Array[int] = [102, 103, 104]
	return woodland_outpost_roster


func get_village_population_density() -> int:
	return 5 # Dense, closely-knit magical grove


# ==============================================================================
# METEOROLOGICAL & CLIMATE CONFIGURATION
# ==============================================================================

func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return -1


func get_climate_profile() -> IClimateProfile:
	return TemperateClimateProfile.new()
