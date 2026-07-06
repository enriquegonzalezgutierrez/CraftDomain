# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the high stone mountains and subterranean cave structures
#              (Craggy Peaks & Caves).
#              SOLID COMPLIANCE: 
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Open-Closed Principle (OCP): Overrides wilderness wildlife to 
#                spawn livestock, deep coal veins, nocturnal Gargoyles (12), 
#                and sneaky, rapid-trotting Goblins (13) in mountain caves.
#              - i18n Localization: Added `tr()` wrapper to the biome name 
#                to ensure dynamic translation parsing across the GPS HUD.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/CraggyMinesBiome.gd
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


## Concrete Implementation: Evaluates peaks for mine support pillars structures
func get_landmark_type(spawn_hash: int, _base_height: int) -> int:
	if spawn_hash % 160 == 7:
		return 4
	return 0


## Concrete Override: Spawns specialized Cave Miners (105) and Guards (102).
func get_outpost_population_ids() -> Array[int]:
	var specialized_population: Array[int] = [105, 102]
	return specialized_population


## Concrete Override (OCP): Spawns livestock [0, 1], Coal Ore (21), Gargoyles (12), and Goblins (13).
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [0, 1, 21, 12, 13]
	return local_wildlife
