# ==============================================================================
# Pathfile: res://src/Infrastructure/World/WorldPersistenceService.gd
# Description: Infrastructure Service responsible for serializing game metadata,
#              player vectors, inventory, and campaign progress to disk.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. All verbose console print logs purged for FPS gains.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WorldPersistenceService
extends RefCounted

var repository: WorldRepository


func _init(p_repository: WorldRepository) -> void:
	repository = p_repository


func save_game(player: CharacterBody3D, world_state: WorldState) -> void:
	if not is_instance_valid(repository):
		return # Silent exit to prevent console I/O stutters
		
	_serialize_chunk_deltas(world_state)
	_serialize_player_metadata(player)


func _serialize_chunk_deltas(world_state: WorldState) -> void:
	for chunk_pos: Vector3i in world_state._chunk_modifications.keys():
		var modifications: Dictionary = world_state.get_chunk_modifications(chunk_pos)
		repository.save_chunk_modifications(chunk_pos, modifications)


func _serialize_player_metadata(player: CharacterBody3D) -> void:
	if not is_instance_valid(player): return
		
	var inv_data: Array = _get_inventory_serialize_data(player)
	var active_q_id: String = _get_active_quest_id()
	var seed_val: int = _extract_world_seed(player)
	var time_data: Vector2 = _get_celestial_time_data()
	
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
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	if is_instance_valid(inventory):
		inv_data = inventory.get_serialize_data()
	return inv_data


func _get_active_quest_id() -> String:
	var active_q: Quest = QuestService.get_active_quest()
	if active_q != null:
		return active_q.quest_id
	return "COMPLETED"


func _extract_world_seed(player: CharacterBody3D) -> int:
	var seed_val: int = 42
	var world_controller: Node = player.get("world_controller") as Node
	if is_instance_valid(world_controller) and "generator" in world_controller:
		var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
		if is_instance_valid(generator) and "_terrain_noise" in generator:
			var noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if noise != null:
				seed_val = noise.get("seed") as int
	return seed_val
