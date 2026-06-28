# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC, Fauna, and interactive prop classes dynamically inside chunks.
#              SOLID COMPLIANCE: Adheres to Single Responsibility Principle (SRP)
#              and Liskov Substitution Principle (LSP). Changed return type to 
#              Array[Node] to treat both character bodies and static body props 
#              polymorphically during chunk load/unload states.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted

# Dynamic compilation isolation
var _pig_script := load("res://src/Infrastructure/Life/PigEntity.gd")
var _chicken_script := load("res://src/Infrastructure/Life/ChickenEntity.gd")
var _sheep_script := load("res://src/Infrastructure/Life/SheepEntity.gd")
var _cow_script := load("res://src/Infrastructure/Life/CowEntity.gd")
var _villager_script := load("res://src/Infrastructure/Life/VillagerEntity.gd")
var _merchant_script := load("res://src/Infrastructure/Life/MerchantEntity.gd")
var _guard_script := load("res://src/Infrastructure/Life/GuardEntity.gd")
var _farmer_script := load("res://src/Infrastructure/Life/FarmerEntity.gd")

# UPGRADE: Load the 3D Chest Prop script dynamically (SRP compliant)
var _chest_script := load("res://src/Infrastructure/World/ChestEntity.gd")

## Calculates and spawns passive entities and props for a given chunk, returning the active list.
## LSP UPGRADE: Returns Array[Node] to allow static props (StaticBody3D) and mobs (CharacterBody3D)
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var entities_list: Array[Node] = []
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	
	# Determine if this chunk is a real village by querying the generator noise on the main thread
	var is_real_village: bool = false
	var generator = world_node.get("generator")
	
	if is_instance_valid(generator):
		var terrain_noise = generator.get("_terrain_noise")
		if terrain_noise != null:
			# Scan the center column of the chunk dynamically
			var center_x := chunk_pos.x * Chunk.SIZE + 8
			var center_z := chunk_pos.z * Chunk.SIZE + 8
			var profile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise)
			
			# Landmark 3 is the Village Market Cabin!
			is_real_village = (profile.landmark_id == 3)

	# 1. Village Spawning (ONLY triggered if a Cabin was actually built here!)
	if is_real_village:
		print("[MobSpawningService] Village detected at chunk %s. Spawning civil community & props!" % str(chunk_pos))
		
		# A. Common Villager
		if _villager_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 7, int(chunk_offset.z) + 5)
			var pos := chunk_offset + Vector3(7.5, gy, 5.5)
			var villager = _villager_script.new(pos)
			world_node.add_child(villager)
			entities_list.append(villager)
			
			var q1 := QuestService.get_quest("lost_bazaar")
			if q1 != null:
				q1.target_position = pos
				print("[MobSpawningService] GPS Quest 1 Target updated to exact Villager spawn: ", pos)
			
		# B. Merchant Stall Owner
		if _merchant_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 5, int(chunk_offset.z) + 7)
			var pos := chunk_offset + Vector3(5.5, gy, 7.5)
			var merchant = _merchant_script.new(pos)
			world_node.add_child(merchant)
			entities_list.append(merchant)
			
			var q2 := QuestService.get_quest("fuel_fryer")
			if q2 != null:
				q2.target_position = pos
				print("[MobSpawningService] GPS Quest 2 Target updated to exact Merchant spawn: ", pos)
			
		# C. Armed Patrol Guard
		if _guard_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 10, int(chunk_offset.z) + 10)
			var pos := chunk_offset + Vector3(10.5, gy, 10.5)
			var guard = _guard_script.new(pos)
			world_node.add_child(guard)
			entities_list.append(guard)
			
			var q3 := QuestService.get_quest("plains_defender")
			if q3 != null:
				q3.target_position = pos
				print("[MobSpawningService] GPS Quest 3 Target updated to exact Guard spawn: ", pos)
			
		# D. Field Tending Farmer
		if _farmer_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 2, int(chunk_offset.z) + 12)
			var pos := chunk_offset + Vector3(2.5, gy, 12.5)
			var farmer = _farmer_script.new(pos)
			world_node.add_child(farmer)
			entities_list.append(farmer)
			
		# E. Interactive Loot Chest (3D GLB Prop - Micro-Phase 7)
		if _chest_script != null:
			var gy := _get_ground_surface_y(world_state, int(chunk_offset.x) + 4, int(chunk_offset.z) + 8)
			var pos := chunk_offset + Vector3(4.5, gy, 8.5)
			
			var chest = _chest_script.new()
			chest.position = pos
			world_node.add_child(chest)
			entities_list.append(chest)
			print("[MobSpawningService] 3D Loot Chest spawned at position: ", pos)
			
	# 2. Fauna Spawning (Wild animals are allowed to spawn anywhere in plains/mountains)
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
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
			return float(y) + 1.0 
			
	return 8.0
