# ==============================================================================
# Pathfile: res://src/Core/World/ChunkLoaderService.gd
# Description: Application Service calculating procedural chunk loading and 
#              unloading queues based on player spatial translations.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkLoaderService
extends RefCounted

# Configurable constants to eliminate magic numbers (SOLID compliance)
const ANGLE_ROTATION_THRESHOLD: float = 0.96 # ~15 degrees
const SORT_DOT_ATTENUATION: float = 0.85
const MIN_DISTANCE_THRESHOLD: float = 0.1

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
	var current_viewer_chunk_pos := _get_viewer_chunk_pos(player_global_pos, world_state)
	var current_distance := global_view_distance
	
	if _should_skip_update(current_viewer_chunk_pos, current_distance, player_look_dir):
		return task
		
	_update_cached_viewer_state(current_viewer_chunk_pos, current_distance, player_look_dir)
	
	var desired_chunks := _gather_desired_chunks(current_viewer_chunk_pos, current_distance, world_state, task)
	_sort_chunks_by_view(task.to_load, current_viewer_chunk_pos, player_look_dir)
	_gather_unloaded_chunks(desired_chunks, world_state, task)
	
	return task


func _get_viewer_chunk_pos(player_global_pos: Vector3, world_state: WorldState) -> Vector3i:
	var player_block_pos := Vector3i(
		floori(player_global_pos.x),
		floori(player_global_pos.y),
		floori(player_global_pos.z)
	)
	return world_state.global_to_chunk_pos(player_block_pos)


func _should_skip_update(current_viewer_chunk_pos: Vector3i, current_distance: int, player_look_dir: Vector3) -> bool:
	var look_diff: float = _last_look_dir.dot(player_look_dir)
	return (
		current_viewer_chunk_pos == _last_viewer_chunk_pos 
		and current_distance == _last_view_distance 
		and look_diff > ANGLE_ROTATION_THRESHOLD
	)


func _update_cached_viewer_state(current_viewer_chunk_pos: Vector3i, current_distance: int, player_look_dir: Vector3) -> void:
	_last_viewer_chunk_pos = current_viewer_chunk_pos
	_last_view_distance = current_distance
	_last_look_dir = player_look_dir


func _gather_desired_chunks(center: Vector3i, distance: int, world_state: WorldState, task: ChunkUpdateTask) -> Dictionary:
	var desired_chunks: Dictionary = {}
	for x: int in range(-distance, distance + 1):
		for z: int in range(-distance, distance + 1):
			for y: int in range(2): # Height layers Y=0 and Y=1
				var target_pos := Vector3i(center.x + x, y, center.z + z)
				desired_chunks[target_pos] = true
				_queue_unloaded_chunk(target_pos, world_state, task)
	return desired_chunks


func _queue_unloaded_chunk(target_pos: Vector3i, world_state: WorldState, task: ChunkUpdateTask) -> void:
	if world_state.get_chunk(target_pos) == null:
		task.to_load.append(target_pos)


func _sort_chunks_by_view(to_load: Array[Vector3i], center: Vector3i, player_look_dir: Vector3) -> void:
	var flat_look := Vector2(player_look_dir.x, player_look_dir.z).normalized()
	to_load.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var score_a := _calculate_chunk_view_score(a, center, flat_look)
		var score_b := _calculate_chunk_view_score(b, center, flat_look)
		return score_a < score_b
	)


func _calculate_chunk_view_score(chunk_pos: Vector3i, center: Vector3i, flat_look: Vector2) -> float:
	var vec := Vector2(float(chunk_pos.x - center.x), float(chunk_pos.z - center.z))
	var dist := vec.length()
	var dot_val := flat_look.dot(vec.normalized()) if dist > MIN_DISTANCE_THRESHOLD else 1.0
	return dist * (1.0 - (dot_val * SORT_DOT_ATTENUATION))


func _gather_unloaded_chunks(desired_chunks: Dictionary, world_state: WorldState, task: ChunkUpdateTask) -> void:
	for active_pos: Vector3i in world_state._chunks.keys():
		if not desired_chunks.has(active_pos):
			task.to_unload.append(active_pos)
