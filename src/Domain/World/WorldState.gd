# ==============================================================================
# Project: CraftDomain
# Description: Domain Aggregate Root representing the global voxel world, managing
#              chunk storage, coordinate systems, and block modification tracking.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Coordinates block writes 
#                and modifications.
#              - Domain-Driven Design (DDD): Centralizes core geographic rules 
#                (like vertical ground scans) in the Domain layer, preventing 
#                Domain leakage to Infrastructure.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldState.gd
# ==============================================================================
class_name WorldState
extends RefCounted

## Dictionary storing chunks, mapping Vector3i (chunk coordinates) -> Chunk.
var _chunks: Dictionary = {}

## Tracker dictionary mapping Vector3i (chunk coordinates) -> Dictionary (local block coordinates -> BlockType.Type)
var _chunk_modifications: Dictionary = {}


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


## Returns a Chunk entity if registered, otherwise returns null.
func get_chunk(chunk_pos: Vector3i) -> Chunk:
	if _chunks.has(chunk_pos):
		return _chunks[chunk_pos]
	return null


## Adds or updates a chunk in the state registry.
func add_chunk(chunk: Chunk) -> void:
	_chunks[chunk.position] = chunk


## Removes a chunk from the registry to free system memory.
func remove_chunk(chunk_pos: Vector3i) -> void:
	if _chunks.has(chunk_pos):
		_chunks.erase(chunk_pos)


## Returns the modification dictionary for a specific chunk (Returns empty if none).
func get_chunk_modifications(chunk_pos: Vector3i) -> Dictionary:
	if _chunk_modifications.has(chunk_pos):
		return _chunk_modifications[chunk_pos]
	return {}


## Overwrites and applies a list of saved modifications to a chunk's voxel grid.
func apply_chunk_modifications(chunk_pos: Vector3i, modifications: Dictionary) -> void:
	_chunk_modifications[chunk_pos] = modifications
	var chunk := get_chunk(chunk_pos)
	if chunk != null:
		for local_pos in modifications.keys():
			var pos: Vector3i = local_pos
			chunk.set_block(pos.x, pos.y, pos.z, modifications[local_pos])


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
	var chunk_pos := global_to_chunk_pos(global_pos)
	var chunk := get_chunk(chunk_pos)
	
	# If chunk does not exist on writing, we create a new one dynamically.
	if chunk == null:
		chunk = Chunk.new(chunk_pos)
		add_chunk(chunk)
		
	var local_pos := global_to_local_pos(global_pos)
	chunk.set_block(local_pos.x, local_pos.y, local_pos.z, type)
	
	# Log the modification delta
	if not _chunk_modifications.has(chunk_pos):
		_chunk_modifications[chunk_pos] = {}
	_chunk_modifications[chunk_pos][local_pos] = type


# ==============================================================================
# CORE GEOGRAPHIC DOMAIN RULES (DDD Pure Domain)
# ==============================================================================

## Domain Rule: Performs a vertical downward scan from max altitude (Y=31)
## to locate the coordinates of the highest solid ground surface block.
## Returns the safe pivot Y coordinate + 2.0 (air space), or a default height (e.g. 14.0) if none found.
func get_highest_solid_y(global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		if BlockType.is_solid(get_block(check_pos)):
			# Ensure there is enough open space above (2 empty blocks) to place entities/player
			var space_above_1 := get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				# FIXED: Return float(y) + 2.0 (safe capsule origin above solid block top face)
				return float(y) + 2.0
	return 14.0 # Default safe fallback above water level
