# ==============================================================================
# Project: CraftDomain
# Description: Application Service calculating procedural chunk loading and 
#              unloading queues based on player spatial translations.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively player 
#                boundary tracking and queue calculations.
#              - Open-Closed Principle (OCP): Dynamically reacts to static 
#                configuration changes without modifying core logic.
#              ALGORITHM OVERHAUL (ROTATION-AWARE SCHEDULING):
#              - Added look direction tracking (`_last_look_dir`). 
#              - Now triggers a recalculation whenever the player crosses boundaries 
#                OR rotates their camera by more than 15 degrees (Dot Product < 0.96).
#                This allows the queue to be hot-swapped dynamically during panning.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/World/ChunkLoaderService.gd
# ==============================================================================
class_name ChunkLoaderService
extends RefCounted

static var global_view_distance: int = 8

## Keeps track of the last chunk position the player was in to avoid redundant updates.
var _last_viewer_chunk_pos: Vector3i = Vector3i(999, 999, 999)

## Keeps track of the last evaluated distance to force updates if settings change dynamically.
var _last_view_distance: int = -1

## Keeps track of the last look direction to trigger re-sorting on rotation shifts.
var _last_look_dir: Vector3 = Vector3.ZERO

## Struct containing the calculated state change queues.
class ChunkUpdateTask:
	var to_load: Array[Vector3i] = []
	var to_unload: Array[Vector3i] = []


## Evaluates the player's position and look direction, prioritizing visible chunks.
func check_viewer_position(player_global_pos: Vector3, player_look_dir: Vector3, world_state: WorldState) -> ChunkUpdateTask:
	var task := ChunkUpdateTask.new()
	
	# 1. Translate the player's global float coordinates to its chunk position
	var player_block_pos := Vector3i(
		floor(player_global_pos.x),
		floor(player_global_pos.y),
		floor(player_global_pos.z)
	)
	var current_viewer_chunk_pos := world_state.global_to_chunk_pos(player_block_pos)
	var current_distance := global_view_distance
	
	# Calculate directional alignment drift (Dot product of look vectors)
	var look_diff: float = _last_look_dir.dot(player_look_dir)
	
	# 2. Trigger updates on boundary crossings OR when camera rotates > 15 degrees (dot < 0.96)
	if current_viewer_chunk_pos == _last_viewer_chunk_pos and current_distance == _last_view_distance and look_diff > 0.96:
		return task # Position, distance, and direction are stable, skip
		
	_last_viewer_chunk_pos = current_viewer_chunk_pos
	_last_view_distance = current_distance
	_last_look_dir = player_look_dir
	
	# 3. Calculate all chunk positions that should be active
	var desired_chunks: Dictionary = {}
	for x: int in range(-current_distance, current_distance + 1):
		for z: int in range(-current_distance, current_distance + 1):
			# We load layers Y=0 and Y=1 (Height range 0 to 31) to support full heights & building
			for y: int in range(2):
				var target_pos := Vector3i(current_viewer_chunk_pos.x + x, y, current_viewer_chunk_pos.z + z)
				desired_chunks[target_pos] = true
				
				# If the desired chunk does not exist in the database, queue it for loading
				if world_state.get_chunk(target_pos) == null:
					task.to_load.append(target_pos)
					
	# ==========================================================================
	# FRUSTUM VIEW-DIRECTED SORTING ALGORITHM
	# ==========================================================================
	var center := current_viewer_chunk_pos
	# Flatten the camera vector to 2D (X and Z)
	var flat_look := Vector2(player_look_dir.x, player_look_dir.z).normalized()
	
	task.to_load.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var vec_a := Vector2(float(a.x - center.x), float(a.z - center.z))
		var vec_b := Vector2(float(b.x - center.x), float(b.z - center.z))
		
		var dist_a := vec_a.length()
		var dist_b := vec_b.length()
		
		# Prevent division by zero if the chunk is the one the player stands inside
		var dot_a := flat_look.dot(vec_a.normalized()) if dist_a > 0.1 else 1.0
		var dot_b := flat_look.dot(vec_b.normalized()) if dist_b > 0.1 else 1.0
		
		# SCORE FORMULA: Closer distance is better (lower score).
		# Being in front (dot > 0) reduces the score dramatically (loads first).
		# Being behind (dot < 0) multiplies the score, heavily penalizing it (loads last).
		var score_a := dist_a * (1.0 - (dot_a * 0.85))
		var score_b := dist_b * (1.0 - (dot_b * 0.85))
		
		return score_a < score_b
	)
	# ==========================================================================
				
	# 4. Identify chunks currently in the database that are outside the view distance
	for active_pos: Vector3i in world_state._chunks.keys():
		if not desired_chunks.has(active_pos):
			task.to_unload.append(active_pos)
			
	return task
