# ==============================================================================
# Pathfile: res://src/Domain/World/RedBadlandsBiome.gd
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the Red Terracotta Canyons.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 12 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RedBadlandsBiome
extends IBiome


func get_biome_id() -> int:
	return 6


func get_biome_name() -> String:
	return tr("BIOME_RED_BADLANDS")


func get_minimap_color() -> Color:
	return Color(0.85, 0.38, 0.22)


func get_base_height(noise_value: float) -> int:
	var raw_b := 4.0 + (noise_value + 1.0) * 8.0
	return int(round(raw_b / 3.0) * 3.0) 


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.RED_SAND


func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 50 == 4:
		return 14 
	return 0


## Concrete Override (OCP): Dynamically returns desert vegetation prop IDs
func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 7:
		return 224 # Dead Bush Prop (.tscn)
	return 225     # Cactus Prop (.tscn)


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 3, 209]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 1.963 and angle_rad < 2.748


func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.55, 0.32, 0.22),        
		"stone_light": Color(0.75, 0.48, 0.35),       
		"wood_pole": Color(0.28, 0.18, 0.12),         
		"iron_black": Color(0.12, 0.12, 0.15),        
		"lantern_glow": Color(1.0, 0.55, 0.0),         
		"light_tint": Color(1.0, 0.55, 0.0)           
	}


func requires_terrain_smoothing() -> bool:
	return true 


func get_water_level() -> int:
	return -1
