# ==============================================================================
# Pathfile: res://src/Domain/World/NeonRuinsBiome.gd
# Description: Concrete Biome Strategy implementing rules for Neon Ruins.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Exclusively coordinates environmental
#   topography heights, wildlife tables, and block-depth layers.
# - Liskov Substitution Principle (LSP): Fully implements IBiome interface.
# - Open-Closed Principle (OCP): Integrated Type-safe Cyber Panel, Metal Grate,
#   and Warning Stripes enum members to permanently silence compiler warnings.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NeonRuinsBiome
extends IBiome


func get_biome_id() -> int:
	return 7


## Concrete Implementation: Returns the HUD localized friendly name of the biome
func get_biome_name() -> String:
	return tr("BIOME_NEON_RUINS")


## Concrete Implementation: Returns the deep charcoal slate color for the minimap
func get_minimap_color() -> Color:
	return Color(0.12, 0.12, 0.16)


## Concrete Implementation: Standard basin hills topography calculations
func get_base_height(noise_value: float) -> int:
	return int(8.0 + (noise_value + 1.0) * 2.0)


## Concrete Implementation: Maps roads, warning signs, grates, and subsurface conduits
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 3:
		return BlockType.Type.STONE
		
	if y == base_height:
		# Pavement surface detail decimation
		var surface_seed := base_height % 10
		if surface_seed == 1:
			return BlockType.Type.METAL_GRATE # INTEGRATED: Type-safe Metal Grate
		elif surface_seed == 2:
			return BlockType.Type.WARNING_STRIPES # INTEGRATED: Type-safe Warning Stripes
		return BlockType.Type.ROAD
		
	# Sub-pavement industrial conduits
	var depth_seed := (y + base_height) % 6
	if depth_seed == 0:
		return BlockType.Type.CYBER_PANEL # INTEGRATED: Type-safe Cyber Panel
		
	return BlockType.Type.COAL_ORE


func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	# Stepped Neon Pyramid is represented by ID 6
	if spawn_hash % 240 == 33:
		return 6
	return 0


## Override: Spawns magical Glowing Giant Fungi in the cyber basin
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 70 == 9:
		return 11 
	return 0


## Concrete Override: Spawns specialized Cyber Citizens (106) and Guards (102).
func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [106, 102]
	return specialized_population


## Concrete Override (OCP): Spawns livestock [0, 1, 2, 3] in the ruins.
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 2, 3]
	return local_wildlife


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the northeastern tech basin slice
func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= -1.178 and angle_rad < -0.392


# ==============================================================================
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant)
# ==============================================================================

## Concrete Override: Returns the custom Cyberpunk theme parameters for ruins streetlights
func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.12, 0.12, 0.15),       # Dark matte obsidian-steel base
		"stone_light": Color(0.08, 0.08, 0.1),       # Charcoal-black shaft
		"wood_pole": Color(0.0, 0.95, 0.95),         # Glowing cyan neon post
		"iron_black": Color(0.12, 0.12, 0.15),       # Wrought iron cap
		"lantern_glow": Color(0.95, 0.0, 0.95),      # Glowing magenta bulb emission
		"light_tint": Color(0.0, 0.95, 0.95)         # High-contrast cyan OmniLight3D color
	}


# ==============================================================================
# PROCEDURAL WORLD GENERATION RULES (OCP Compliant)
# ==============================================================================

func requires_terrain_smoothing() -> bool:
	return true # Cyber craters require heavy smoothing

func get_water_level() -> int:
	return -1 # No sea-level water in the technological basin
