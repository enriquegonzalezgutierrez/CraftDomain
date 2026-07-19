# ==============================================================================
# Pathfile: res://src/Domain/World/NeonRuinsBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              post-apocalyptic tech-noir Neon Ruins.
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
		return 6 # Neon Pyramid
	return 0


func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 70 == 9:
		return 11 # Underworld Fungus
	return 0


# ==============================================================================
# SOLID OCP SCALED POPULATION CONFIGURATION (OCP Compliance)
# ==============================================================================

func get_spawn_probability() -> float:
	return 0.35 # Decaying urban environment, moderate-high spawn rate


func get_max_group_size() -> int:
	return 4 # Small tactical squads of scavengers and droids


func get_wilderness_wildlife_ids() -> Array[int]:
	# A mix of tech-husks, nocturnal statues, and urban scavengers
	var ruins_wildlife_roster: Array[int] = [10, 12, 13, 206, 211]
	return ruins_wildlife_roster


func get_village_civilian_ids() -> Array[int]:
	# High-tech city roster: Cyber Citizens, Security Bots, and Scrap Miners
	var cyber_city_roster: Array[int] = [102, 105, 106]
	return cyber_city_roster


func get_village_population_density() -> int:
	return 6 # Moderate active city feel


# ==============================================================================
# METEOROLOGICAL & CLIMATE CONFIGURATION
# ==============================================================================

func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.12, 0.12, 0.15),       # Dark matte obsidian-steel base
		"stone_light": Color(0.08, 0.08, 0.1),       # Charcoal-black shaft
		"wood_pole": Color(0.0, 0.95, 0.95),         # Glowing cyan neon post
		"iron_black": Color(0.12, 0.12, 0.15),       # Wrought iron cap
		"lantern_glow": Color(0.95, 0.0, 0.95),      # Glowing magenta bulb emission
		"light_tint": Color(0.0, 0.95, 0.95)         # High-contrast cyan OmniLight3D color
	}


func requires_terrain_smoothing() -> bool:
	return true 


func get_water_level() -> int:
	return -1


func get_climate_profile() -> IClimateProfile:
	return DesertClimateProfile.new()
