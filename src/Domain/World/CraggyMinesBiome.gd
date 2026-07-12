# ==============================================================================
# Pathfile: res://src/Domain/World/CraggyMinesBiome.gd
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the high stone mountains and subterranean cave structures
#              (Craggy Peaks & Caves).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CraggyMinesBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Craggy Mines (ID 3)
func get_biome_id() -> int:
	return 3


## Concrete Implementation: Returns the HUD friendly name using dynamic i18n lookup
func get_biome_name() -> String:
	return tr("BIOME_CRAGGY_MINES")


## Concrete Implementation: Returns the dark grey peaks color for the minimap
func get_minimap_color() -> Color:
	return Color(0.48, 0.48, 0.48)


## Concrete Implementation: Jagged and vertical mountain peaks topography calculations
func get_base_height(noise_value: float) -> int:
	return int(6.0 + (noise_value + 1.0) * 8.0)


## Concrete Implementation: Maps dark stone blocks for both surface and deep core
func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	return BlockType.Type.STONE


## Concrete Implementation: All roadside/village lighting is now delegated to 
## the superior dual-lantern StreetlightEntity, making block pillars obsolete.
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


## Concrete Override: Organically scatters active Geothermal Magma Vents (ID 16)
## across peaks as rare, spectacular landmarks.
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 180 == 13:
		return 16 # Steaming Geothermal Magma Vent (Case C)
	return 0


## Concrete Override: Spawns specialized Cave Miners (105) and Guards (102).
func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [105, 102]
	return specialized_population


## Concrete Override (OCP): Spawns livestock [0, 1], Coal Ore (21), Gargoyles (12), and Goblins (13).
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 21, 12, 13]
	return local_wildlife


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the northwestern mountain slice
func is_coordinate_inside(_pos_flat: Vector2, _distance: float, angle_rad: float) -> bool:
	return angle_rad >= -2.748 and angle_rad < -1.963


# ==============================================================================
# PROCEDURAL WORLD GENERATION RULES (OCP Compliant)
# ==============================================================================

func requires_terrain_smoothing() -> bool:
	return true # Extreme elevation noise requires Box-Blur smoothing!

func get_water_level() -> int:
	return -1 # No sea-level water in high peaks
