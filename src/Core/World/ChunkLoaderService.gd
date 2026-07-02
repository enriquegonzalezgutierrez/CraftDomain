# ==============================================================================
# Project: CraftDomain
# Description: Application Service calculating procedural chunk loading and 
#              unloading queues based on player spatial translations.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively player 
#                boundary tracking and queue calculations.
#              - Open-Closed Principle (OCP): Dynamically reacts to static 
#                configuration changes without modifying core logic.
#              WARNING FIX:
#              - Added explicit static typing `Vector3i` to the `active_pos` iterator 
#                on line 70 to eliminate `UNTYPED_DECLARATION` warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/World/ChunkLoaderService.gd
# ==============================================================================
class_name ChunkLoaderService
extends RefCounted

## Global configuration for chunk render distance radius.
## Managed by the SettingsMenu. Default is 8.
static var global_view_distance: int = 8

## Keeps track of the last chunk position the player was in to avoid redundant updates.
var _last_viewer_chunk_pos: Vector3i = Vector3i(999, 999, 999)

## Keeps track of the last evaluated distance to force updates if settings change dynamically.
var _last_view_distance: int = -1

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
	var current_distance := global_view_distance
	
	# 2. Only run intensive calculations if the player crossed a boundary OR changed settings
	if current_viewer_chunk_pos == _last_viewer_chunk_pos and current_distance == _last_view_distance:
		return task # Empty task, skip calculation
		
	_last_viewer_chunk_pos = current_viewer_chunk_pos
	_last_view_distance = current_distance
	
	# 3. Calculate all chunk positions that should be active
	var desired_chunks: Dictionary = {}
	for x in range(-current_distance, current_distance + 1):
		for z in range(-current_distance, current_distance + 1):
			# We load layers Y=0 and Y=1 (Height range 0 to 31) to support full heights & building
			for y in range(2):
				var target_pos := Vector3i(current_viewer_chunk_pos.x + x, y, current_viewer_chunk_pos.z + z)
				desired_chunks[target_pos] = true
				
				# If the desired chunk does not exist in the database, queue it for loading
				if world_state.get_chunk(target_pos) == null:
					task.to_load.append(target_pos)
				
	# 4. Identify chunks currently in the database that are outside the view distance
	# FIX: Added explicit type declaration `Vector3i` to iterator variable
	for active_pos: Vector3i in world_state._chunks.keys():
		if not desired_chunks.has(active_pos):
			task.to_unload.append(active_pos)
			
	return task
