# ==============================================================================
# Pathfile: res://src/Domain/World/VoxelNavigationService.gd
# Description: Pure Domain Service managing the abstract 3D A* navigation graph
#              with automatic doorway, archway, and exit detection.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelNavigationService
extends RefCounted

var _astar: AStar3D

var _coord_to_id: Dictionary = {} 
var _id_to_coord: Dictionary = {} 
var _next_id: int = 1

var _indoor_nodes: Array[Vector3i] = []
var _lock: Mutex


func _init() -> void:
	_astar = AStar3D.new()
	_lock = Mutex.new()


func add_navigation_node(coord: Vector3i, is_roofed: bool = false) -> void:
	_lock.lock()
	if _coord_to_id.has(coord):
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


func connect_nodes(coord_a: Vector3i, coord_b: Vector3i) -> void:
	_lock.lock()
	if not _coord_to_id.has(coord_a) or not _coord_to_id.has(coord_b):
		_lock.unlock()
		return
		
	var id_a: int = _coord_to_id[coord_a]
	var id_b: int = _coord_to_id[coord_b]
	
	_astar.connect_points(id_a, id_b, true)
	_lock.unlock()


func disconnect_nodes(coord_a: Vector3i, coord_b: Vector3i) -> void:
	_lock.lock()
	if not _coord_to_id.has(coord_a) or not _coord_to_id.has(coord_b):
		_lock.unlock()
		return
		
	var id_a: int = _coord_to_id[coord_a]
	var id_b: int = _coord_to_id[coord_b]
	
	_astar.disconnect_points(id_a, id_b, true)
	_lock.unlock()


func clear_graph() -> void:
	_lock.lock()
	_astar.clear()
	_coord_to_id.clear()
	_id_to_coord.clear()
	_indoor_nodes.clear()
	_next_id = 1
	_lock.unlock()


func find_path(start_pos: Vector3, target_pos: Vector3) -> Array[Vector3]:
	_lock.lock()
	if _coord_to_id.is_empty():
		_lock.unlock()
		return []
		
	var start_coord := Vector3i(floori(start_pos.x), floori(start_pos.y), floori(start_pos.z))
	var target_coord := Vector3i(floori(target_pos.x), floori(target_pos.y), floori(target_pos.z))
	
	var start_id := _resolve_target_id(start_coord)
	var target_id := _resolve_target_id(target_coord)
	
	if start_id == -1 or target_id == -1:
		_lock.unlock()
		return []
		
	var id_path := _astar.get_id_path(start_id, target_id)
	var world_path := _translate_id_path_to_world(id_path)
	
	_lock.unlock()
	return world_path


func find_closest_exit_node(from_pos: Vector3) -> Vector3:
	_lock.lock()
	if _coord_to_id.is_empty():
		_lock.unlock()
		return Vector3.ZERO
		
	var closest_coord := Vector3i.ZERO
	var min_dist_sq := 999999.0
	
	for coord: Vector3i in _coord_to_id.keys():
		if not _indoor_nodes.has(coord):
			var dist_sq := from_pos.distance_squared_to(Vector3(coord))
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_coord = coord
				
	_lock.unlock()
	if closest_coord == Vector3i.ZERO:
		return Vector3.ZERO
	return Vector3(float(closest_coord.x) + 0.5, float(closest_coord.y) + 0.1, float(closest_coord.z) + 0.5)


func get_random_walkable_node_near(from_pos: Vector3, min_dist: float, max_dist: float) -> Vector3:
	_lock.lock()
	if _coord_to_id.is_empty():
		_lock.unlock()
		return Vector3.ZERO
		
	var candidates: Array[Vector3i] = []
	var min_sq := min_dist * min_dist
	var max_sq := max_dist * max_dist
	
	for coord: Vector3i in _coord_to_id.keys():
		var dist_sq := from_pos.distance_squared_to(Vector3(coord))
		if dist_sq >= min_sq and dist_sq <= max_sq:
			candidates.append(coord)
			
	_lock.unlock()
	if candidates.is_empty():
		return Vector3.ZERO
		
	var chosen := candidates[randi() % candidates.size()]
	return Vector3(float(chosen.x) + 0.5, float(chosen.y) + 0.1, float(chosen.z) + 0.5)


