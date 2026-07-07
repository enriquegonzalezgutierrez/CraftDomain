# ==============================================================================
# Project: CraftDomain
# Description: Concrete Biome Strategy implementing the geographic and visual 
#              rules for the tropical starter bay (Bay of Sails).
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Fully implements IBiome.
#              - Open-Closed Principle (OCP): Overrides wilderness wildlife to 
#                spawn aquatic Sea Turtles (201), Beach Crabs (208), 
#                deep-water Octopuses (210), and Great White Sharks (11) on shores.
# GEOGRAPHICAL SENSING (Phase 4):
#              - Implements `is_coordinate_inside()` to encapsulate its own 
#                spawning boundaries (restricted to a 130m circular spawn core).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BayOfSailsBiome.gd
# ==============================================================================
class_name BayOfSailsBiome
extends IBiome

## Concrete Implementation: Returns the unique identifier for the Bay of Sails (ID 0)
func get_biome_id() -> int:
	return 0


## Concrete Implementation: Returns the dynamic localized name of the biome
func get_biome_name() -> String:
	return tr("BIOME_BAY_OF_SAILS")


## Concrete Implementation: Returns the vibrant tropical blue color for the minimap
func get_minimap_color() -> Color:
	return Color(0.12, 0.55, 0.82)


## Concrete Implementation: Standard flat sandy bay topography calculations
func get_base_height(noise_value: float) -> int:
	return int(3.0 + (noise_value + 1.0) * 1.5)


## Concrete Implementation: Maps sand beaches on surface and solid stone core underground
func get_block_for_depth(y: int, base_height: int) -> BlockType.Type:
	if y < base_height - 2:
		return BlockType.Type.STONE
	return BlockType.Type.SAND


## Concrete Implementation: Evaluates sandy shores for harbor dock placements
func get_landmark_type(spawn_hash: int, base_height: int) -> int:
	if base_height <= 4 and spawn_hash % 200 == 12:
		return 1 
	return 0


## Concrete Override (OCP): Spawns Sea Turtles (201), Beach Crabs (208), deep-water Octopuses (210), and Great White Sharks (11).
func get_wilderness_wildlife_ids() -> Array[int]:
	var local_wildlife: Array[int] = [201, 208, 210, 11]
	return local_wildlife


# ==============================================================================
# GEOGRAPHICAL BOUNDARY SENSING (OCP Compliant)
# ==============================================================================

## Concrete Implementation: Returns true if within the 130-meter spawning core
func is_coordinate_inside(_pos_flat: Vector2, distance: float, _angle_rad: float) -> bool:
	return distance < 130.0
