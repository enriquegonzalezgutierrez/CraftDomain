# ==============================================================================
# Project: CraftDomain
# Description: Domain Registry and Router for Mega-Structures.
#              OCP COMPLIANT: Evaluates chunk AABBs against structure boundaries.
#              FIXED: Integer division warnings resolved using safe float casting.
# Author: Enrique González Gutiérrez
# ==============================================================================
class_name MegaStructureService
extends RefCounted

static var _structures: Array[IMegaStructure] = []

## Registers a new fixed mega-structure at boot
static func register_structure(structure: IMegaStructure) -> void:
	if structure != null:
		_structures.append(structure)
		print("[MegaStructureService] Registered Fixed POI: ", structure.get_name(), " at ", structure.global_center)

## Called by WorldGenerator. Checks if the chunk overlaps any mega-structure and applies it.
static func apply_mega_structures(chunk: Chunk) -> void:
	if _structures.size() == 0:
		return
		
	var c_pos := chunk.position * Chunk.SIZE
	var chunk_rect := Rect2i(c_pos.x, c_pos.z, Chunk.SIZE, Chunk.SIZE)
	
	for s in _structures:
		# FIXED: Safe float division to eliminate INTEGER_DIVISION warnings
		var s_rect := Rect2i(
			s.global_center.x - int(s.bounds_size.x / 2.0),
			s.global_center.y - int(s.bounds_size.y / 2.0),
			s.bounds_size.x,
			s.bounds_size.y
		)
		
		# If the chunk intersects the structure's territory, let it sculpt!
		if chunk_rect.intersects(s_rect):
			s.build_chunk(chunk, c_pos)

## Consults structures if they have specific entities (Guards/NPCs/Props) for this chunk
static func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	for s in _structures:
		entities.append_array(s.get_entities_for_chunk(chunk_pos))
	return entities
