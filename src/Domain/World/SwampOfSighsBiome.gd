# ==============================================================================
# Pathfile: res://src/Domain/World/SwampOfSighsBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              murky, humid Swamp of Sighs.
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


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 3:
		return 228 # 3D Swamp Fern
	elif type_roll < 5:
		return 229 # 3D Sugar Cane
	elif type_roll < 7:
		return 237 # 3D Glowing Bio-Mushroom (NEW!)
	elif type_roll < 9:
		return 239 # 3D Water Lily Pad (NEW!)
	return 222     # 3D Blue Orchid


func get_wilderness_wildlife_ids() -> Array[int]:
	var swamp_wildlife_roster: Array[int] = [0, 3, 11, 201, 208]
	return swamp_wildlife_roster


func get_village_civilian_ids() -> Array[int]:
	var swamp_outpost_roster: Array[int] = [100, 104, 105]
	return swamp_outpost_roster


func get_village_population_density() -> int:
	return 5


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


func get_water_level() -> int:
	return 4


func get_climate_profile() -> IClimateProfile:
	return SwampClimateProfile.new()
