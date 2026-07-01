# ==============================================================================
# Project: CraftDomain
# Description: Application Service calculating procedural chunk loading and 
#              unloading queues based on player spatial translations.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively player 
#                boundary tracking and queue calculations.
#              OPTIMIZATION:
#              - Reduced view_distance from 4 chunks radius to 2 chunks radius (5x2x5 grid = 50 chunks).
#                This massively reduces draw calls, memory footprint, and CPU overhead.
#              FIXED: Removed unused private class variable '_to_unload_queue' 
#              to resolve static analyzer warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/World/ChunkLoaderService.gd
# ==============================================================================
class_name ChunkLoaderService
extends RefCounted

## Optimized View Distance Radius (2 chunks radius = 5x2x5 grid = 50 active chunks).
## This significantly improves performance on all hardware configurations.
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
	
	# 1. Translate the player's global float coordinates to its chunk position
	var player_block_pos := Vector3i(
		floor(player_global_pos.x),
		floor(player_global_pos.y),
		floor(player_global_pos.z)
	)
	var current_viewer_chunk_pos := world_state.global_to_chunk_pos(player_block_pos)
	
	# 2. Only run intensive calculations if the player has crossed a chunk boundary
	if current_viewer_chunk_pos == _last_viewer_chunk_pos:
		return task # Empty task, skip calculation
		
	_last_viewer_chunk_pos = current_viewer_chunk_pos
	
	# 3. Calculate all chunk positions that should be active (5x2x5 3D grid)
	var desired_chunks: Dictionary = {}
	for x in range(-view_distance, view_distance + 1):
		for z in range(-view_distance, view_distance + 1):
			# We load layers Y=0 and Y=1 (Height range 0 to 31) to support full heights & building
			for y in range(2):
				var target_pos := Vector3i(current_viewer_chunk_pos.x + x, y, current_viewer_chunk_pos.z + z)
				desired_chunks[target_pos] = true
				
				# If the desired chunk does not exist in the database, queue it for loading
				if world_state.get_chunk(target_pos) == null:
					task.to_load.append(target_pos)
				
	# 4. Identify chunks currently in the database that are outside the view distance
	for active_pos in world_state._chunks.keys():
		if not desired_chunks.has(active_pos):
			task.to_unload.append(active_pos)
			
	return task
