# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Interface defining the strategic contract for any
#              procedural biome. Decouples physical, visual, and landmark
#              rules into independent, extensible classes.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates biome specifications.
#              - Liskov Substitution Principle (LSP): Sub-classes fully satisfy 
#                the contract, implementing custom outpost populations.
#              - Open-Closed Principle (OCP): Outpost spawns are now data-driven,
#                removing hardcoded mappings from spawner services.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IBiome.gd
# ==============================================================================
class_name IBiome
extends RefCounted

## Abstract contract: Returns the unique integer identifier representing this biome.
func get_biome_id() -> int:
	assert(false, "[IBiome] get_biome_id() must be implemented by concrete subclass.")
	return 0

## Abstract contract: Returns the dynamically localized name of the biome (OCP compliant).
## Subclasses must implement this using Godot's built-in tr() TranslationServer.
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
## Overridden by subclasses to distribute trees/mushrooms organically without editing the core generator.
func get_scatter_blueprint_id(_scatter_hash: int) -> int:
	return 0


## Virtual Contract: Returns the list of specialized Mob/NPC IDs that populate outposts in this biome.
## Defaults to standard Farmer (103) and Guard (102). Specialized biomes will override this.
func get_outpost_population_ids() -> Array[int]:
	var default_population: Array[int] = [103, 102]
	return default_population
