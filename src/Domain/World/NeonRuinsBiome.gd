# ==============================================================================
# Pathfile: res://src/Domain/World/NeonRuinsBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              post-apocalyptic tech-noir Neon Ruins.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly Neon Ruins parameters.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NeonRuinsBiome
extends IBiome


func get_biome_id() -> int:
	return 7


func get_biome_name() -> String:
	return tr("BIOME_NEON_RUINS")


func get_minimap_color() -> Color:
	return Color(0.12, 0.12, 0.16)


func get_base_height(noise_value: float) -> int:
	return int(8.0 + (noise_value + 1.0) * 2.0)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 3:
		return BlockType.Type.STONE
		
	if y == base_height:
		var surface_seed := base_height % 10
		if surface_seed == 1:
			return BlockType.Type.METAL_GRATE
		elif surface_seed == 2:
			return BlockType.Type.WARNING_STRIPES
		return BlockType.Type.ROAD
		
	var depth_seed := (y + base_height) % 6
	if depth_seed == 0:
		return BlockType.Type.CYBER_PANEL
		
	return BlockType.Type.COAL_ORE


func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 240 == 33:
		return 6 
	return 0


func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 70 == 9:
		return 11 
	return 0


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 4:
		return 237 # 3D Glowing Bio-Mushroom (NEW!)
	elif type_roll < 7:
		return 224 # 3D Dead Bush
	elif type_roll < 9:
		return 225 # 3D Cactus
	return 0       


func get_spawn_probability() -> float:
	return 0.35


func get_max_group_size() -> int:
	return 4


func get_wilderness_wildlife_ids() -> Array[int]:
	var ruins_wildlife_roster: Array[int] = [10, 12, 13, 206, 211]
	return ruins_wildlife_roster


func get_village_civilian_ids() -> Array[int]:
	var cyber_city_roster: Array[int] = [102, 105, 106]
	return cyber_city_roster


func get_village_population_density() -> int:
	return 6


func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.12, 0.12, 0.15),       
		"stone_light": Color(0.08, 0.08, 0.1),       
		"wood_pole": Color(0.0, 0.95, 0.95),         
		"iron_black": Color(0.12, 0.12, 0.15),       
		"lantern_glow": Color(0.95, 0.0, 0.95),      
		"light_tint": Color(0.0, 0.95, 0.95)         
	}


func requires_terrain_smoothing() -> bool:
	return true 


func get_water_level() -> int:
	return -1


func get_climate_profile() -> IClimateProfile:
	return DesertClimateProfile.new()
