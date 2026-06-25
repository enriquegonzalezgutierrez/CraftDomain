# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              villager, merchant, and animal entities dynamically inside chunks.
#              Optimized to scan chunk columns and spawn entities directly on the
#              ground surface, eliminating falling physics stress and visual glitches.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted

## Dynamically loaded Entity Script to prevent compile-time cache bugs
var _entity_script: Script = load("res://src/Infrastructure/Life/PassiveEntity.gd")

## Calculates and spawns passive entities for a given chunk, returning the active list.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node) -> Array[CharacterBody3D]:
	var entities_list: Array[CharacterBody3D] = []
	
	if _entity_script == null:
		return entities_list
		
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	
	# 1. Spawn a Villager and a Merchant if the chunk generated a rustic cabin
	var has_house: bool = (abs(chunk_pos.x) + abs(chunk_pos.z)) % 3 == 2 and chunk_pos.y == 0
	if has_house:
		# Scan local column coordinates (X:7, Z:5) to find the exact grass surface height
		var villager_y := _get_ground_surface_y(chunk, 7, 5)
		var villager_pos := chunk_offset + Vector3(7.5, villager_y, 5.5)
		
		var villager = _entity_script.new(2, villager_pos) as CharacterBody3D
		world_node.add_child(villager)
		entities_list.append(villager)
		
		# Scan local column coordinates (X:5, Z:7) for the Merchant stall surface height
		var merchant_y := _get_ground_surface_y(chunk, 5, 7)
		var merchant_pos := chunk_offset + Vector3(5.5, merchant_y, 7.5)
		
		var merchant = _entity_script.new(3, merchant_pos) as CharacterBody3D
		world_node.add_child(merchant)
		entities_list.append(merchant)
		
	# 2. Spawn local animals (Pigs / Chickens) deterministically
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
		# Type 0 is PIG, Type 1 is CHICKEN
		var animal_type_id: int = 0 if (chunk_pos.x + chunk_pos.z) % 2 == 0 else 1
		
		# Scan local column coordinates (X:8, Z:8) for animal safe surface height
		var animal_y := _get_ground_surface_y(chunk, 8, 8)
		var animal_pos := chunk_offset + Vector3(8.5, animal_y, 8.5)
		
		var animal = _entity_script.new(animal_type_id, animal_pos) as CharacterBody3D
		world_node.add_child(animal)
		entities_list.append(animal)
		
	return entities_list

## Helper method to scan a block column from top to bottom and return the exact surface Y coordinate
func _get_ground_surface_y(chunk: Chunk, local_x: int, local_z: int) -> float:
	# Scan downwards starting from the maximum chunk block limit
	for y in range(Chunk.SIZE - 1, -1, -1):
		var block_type := chunk.get_block(local_x, y, local_z)
		
		# If we hit a solid block (Grass, Dirt, Stone, Wood), return the surface coordinate exactly above it
		if BlockType.is_solid(block_type):
			return float(y) + 1.0 # Standard physical offset for safe resting
			
	# Safe fallback height if the entire column is empty
	return 8.0
