# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC, Fauna, and interactive prop classes dynamically inside chunks.
#              SOLID COMPLIANCE: Adheres to Single Responsibility Principle (SRP)
#              and Liskov Substitution Principle (LSP) by utilizing `MobRegistry`.
#              FASE A & BUG 1 FIX:
#              - Implemented a smart vertical scanner that prevents suffocation by
#                ensuring the two blocks above spawn feet are non-solid.
#              - Replaced the low 8.0 fallback with a safe tilled village-plains
#                surface fallback level (11.0) to prevent NPCs spawning underground.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted

## Calculates and spawns passive entities and props for a given chunk, returning the active list.
## LSP COMPLIANCE: Returns Array[Node] to handle both CharacterBody3D and StaticBody3D polymorphically.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var entities_list: Array[Node] = []
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	
	var is_real_village: bool = false
	var generator = world_node.get("generator")
	
	if is_instance_valid(generator):
		var terrain_noise = generator.get("_terrain_noise")
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + 8
			var center_z := chunk_pos.z * Chunk.SIZE + 8
			var profile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise)
			# Landmark 3 is the Village Market Cabin
			is_real_village = (profile.landmark_id == 3)

	# 1. Village Spawning (Delegated securely to the OCP MobRegistry)
	if is_real_village:
		print("[MobSpawningService] Village detected at chunk %s. Spawning civil community & props!" % str(chunk_pos))
		
		# A. Villager (ID: 100)
		_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, entities_list, "lost_bazaar")
		# B. Merchant (ID: 101)
		_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, entities_list, "fuel_fryer")
		# C. Guard (ID: 102)
		_spawn_and_register_entity(102, chunk_offset, 10.5, 10.5, world_state, world_node, entities_list, "plains_defender")
		# D. Farmer (ID: 103)
		_spawn_and_register_entity(103, chunk_offset, 2.5, 12.5, world_state, world_node, entities_list, "")
		
		# E. Loot Chest (ID: 200)
		_spawn_and_register_entity(200, chunk_offset, 4.5, 8.5, world_state, world_node, entities_list, "")
		print("[MobSpawningService] Village generation completed.")
			
	# 2. Fauna Spawning (Wild animals are allowed to spawn anywhere in plains/mountains)
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
		var spawn_roll: int = int(abs(chunk_pos.x + chunk_pos.z)) % 4
		_spawn_and_register_entity(spawn_roll, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list, "")
			
	return entities_list

## Helper method encapsulating dynamic OCP entity creation, altitude placement, and GPS quest target synchronization
func _spawn_and_register_entity(
	mob_id: int, offset: Vector3, lx: float, lz: float, 
	world_state: WorldState, world_node: Node, 
	list: Array[Node], quest_sync_id: String
) -> void:
	
	if not MobRegistry.has_mob(mob_id):
		return
		
	var gy := _get_ground_surface_y(world_state, int(offset.x + lx), int(offset.z + lz))
	var pos := offset + Vector3(lx, gy, lz)
	
	var entity: Node = MobRegistry.create_mob(mob_id, pos)
	if entity != null:
		world_node.add_child(entity)
		list.append(entity)
		
		# Sync GPS if this entity is a quest target
		if quest_sync_id != "":
			var quest := QuestService.get_quest(quest_sync_id)
			if quest != null:
				quest.target_position = pos
				print("[MobSpawningService] GPS Quest Target [", quest_sync_id, "] synced to exact spawn coordinate: ", pos)

## Helper method to scan a block column from top to bottom (31 down to 0) globally
## BUG 1 FIXED: Prevents suffocation/underground spawning by checking the two spaces above
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		if BlockType.is_solid(block_type):
			# Ensure the two spaces directly above are empty to prevent suffocation
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 1.0 
			
	# Safe tilled village-plains surface level fallback if the column scan gets lost/buried
	return 11.0
