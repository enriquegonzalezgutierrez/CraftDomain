# ==============================================================================
# Pathfile: res://src/Infrastructure/World/ChunkNavigationBuilder.gd
# Description: Infrastructure Service compiling spatial voxel grids into 3D 
#              navigation nodes with fast-path AStar graph node re-evaluations.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkNavigationBuilder
extends RefCounted

const HORIZONTAL_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]


## Loops through the 4096 voxel nodes of a chunk in the background, compiling 
## a pre-filtered array of walkable coordinate nodes and their roofed status.
static func compile_walkable_nodes_asynchronous(chunk: Chunk, world_state: WorldState) -> Array[Dictionary]:
	var walkable_list: Array[Dictionary] = []
	var chunk_offset: Vector3i = chunk.position * Chunk.SIZE
	
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				var local_pos := Vector3i(x, y, z)
				var global_pos := chunk_offset + local_pos
				
				if _is_node_walkable_local(chunk, local_pos, global_pos, world_state):
					var is_roofed := _check_is_roofed_local(chunk, local_pos, global_pos, world_state)
					walkable_list.append({
						"pos": global_pos,
						"is_roofed": is_roofed
					})
					
	return walkable_list


## Binds pre-filtered, background-compiled navigation nodes directly to 
## the global AStar graph without performing expensive main-thread chunk scans.
static func register_compiled_nodes_synchronous(walkable_nodes: Array[Dictionary], world_state: WorldState, nav_service: VoxelNavigationService) -> void:
	if nav_service == null or walkable_nodes.is_empty():
		return
		
	for node: Dictionary in walkable_nodes:
		var pos: Vector3i = node["pos"] as Vector3i
		var is_roofed: bool = node["is_roofed"] as bool
		nav_service.add_navigation_node(pos, is_roofed)
		
	for node: Dictionary in walkable_nodes:
		var pos: Vector3i = node["pos"] as Vector3i
		_connect_walkable_neighbors(pos, world_state, nav_service)


## Reactive API: Updates the global A* navigation graph dynamically when a block is modified.
static func update_navigation_on_block_modified(global_pos: Vector3i, _type: BlockType.Type, world_state: WorldState, nav_service: VoxelNavigationService) -> void:
	if nav_service == null or world_state == null:
		return
		
	for offset_y: int in range(-1, 3):
		var eval_pos := global_pos + Vector3i(0, offset_y, 0)
		_re_evaluate_node_integrity(eval_pos, world_state, nav_service)


static func _re_evaluate_node_integrity(pos: Vector3i, world_state: WorldState, nav_service: VoxelNavigationService) -> void:
	var currently_walkable := _is_node_walkable_global(pos, world_state)
	var registered_in_graph := nav_service._coord_to_id.has(pos)
	
	if currently_walkable:
		if not registered_in_graph:
			var is_roofed := _check_is_roofed_global(pos, world_state)
			nav_service.add_navigation_node(pos, is_roofed)
		_connect_walkable_neighbors(pos, world_state, nav_service)
	else:
		if registered_in_graph:
			nav_service.remove_navigation_node(pos)


static func _get_block_safe(chunk: Chunk, local_pos: Vector3i, global_pos: Vector3i, world_state: WorldState) -> BlockType.Type:
	if local_pos.x >= 0 and local_pos.x < Chunk.SIZE and \
	   local_pos.y >= 0 and local_pos.y < Chunk.SIZE and \
	   local_pos.z >= 0 and local_pos.z < Chunk.SIZE:
		return chunk.get_block(local_pos.x, local_pos.y, local_pos.z)
	return world_state.get_block(global_pos)


