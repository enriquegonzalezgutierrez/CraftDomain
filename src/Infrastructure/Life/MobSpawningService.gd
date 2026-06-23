# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              villager, merchant, and animal entities dynamically inside chunks.
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
		# Place the Villager safely above ground (Type 2 is VILLAGER)
		var spawn_pos_global := chunk_offset + Vector3(7.5, 14.0, 5.5)
		var villager = _entity_script.new(2, spawn_pos_global) as CharacterBody3D
		world_node.add_child(villager)
		entities_list.append(villager)
		
		# Place the Merchant on the side of the house (Type 3 is MERCHANT)
		var merchant_pos_global := chunk_offset + Vector3(5.5, 14.0, 7.5)
		var merchant = _entity_script.new(3, merchant_pos_global) as CharacterBody3D
		world_node.add_child(merchant)
		entities_list.append(merchant)
		
	# 2. Spawn local animals (Pigs / Chickens) deterministically
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
		# Type 0 is PIG, Type 1 is CHICKEN
		var animal_type_id: int = 0 if (chunk_pos.x + chunk_pos.z) % 2 == 0 else 1
		var spawn_pos_global := chunk_offset + Vector3(8.5, 14.0, 8.5)
		var animal = _entity_script.new(animal_type_id, spawn_pos_global) as CharacterBody3D
		world_node.add_child(animal)
		entities_list.append(animal)
		
	return entities_list
