# ==============================================================================
# Pathfile: res://src/Domain/World/CloudKingdomBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              celestial floating Cloud Kingdom.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly Cloud Kingdom parameters.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
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


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 6:
		return 240 # 3D Glacial Frost Flower (NEW!)
	return 0


func get_wilderness_wildlife_ids() -> Array[int]:
	var celestial_wildlife: Array[int] = [205, 207]
	return celestial_wildlife


func get_spawn_probability() -> float:
	return 0.40


func get_max_group_size() -> int:
	return 6


func get_village_civilian_ids() -> Array[int]:
	var sky_outpost_roster: Array[int] = [100, 102]
	return sky_outpost_roster


func get_village_population_density() -> int:
	return 4


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
