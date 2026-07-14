# ==============================================================================
# Pathfile: res://src/Domain/World/IBiome.gd
# Description: Pure Domain Interface defining the strategic contract for any
#              procedural biome. Decouples physical, visual, and landmark
#              rules into independent, extensible classes.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 12 lines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name IBiome
extends RefCounted


func get_biome_id() -> int:
	assert(false, "[IBiome] get_biome_id() must be implemented by concrete subclass.")
	return 0


func get_biome_name() -> String:
	assert(false, "[IBiome] get_biome_name() must be implemented by concrete subclass.")
	return ""


func get_minimap_color() -> Color:
	assert(false, "[IBiome] get_minimap_color() must be implemented by concrete subclass.")
	return Color.BLACK


func get_base_height(_noise_value: float) -> int:
	assert(false, "[IBiome] get_base_height() must be implemented by concrete subclass.")
	return 0


func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	assert(false, "[IBiome] get_block_for_depth() must be implemented by concrete subclass.")
	return BlockType.Type.AIR


func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	assert(false, "[IBiome] get_landmark_type() must be implemented by concrete subclass.")
	return 0


func get_scatter_blueprint_id(_scatter_hash: int) -> int:
	return 0


## Virtual Contract (OCP): Returns the custom 3D scenery prop ID (e.g. vegetation)
## deterministically for the given coordinates hash. Defaults to 0 (no prop).
func get_wilderness_prop_id(_scatter_hash: int) -> int:
	return 0


func get_outpost_population_ids() -> Array[int]:
	var default_population: Array[int] = [103, 102]
	return default_population


func get_wilderness_wildlife_ids() -> Array[int]:
	var default_wildlife: Array[int] = [0, 1, 2, 3]
	return default_wildlife


func is_coordinate_inside(_pos_2d: Vector2, _distance: float, _angle_rad: float) -> bool:
	return false


func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.38, 0.40, 0.42),      
		"stone_light": Color(0.55, 0.58, 0.60),     
		"wood_pole": Color(0.45, 0.30, 0.15),       
		"iron_black": Color(0.12, 0.12, 0.15),      
		"lantern_glow": Color(1.0, 0.72, 0.2),      
		"light_tint": Color(1.0, 0.72, 0.3)         
	}


func requires_terrain_smoothing() -> bool:
	return false


func get_water_level() -> int:
	return -1
