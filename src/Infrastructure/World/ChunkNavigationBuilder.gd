# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service compiling spatial voxel grids into 3D navigation nodes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively spatial chunk scans,
#   identifying walkable block zones, and linking adjacent graph nodes.
# - Open-Closed Principle (OCP): Easily extendable. New block geometries or custom
#   climbs (like ladders or vines) can be integrated by adding offset connect rules.
# - Dependency Inversion Principle (DIP): Communicates directly with the abstract
#   VoxelNavigationService, decoupling graph mathematics from the scene tree.
# SHELTER-SEEKING SCHEDULE UPGRADE:
# - Implemented `_check_is_roofed` to dynamically scan vertical axes above walkable coordinates.
# - Registers nodes as indoor shelters inside the navigation graph if a solid ceiling block is found.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/ChunkNavigationBuilder.gd
# ==============================================================================
class_name ChunkNavigationBuilder
extends RefCounted

# Directional coordinate offsets used to scan adjacent block headings (Horizontal plane)
const HORIZONTAL_OFFSETS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]


## Scans a tridimensional chunk grid and registers all discovered walkable nodes into the graph.
static func build_navigation_for_chunk(chunk: Chunk, world_state: WorldState, nav_service: VoxelNavigationService) -> void:
	if chunk == null or world_state == null or nav_service == null:
		return
		
	var chunk_offset: Vector3i = chunk.position * Chunk.SIZE
	
	# ==========================================================================
	# PASS 1: SCAN AND SOW WALKABLE NODES (With Shelter Detection)
	# Registers 3D coordinate nodes that possess a solid standing floor and head clearance.
	# ==========================================================================
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				var global_pos := chunk_offset + Vector3i(x, y, z)
				
				if _is_node_walkable(global_pos, world_state):
					var is_roofed: bool = _check_is_roofed(global_pos, world_state)
					nav_service.add_navigation_node(global_pos, is_roofed)
					
	# ==========================================================================
	# PASS 2: CONNECT ADJACENT GRAPH NODES
	# Dynamically links adjacent nodes to support flat walking and stair step-ups/downs.
	# ==========================================================================
	for x: int in range(Chunk.SIZE):
		for y: int in range(Chunk.SIZE):
			for z: int in range(Chunk.SIZE):
				var global_pos := chunk_offset + Vector3i(x, y, z)
				
				# Connect neighboring vectors only if this node itself is registered
				if nav_service._coord_to_id.has(global_pos):
					_connect_walkable_neighbors(global_pos, world_state, nav_service)


## Evaluates if a specific global coordinate coordinate has solid ground and sufficient standing clearance
static func _is_node_walkable(pos: Vector3i, world_state: WorldState) -> bool:
	# 1. Floor must be solid
	var block_below: BlockType.Type = world_state.get_block(pos + Vector3i(0, -1, 0))
	if not BlockType.is_solid(block_below):
		return false
		
	# 2. Self block must be non-solid (empty standing area)
	var block_self: BlockType.Type = world_state.get_block(pos)
	if BlockType.is_solid(block_self):
		return false
		
	# 3. Block above must also be non-solid (head clearance)
	var block_above: BlockType.Type = world_state.get_block(pos + Vector3i(0, 1, 0))
	if BlockType.is_solid(block_above):
		return false
		
	return true


## Scans upward columns above a walkable space to detect if there is a ceiling (roof) block
static func _check_is_roofed(pos: Vector3i, world_state: WorldState) -> bool:
	# Scan up to 6 blocks above the head-clearance baseline to find a solid ceiling
	# (Range 3 to 6 block offsets cover standard custom house ceiling heights)
	for offset_y in range(3, 7):
		var check_pos := pos + Vector3i(0, offset_y, 0)
		var block_above: BlockType.Type = world_state.get_block(check_pos)
		if BlockType.is_solid(block_above):
			return true
	return false


## Checks neighbors horizontally and vertically to map stair climbs and steep drops
static func _connect_walkable_neighbors(pos: Vector3i, world_state: WorldState, nav_service: VoxelNavigationService) -> void:
	# FIX: Explicit static typing on loop offset iterator
	for offset: Vector3i in HORIZONTAL_OFFSETS:
		
		# ----------------------------------------------------------------------
		# CASE 1: FLAT WALK (Same elevation level)
		# ----------------------------------------------------------------------
		var neighbor_flat := pos + offset
		if nav_service._coord_to_id.has(neighbor_flat):
			nav_service.connect_nodes(pos, neighbor_flat)
			
		# ----------------------------------------------------------------------
		# CASE 2: STEP-UP STAIR CLIMB (1-block vertical step)
		# ----------------------------------------------------------------------
		var neighbor_up := pos + offset + Vector3i(0, 1, 0)
		if nav_service._coord_to_id.has(neighbor_up):
			# Verify if there is enough head clearance above the step (ceiling at Y+2 is empty)
			var ceiling_clearance: BlockType.Type = world_state.get_block(pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(ceiling_clearance):
				nav_service.connect_nodes(pos, neighbor_up)
				
		# ----------------------------------------------------------------------
		# CASE 3: STEP-DOWN DESCENT (1-block vertical drop)
		# ----------------------------------------------------------------------
		var neighbor_down := pos + offset + Vector3i(0, -1, 0)
		if nav_service._coord_to_id.has(neighbor_down):
			# Verify if the dropping block's ceiling has head clearance
			var ceiling_clearance: BlockType.Type = world_state.get_block(neighbor_down + Vector3i(0, 2, 0))
			if not BlockType.is_solid(ceiling_clearance):
				nav_service.connect_nodes(pos, neighbor_down)
