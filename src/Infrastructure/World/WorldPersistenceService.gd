# ==============================================================================
# Pathfile: res://src/Infrastructure/World/WorldPersistenceService.gd
# Description: Infrastructure Service responsible for serializing game metadata,
#              player vectors, inventory, and campaign progress to disk.
#              Refactored into single-responsibility short helpers (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WorldPersistenceService
extends RefCounted

var repository: WorldRepository


func _init(p_repository: WorldRepository) -> void:
	repository = p_repository


## Public API: Orchestrates the sequential saving steps
func save_game(player: CharacterBody3D, world_state: WorldState) -> void:
	if not is_instance_valid(repository):
		print("[WorldPersistenceService] Save aborted: Repository is already freed.")
		return
		
	print("[WorldPersistenceService] Initiating disk serialization sequence...")
	_serialize_chunk_deltas(world_state)
	_serialize_player_metadata(player)
	print("[WorldPersistenceService] World saved successfully.")


func _serialize_chunk_deltas(world_state: WorldState) -> void:
	for chunk_pos: Vector3i in world_state._chunk_modifications.keys():
		var modifications: Dictionary = world_state.get_chunk_modifications(chunk_pos)
		repository.save_chunk_modifications(chunk_pos, modifications)


func _serialize_player_metadata(player: CharacterBody3D) -> void:
	if not is_instance_valid(player):
		return
		
	var inv_data := _get_inventory_serialize_data(player)
	var active_q_id := _get_active_quest_id()
	var seed_val := _extract_world_seed(player)
	
	var celestial_time: float = 0.5
	var calendar_day: int = 14
	var celestial := CelestialService.instance
	if is_instance_valid(celestial):
		celestial_time = celestial.get("_current_time") as float
		calendar_day = celestial.get("_calendar_days") as int
		
	repository.save_global_state(
		player.global_position, 
		player.rotation, 
		seed_val,
		inv_data,
		active_q_id,
		celestial_time,
		calendar_day
	)


func _get_inventory_serialize_data(player: CharacterBody3D) -> Array:
	var inv_data: Array = []
	var inventory := player.get("inventory") as InventoryComponent
	if is_instance_valid(inventory):
		inv_data = inventory.get_serialize_data()
	return inv_data


func _get_active_quest_id() -> String:
	var active_q := QuestService.get_active_quest()
	if active_q != null:
		return active_q.quest_id
	return "COMPLETED"


func _extract_world_seed(player: CharacterBody3D) -> int:
	var seed_val: int = 42
	var world_controller := player.get("world_controller") as Node
	if is_instance_valid(world_controller) and "generator" in world_controller:
		var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
		if is_instance_valid(generator) and "_terrain_noise" in generator:
			var noise := generator.get("_terrain_noise") as FastNoiseLite
			if noise != null:
				seed_val = noise.get("seed") as int
	return seed_val
