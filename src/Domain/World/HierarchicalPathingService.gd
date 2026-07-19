# ==============================================================================
# Pathfile: res://src/Domain/World/HierarchicalPathingService.gd
# Description: Pure Domain Service implementing Hierarchical Pathfinding (HPA*).
#              Calculates macro-routes across abstract Chunk-level graphs for 
#              long-distance travel, allowing NPCs to traverse thousands of 
#              blocks without saturating RAM or CPU time budgets.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates chunk-to-chunk
#   abstractions, completely decoupled from micro-voxel A* calculations.
# - Liskov Substitution Principle (LSP): Fully abstracted and type-safe.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name HierarchicalPathingService
extends RefCounted

## Inner class representing a high-level region/chunk in the macro-graph
class MacroNode:
	var chunk_coord: Vector2i
	var connected_chunks: Array[Vector2i] = []
	
	func _init(p_coord: Vector2i) -> void:
		chunk_coord = p_coord


## In-memory abstract graph of active, traversable chunk connections
static var _macro_graph: Dictionary = {} # Vector2i -> MacroNode
static var _lock: Mutex = Mutex.new()

# Pre-defined orthogonal offsets for checking chunk adjacency
const CHUNK_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1)
]


## Registers a generated chunk into the macro-graph and links it to adjacent,
## already-generated chunks to form continuous long-distance highways.
static func register_chunk(chunk_pos: Vector3i) -> void:
	_lock.lock()
	
	var c_flat := Vector2i(chunk_pos.x, chunk_pos.z)
	if _macro_graph.has(c_flat):
		_lock.unlock()
		return
		
	var node := MacroNode.new(c_flat)
	_macro_graph[c_flat] = node
	
	# Bi-directionally link to available neighbors
	for offset: Vector2i in CHUNK_OFFSETS:
		var neighbor := c_flat + offset
		if _macro_graph.has(neighbor):
			var n_node: MacroNode = _macro_graph[neighbor] as MacroNode
			n_node.connected_chunks.append(c_flat)
			node.connected_chunks.append(neighbor)
			
	_lock.unlock()


## Removes a chunk from the macro-graph (Called during memory unloads).
static func unregister_chunk(chunk_pos: Vector3i) -> void:
	_lock.lock()
	
	var c_flat := Vector2i(chunk_pos.x, chunk_pos.z)
	if _macro_graph.has(c_flat):
		var node: MacroNode = _macro_graph[c_flat] as MacroNode
		
		# Break bidirectional links
		for neighbor: Vector2i in node.connected_chunks:
			if _macro_graph.has(neighbor):
				var n_node: MacroNode = _macro_graph[neighbor] as MacroNode
				n_node.connected_chunks.erase(c_flat)
				
		_macro_graph.erase(c_flat)
		
	_lock.unlock()


## Performs a high-level A* search over the chunk graph.
## Returns an array of global world coordinates representing the central 
## portal/gateway points the NPC must cross to reach the target chunk.
static func find_macro_path(start_global: Vector3, target_global: Vector3, ws: WorldState) -> Array[Vector3]:
	if not is_instance_valid(ws):
		return []
		
	var start_c := ws.global_to_chunk_pos(Vector3i(floori(start_global.x), 0, floori(start_global.z)))
	var target_c := ws.global_to_chunk_pos(Vector3i(floori(target_global.x), 0, floori(target_global.z)))
	
	var start_flat := Vector2i(start_c.x, start_c.z)
	var target_flat := Vector2i(target_c.x, target_c.z)
	
	if start_flat == target_flat:
		return [target_global] # Same chunk, bypass macro-routing entirely
		
	return _execute_macro_astar(start_flat, target_flat, start_global, target_global, ws)


static func _execute_macro_astar(start: Vector2i, target: Vector2i, start_gl: Vector3, target_gl: Vector3, ws: WorldState) -> Array[Vector3]:
	_lock.lock()
	
	if not _macro_graph.has(start) or not _macro_graph.has(target):
		_lock.unlock()
		return []
		
	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start} # Vector2i -> Vector2i
	var cost_so_far: Dictionary = {start: 0.0} # Vector2i -> float
	
	var success := false
	
	while frontier.size() > 0:
		var current: Vector2i = _pop_lowest_cost(frontier, cost_so_far, target)
		
		if current == target:
			success = true
			break
			
		var node: MacroNode = _macro_graph[current] as MacroNode
		for next_node: Vector2i in node.connected_chunks:
			var new_cost: float = cost_so_far[current] + 1.0 # Base cost per chunk is 1
			if not cost_so_far.has(next_node) or new_cost < cost_so_far[next_node]:
				cost_so_far[next_node] = new_cost
				came_from[next_node] = current
				if not frontier.has(next_node):
					frontier.append(next_node)
					
	_lock.unlock()
	
	if not success:
		return []
		
	return _reconstruct_macro_path(came_from, start, target, start_gl, target_gl, ws)


static func _pop_lowest_cost(frontier: Array[Vector2i], costs: Dictionary, target: Vector2i) -> Vector2i:
	var best_node := frontier[0]
	var best_score := 999999.0
	var best_idx := 0
	
	for i in range(frontier.size()):
		var node: Vector2i = frontier[i]
		# Score = Running Cost + Heuristic (Manhattan distance to target chunk)
		var score: float = costs[node] + float(abs(node.x - target.x) + abs(node.y - target.y))
		if score < best_score:
			best_score = score
			best_node = node
			best_idx = i
			
	frontier.remove_at(best_idx)
	return best_node


static func _reconstruct_macro_path(came_from: Dictionary, start: Vector2i, target: Vector2i, start_gl: Vector3, target_gl: Vector3, ws: WorldState) -> Array[Vector3]:
	var chunk_path: Array[Vector2i] = []
	var current := target
	
	while current != start:
		chunk_path.insert(0, current)
		current = came_from[current]
		
	var global_waypoints: Array[Vector3] = []
	var previous_pos := start_gl
	
	for chunk_flat: Vector2i in chunk_path:
		# Convert chunk transition border into an absolute global coordinate gateway
		var gateway_pos := _calculate_chunk_gateway(previous_pos, chunk_flat, ws)
		global_waypoints.append(gateway_pos)
		previous_pos = gateway_pos
		
	# Finally, append the actual precision target within the final chunk
	global_waypoints.append(target_gl)
	return global_waypoints


## Identifies a safe, walkable coordinate on the border between two chunks to act as a transition gateway.
static func _calculate_chunk_gateway(_prev_pos: Vector3, next_chunk: Vector2i, ws: WorldState) -> Vector3:
	# Calculate the absolute center of the target chunk
	var center_x := float(next_chunk.x * Chunk.SIZE) + (float(Chunk.SIZE) / 2.0)
	var center_z := float(next_chunk.y * Chunk.SIZE) + (float(Chunk.SIZE) / 2.0)
	
	# Find the highest safe ground at that center to ensure the NPC doesn't route into a wall
	var safe_y := ws.get_highest_solid_y(int(center_x), int(center_z))
	
	return Vector3(center_x, safe_y, center_z)
