# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographical, block-depth,
#              and vegetation scatter rules for the Red Terracotta Canyons.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Single Responsibility Principle (SRP): Only manages desert canyons 
#                topography, sandstone blocks, and local plant scattering rules.
#              LANDSCAPE OVERHAUL:
#              - Integrated organic scattering selectors for Dead Shrubs (ID 14).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RedBadlandsBiome.gd
# ==============================================================================
class_name RedBadlandsBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Red Badlands (ID 6)
func get_biome_id() -> int:
	return 6


## Concrete Implementation: Returns the HUD friendly name.
func get_biome_name() -> String:
	return tr("BIOME_RED_BADLANDS")


## Concrete Implementation: Returns the burnt terracotta orange color for the minimap.
func get_minimap_color() -> Color:
	return Color(0.85, 0.38, 0.22)


## Concrete Implementation: Terraced badlands canyons using step-function mathematics.
func get_base_height(noise_value: float) -> int:
	var raw_b := 4.0 + (noise_value + 1.0) * 8.0
	return int(round(raw_b / 3.0) * 3.0) # Snap heights to 3-block steps


## Concrete Implementation: Maps layers of red sand and stone cores underground.
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.RED_SAND


## Concrete Implementation: Natural desert canyons with no structural landmarks.
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	return 0


## Concrete Override: Organically scatters dry, twisted Dead Shrubs (ID 14) across the sand steps.
func get_scatter_blueprint_id(scatter_hash: int) -> int:
	if scatter_hash % 50 == 4:
		return 14 # Dead Shrub (ID 14)
	return 0
