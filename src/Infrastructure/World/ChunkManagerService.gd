# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service managing background chunk thread tasks,
#              LRU caching, and chunk node lifecycles.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Isolates chunk rendering 
#                and lifecycle updates from core game loop logic.
#              OPTIMIZATIONS:
#              - Eliminated neighboring chunk "seam sewing" rebuild storms on initial
#                loads to prevent CPU thread pools starvation and main-thread stalls.
#              - Retained reactive boundary rebuilds exclusively for real-time player 
#                block placements or break modifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/ChunkManagerService.gd
# ==============================================================================
class_name ChunkManagerService
extends RefCounted

var controller: Node3D # References WorldController
var world_state: WorldState

# Thread safety synchronization structures
var _queue_mutex: Mutex
var _completed_tasks_queue: Array[GeneratedChunkTask] = []
var _unload_queue: Array[Vector3i] = []
var _pending_loading_chunks: Dictionary = {}

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode
var _chunk_nodes: Dictionary = {}

## Tracking map for entities spawned within specific chunk columns: Vector3i (y=0) -> Array[Node]
var _chunk_entities: Dictionary = {}

# Least Recently Used (LRU) task cache system
var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	controller = p_controller
	world_state = p_world_state
	_queue_mutex = Mutex.new()


## Verifies if a chunk is loaded and rendered in the scene tree.
func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_nodes.has(chunk_pos)


## Public API: Returns the active chunk nodes (used by climate and lighting services).
func get_active_nodes() -> Dictionary:
	return _chunk_nodes


## Queues chunks for asynchronous loading on background thread tasks.
func queue_loads(chunk_positions: Array[Vector3i]) -> void:
	for pos in chunk_positions:
		_request_asynchronous_chunk_load(pos)


## Queues chunks to be unloaded and freed from memory safely.
func queue_unloads(chunk_positions: Array[Vector3i]) -> void:
	for pos in chunk_positions:
		if not _unload_queue.has(pos):
			_unload_queue.append(pos)


## Safe Frame Ticker: Process unloads and drains the entire completed tasks queue in a single frame.
func process_frame_queues() -> void:
	# Process unloads up to 3 chunks per frame to avoid CPU frame stalls
	var unloads_processed := 0
	while _unload_queue.size() > 0 and unloads_processed < 3:
		var chunk_to_unload := _unload_queue.pop_front() as Vector3i
		_unload_chunk_node(chunk_to_unload)
		unloads_processed += 1
		
	# Instantly render all completed background generation tasks
	_render_completed_chunks_from_queue()


func _request_asynchronous_chunk_load(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		return
		
	if _chunk_task_cache.has(chunk_pos):
		var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos]
		_queue_mutex.lock()
		_completed_tasks_queue.append(cached_task)
		_queue_mutex.unlock()
		return
		
	_pending_loading_chunks[chunk_pos] = true
	WorkerThreadPool.add_task(_background_generate_chunk_task.bind(chunk_pos))


## ASYNC REBUILD: Queues a single chunk to be re-meshed in the background thread.
func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_nodes.has(chunk_pos):
		return
		
	if _pending_loading_chunks.has(chunk_pos):
		return
		
	_pending_loading_chunks[chunk_pos] = true
	WorkerThreadPool.add_task(_background_rebuild_chunk_task.bind(chunk_pos))

# ==============================================================================
# THREAD OPERATIONS (Calculates raw meshes and collision arrays)
# ==============================================================================

func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := Chunk.new(chunk_pos)
	controller.generator.generate_chunk(chunk)
	
	var saved_edits: Dictionary = controller.repository.load_chunk_modifications(chunk_pos)
	if saved_edits.size() > 0:
		for local_pos in saved_edits.keys():
			var pos: Vector3i = local_pos
			chunk.set_block(pos.x, pos.y, pos.z, saved_edits[local_pos])
			
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state)
	
	var liquids: Dictionary = {}
	for l_type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type)
		if l_mesh != null:
			liquids[l_type] = l_mesh
	
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_vertices = visual_data["collision_vertices"] as PackedVector3Array
	task_result.liquid_meshes = liquids
	task_result.is_rebuild = false
	
	_queue_mutex.lock()
	_chunk_task_cache[chunk_pos] = task_result
	_completed_tasks_queue.append(task_result)
	
	if _chunk_task_cache.size() > CACHE_SIZE_LIMIT:
		var oldest_key = _chunk_task_cache.keys()[0]
		_chunk_task_cache.erase(oldest_key)
	_queue_mutex.unlock()


func _background_rebuild_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := world_state.get_chunk(chunk_pos)
	if chunk == null:
		_queue_mutex.lock()
		_pending_loading_chunks.erase(chunk_pos)
		_queue_mutex.unlock()
		return
		
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state)
	
	var liquids: Dictionary = {}
	for l_type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type)
		if l_mesh != null:
			liquids[l_type] = l_mesh

	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_vertices = visual_data["collision_vertices"] as PackedVector3Array
	task_result.liquid_meshes = liquids
	task_result.is_rebuild = true

	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()

