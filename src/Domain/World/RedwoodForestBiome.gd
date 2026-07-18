# ==============================================================================
# Pathfile: res://src/Domain/World/RedwoodForestBiome.gd
# Description: Concrete Biome Strategy implementing rules for Whispering Redwood Forest.
#              WEATHER UPGRADE: Configured damp canopy climate weights, shielded wind
#              limits, and moderately heavy forest fog density multipliers.
#              SYNTAX FIX: Replaced C++ comment slashes with GDScript '#' hashes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
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
		return 15 
	elif scatter_hash % 60 == 5:
		return 1  
	elif scatter_hash % 120 == 12:
		return 2  
	return 0


## Concrete Override (OCP): Dynamically returns forest vegetation prop IDs
func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 7:
		return 223   # Tall Grass/Helechos Prop (.tscn)
	elif type_roll < 9:
		return 222   # Blue Orchid Prop (.tscn)
	return 221       # Poppy Prop (.tscn)


func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [104, 102]
	return specialized_population


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [204, 205, 211, 213]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 0.392 and angle_rad < 1.178


func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return -1


# ==============================================================================
# CLIMATOLOGICAL OVERRIDES (OCP / SOLID Compliance)
# ==============================================================================

func get_climate_weights() -> Dictionary:
	return {
		"sunny": 0.4,
		"rainy": 0.3,      # Forest drizzles are common (Fixed comment syntax)
		"snowy": 0.0,
		"sandstorm": 0.0,
		"foggy": 0.3       # Ground mist often creeps between giant redwoods (Fixed syntax)
	}


func get_max_wind_strength() -> float:
	return 0.75 # Shielded by massive canopies, forest floors remain calm


func get_fog_density_multiplier() -> float:
	return 1.45 # Damp forest environment mist
