# ==============================================================================
# Project: CraftDomain
# Description: Application Service that calculates chunk loading and unloading 
#              queues, optimized for mid-range CPUs by using a compact view distance.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/World/ChunkLoaderService.gd
# ==============================================================================
class_name ChunkLoaderService
extends RefCounted

## Optimized View Distance (2 chunks radius = 5x1x5 grid = 25 active chunks).
## This drastically reduces Godot's single-threaded CPU physics bottle-neck.
var view_distance: int = 2

## Keeps track of the last chunk position the player was in to avoid redundant updates.
var _last_viewer_chunk_pos: Vector3i = Vector3i(999, 999, 999)

## Struct containing the calculated state change queues.
class ChunkUpdateTask:
	var to_load: Array[Vector3i] = []
	var to_unload: Array[Vector3i] = []

## Evaluates the player's position and returns the queues of chunks to load/unload.
func check_viewer_position(player_global_pos: Vector3, world_state: WorldState) -> ChunkUpdateTask:
	var task := ChunkUpdateTask.new()
	
	# 1. Translate player's global float coordinates to its chunk position
	var player_block_pos := Vector3i(
		floor(player_global_pos.x),
		floor(player_global_pos.y),
		floor(player_global_pos.z)
	)
	var current_viewer_chunk_pos := world_state.global_to_chunk_pos(player_block_pos)
	
	# 2. Only run calculations if the player has crossed a chunk boundary
	if current_viewer_chunk_pos == _last_viewer_chunk_pos:
		return task # Empty task, no update needed
		
	_last_viewer_chunk_pos = current_viewer_chunk_pos
	
	# 3. Calculate all chunk positions that should be active (5x1x5 grid)
	var desired_chunks: Dictionary = {}
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			# Maintain a flat horizontal layer (y = 0)
			var target_pos := Vector3i(current_viewer_chunk_pos.x + x, 0, current_viewer_chunk_pos.z + z)
			desired_chunks[target_pos] = true
			
			# If the desired chunk does not exist in the database, queue it for loading
			if world_state.get_chunk(target_pos) == null:
				task.to_load.append(target_pos)
				
	# 4. Identify chunks currently in the database that are outside the view distance
	for active_pos in world_state._chunks.keys():
		if not desired_chunks.has(active_pos):
			task.to_unload.append(active_pos)
			
	return task
