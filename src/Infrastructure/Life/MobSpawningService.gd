# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC and Fauna classes dynamically inside chunks.
#              OCP COMPLIANT: Completely decoupled from strict types. Loads 
#              individual subclasses dynamically to satisfy SOLID specifications.
#              FIXED: Declared static int casting for spawn_roll variable.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted

# Dynamic compilation isolation (OCP Compliant)
var _pig_script := load("res://src/Infrastructure/Life/PigEntity.gd")
var _chicken_script := load("res://src/Infrastructure/Life/ChickenEntity.gd")
var _sheep_script := load("res://src/Infrastructure/Life/SheepEntity.gd")
var _cow_script := load("res://src/Infrastructure/Life/CowEntity.gd")
var _villager_script := load("res://src/Infrastructure/Life/VillagerEntity.gd")
var _merchant_script := load("res://src/Infrastructure/Life/MerchantEntity.gd")
var _guard_script := load("res://src/Infrastructure/Life/GuardEntity.gd")
var _farmer_script := load("res://src/Infrastructure/Life/FarmerEntity.gd")

## Calculates and spawns passive entities for a given chunk, returning the active list.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[CharacterBody3D]:
	var entities_list: Array[CharacterBody3D] = []
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	
	# 1. Village Spawning (If cabin is present)
	var has_house: bool = (abs(chunk_pos.x) + abs(chunk_pos.z)) % 3 == 2 and chunk_pos.y == 0
	if has_house:
		# A. Common Villager
		if _villager_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 7, int(chunk_offset.z) + 5)
			var pos := chunk_offset + Vector3(7.5, gy, 5.5)
			var villager = _villager_script.new(pos)
			world_node.add_child(villager)
			entities_list.append(villager)
			
		# B. Merchant Stall Owner
		if _merchant_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 5, int(chunk_offset.z) + 7)
			var pos := chunk_offset + Vector3(5.5, gy, 7.5)
			var merchant = _merchant_script.new(pos)
			world_node.add_child(merchant)
			entities_list.append(merchant)
			
		# C. Armed Patrol Guard
		if _guard_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 10, int(chunk_offset.z) + 10)
			var pos := chunk_offset + Vector3(10.5, gy, 10.5)
			var guard = _guard_script.new(pos)
			world_node.add_child(guard)
			entities_list.append(guard)
			
		# D. Field Tending Farmer
		if _farmer_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 2, int(chunk_offset.z) + 12)
			var pos := chunk_offset + Vector3(2.5, gy, 12.5)
			var farmer = _farmer_script.new(pos)
			world_node.add_child(farmer)
			entities_list.append(farmer)
			
	# 2. Fauna Spawning (Deterministic herd spawn)
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
		# FIXED: Declared static int casting to satisfy Godot's static analyzer
		var spawn_roll: int = int(abs(chunk_pos.x + chunk_pos.z)) % 4
		var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 8, int(chunk_offset.z) + 8)
		var pos := chunk_offset + Vector3(8.5, gy, 8.5)
		
		var animal_node: CharacterBody3D = null
		match spawn_roll:
			0:
				if _pig_script != null: animal_node = _pig_script.new(pos)
			1:
				if _chicken_script != null: animal_node = _chicken_script.new(pos)
			2:
				if _sheep_script != null: animal_node = _sheep_script.new(pos)
			3:
				if _cow_script != null: animal_node = _cow_script.new(pos)
				
		if animal_node != null:
			world_node.add_child(animal_node)
			entities_list.append(animal_node)
			
	return entities_list

## Helper method to scan a block column from top to bottom (31 down to 0) globally
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		if BlockType.is_solid(block_type):
			return float(y) + 1.0 # Standard physical offset for safe resting
			
	return 8.0
