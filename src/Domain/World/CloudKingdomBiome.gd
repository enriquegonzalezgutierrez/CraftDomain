# ==============================================================================
# Pathfile: res://src/Domain/World/CloudKingdomBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              celestial floating Cloud Kingdom.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CloudKingdomBiome
extends IBiome


func get_biome_id() -> int:
	return 9


func get_biome_name() -> String:
	return tr("BIOME_CLOUD_KINGDOM")


func get_minimap_color() -> Color:
	return Color(1.0, 1.0, 1.0)


func get_base_height(_noise_value: float) -> int:
	return 0


func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	return BlockType.Type.AIR


func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


func get_wilderness_wildlife_ids() -> Array[int]:
	# Primarily flying fauna for the stratospheric islands
	var celestial_wildlife: Array[int] = [205, 207]
	return celestial_wildlife


# ==============================================================================
# SOLID OCP SCALED POPULATION CONFIGURATION (OCP Compliance)
# ==============================================================================

func get_spawn_probability() -> float:
	return 0.40 # High altitude birds are common in the clouds


func get_max_group_size() -> int:
	return 6 # Large, beautiful flocks of birds


func get_village_civilian_ids() -> Array[int]:
	# Sky travelers and watchers
	var sky_outpost_roster: Array[int] = [100, 102]
	return sky_outpost_roster


func get_village_population_density() -> int:
	return 4 # Small celestial observation posts


# ==============================================================================
# METEOROLOGICAL & CLIMATE CONFIGURATION
# ==============================================================================

func get_climate_weights() -> Dictionary:
	return {
		"sunny": 1.0,      
		"rainy": 0.0,
		"snowy": 0.0,
		"sandstorm": 0.0,
		"foggy": 0.0
	}


func get_max_wind_strength() -> float:
	return 1.6


func get_fog_density_multiplier() -> float:
	return 0.15


func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return -1
