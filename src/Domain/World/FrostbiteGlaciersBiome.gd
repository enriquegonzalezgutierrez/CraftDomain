# ==============================================================================
# Pathfile: res://src/Domain/World/FrostbiteGlaciersBiome.gd
# Description: Concrete Biome Strategy implementing geographical, geological,
#              meteorological, and scaled population parameters for the 
#              frozen polar Frostbite Glaciers.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FrostbiteGlaciersBiome
extends IBiome


func get_biome_id() -> int:
	return 4


func get_biome_name() -> String:
	return tr("BIOME_FROSTBITE_GLACIERS")


func get_minimap_color() -> Color:
	return Color(0.98, 0.98, 0.98)


func get_base_height(noise_value: float) -> int:
	return int(10.0 + (noise_value + 1.0) * 3.0)


func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	if y == base_height:
		return BlockType.Type.SNOW
	return BlockType.Type.ICE


func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 220 == 9:
		return 5 # Ice Temple
	return 0


func is_coordinate_inside(pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	var is_north_polar_cap: bool = pos_flat.y < -420.0 and abs(pos_flat.x) < 180.0
	var is_north_glacial_shelf: bool = angle_rad >= -1.963 and angle_rad < -1.178
	return is_north_polar_cap or is_north_glacial_shelf


# ==============================================================================
# SOLID OCP SCALED POPULATION CONFIGURATION (OCP Compliance)
# ==============================================================================

func get_spawn_probability() -> float:
	return 0.20 # Desolate, harsh environment, lower spawning rate


func get_max_group_size() -> int:
	return 3 # Smaller, scattered animal clusters


func get_wilderness_wildlife_ids() -> Array[int]:
	# Specialized polar fauna: Heavy-wool Sheep, Arctic Foxes, Snowy Birds, and Frozen Zombies
	var polar_wildlife_roster: Array[int] = [2, 10, 204, 205]
	return polar_wildlife_roster


func get_village_civilian_ids() -> Array[int]:
	# Winter survival outpost roster: Parka Villagers, Armored Guards, and Ice Miners!
	var winter_outpost_roster: Array[int] = [100, 102, 105]
	return winter_outpost_roster


func get_village_population_density() -> int:
	return 4 # Small, tight survival outpost


# ==============================================================================
# METEOROLOGICAL & CLIMATE CONFIGURATION
# ==============================================================================

func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.62, 0.88, 0.95),       # Frozen ice blue base
		"stone_light": Color(0.48, 0.75, 0.85),      # Frosted blue-ice shaft
		"wood_pole": Color(0.98, 0.98, 0.98),        # Cold snow-white post
		"iron_black": Color(0.12, 0.12, 0.15),       # Wrought iron cap
		"lantern_glow": Color(0.75, 0.85, 1.0),      # Silver-blue ice bulb emission
		"light_tint": Color(0.75, 0.85, 1.0)         # Cold silver-blue OmniLight3D color
	}


func requires_terrain_smoothing() -> bool:
	return false


func get_water_level() -> int:
	return -1


func get_climate_profile() -> IClimateProfile:
	return GlacialClimateProfile.new()
