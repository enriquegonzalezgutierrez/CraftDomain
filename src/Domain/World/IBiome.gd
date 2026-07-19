# ==============================================================================
# Pathfile: res://src/Domain/World/IBiome.gd
# Description: Pure Domain Abstract Strategy Interface defining the physical,
#              geographical, meteorological, and population density contracts
#              for any procedural biome.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IBiome
extends RefCounted


## Returns the unique identifier of the biome.
func get_biome_id() -> int:
	assert(false, "[IBiome] get_biome_id() must be implemented by concrete subclass.")
	return 0


## Returns the HUD localized friendly name of the biome.
func get_biome_name() -> String:
	assert(false, "[IBiome] get_biome_name() must be implemented by concrete subclass.")
	return ""


## Returns the color representation for the minimap radar.
func get_minimap_color() -> Color:
	assert(false, "[IBiome] get_minimap_color() must be implemented by concrete subclass.")
	return Color.BLACK


## Calculates the baseline terrain height based on 2D noise.
func get_base_height(_noise_value: float) -> int:
	assert(false, "[IBiome] get_base_height() must be implemented by concrete subclass.")
	return 0


## Determines which solid block to place at the specific Y altitude.
func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	assert(false, "[IBiome] get_block_for_depth() must be implemented by concrete subclass.")
	return BlockType.Type.AIR


## Returns a landmark structure ID (such as pyramids or cabins) if applicable.
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	assert(false, "[IBiome] get_landmark_type() must be implemented by concrete subclass.")
	return 0


## Returns an organic scattered structure ID (such as trees or giant mushrooms).
func get_scatter_blueprint_id(_scatter_hash: int) -> int:
	return 0


## Returns a custom 3D scenery prop ID (such as wild flowers, grass, or cacti).
func get_wilderness_prop_id(_scatter_hash: int) -> int:
	return 0


## Returns a list of mobile entity IDs allowed to spawn as active wilderness wildlife.
func get_wilderness_wildlife_ids() -> Array[int]:
	var default_wildlife: Array[int] = [0, 1, 2, 3] # Pig, Chicken, Sheep, Cow
	return default_wildlife


# ==============================================================================
# SOLID OCP POPULATION DENSITY CONTROLS (DIP Compliance)
# ==============================================================================
## Returns the spawn probability [0.0 - 1.0] of spawning wildlife in this biome.
func get_spawn_probability() -> float:
	return 0.28 # Default baseline spawning rate


## Returns the maximum size of a single wilderness wildlife herd group.
func get_max_group_size() -> int:
	return 4 # Default baseline herd size


## Returns a list of available civilian role IDs for village chunks in this biome.
func get_village_civilian_ids() -> Array[int]:
	# Default: Common Villager, Guard, Farmer, Miner
	var default_village_roster: Array[int] = [100, 102, 103, 105]
	return default_village_roster


## Returns the total number of active civilians to spawn in a village chunk.
func get_village_population_density() -> int:
	return 3 # Default baseline village density


# ==============================================================================
# METEOROLOGICAL & CLIMATE SYSTEMS
# ==============================================================================
## Returns the default Streetlight theme colors for paved roads in this biome.
func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.38, 0.40, 0.42),      
		"stone_light": Color(0.55, 0.58, 0.60),     
		"wood_pole": Color(0.45, 0.30, 0.15),       
		"iron_black": Color(0.12, 0.12, 0.15),      
		"lantern_glow": Color(1.0, 0.72, 0.2),      
		"light_tint": Color(1.0, 0.72, 0.3)         
	}


## Returns true if the generator needs to apply a low-pass filter to smooth coordinates.
func requires_terrain_smoothing() -> bool:
	return false


## Returns the global sea level coordinate, or -1 if no water blocks should generate.
func get_water_level() -> int:
	return -1


## Returns the decoupled climatological profile associated with this biome.
func get_climate_profile() -> IClimateProfile:
	return IClimateProfile.new()
