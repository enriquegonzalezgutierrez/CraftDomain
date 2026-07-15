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
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StructuralIntegritySolver
extends RefCounted

const BEDROCK_Y_LEVEL: int = 0

# Maximum horizontal cantilever distances per material type (OCP Compliant)
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
## Returns true if the block is vertically anchored or within the material's 
## horizontal cantilever limits, false otherwise (initiating physical collapse).
func verify_integrity(start_coord: Vector3i, world_state: WorldState) -> bool:
	if world_state == null:
		return false
		
	var start_block := world_state.get_block(start_coord)
	if not BlockType.is_solid(start_block):
		return true # Fluids, air, and foliage ignore gravity calculations
		
	if start_coord.y <= BEDROCK_Y_LEVEL:
		return true # Permanently anchored to the bottom bedrock floor of the world
		
	# 1. If the block is directly supported by a solid pillar below it, it is stable
	if _is_vertically_supported(start_coord, world_state):
		return true
		
	# 2. Otherwise, calculate its horizontal cantilever distance to the nearest vertical pillar
	return _solve_cantilever_limit(start_coord, start_block, world_state)


## Vertical Scanner: Determines if a coordinate is stacked on top of a continuous 
## solid column leading all the way down to a solid foundation or bedrock.
func _is_vertically_supported(coord: Vector3i, world_state: WorldState) -> bool:
	var current := coord + Vector3i(0, -1, 0)
	
	# Scan straight down to find any air gaps or liquid voids
	while current.y >= BEDROCK_Y_LEVEL:
		var block := world_state.get_block(current)
		if not BlockType.is_solid(block):
			return false # Gap discovered! This column is NOT a stable vertical pillar
			
		# Solid natural stone or indestructible bedrock serves as stable foundations
		var is_natural := (block == BlockType.Type.STONE or block == BlockType.Type.OBSIDIAN)
		if current.y == BEDROCK_Y_LEVEL or is_natural:
			return true
			
		current.y -= 1
		
	return false


## Horizontal BFS: Calculates the shortest horizontal distance of solid blocks 
## connecting this cantilevered node to a vertically supported pillar.
func _solve_cantilever_limit(start_coord: Vector3i, start_block: BlockType.Type, world_state: WorldState) -> bool:
	var max_limit := CANTILEVER_LIMITS.get(start_block, DEFAULT_CANTILEVER_LIMIT) as int
	
	# Queue storing: [current_coordinate (Vector3i), distance_travelled (int)]
	var queue: Array[Array] = [[start_coord, 0]]
	var visited: Dictionary = {start_coord: true}
	
	while queue.size() > 0:
		var item: Array = queue.pop_front()
		var current: Vector3i = item[0]
		var dist: int = item[1]
		
		if dist > max_limit:
			continue # Path exceeded this material's tensile strength limit
			
		# If the current node in the path has solid vertical support below it,
		# we have successfully anchored the cantilever beam!
		if _is_vertically_supported(current, world_state):
			return true
			
		# Traverse adjacent solid neighbors
		for offset: Vector3i in ADJACENT_OFFSETS:
			var neighbor := current + offset
			
			# We only traverse horizontal connections, as vertical connections 
			# are already checked by `_is_vertically_supported`.
			if offset.y != 0:
				continue
				
			if not visited.has(neighbor):
				var neighbor_block := world_state.get_block(neighbor)
				if BlockType.is_solid(neighbor_block):
					visited[neighbor] = true
					queue.append([neighbor, dist + 1])
					
	return false # No vertical pillar found within the material's strength limits
