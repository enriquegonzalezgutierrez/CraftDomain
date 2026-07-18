# ==============================================================================
# Pathfile: res://src/Domain/World/BayOfSailsBiome.gd
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the tropical starter bay (Bay of Sails).
#              SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 12 lines.
#              WEATHER UPGRADE: Configured maritime coastal climate weights,
#              steady sea breeze wind limits, and humid ocean fog.
#              SYNTAX FIX: Replaced C++ comment slashes with GDScript '#' hashes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name BayOfSailsBiome
extends IBiome


func get_biome_id() -> int:
	return 0


func get_biome_name() -> String:
	return tr("BIOME_BAY_OF_SAILS")


func get_minimap_color() -> Color:
	return Color(0.08, 0.45, 0.72)


func get_base_height(noise_value: float) -> int:
	return int(3.0 + (noise_value + 1.0) * 1.5)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.SAND


func get_landmark_type(spawn_hash: int, base_height: int) -> int:
	if base_height <= 4 and spawn_hash % 200 == 12:
		return 1 
	return 0


## Concrete Override (OCP): Dynamically returns tropical shore vegetation prop IDs
func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 5:
		return 223 # Tall Grass Prop (.tscn)
	elif type_roll < 8:
		return 222 # Blue Orchid Prop (.tscn)
	return 0       # Bare sand beaches


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [201, 208, 210, 11]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, distance: float, _angle_rad: float) -> bool:
	return distance < 130.0


func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return 5


# ==============================================================================
# CLIMATOLOGICAL OVERRIDES (OCP / SOLID Compliance)
# ==============================================================================

func get_climate_weights() -> Dictionary:
	return {
		"sunny": 0.5,
		"rainy": 0.3,      # High probability of tropical ocean showers (Fixed comment syntax)
		"snowy": 0.0,
		"sandstorm": 0.0,
		"foggy": 0.2       # Coastal morning sea mists (Fixed comment syntax)
	}


func get_max_wind_strength() -> float:
	return 1.2 # Constant dynamic maritime sea breeze


func get_fog_density_multiplier() -> float:
	return 1.15 # Humid ocean horizon overlay
