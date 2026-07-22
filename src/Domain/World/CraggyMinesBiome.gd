# ==============================================================================
# Pathfile: res://src/Domain/World/CraggyMinesBiome.gd
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the Craggy Peaks & Caves.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly Craggy Mines parameters.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CraggyMinesBiome
extends IBiome


func get_biome_id() -> int:
	return 3


func get_biome_name() -> String:
	return tr("BIOME_CRAGGY_MINES")


func get_minimap_color() -> Color:
	return Color(0.48, 0.48, 0.48)


func get_base_height(noise_value: float) -> int:
	return int(6.0 + (noise_value + 1.0) * 8.0)


func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	return BlockType.Type.STONE


func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 180 == 13:
		return 16 
	return 0


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 4:
		return 223 # 3D Beach Grass
	elif type_roll < 7:
		var item_hash := (scatter_hash + 11) % 2
		return 226 if item_hash == 0 else 227 # 3D Allium or 3D Bluebell (NEW!)
	elif type_roll < 9:
		return 224 # 3D Dead Bush
	return 0       


func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [105, 102]
	return specialized_population


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 21, 12, 13]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= -2.748 and angle_rad < -1.963


func requires_terrain_smoothing() -> bool:
	return true 


func get_water_level() -> int:
	return -1
