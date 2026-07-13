# ==============================================================================
# Pathfile: res://src/Domain/World/StructuralIntegritySolver.gd
# Description: Pure Domain solver calculating block connectivity networks
#              to verify structural anchorage using optimized BFS traversal.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StructuralIntegritySolver
extends RefCounted

# Structural physics constraints to avoid magic numbers
const MAX_SUPPORT_DISTANCE: int = 16 # Max horizontal/vertical support spans
const BEDROCK_Y_LEVEL: int = 0      # Ground anchors boundary

# Traversal offsets mapping adjacent voxels
const ADJACENT_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]


## Evaluates if the block at the target coordinate is structurally supported.
## Returns true if a path of solid blocks leads to an anchor point, false otherwise.
func verify_integrity(start_coord: Vector3i, world_state: WorldState) -> bool:
	if world_state == null:
		return false
		
	var start_block := world_state.get_block(start_coord)
	if not BlockType.is_solid(start_block):
		return true # Non-solid blocks (Air, Water, Lava) ignore gravity calculations
		
	if start_coord.y <= BEDROCK_Y_LEVEL:
		return true # Direct bedrock contact acts as a permanent anchor
		
	return _solve_support_path_bfs(start_coord, world_state)


## Internal Helper: Solves the shortest path to an anchor using Breadth-First Search (BFS)
func _solve_support_path_bfs(start_coord: Vector3i, world_state: WorldState) -> bool:
	# FIFO Queue containing coordinates to explore
	var queue: Array[Vector3i] = [start_coord]
	
	# Maps Vector3i (visited coordinates) -> int (distance steps from start)
	var visited: Dictionary = {start_coord: 0}
	
	while queue.size() > 0:
		var current: Vector3i = queue.pop_front() as Vector3i
		var current_depth: int = visited[current] as int
		
		# If we hit an anchor, the entire structure is stable!
		if _is_coordinate_anchor(current, world_state):
			return true
			
		if current_depth >= MAX_SUPPORT_DISTANCE:
			continue # Stop search along this branch (exceeded safe cantilevering limit)
			
		# Enqueue adjacent solid blocks
		for offset: Vector3i in ADJACENT_OFFSETS:
			var neighbor := current + offset
			
			if not visited.has(neighbor):
				var neighbor_block := world_state.get_block(neighbor)
				if BlockType.is_solid(neighbor_block):
					visited[neighbor] = current_depth + 1
					queue.append(neighbor)
					
	return false # No stable anchor point discovered within distance limits


## Evaluates if a specific coordinate serves as a permanent structural support.
func _is_coordinate_anchor(coord: Vector3i, world_state: WorldState) -> bool:
	if coord.y <= BEDROCK_Y_LEVEL:
		return true # Sits flat on the indestructible bottom crust
		
	# Check if the block sits directly on top of a bedrock or naturally spawned terrain anchor.
	# We query if the block below is solid and sits at the base.
	var block_below_coord := coord + Vector3i(0, -1, 0)
	var block_below := world_state.get_block(block_below_coord)
	
	# Solid natural stone or ores serve as stable foundations
	var is_natural_ground := (
		block_below == BlockType.Type.STONE or 
		block_below == BlockType.Type.COAL_ORE or
		block_below == BlockType.Type.DIAMOND_ORE
	)
	
	return block_below_coord.y <= BEDROCK_Y_LEVEL or (is_natural_ground and BlockType.is_solid(block_below))
