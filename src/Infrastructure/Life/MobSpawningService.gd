# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              villager, merchant, and animal entities dynamically inside chunks.
#              UPDATED: Modified to scan block columns globally using WorldState
#              from height 31 down to 0, preventing NPCs from spawning underground.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted

## Dynamically loaded Entity Script to prevent compile-time cache bugs
var _entity_script: Script = load("res://src/Infrastructure/Life/PassiveEntity.gd")

## Calculates and spawns passive entities for a given chunk, returning the active list.
## UPDATED: Added WorldState parameter to allow global 3D vertical height scanning.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[CharacterBody3D]:
	var entities_list: Array[CharacterBody3D] = []
	
	if _entity_script == null:
		return entities_list
		
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	
	# 1. Spawn a Villager and a Merchant if the chunk generated a rustic cabin
	var has_house: bool = (abs(chunk_pos.x) + abs(chunk_pos.z)) % 3 == 2 and chunk_pos.y == 0
	if has_house:
		# Calculate global column coordinates for precise scanning
		var villager_gx := int(chunk_offset.x) + 7
		var villager_gz := int(chunk_offset.z) + 5
		var villager_y := _get_ground_surface_y(world_state, villager_gx, villager_gz)
		var villager_pos := Vector3(float(villager_gx) + 0.5, villager_y, float(villager_gz) + 0.5)
		
		var villager = _entity_script.new(2, villager_pos) as CharacterBody3D
		world_node.add_child(villager)
		entities_list.append(villager)
		
		# Calculate global column coordinates for the Merchant
		var merchant_gx := int(chunk_offset.x) + 5
		var merchant_gz := int(chunk_offset.z) + 7
		var merchant_y := _get_ground_surface_y(world_state, merchant_gx, merchant_gz)
		var merchant_pos := Vector3(float(merchant_gx) + 0.5, merchant_y, float(merchant_gz) + 0.5)
		
		var merchant = _entity_script.new(3, merchant_pos) as CharacterBody3D
		world_node.add_child(merchant)
		entities_list.append(merchant)
		
	# 2. Spawn local animals (Pigs / Chickens) deterministically
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
		var animal_type_id: int = 0 if (chunk_pos.x + chunk_pos.z) % 2 == 0 else 1
		
		# Calculate global column coordinates for the Animal
		var animal_gx := int(chunk_offset.x) + 8
		var animal_gz := int(chunk_offset.z) + 8
		var animal_y := _get_ground_surface_y(world_state, animal_gx, animal_gz)
		var animal_pos := Vector3(float(animal_gx) + 0.5, animal_y, float(animal_gz) + 0.5)
		
		var animal = _entity_script.new(animal_type_id, animal_pos) as CharacterBody3D
		world_node.add_child(animal)
		entities_list.append(animal)
		
	return entities_list

## Helper method to scan a block column from top to bottom (31 down to 0) globally
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	# Scan downwards starting from the maximum world vertical limit (Y=31)
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		# If we hit a solid block, return the surface coordinate exactly above it
		if BlockType.is_solid(block_type):
			return float(y) + 1.0 # Standard physical offset for safe resting
			
	# Safe fallback height if the entire column is empty
	return 8.0
