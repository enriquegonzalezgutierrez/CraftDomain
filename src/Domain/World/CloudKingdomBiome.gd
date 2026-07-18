# ==============================================================================
# Pathfile: res://src/Domain/World/CloudKingdomBiome.gd
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the celestial floating clouds region (Cloud Kingdom).
#              WEATHER UPGRADE: Configured high-altitude jet stream wind limits,
#              eternal clear sun weights, and minimal stratospheric fog.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
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
	var local_wildlife: Array[int] = [205, 207]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, _distance: float, _angle_rad: float) -> bool:
	return false


func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return -1


# ==============================================================================
# CLIMATOLOGICAL OVERRIDES (OCP / SOLID Compliance)
# ==============================================================================

func get_climate_weights() -> Dictionary:
	return {
		"sunny": 1.0,      # Floating above the storm deck, the sky is eternally clear
		"rainy": 0.0,
		"snowy": 0.0,
		"sandstorm": 0.0,
		"foggy": 0.0
	}


func get_max_wind_strength() -> float:
	return 1.6 # Mighty stratospheric jet stream wind speeds


func get_fog_density_multiplier() -> float:
	return 0.15 # Thin, dry, and crystal-clear air at high altitudes
