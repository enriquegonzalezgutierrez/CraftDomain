# ==============================================================================
# Project: CraftDomain
# Description: Domain Aggregate Root representing the global voxel world, managing
#              chunk storage and coordinate coordinate conversions.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WorldState.gd
# ==============================================================================
class_name WorldState
extends RefCounted

## Dictionary storing chunks, mapping Vector3i (chunk coordinates) -> Chunk.
var _chunks: Dictionary = {}

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

## Queries any block in global world space coordinates.
func get_block(global_pos: Vector3i) -> BlockType.Type:
	var chunk_pos := global_to_chunk_pos(global_pos)
	var chunk := get_chunk(chunk_pos)
	if chunk == null:
		return BlockType.Type.AIR
	
	var local_pos := global_to_local_pos(global_pos)
	return chunk.get_block(local_pos.x, local_pos.y, local_pos.z)

## Sets a block in global world space coordinates.
func set_block(global_pos: Vector3i, type: BlockType.Type) -> void:
	var chunk_pos := global_to_chunk_pos(global_pos)
	var chunk := get_chunk(chunk_pos)
	
	# If chunk does not exist on writing, we create a new one dynamically.
	if chunk == null:
		chunk = Chunk.new(chunk_pos)
		add_chunk(chunk)
		
	var local_pos := global_to_local_pos(global_pos)
	chunk.set_block(local_pos.x, local_pos.y, local_pos.z, type)
