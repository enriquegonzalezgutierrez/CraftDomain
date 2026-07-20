# ==============================================================================
# Pathfile: res://src/Domain/World/StructuralIntegritySolver.gd
# Description: Pure Domain solver calculating block connectivity networks
#              and horizontal cantilever tensile limits to verify structural 
#              anchorage.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates block stability 
#   calculations and mass tension limits, fully decoupled from physics bodies.
# - Open-Closed Principle (OCP): Easily extendable with new material specific 
#   tensile strengths inside the CANTILEVER_LIMITS dictionary.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# - BUG FIX: Redirected all physics queries to the uncoupled BlockLibrary.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StructuralIntegritySolver
extends RefCounted

const BEDROCK_Y_LEVEL: int = 0

const CANTILEVER_LIMITS: Dictionary = {
	BlockType.Type.STONE: 2,
	BlockType.Type.COBBLESTONE: 2,
	BlockType.Type.STONE_BRICKS: 3,
	BlockType.Type.BRICKS: 3,
	BlockType.Type.WOOD: 4,
	BlockType.Type.BIRCH_LOG: 4,
	BlockType.Type.SPRUCE_LOG: 4,
	BlockType.Type.OAK_PLANKS: 5,
	BlockType.Type.SPRUCE_PLANKS: 5,
	BlockType.Type.LEAVES: 1,
	BlockType.Type.SPRUCE_LEAVES: 1
}

const DEFAULT_CANTILEVER_LIMIT: int = 2

const ADJACENT_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]


## Evaluates if the block at the target coordinate is structurally supported.
func verify_integrity(start_coord: Vector3i, world_state: WorldState) -> bool:
	if world_state == null:
		return false
		
	var start_block := world_state.get_block(start_coord)
	if not BlockLibrary.is_solid(start_block):
		return true 
		
	if start_coord.y <= BEDROCK_Y_LEVEL:
		return true 
		
	if _is_vertically_supported(start_coord, world_state):
		return true
		
	return _solve_cantilever_limit(start_coord, start_block, world_state)


## Vertical Scanner: Determines if a coordinate is stacked on top of a continuous 
## solid column leading all the way down to a solid foundation or bedrock.
func _is_vertically_supported(coord: Vector3i, world_state: WorldState) -> bool:
	var current := coord + Vector3i(0, -1, 0)
	
	while current.y >= BEDROCK_Y_LEVEL:
		var block := world_state.get_block(current)
		if not BlockLibrary.is_solid(block):
			return false 
			
		var is_natural := (block == BlockType.Type.STONE or block == BlockType.Type.OBSIDIAN)
		if current.y == BEDROCK_Y_LEVEL or is_natural:
			return true
			
		current.y -= 1
		
	return false


## Horizontal BFS: Calculates the shortest horizontal distance of solid blocks 
func _solve_cantilever_limit(start_coord: Vector3i, start_block: BlockType.Type, world_state: WorldState) -> bool:
	var max_limit := CANTILEVER_LIMITS.get(start_block, DEFAULT_CANTILEVER_LIMIT) as int
	var queue: Array[Array] = [[start_coord, 0]]
	var visited: Dictionary = {start_coord: true}
	
	while queue.size() > 0:
		var item: Array = queue.pop_front()
		var current: Vector3i = item[0]
		var dist: int = item[1]
		
		if dist > max_limit:
			continue 
			
		if _is_vertically_supported(current, world_state):
			return true
			
		_traverse_neighbors_cantilever(current, dist, queue, visited, world_state)
				
	return false 


func _traverse_neighbors_cantilever(current: Vector3i, dist: int, queue: Array[Array], visited: Dictionary, world_state: WorldState) -> void:
	for offset: Vector3i in ADJACENT_OFFSETS:
		var neighbor := current + offset
		if offset.y != 0:
			continue
			
		if not visited.has(neighbor):
			var neighbor_block := world_state.get_block(neighbor)
			if BlockLibrary.is_solid(neighbor_block):
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
