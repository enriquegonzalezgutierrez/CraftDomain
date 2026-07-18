# ==============================================================================
# Pathfile: res://src/Domain/World/MegaStructureService.gd
# Description: Domain Service managing registration, lookup, and physical block 
#              generation routing of large fixed Mega-Structures (POIs).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only manages global fixed 
#   landmarks, fully decoupled from entity spawning or chunk population rosters.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MegaStructureService
extends RefCounted

## Dynamic registry holding all active global fixed points of interest.
static var _structures: Array[IMegaStructure] = []


## Startup Initializer: Instantiates and registers the default set of 
## global fixed POI mega-structures, keeping Bootstrap.gd clean.
static func initialize_megastructures() -> void:
	_structures.clear()
	
	register_structure(GrandCastleMegaStructure.new())
	register_structure(HarborCityMegaStructure.new())
	register_structure(NetherPortalMegaStructure.new())
	register_structure(StevesCabinMegaStructure.new())
	register_structure(DesertOasisMegaStructure.new())
	register_structure(LithicLurkerLairMegaStructure.new())


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
	
	for s: IMegaStructure in _structures:
		var s_rect := Rect2i(
			s.global_center.x - int(s.bounds_size.x / 2.0),
			s.global_center.y - int(s.bounds_size.y / 2.0),
			s.bounds_size.x,
			s.bounds_size.y
		)
		
		# If the chunk intersects the structure's territory, let it sculpt!
		if chunk_rect.intersects(s_rect):
			s.build_chunk(chunk, c_pos)


## Public API: Returns all globally registered fixed points of interest.
static func get_structures() -> Array[IMegaStructure]:
	return _structures
