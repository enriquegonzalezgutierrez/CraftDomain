# ==============================================================================
# Pathfile: res://src/Domain/World/BayOfSailsBiome.gd
# Description: Concrete Biome Strategy for the tropical starter Bay of Sails.
#              Generates gradual sandy shores and deep underwater ocean trenches.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BayOfSailsBiome
extends IBiome


func get_biome_id() -> int:
	return 0


func get_biome_name() -> String:
	return tr("BIOME_BAY_OF_SAILS")


func get_minimap_color() -> Color:
	return Color(0.08, 0.45, 0.72)


## GEOLOGICAL HEIGHT RESOLVER: Generates gradual shorelines and deep submarine valleys.
func get_base_height(noise_value: float) -> int:
	# Deep Ocean Trenches: Down to Y=1 (yielding 4-5 blocks of water depth)
	if noise_value < -0.15:
		return int(lerpf(1.0, 3.0, (noise_value + 1.0) / 0.85))
		
	# Shallow Sandbanks and Beaches: Sloping gently up to Y=6 (exposed land)
	return int(3.0 + (noise_value + 1.0) * 1.5)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.SAND


func get_landmark_type(spawn_hash: int, base_height: int) -> int:
	if base_height <= 4 and spawn_hash % 200 == 12:
		return 1 # Harbor City
	return 0


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 5:
		return 223 # Tall Grass
	elif type_roll < 8:
		return 222 # Blue Orchid
	return 0


func get_wilderness_wildlife_ids() -> Array[int]:
	# Marine wildlife roster
	var ocean_wildlife_roster: Array[int] = [201, 208, 210, 11]
	return ocean_wildlife_roster


func get_spawn_probability() -> float:
	return 0.45


func get_max_group_size() -> int:
	return 6


func get_village_civilian_ids() -> Array[int]:
	var harbor_roster: Array[int] = [100, 101, 102]
	return harbor_roster


func get_village_population_density() -> int:
	return 6


func get_climate_weights() -> Dictionary:
	return {
		"sunny": 0.5,
		"rainy": 0.3,      
		"snowy": 0.0,
		"sandstorm": 0.0,
		"foggy": 0.2       
	}


func get_max_wind_strength() -> float:
	return 1.2


func get_fog_density_multiplier() -> float:
	return 1.15


func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return 5


func get_climate_profile() -> IClimateProfile:
	return IClimateProfile.new()
