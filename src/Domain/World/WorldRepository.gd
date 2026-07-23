# ==============================================================================
# Pathfile: res://src/Domain/World/WorldRepository.gd
# Description: Pure Domain Repository Interface defining storage contracts 
#              for chunk deltas, player metadata, and world state persistence.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WorldRepository
extends RefCounted


## Abstract contract: Saves modifications for a specific chunk.
func save_chunk_modifications(_chunk_pos: Vector3i, _modifications: Dictionary) -> void:
	assert(false, "[WorldRepository] save_chunk_modifications() must be implemented by concrete subclass.")


## Abstract contract: Loads and returns saved modifications for a specific chunk.
func load_chunk_modifications(_chunk_pos: Vector3i) -> Dictionary:
	assert(false, "[WorldRepository] load_chunk_modifications() must be implemented by concrete subclass.")
	return {}


## Abstract contract: Saves global metadata (coordinates, rotation, world seed, inventory, quests, time).
func save_global_state(
	_player_pos: Vector3, 
	_player_rot: Vector3, 
	_seed_val: int, 
	_inventory_quantities: Array = [], 
	_active_quest_id: String = "",
	_celestial_time: float = 0.5,
	_calendar_day: int = 1
) -> void:
	assert(false, "[WorldRepository] save_global_state() must be implemented by concrete subclass.")


## Abstract contract: Loads global metadata.
func load_global_state() -> Dictionary:
	assert(false, "[WorldRepository] load_global_state() must be implemented by concrete subclass.")
	return {}