# ==============================================================================
# MAIN THREAD RENDER DISPATCH
# ==============================================================================

## Flushes and processes all completed background threads on the main thread loop.
func _render_completed_chunks_from_queue() -> void:
	while true:
		var task: GeneratedChunkTask = null
		
		_queue_mutex.lock()
		if _completed_tasks_queue.size() > 0:
			task = _completed_tasks_queue.pop_front()
		_queue_mutex.unlock()
		
		if task == null:
			break # Queue is completely empty, resume next frame
			
		var chunk_pos: Vector3i = task.chunk.position
		
		if _pending_loading_chunks.has(chunk_pos):
			_pending_loading_chunks.erase(chunk_pos)
			
		# Case A: Visual Redraw (Triggered on block place / break)
		if task.is_rebuild:
			var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
			if is_instance_valid(chunk_node):
				var collision_body := StaticBody3D.new()
				collision_body.name = "StaticCollisionBody"
				
				if task.collision_vertices.size() > 0:
					var col_shape := CollisionShape3D.new()
					col_shape.name = "ChunkCollisionShape"
					var concave_shape := ConcavePolygonShape3D.new()
					concave_shape.data = task.collision_vertices
					col_shape.shape = concave_shape
					collision_body.add_child(col_shape)
					
				chunk_node.setup_chunk_visuals(task.multimesh_data, collision_body, task.liquid_meshes)
				
		# Case B: Instantiation of a new chunk area
		else:
			if not _chunk_nodes.has(chunk_pos):
				world_state.add_chunk(task.chunk)
				var chunk_node := ChunkNode.new(task.chunk)
				controller.add_child(chunk_node)
				_chunk_nodes[chunk_pos] = chunk_node
				
				var collision_body := StaticBody3D.new()
				collision_body.name = "StaticCollisionBody"
				
				if task.collision_vertices.size() > 0:
					var col_shape := CollisionShape3D.new()
					col_shape.name = "ChunkCollisionShape"
					var concave_shape := ConcavePolygonShape3D.new()
					concave_shape.data = task.collision_vertices
					col_shape.shape = concave_shape
					collision_body.add_child(col_shape)
				
				chunk_node.setup_chunk_visuals(task.multimesh_data, collision_body, task.liquid_meshes)
				
				# Spawners Trigger
				var col_pos := Vector3i(chunk_pos.x, 0, chunk_pos.z)
				var spawn_chunk_pos_0 := Vector3i(chunk_pos.x, 0, chunk_pos.z)
				var spawn_chunk_pos_1 := Vector3i(chunk_pos.x, 1, chunk_pos.z)
				
				if _spawn_chunk_pos_0_exists_and_valid(spawn_chunk_pos_0, spawn_chunk_pos_1):
					if not _chunk_entities.has(col_pos):
						var chunk_0 = _chunk_nodes[spawn_chunk_pos_0].chunk
						var spawned: Array[Node] = controller.spawn_mobs_for_chunk(chunk_0)
						if spawned.size() > 0:
							_chunk_entities[col_pos] = spawned
				
				controller.register_streetlights_for_chunk(task.chunk)
				controller.check_player_spawn_activation()


func _spawn_chunk_pos_0_exists_and_valid(pos_0: Vector3i, pos_1: Vector3i) -> bool:
	return _chunk_nodes.has(pos_0) and _chunk_nodes.has(pos_1)


func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		return

	# Handle safe dynamic animal and village NPC removal
	var col_pos := Vector3i(chunk_pos.x, 0, chunk_pos.z)
	if _chunk_entities.has(col_pos):
		var entities: Array = _chunk_entities[col_pos]
		for entity in entities:
			if is_instance_valid(entity): entity.queue_free()
		_chunk_entities.erase(col_pos)

	# Safety checks before calling queue_free on chunks
	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	if is_instance_valid(chunk_node):
		chunk_node.queue_free()
		_chunk_nodes.erase(chunk_pos)
		world_state.remove_chunk(chunk_pos)


## Places or breaks a block globally and schedules asynchronous redraw queues.
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	var local_pos := world_state.global_to_local_pos(global_pos)
	
	_request_chunk_rebuild(chunk_pos)
	
	# Only rebuild neighbor boundaries if the modification was done at the borders
	if local_pos.x == 0: _request_chunk_rebuild(chunk_pos + Vector3i(-1, 0, 0))
	elif local_pos.x == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(1, 0, 0))
	
	if local_pos.z == 0: _request_chunk_rebuild(chunk_pos + Vector3i(0, 0, -1))
	elif local_pos.z == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(0, 0, 1))
	
	if local_pos.y == 0: _request_chunk_rebuild(chunk_pos + Vector3i(0, -1, 0))
	elif local_pos.y == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(0, 1, 0))
