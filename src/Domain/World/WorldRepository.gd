# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Repository Interface defining the storage contract 
#              for world chunks and player persistence, keeping domain logic
#              independent of disk serialization methods.
#              UPDATED: Added contracts to support saving and loading player 
#              inventory quantities and active campaign quest states.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldRepository.gd
# ==============================================================================
class_name WorldRepository
extends RefCounted

## Abstract contract: Saves modifications for a specific chunk.
## Modifications is a Dictionary mapping: Vector3i (local block position) -> BlockType.Type
func save_chunk_modifications(_chunk_pos: Vector3i, _modifications: Dictionary) -> void:
	assert(false, "[WorldRepository] save_chunk_modifications() must be implemented by concrete subclass.")

## Abstract contract: Loads and returns saved modifications for a specific chunk.
## Returns an empty dictionary if no modifications exist.
func load_chunk_modifications(_chunk_pos: Vector3i) -> Dictionary:
	assert(false, "[WorldRepository] load_chunk_modifications() must be implemented by concrete subclass.")
	return {}

## Abstract contract: Saves global metadata (coordinates, rotation, world seed, inventory state, and active quest).
func save_global_state(_player_pos: Vector3, _player_rot: Vector3, _seed_val: int, _inventory_quantities: Array = [], _active_quest_id: String = "") -> void:
	assert(false, "[WorldRepository] save_global_state() must be implemented by concrete subclass.")

## Abstract contract: Loads global metadata.
## Returns a dictionary containing 'player_pos', 'player_rot', 'seed', 'inventory_quantities' and 'active_quest_id'.
func load_global_state() -> Dictionary:
	assert(false, "[WorldRepository] load_global_state() must be implemented by concrete subclass.")
	return {}
