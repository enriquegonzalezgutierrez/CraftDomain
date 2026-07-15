# ==============================================================================
# Pathfile: res://src/Infrastructure/World/WorldPersistenceService.gd
# Description: Infrastructure Service responsible for serializing game metadata,
#              player vectors, inventory, active campaign progress, and 
#              dual-timeline (Present/Past) chunk modifications to disk.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively high-level saving 
#   coordination, delegating file-system raw E/S to WorldRepository.
# - Open-Closed Principle (OCP): Fully compatible with the double-buffered 
#   timeline world state without modifying repository structures.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WorldPersistenceService
extends RefCounted

var repository: WorldRepository


func _init(p_repository: WorldRepository) -> void:
	repository = p_repository


## Coordinates the complete serialization of the simulation state
func save_game(player: CharacterBody3D, world_state: WorldState) -> void:
	if not is_instance_valid(repository):
		return
		
	_serialize_dual_timeline_deltas(world_state)
	_serialize_player_metadata(player)


func _serialize_dual_timeline_deltas(world_state: WorldState) -> void:
	var present_map: Dictionary = world_state._timeline_modifications[WorldState.Timeline.PRESENT] as Dictionary
	var past_map: Dictionary = world_state._timeline_modifications[WorldState.Timeline.PAST] as Dictionary
	
	# Gather union of all modified chunks across both eras
	var unique_chunks: Dictionary = {}
	for pos: Vector3i in present_map.keys():
		unique_chunks[pos] = true
	for pos: Vector3i in past_map.keys():
		unique_chunks[pos] = true
		
	for chunk_pos: Vector3i in unique_chunks.keys():
		var present_mods: Dictionary = present_map.get(chunk_pos, {}) as Dictionary
		var past_mods: Dictionary = past_map.get(chunk_pos, {}) as Dictionary
		
		# Pack both timelines into a single container dictionary to keep Repo signatures intact
		var dual_data := {
			"present": present_mods,
			"past": past_mods
		}
		repository.save_chunk_modifications(chunk_pos, dual_data)


func _serialize_player_metadata(player: CharacterBody3D) -> void:
	if not is_instance_valid(player): 
		return
		
	var inv_data := _get_inventory_serialize_data(player)
	var active_q_id := _get_active_quest_id()
	var seed_val := _extract_world_seed(player)
	var time_data := _get_celestial_time_data()
	
	repository.save_global_state(
		player.global_position, 
		player.rotation, 
		seed_val,
		inv_data,
		active_q_id,
		time_data.x,
		int(time_data.y)
	)


func _get_celestial_time_data() -> Vector2:
	var celestial_time: float = 0.5
	var calendar_day: float = 14.0
	var celestial: Node = CelestialService.instance
	
	if is_instance_valid(celestial):
		celestial_time = celestial.get("_current_time") as float
		calendar_day = float(celestial.get("_calendar_days") as int)
		
	return Vector2(celestial_time, calendar_day)


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
		var generator := world_controller.get("generator") as WorldGenerator
		if is_instance_valid(generator) and "_terrain_noise" in generator:
			var noise := generator.get("_terrain_noise") as FastNoiseLite
			if noise != null:
				seed_val = noise.get("seed") as int
	return seed_val
