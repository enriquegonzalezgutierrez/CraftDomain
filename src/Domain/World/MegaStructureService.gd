# ==============================================================================
# Project: CraftDomain
# Description: Domain Service managing registration, lookup, and physical block 
#              generation routing of large fixed Mega-Structures (POIs).
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Only manages global fixed 
#                landmarks and their chunk-offset calculations.
#              - Open-Closed Principle (OCP): Registers default mega-structures 
#                internally on startup, removing registration bloat from Bootstrap.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MegaStructureService.gd
# ==============================================================================
class_name MegaStructureService
extends RefCounted

## Dynamic registry holding all active global fixed points of interest.
static var _structures: Array[IMegaStructure] = []


## Startup Initializer: Instantiates and registers the default set of 
## global fixed POI mega-structures, keeping Bootstrap.gd clean.
static func initialize_megastructures() -> void:
	print("[MegaStructureService] Initializing and registering fixed POI Mega-Structures...")
	_structures.clear()
	
	register_structure(GrandCastleMegaStructure.new())
	register_structure(HarborCityMegaStructure.new())
	register_structure(NetherPortalMegaStructure.new())
	register_structure(StevesCabinMegaStructure.new())
	
	print("[MegaStructureService] Initialization complete. Registered Mega-Structures count: ", _structures.size())


## Static registry API: Registers a new fixed mega-structure at boot.
static func register_structure(structure: IMegaStructure) -> void:
	if structure != null:
		_structures.append(structure)


## Called by WorldGenerator. Checks if the chunk overlaps any mega-structure and applies it.
static func apply_mega_structures(chunk: Chunk) -> void:
	if _structures.size() == 0:
		return
		
	var c_pos := chunk.position * Chunk.SIZE
	var chunk_rect := Rect2i(c_pos.x, c_pos.z, Chunk.SIZE, Chunk.SIZE)
	
	for s in _structures:
		var s_rect := Rect2i(
			s.global_center.x - int(s.bounds_size.x / 2.0),
			s.global_center.y - int(s.bounds_size.y / 2.0),
			s.bounds_size.x,
			s.bounds_size.y
		)
		
		# If the chunk intersects the structure's territory, let it sculpt!
		if chunk_rect.intersects(s_rect):
			s.build_chunk(chunk, c_pos)


## Consults structures if they have specific entities (Guards/NPCs/Props) for this chunk.
static func get_entities_for_chunk(chunk_pos: Vector3i) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	for s in _structures:
		entities.append_array(s.get_entities_for_chunk(chunk_pos))
	return entities


## Public API: Returns all globally registered fixed points of interest.
static func get_structures() -> Array[IMegaStructure]:
	return _structures
