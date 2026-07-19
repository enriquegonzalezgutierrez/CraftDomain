# ==============================================================================
# Pathfile: res://src/Domain/World/IncrementalNavigationService.gd
# Description: Pure Domain Service implementing local path repair algorithms 
#              (D* Lite principles) to patch broken routes dynamically. 
#              Prevents the AI from recalculating massive macro-routes from 
#              scratch every time a player places or destroys a block.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively handles the mathematical
#   splicing and local repair of active coordinate arrays.
# - Liskov Substitution Principle (LSP): Fully compatible with standard Vector3 
#   path arrays returned by the core navigation service.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IncrementalNavigationService
extends RefCounted

## The radius of nodes (in grid steps) to step back and forward from the 
## blockage to establish safe start/end points for the local detour.
const DETOUR_SEARCH_RADIUS: int = 4


## Evaluates if a coordinate change breaks an active path. If so, attempts to
## stitch a localized detour. Returns the repaired path, or an empty array if
## the route is completely severed and requires a full macro-recalculation.
static func repair_path(active_path: Array[Vector3], blocked_coord: Vector3i, nav_graph: VoxelNavigationService) -> Array[Vector3]:
	var block_index := _find_blocked_index(active_path, blocked_coord)
	if block_index == -1:
		return active_path # Path is unaffected by this block change
		
	var safe_start := _get_safe_node_before(active_path, block_index)
	var safe_end := _get_safe_node_after(active_path, block_index)
	
	if safe_start == Vector3.ZERO or safe_end == Vector3.ZERO:
		return [] # Cannot repair; blockage is too close to the endpoints
		
	var detour := _calculate_local_detour(safe_start, safe_end, nav_graph)
	if detour.is_empty():
		return [] # Local repair failed; structural blockage is complete
		
	return _splice_detour(active_path, detour, safe_start, safe_end)


static func _find_blocked_index(path: Array[Vector3], blocked_coord: Vector3i) -> int:
	for i: int in range(path.size()):
		var node: Vector3 = path[i]
		var node_coord := Vector3i(floori(node.x), floori(node.y), floori(node.z))
		if node_coord == blocked_coord:
			return i
	return -1


static func _get_safe_node_before(path: Array[Vector3], blocked_index: int) -> Vector3:
	var target_idx := blocked_index - DETOUR_SEARCH_RADIUS
	if target_idx < 0:
		return Vector3.ZERO # Blockage is right at the start of the path
	return path[target_idx]


static func _get_safe_node_after(path: Array[Vector3], blocked_index: int) -> Vector3:
	var target_idx := blocked_index + DETOUR_SEARCH_RADIUS
	if target_idx >= path.size():
		return Vector3.ZERO # Blockage is right at the final destination
	return path[target_idx]


static func _calculate_local_detour(start_node: Vector3, end_node: Vector3, nav_graph: VoxelNavigationService) -> Array[Vector3]:
	# Ask the AStar graph to find a micro-path strictly between the two safe points,
	# completely bypassing the massive overhead of calculating the entire journey.
	if is_instance_valid(nav_graph):
		return nav_graph.find_path(start_node, end_node)
	return []


static func _splice_detour(original: Array[Vector3], detour: Array[Vector3], start_node: Vector3, end_node: Vector3) -> Array[Vector3]:
	var spliced: Array[Vector3] = []
	var is_skipping := false
	
	for node: Vector3 in original:
		if not is_skipping:
			spliced.append(node)
			if node.distance_squared_to(start_node) < 0.01:
				is_skipping = true
				_append_detour_nodes(spliced, detour)
		else:
			# Stop skipping once we reconnect with the original safe path
			if node.distance_squared_to(end_node) < 0.01:
				is_skipping = false
				spliced.append(node)
				
	return spliced


static func _append_detour_nodes(spliced: Array[Vector3], detour: Array[Vector3]) -> void:
	# Skip the first and last nodes of the detour array, as they correspond 
	# identically to safe_start and safe_end, preventing duplicate waypoints.
	if detour.size() > 2:
		for i: int in range(1, detour.size() - 1):
			spliced.append(detour[i])