func find_closest_doorway_node(from_pos: Vector3) -> Vector3:
	_lock.lock()
	if _coord_to_id.is_empty():
		_lock.unlock()
		return Vector3.ZERO
		
	var closest_door := Vector3i.ZERO
	var min_dist_sq := 999999.0
	
	for coord: Vector3i in _coord_to_id.keys():
		if _is_node_a_doorway(coord):
			var dist_sq := from_pos.distance_squared_to(Vector3(coord))
			if dist_sq < min_dist_sq and dist_sq > 0.8:
				min_dist_sq = dist_sq
				closest_door = coord
				
	_lock.unlock()
	if closest_door == Vector3i.ZERO:
		return Vector3.ZERO
	return Vector3(float(closest_door.x) + 0.5, float(closest_door.y) + 0.1, float(closest_door.z) + 0.5)


func _is_node_a_doorway(coord: Vector3i) -> bool:
	var left_right_blocked := not _coord_to_id.has(coord + Vector3i(1, 0, 0)) and not _coord_to_id.has(coord + Vector3i(-1, 0, 0))
	var front_back_open := _coord_to_id.has(coord + Vector3i(0, 0, 1)) and _coord_to_id.has(coord + Vector3i(0, 0, -1))
	var is_z_passage := left_right_blocked and front_back_open
	
	var front_back_blocked := not _coord_to_id.has(coord + Vector3i(0, 0, 1)) and not _coord_to_id.has(coord + Vector3i(0, 0, -1))
	var left_right_open := _coord_to_id.has(coord + Vector3i(1, 0, 0)) and _coord_to_id.has(coord + Vector3i(-1, 0, 0))
	var is_x_passage := front_back_blocked and left_right_open
	
	return is_z_passage or is_x_passage


func _resolve_target_id(target_coord: Vector3i) -> int:
	if _coord_to_id.has(target_coord):
		return _coord_to_id[target_coord] as int
		
	var closest_id := -1
	var min_dist_sq := 9999.0
	
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var neighbor := target_coord + Vector3i(x, y, z)
				if _coord_to_id.has(neighbor):
					var dist_sq := float(x*x + y*y + z*z)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_id = _coord_to_id[neighbor] as int
						
	if closest_id != -1:
		return closest_id
	return _astar.get_closest_point(Vector3(target_coord))


func _translate_id_path_to_world(id_path: PackedInt64Array) -> Array[Vector3]:
	var world_path: Array[Vector3] = []
	for node_id in id_path:
		var id_int := int(node_id)
		if _id_to_coord.has(id_int):
			var coord: Vector3i = _id_to_coord[id_int]
			world_path.append(Vector3(float(coord.x) + 0.5, float(coord.y) + 0.1, float(coord.z) + 0.5))
	return world_path


func find_closest_shelter_node(from_pos: Vector3) -> Vector3:
	_lock.lock()
	if _indoor_nodes.is_empty():
		_lock.unlock()
		return Vector3.ZERO
		
	var closest_coord := Vector3i.ZERO
	var min_dist_sq := 999999.0
	
	for coord: Vector3i in _indoor_nodes:
		var dist_sq := from_pos.distance_squared_to(Vector3(coord))
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest_coord = coord
			
	_lock.unlock()
	return Vector3(float(closest_coord.x) + 0.5, float(closest_coord.y) + 0.1, float(closest_coord.z) + 0.5)


func get_total_nodes_count() -> int:
	_lock.lock()
	var count := _coord_to_id.size()
	_lock.unlock()
	return count
