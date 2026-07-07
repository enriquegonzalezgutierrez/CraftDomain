# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service managing the abstract 3D navigation graph.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively graph nodes allocation,
#   coordinate-to-ID translations, and mathematical path routing.
# - Open-Closed Principle (OCP): Fully generic. Walkable connections are mapped 
#   using dynamic coordinate offsets, supporting stairs, steps, or vertical ladders.
# - Dependency Inversion Principle (DIP): Pure data-oriented RefCounted service,
#   completely decoupled from Godot's SceneTree, PhysicsServers, or RenderingServer.
# SHELTER-SEEKING SCHEDULE UPGRADE:
# - Added a thread-safe `_indoor_nodes` cache array to store shelter coordinates (roofed blocks).
# - Implemented `find_closest_shelter_node` to allow civilian NPCs to instantly locate 
#   the nearest indoor safety coordinate during nightfall or storm cycles.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/VoxelNavigationService.gd
# ==============================================================================
class_name VoxelNavigationService
extends RefCounted

# High-performance C++ data-oriented pathfinding solver
var _astar: AStar3D

# Bidirectional dictionaries mapping world coordinates to unique sequential graph IDs
var _coord_to_id: Dictionary = {} # Vector3i -> int
var _id_to_coord: Dictionary = {} # int -> Vector3i
var _next_id: int = 1

# Thread-safe array cache storing registered indoor/roofed shelter coordinates
var _indoor_nodes: Array[Vector3i] = []

# Mutex to ensure thread-safety during parallel chunk loading compilations
var _lock: Mutex


func _init() -> void:
	_astar = AStar3D.new()
	_lock = Mutex.new()


## Registers a walkable node coordinate into the navigation graph if not already present.
## Also registers it as an indoor shelter if flagged as roofed by the compiler.
func add_navigation_node(coord: Vector3i, is_roofed: bool = false) -> void:
	_lock.lock()
	if _coord_to_id.has(coord):
		# If already exists but is now flagged as roofed, update the shelter cache
		if is_roofed and not _indoor_nodes.has(coord):
			_indoor_nodes.append(coord)
		_lock.unlock()
		return
		
	var node_id := _next_id
	_next_id += 1
	
	_coord_to_id[coord] = node_id
	_id_to_coord[node_id] = coord
	
	var world_pos := Vector3(float(coord.x) + 0.5, float(coord.y) + 0.05, float(coord.z) + 0.5)
	_astar.add_point(node_id, world_pos)
	
	if is_roofed:
		_indoor_nodes.append(coord)
		
	_lock.unlock()


## Removes a coordinate from the navigation graph and clears it from shelter caches.
func remove_navigation_node(coord: Vector3i) -> void:
	_lock.lock()
	if not _coord_to_id.has(coord):
		_lock.unlock()
		return
		
	var node_id: int = _coord_to_id[coord]
	_astar.remove_point(node_id)
	_coord_to_id.erase(coord)
	_id_to_coord.erase(node_id)
	
	if _indoor_nodes.has(coord):
		_indoor_nodes.erase(coord)
		
	_lock.unlock()


## Links two registered coordinate nodes bidirectionally in the graph.
func connect_nodes(coord_a: Vector3i, coord_b: Vector3i) -> void:
	_lock.lock()
	if not _coord_to_id.has(coord_a) or not _coord_to_id.has(coord_b):
		_lock.unlock()
		return
		
	var id_a: int = _coord_to_id[coord_a]
	var id_b: int = _coord_to_id[coord_b]
	
	_astar.connect_points(id_a, id_b, true) # True for bidirectional traversal
	_lock.unlock()


## Clears connections between two coordinates.
func disconnect_nodes(coord_a: Vector3i, coord_b: Vector3i) -> void:
	_lock.lock()
	if not _coord_to_id.has(coord_a) or not _coord_to_id.has(coord_b):
		_lock.unlock()
		return
		
	var id_a: int = _coord_to_id[coord_a]
	var id_b: int = _coord_to_id[coord_b]
	
	_astar.disconnect_points(id_a, id_b, true)
	_lock.unlock()


## Cleans up all data structures (Useful during world unloads or fast travel relocations)
func clear_graph() -> void:
	_lock.lock()
	_astar.clear()
	_coord_to_id.clear()
	_id_to_coord.clear()
	_indoor_nodes.clear()
	_next_id = 1
	_lock.unlock()


## Computes the shortest, most optimal path between two global world coordinates.
## Returns an array of world-space positions, or an empty array if blocked.
func find_path(start_pos: Vector3, target_pos: Vector3) -> Array[Vector3]:
	_lock.lock()
	if _coord_to_id.is_empty():
		_lock.unlock()
		return []
		
	# 1. Translate world floats to integer voxel coordinates
	var start_coord := Vector3i(floori(start_pos.x), floori(start_pos.y), floori(start_pos.z))
	var target_coord := Vector3i(floori(target_pos.x), floori(target_pos.y), floori(target_pos.z))
	
	# 2. Locate the closest registered graph IDs
	var start_id := _astar.get_closest_point(Vector3(start_coord))
	var target_id := _astar.get_closest_point(Vector3(target_coord))
	
	# Fallback check: If the targets map to invalid IDs, cancel routing
	if start_id == -1 or target_id == -1:
		_lock.unlock()
		return []
		
	# 3. Solve the path using high-performance A* heuristic calculations
	var id_path := _astar.get_id_path(start_id, target_id)
	var world_path: Array[Vector3] = []
	
	# Translate sequential integer IDs back to floating world coordinates
	for node_id: int in id_path:
		if _id_to_coord.has(node_id):
			var coord: Vector3i = _id_to_coord[node_id]
			# Placed slightly above block floor to prevent capsule interpenetration clipping
			world_path.append(Vector3(float(coord.x) + 0.5, float(coord.y) + 0.1, float(coord.z) + 0.5))
			
	_lock.unlock()
	return world_path


# ==============================================================================
# PROACTIVE SHELTER SEEKING GEOMETRIES (Phase 2)
# ==============================================================================

## Proximity Scanner: Returns the global coordinates of the closest registered 
## roofed shelter block relative to the querying NPC position.
## Returns Vector3.ZERO if no indoor nodes are loaded yet.
func find_closest_shelter_node(from_pos: Vector3) -> Vector3:
	_lock.lock()
	if _indoor_nodes.is_empty():
		_lock.unlock()
		return Vector3.ZERO # No shelters registered in this region yet
		
	var closest_coord := Vector3i.ZERO
	var min_dist_sq := 999999.0
	
	for coord: Vector3i in _indoor_nodes:
		var dist_sq := from_pos.distance_squared_to(Vector3(coord))
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_coord = coord
			
	_lock.unlock()
	return Vector3(float(closest_coord.x) + 0.5, float(closest_coord.y) + 0.1, float(closest_coord.z) + 0.5)


## Debug Helper: Returns the total count of active walkable nodes registered in the graph
func get_total_nodes_count() -> int:
	_lock.lock()
	var count := _coord_to_id.size()
	_lock.unlock()
	return count
