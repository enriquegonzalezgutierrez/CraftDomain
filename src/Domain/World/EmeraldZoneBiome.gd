# ==============================================================================
# Pathfile: res://src/Domain/World/EmeraldZoneBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and wildlife scatter rules for the high-speed 
#              Emerald Zone (Biome ID 10).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EmeraldZoneBiome
extends IBiome


func get_biome_id() -> int:
	return 10


func get_biome_name() -> String:
	return tr("BIOME_EMERALD_ZONE")


func get_minimap_color() -> Color:
	return Color(0.12, 0.82, 0.35)


func get_base_height(noise_value: float) -> int:
	return int(8.0 + (noise_value + 1.0) * 2.0)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.ROAD # Checkered soil base


func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 4:
		return 251 # Sonic Palm Tree
	elif type_roll < 7:
		return 252 # Golden Ring Prop
	elif type_roll < 9:
		return 253 # Speed Spring Pad
	return 223     # Tall Grass


func get_wilderness_wildlife_ids() -> Array[int]:
	# Emerald Zone fauna: Speedy Blue Hedgehog (ID 214) and Badnik Crab (ID 14)
	var emerald_wildlife: Array[int] = [214, 14, 205]
	return emerald_wildlife


func get_spawn_probability() -> float:
	return 0.55


func get_max_group_size() -> int:
	return 5


func requires_terrain_smoothing() -> bool:
	return false


func get_water_level() -> int:
	return -1


func get_climate_profile() -> IClimateProfile:
	return TemperateClimateProfile.new()
