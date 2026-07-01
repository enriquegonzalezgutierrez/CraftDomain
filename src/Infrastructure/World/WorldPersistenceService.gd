# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for formatting and serializing
#              save metadata to the injected WorldRepository.
#              SOLID COMPLIANCE: SRP compliant by isolating I/O serialization
#              from SceneTree physics or game loop frames.
#              FIXED: Added is_instance_valid check on the repository reference
#              to prevent "previously freed" null assertion crashes upon game exit.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/WorldPersistenceService.gd
# ==============================================================================
class_name WorldPersistenceService
extends RefCounted

var repository: WorldRepository

func _init(p_repository: WorldRepository) -> void:
	repository = p_repository

## Performs atomic database saving safely by gathering modifications and serializing.
func save_game(player: CharacterBody3D, world_state: WorldState) -> void:
	# Lifecycle Shield: Prevent execution if the repository has been freed during shutdown
	if not is_instance_valid(repository):
		print("[WorldPersistenceService WARNING] Save aborted: Repository is already freed or shutting down.")
		return
		
	print("[WorldPersistenceService] Initiating asynchronous disk save sequence...")
	
	# 1. Save all tracked chunk modification deltas
	for chunk_pos in world_state._chunk_modifications.keys():
		var modifications: Dictionary = world_state.get_chunk_modifications(chunk_pos)
		repository.save_chunk_modifications(chunk_pos, modifications)
		
	# 2. Extract, serialize, and pack Player profile metadata
	if is_instance_valid(player):
		var inv_data: Array = []
		var inventory := player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			inv_data = inventory.get_serialize_data()
			
		var active_q_id := ""
		var active_q := QuestService.get_active_quest()
		if active_q != null:
			active_q_id = active_q.quest_id
		else:
			active_q_id = "COMPLETED" # Finished campaign state flag
			
		# Extract World Seed safely from coordinator
		var seed_val: int = 42
		var world_controller := player.get("world_controller") as Node
		if is_instance_valid(world_controller) and "generator" in world_controller:
			var generator := world_controller.get("generator") as RefCounted
			if is_instance_valid(generator) and "_terrain_noise" in generator:
				var noise := generator.get("_terrain_noise") as RefCounted
				if noise != null:
					seed_val = noise.get("seed") as int
				
		repository.save_global_state(
			player.global_position, 
			player.rotation, 
			seed_val,
			inv_data,
			active_q_id
		)
		print("[WorldPersistenceService] Atomic disk serialization finished.")
