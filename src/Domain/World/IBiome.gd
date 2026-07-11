# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Interface defining the strategic contract for any
#              procedural biome. Decouples physical, visual, and landmark
#              rules into independent, extensible classes.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Isolates biome specifications.
# - Liskov Substitution Principle (LSP): Sub-classes fully satisfy 
#   the contract, implementing custom outpost populations and wildlife.
# - Open-Closed Principle (OCP): Outpost and wilderness spawns are now 
#   completely data-driven, removing hardcoded mappings from spawner services.
# GEOGRAPHICAL BOUNDARY SENSING UPGRADE:
# - Added `is_coordinate_inside()` virtual contract. Each concrete biome 
#   subclass now determines its own physical boundary mathematics, allowing 
#   `BiomeService.gd` to remain closed to modifications during world expansions.
# STREETLIGHT PORTABLE THEME UPGRADE (Phase 4):
# - Added `get_streetlight_theme()` virtual contract returning a default 
#   rustic-plains lighting color palette. Concrete biomes can override this 
#   to customize surrounding block lamp assemblies polymorphically.
# PROCEDURAL GENERATOR OVERHAUL (Phase 5):
# - Added `requires_terrain_smoothing()` and `get_water_level()` to completely
#   decouple the WorldGenerator from hardcoded biome IDs, strictly enforcing OCP.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IBiome.gd
# ==============================================================================
class_name IBiome
extends RefCounted

## Abstract contract: Returns the unique integer identifier representing this biome.
func get_biome_id() -> int:
	assert(false, "[IBiome] get_biome_id() must be implemented by concrete subclass.")
	return 0

## Abstract contract: Returns the dynamically localized name of the biome.
func get_biome_name() -> String:
	assert(false, "[IBiome] get_biome_name() must be implemented by concrete subclass.")
	return ""

## Abstract contract: Returns the color representation to render on the circular Minimap.
func get_minimap_color() -> Color:
	assert(false, "[IBiome] get_minimap_color() must be implemented by concrete subclass.")
	return Color.BLACK

## Abstract contract: Calculates the maximum solid ground height for this coordinate column.
func get_base_height(_noise_value: float) -> int:
	assert(false, "[IBiome] get_base_height() must be implemented by concrete subclass.")
	return 0

## Abstract contract: Evaluates and returns the appropriate block type for a given vertical depth.
func get_block_for_depth(_y: int, _base_height: int) -> BlockType.Type:
	assert(false, "[IBiome] get_block_for_depth() must be implemented by concrete subclass.")
	return BlockType.Type.AIR

## Abstract contract: Evaluates deterministically if a landmark spawns on this coordinate column.
func get_landmark_type(_spawn_hash: int, _base_height: int) -> int:
	assert(false, "[IBiome] get_landmark_type() must be implemented by concrete subclass.")
	return 0

## Virtual Contract: Returns a random structure blueprint ID to spawn based on hash, or 0 if none.
func get_scatter_blueprint_id(_scatter_hash: int) -> int:
	return 0

## Virtual Contract: Returns the list of specialized Mob/NPC IDs that populate outposts in this biome.
func get_outpost_population_ids() -> Array[int]:
	var default_population: Array[int] = [103, 102]
	return default_population

## Virtual Contract (OCP): Returns the list of wildlife Mob IDs that spawn organically 
## in the wilderness of this biome. Defaults to common farm animals [0, 1, 2, 3].
func get_wilderness_wildlife_ids() -> Array[int]:
	var default_wildlife: Array[int] = [0, 1, 2, 3]
	return default_wildlife

# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING CONTRACT (OCP Compliant)
# ==============================================================================

## Virtual Contract: Returns true if the given 2D global coordinate, length, and 
## polar angle belongs to this biome's territory boundary.
func is_coordinate_inside(_pos_2d: Vector2, _distance: float, _angle_rad: float) -> bool:
	return false

# ==============================================================================
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant)
# ==============================================================================

## Virtual Contract: Returns the custom 3D model styling parameters for streetlights 
## built in this biome. Defaults to a rustic-medieval theme (chiseled stone and warm wood).
func get_streetlight_theme() -> Dictionary:
	return {
		"stone_dark": Color(0.38, 0.40, 0.42),      # Heavy chiseled base stone
		"stone_light": Color(0.55, 0.58, 0.60),     # Cobblestone wall shaft
		"wood_pole": Color(0.45, 0.30, 0.15),       # Wood post
		"iron_black": Color(0.12, 0.12, 0.15),      # Wrought iron cap
		"lantern_glow": Color(1.0, 0.72, 0.2),      # Bulb emission
		"light_tint": Color(1.0, 0.72, 0.3)         # OmniLight3D color
	}

# ==============================================================================
# PROCEDURAL WORLD GENERATION RULES (OCP Compliant)
# ==============================================================================

## Virtual Contract: Returns true if this biome contains jagged or stepped 
## noise generation that requires 3x3 box-blur smoothing across chunk boundaries.
## By default, flat plains and flat oceans do not require smoothing.
func requires_terrain_smoothing() -> bool:
	return false

## Virtual Contract: Returns the Y altitude level where water naturally settles in this biome.
## Returns -1 if this biome does not generate natural sea-level water bodies.
func get_water_level() -> int:
	return -1
