# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Interface for Global Mega-Structures.
#              Allows defining massive handcrafted POIs (Points of Interest)
#              that span across multiple chunks at fixed global coordinates.
# Author: Enrique González Gutiérrez
# ==============================================================================
class_name IMegaStructure
extends RefCounted

var global_center: Vector2i = Vector2i.ZERO
var bounds_size: Vector2i = Vector2i.ZERO

func get_name() -> String:
	return "Unknown MegaStructure"

## Abstract Contract: Executed only if the current chunk overlaps the bounding box.
func build_chunk(_chunk: Chunk, _chunk_offset: Vector3i) -> void:
	assert(false, "[IMegaStructure] build_chunk() must be implemented.")

## Virtual Contract: Returns a list of dictionaries with "mob_id" and "pos" (Vector3)
## to spawn custom guards, villagers, or props at specific global coordinates.
func get_entities_for_chunk(_chunk_pos: Vector3i) -> Array[Dictionary]:
	return []

## Helper Method: Draws a block in global coordinates. Automatically discards 
## the operation if the block falls outside the currently evaluating chunk.
func set_global_block(chunk: Chunk, chunk_offset: Vector3i, gx: int, gy: int, gz: int, type: BlockType.Type) -> void:
	var lx := gx - chunk_offset.x
	var ly := gy - chunk_offset.y
	var lz := gz - chunk_offset.z
	
	if chunk.is_within_bounds(lx, ly, lz):
		chunk.set_block(lx, ly, lz, type)
