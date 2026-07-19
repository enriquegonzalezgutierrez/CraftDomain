# ==============================================================================
# Pathfile: res://src/Domain/World/RedBadlandsBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              arid Red Badlands sandstone canyons.
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
		return 14 # Dead Shrub
	return 0


func get_wilderness_prop_id(scatter_hash: int) -> int:
	var type_roll: int = scatter_hash % 10
	if type_roll < 7:
		return 224 # Dead Bush
	return 225     # Cactus


# ==============================================================================
# SOLID OCP SCALED POPULATION CONFIGURATION (OCP Compliance)
# ==============================================================================

func get_spawn_probability() -> float:
	return 0.30 # Arid sandstone environment, balanced spawning rate


func get_max_group_size() -> int:
	return 4 # Moderate animal herd sizes


func get_wilderness_wildlife_ids() -> Array[int]:
	# Specialized desert fauna: Wild Pigs, Clay Cattle, Colossal Elephants, and Fiery Growlithes!
	var desert_wildlife_roster: Array[int] = [0, 3, 209, 212]
	return desert_wildlife_roster


func get_village_civilian_ids() -> Array[int]:
	# Sun-baked desert bazaar roster: Rugged Villagers, Spice Merchants, and Shield Guards!
	var desert_bazaar_roster: Array[int] = [100, 101, 102]
	return desert_bazaar_roster


func get_village_population_density() -> int:
	return 5 # Busy desert bazaar outpost


# ==============================================================================
# METEOROLOGICAL & CLIMATE CONFIGURATION
# ==============================================================================

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


func get_climate_profile() -> IClimateProfile:
	return DesertClimateProfile.new()
