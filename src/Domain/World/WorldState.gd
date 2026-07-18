# ==============================================================================
# Pathfile: res://src/Domain/World/WorldState.gd
# Description: Domain Aggregate Root representing the global voxel world, managing
#              chunk storage, coordinate systems, and a double-buffered timeline 
#              system to support seamless Present/Past chronological shifting.
# SOLID COMPLIANCE: Exclusively coordinates block states and active timeline buffers.
#              MISSION UPGRADE: Added a typesafe global target subscription anchor
#              to guarantee exactly one unique entity holds the active quest star.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WorldState
extends RefCounted

## Domain Event emitted whenever the world's active timeline is swapped
signal timeline_swapped(new_timeline: Timeline)

## Structural timeline states
enum Timeline {
	PRESENT,
	PAST
}

## Tracks the active chronological state of the world
var active_timeline: Timeline = Timeline.PRESENT

## Dictionary storing chunks, mapping Vector3i (chunk coordinates) -> Chunk
var _chunks: Dictionary = {}

## Double-buffered modifications registry mapping: Timeline -> (chunk_pos -> modifications_dict)
var _timeline_modifications: Dictionary = {
	Timeline.PRESENT: {},
	Timeline.PAST: {}
}

# --- SOLID MISSION REGISTRY ANCHOR (ISP / LSP Compliant) ---
## The single, unique, and compiled CharacterBody3D node designated as the quest target.
## Prevents multiple entities from claiming the gold star indicator simultaneously.
var active_quest_target_node: CharacterBody3D = null


func _init() -> void:
	pass


## Converts a global 3D coordinate to its corresponding chunk index coordinate.
func global_to_chunk_pos(global_pos: Vector3i) -> Vector3i:
	return Vector3i(
		floor(float(global_pos.x) / Chunk.SIZE),
		floor(float(global_pos.y) / Chunk.SIZE),
		floor(float(global_pos.z) / Chunk.SIZE)
	)


## Converts a global 3D coordinate to a local coordinate [0..15] within its chunk.
func global_to_local_pos(global_pos: Vector3i) -> Vector3i:
	var local_x: int = global_pos.x % Chunk.SIZE
	var local_y: int = global_pos.y % Chunk.SIZE
	var local_z: int = global_pos.z % Chunk.SIZE
	
	return Vector3i(
		local_x if local_x >= 0 else local_x + Chunk.SIZE,
		local_y if local_y >= 0 else local_y + Chunk.SIZE,
		local_z if local_z >= 0 else local_z + Chunk.SIZE
	)


## Swaps the active timeline, swapping the modifications buffer and clearing physical chunks
func swap_timeline(new_timeline: Timeline) -> void:
	if active_timeline == new_timeline:
		return
		
	active_timeline = new_timeline
	_chunks.clear()
	
	# Clear the unique quest target reference as the world shifts epoch
	active_quest_target_node = null
	
	timeline_swapped.emit(active_timeline)


## Returns a Chunk entity if registered, otherwise returns null.
func get_chunk(chunk_pos: Vector3i) -> Chunk:
	if _chunks.has(chunk_pos):
		return _chunks[chunk_pos] as Chunk
	return null


## Adds or updates a chunk in the state registry.
func add_chunk(chunk: Chunk) -> void:
	_chunks[chunk.position] = chunk


## Removes a chunk from the registry to free system memory.
func remove_chunk(chunk_pos: Vector3i) -> void:
	if _chunks.has(chunk_pos):
		_chunks.erase(chunk_pos)


## Returns the active modifications dictionary for a specific chunk and timeline.
func get_chunk_modifications(chunk_pos: Vector3i) -> Dictionary:
	var active_mods: Dictionary = _timeline_modifications[active_timeline] as Dictionary
	if active_mods.has(chunk_pos):
		return active_mods[chunk_pos] as Dictionary
	return {}


## Unpacks the consolidated dual-timeline dictionary and caches both epochs in RAM
func apply_chunk_modifications(chunk_pos: Vector3i, modifications: Dictionary) -> void:
	var present_mods: Dictionary = {}
	var past_mods: Dictionary = {}
	
	if modifications.has("present") or modifications.has("past"):
		present_mods = modifications.get("present", {}) as Dictionary
		past_mods = modifications.get("past", {}) as Dictionary
	else:
		if active_timeline == Timeline.PRESENT:
			present_mods = modifications
		else:
			past_mods = modifications
			
	_timeline_modifications[Timeline.PRESENT][chunk_pos] = present_mods
	_timeline_modifications[Timeline.PAST][chunk_pos] = past_mods
	
	_write_mods_to_chunk_mesh(chunk_pos, present_mods, past_mods)


func _write_mods_to_chunk_mesh(chunk_pos: Vector3i, present_mods: Dictionary, past_mods: Dictionary) -> void:
	var chunk := get_chunk(chunk_pos)
	if chunk != null:
		var active_mods := present_mods if active_timeline == Timeline.PRESENT else past_mods
		for local_pos: Vector3i in active_mods.keys():
			var type_val: int = active_mods[local_pos] as int
			chunk.set_block(local_pos.x, local_pos.y, local_pos.z, type_val as BlockType.Type)


## Queries any block in global world space coordinates.
func get_block(global_pos: Vector3i) -> BlockType.Type:
	var chunk_pos := global_to_chunk_pos(global_pos)
	var chunk := get_chunk(chunk_pos)
	if chunk == null:
		return BlockType.Type.AIR
	
	var local_pos := global_to_local_pos(global_pos)
	return chunk.get_block(local_pos.x, local_pos.y, local_pos.z)


## Sets a block in global world space coordinates and logs the modification.
func set_block(global_pos: Vector3i, type: BlockType.Type) -> void:
	if global_pos.y <= 0:
		return
		
	var chunk_pos := global_to_chunk_pos(global_pos)
	var chunk := get_chunk(chunk_pos)
	
	if chunk == null:
		chunk = Chunk.new(chunk_pos)
		add_chunk(chunk)
		
	var local_pos := global_to_local_pos(global_pos)
	chunk.set_block(local_pos.x, local_pos.y, local_pos.z, type)
	
	var active_mods: Dictionary = _timeline_modifications[active_timeline] as Dictionary
	if not active_mods.has(chunk_pos):
		active_mods[chunk_pos] = {}
	active_mods[chunk_pos][local_pos] = type


# ==============================================================================
# CORE GEOGRAPHIC DOMAIN RULES (DDD Pure Domain)
# ==============================================================================

## Domain Rule: Performs a vertical downward scan from max altitude (Y=31)
func get_highest_solid_y(global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		if BlockType.is_solid(get_block(check_pos)):
			var space_above_1 := get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 2.0
	return 14.0 # Default safe fallback above water level