static func _is_node_walkable_local(chunk: Chunk, local_pos: Vector3i, global_pos: Vector3i, world_state: WorldState) -> bool:
	var below_local := local_pos + Vector3i(0, -1, 0)
	var below_global := global_pos + Vector3i(0, -1, 0)
	var block_below := _get_block_safe(chunk, below_local, below_global, world_state)
	
	if not BlockLibrary.is_solid(block_below) or block_below == BlockType.Type.WATER or block_below == BlockType.Type.LAVA:
		return false
		
	var block_self := _get_block_safe(chunk, local_pos, global_pos, world_state)
	if BlockLibrary.is_solid(block_self):
		return false
		
	var above_local := local_pos + Vector3i(0, 1, 0)
	var above_global := global_pos + Vector3i(0, 1, 0)
	var block_above := _get_block_safe(chunk, above_local, above_global, world_state)
	if BlockLibrary.is_solid(block_above):
		return false
		
	return true


static func _check_is_roofed_local(chunk: Chunk, local_pos: Vector3i, global_pos: Vector3i, world_state: WorldState) -> bool:
	for offset_y in range(3, 7):
		var check_local := local_pos + Vector3i(0, offset_y, 0)
		var check_global := global_pos + Vector3i(0, offset_y, 0)
		var block_above := _get_block_safe(chunk, check_local, check_global, world_state)
		if BlockLibrary.is_solid(block_above):
			return true
	return false


static func _is_node_walkable_global(pos: Vector3i, world_state: WorldState) -> bool:
	var block_below := world_state.get_block(pos + Vector3i(0, -1, 0))
	if not BlockLibrary.is_solid(block_below) or block_below == BlockType.Type.WATER or block_below == BlockType.Type.LAVA:
		return false
		
	var block_self := world_state.get_block(pos)
	if BlockLibrary.is_solid(block_self):
		return false
		
	var block_above := world_state.get_block(pos + Vector3i(0, 1, 0))
	if BlockLibrary.is_solid(block_above):
		return false
		
	return true


static func _check_is_roofed_global(pos: Vector3i, world_state: WorldState) -> bool:
	for offset_y in range(3, 7):
		var check_pos := pos + Vector3i(0, offset_y, 0)
		var block_above := world_state.get_block(check_pos)
		if BlockLibrary.is_solid(block_above):
			return true
	return false


static func _connect_walkable_neighbors(pos: Vector3i, world_state: WorldState, nav_service: VoxelNavigationService) -> void:
	for offset: Vector3i in HORIZONTAL_OFFSETS:
		var neighbor_flat := pos + offset
		var neighbor_chunk_pos := world_state.global_to_chunk_pos(neighbor_flat)
		if world_state.get_chunk(neighbor_chunk_pos) == null:
			continue
		
		_connect_flat_node(pos, neighbor_flat, nav_service)
		_connect_stair_nodes(pos, offset, nav_service, world_state)


static func _connect_flat_node(pos: Vector3i, neighbor_flat: Vector3i, nav_service: VoxelNavigationService) -> void:
	if nav_service._coord_to_id.has(neighbor_flat):
		nav_service.connect_nodes(pos, neighbor_flat)


static func _connect_stair_nodes(pos: Vector3i, offset: Vector3i, nav_service: VoxelNavigationService, world_state: WorldState) -> void:
	var neighbor_up := pos + offset + Vector3i(0, 1, 0)
	if nav_service._coord_to_id.has(neighbor_up):
		if _is_stair_path_clear(pos, offset, 1, world_state):
			nav_service.connect_nodes(pos, neighbor_up)
			
	var neighbor_down := pos + offset + Vector3i(0, -1, 0)
	if nav_service._coord_to_id.has(neighbor_down):
		if _is_stair_path_clear(pos, offset, 0, world_state):
			nav_service.connect_nodes(pos, neighbor_down)


static func _is_stair_path_clear(pos: Vector3i, offset: Vector3i, height_offset: int, world_state: WorldState) -> bool:
	var wall_check := world_state.get_block(pos + offset)
	var ceiling_check := world_state.get_block(pos + offset + Vector3i(0, height_offset, 0))
	return not BlockLibrary.is_solid(wall_check) and not BlockLibrary.is_solid(ceiling_check)
