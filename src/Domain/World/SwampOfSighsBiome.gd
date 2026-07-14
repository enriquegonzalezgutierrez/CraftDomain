# ==============================================================================
# Pathfile: res://src/Domain/World/SwampOfSighsBiome.gd
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the murky swamp region (Swamp of Sighs).
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SwampOfSighsBiome
extends IBiome


func get_biome_id() -> int:
	return 8


func get_biome_name() -> String:
	return tr("BIOME_SWAMP_OF_SIGHS")


func get_minimap_color() -> Color:
	return Color(0.28, 0.22, 0.15)


func get_base_height(noise_value: float) -> int:
	return int(2.0 + (noise_value + 1.0) * 1.0)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.MUD


func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


## Concrete Override (OCP): Dynamically returns swamp vegetation prop IDs
func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 4:
		return 228 # Swamp Fern Prop (.tscn)
	elif type_roll < 7:
		return 229 # Sugar Cane Prop (.tscn)
	elif type_roll < 9:
		return 222 # Blue Orchid Prop (.tscn)
	return 224     # Dead Bush Prop (.tscn)


func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 3, 201]
	return local_wildlife


func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= 2.748 or angle_rad < -2.748


func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.22, 0.18, 0.12),       
		"stone_light": Color(0.18, 0.28, 0.15),      
		"wood_pole": Color(0.15, 0.45, 0.12),        
		"iron_black": Color(0.12, 0.12, 0.15),       
		"lantern_glow": Color(0.42, 0.85, 0.25),      
		"light_tint": Color(0.42, 0.85, 0.25)         
	}


func requires_terrain_smoothing() -> bool:
	return false 


func decline_gargoyle_flight() -> bool:
	return true 


func get_water_level() -> int:
	return 4
