# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic)
# Description: Pure Domain Strategy Interface defining the structural contract 
#              for underground procedural ore veins and mineral geode generators.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Defines exclusively the 
#                contract for crawling/growing underground minerals.
#              - Open-Closed Principle (OCP): Allows infinite new mineral patterns 
#                (e.g., Coal Veins, Diamond Geodes, Iron Seams) to be registered 
#                without modifying the chunk generation flow.
#              - Liskov Substitution Principle (LSP): Subclasses must implement 
#                all methods, allowing them to be processed polymorphically.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IOreVeinBlueprint.gd
# ==============================================================================
class_name IOreVeinBlueprint
extends RefCounted

## Abstract contract: Returns the unique integer identifier for this mineral vein blueprint.
func get_vein_id() -> int:
	assert(false, "[IOreVeinBlueprint] get_vein_id() must be implemented by concrete subclass.")
	return 0


## Abstract contract: Returns the target block type representing the ore (e.g., COAL_ORE, DIAMOND_ORE).
func get_ore_block_type() -> BlockType.Type:
	assert(false, "[IOreVeinBlueprint] get_ore_block_type() must be implemented by concrete subclass.")
	return BlockType.Type.AIR


## Abstract contract: Spawns and grows the procedural mineral formation inside the target Chunk.
## Coordinates are local to the chunk [0..15].
## Under DDD principles, this method executes the generation mathematics deterministically.
func grow_vein(chunk: Chunk, start_x: int, start_y: int, start_z: int, seed_hash: int) -> void:
	# Avoid unused parameter warnings in the abstract interface base class
	var _c := chunk
	var _sx := start_x
	var _sy := start_y
	var _sz := start_z
	var _sh := seed_hash
	assert(false, "[IOreVeinBlueprint] grow_vein() must be implemented by concrete subclass.")
