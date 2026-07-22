# ==============================================================================
# Pathfile: res://src/Domain/World/WarpPlateauBiome.gd
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              meteorological, and vegetation scatter rules for the Warp Plateau.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly Warp Plateau parameters.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WarpPlateauBiome
extends IBiome


func get_biome_id() -> int:
	return 1


func get_biome_name() -> String:
	return tr("BIOME_WARP_PLATEAU")


func get_minimap_color() -> Color:
	return Color(0.38, 0.85, 0.28)


func get_base_height(noise_value: float) -> int:
	var raw_h := 8.0 + (noise_value + 1.0) * 12.0
	return int(round(raw_h / 4.0) * 4.0)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT


func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 150 == 42:
		return 2
	return 0


func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 90 == 8:
		return 3 
	return 0


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 3:
		return 223 # 3D Beach Grass
	elif type_roll < 5:
		return 220 # 3D Dandelion
	elif type_roll < 7:
		return 221 # 3D Poppy
	elif type_roll < 9:
		return 238 # 3D Sakura Blossom Shrub (NEW!)
	return 233     # 3D Tulip White


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 3, 212]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 1.178 and angle_rad < 1.963


func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return -1
