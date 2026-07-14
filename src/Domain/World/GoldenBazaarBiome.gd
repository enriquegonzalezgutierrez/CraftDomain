# ==============================================================================
# Pathfile: res://src/Domain/World/GoldenBazaarBiome.gd
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the Golden Bazaar plains.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 12 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GoldenBazaarBiome
extends IBiome


func get_biome_id() -> int:
	return 2


func get_biome_name() -> String:
	return tr("BIOME_GOLDEN_BAZAAR")


func get_minimap_color() -> Color:
	return Color(0.92, 0.85, 0.35)


func get_base_height(noise_value: float) -> int:
	return int(5.0 + (noise_value + 1.0) * 1.0)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.GRASS
	return BlockType.Type.DIRT


func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 180 == 15:
		return 3
	return 0


func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 45 == 3:
		return 12 
	elif scatter_hash % 70 == 5:
		return 1 
	elif scatter_hash % 90 == 8:
		return 13 
	elif scatter_hash % 150 == 12:
		return 10 
	return 0


## Concrete Override (OCP): Dynamically returns wilderness vegetation prop IDs
func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 6:
		return 223   # Tall Grass Prop (.tscn)
	elif type_roll < 8:
		return 220 # Dandelion Prop (.tscn)
	elif type_roll < 9:
		return 221 # Poppy Prop (.tscn)
	return 222     # Blue Orchid Prop (.tscn)


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 2, 3, 206, 211]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= -0.392 and angle_rad < 0.392


func requires_terrain_smoothing() -> bool:
	return false 


func get_water_level() -> int:
	return -1
