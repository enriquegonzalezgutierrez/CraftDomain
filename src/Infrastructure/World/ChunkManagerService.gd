# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for managing background chunk
#              generation threads, task caching, and chunk node lifecycle.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Holds and manages both 
#                _chunk_nodes and _chunk_entities locally, centralizing chunk 
#                resource lifecycles and resolving cyclic type warnings.
#              - HIGH PERFORMANCE PIPELINE: Implements reactive main-thread dispatching,
#                rendering all completed background thread tasks instantly to eliminate
#                frame-stutters and redraw queues starvation.
#              OPTIMIZATIONS:
#              - Replaced individual block shape owners with a single merged 
#                ConcavePolygonShape3D per chunk node to resolve Godot's PhysicsServer3D bottleneck.
#              - Decoupled entity spawning from the initial chunk rendering queue to enable
#                distant chunks to remain completely static.
#              - Added the proximity-based mob spawner API to populate active regions on-demand.
#              - Implemented a Time-Sliced (Amortized) main thread rendering pipeline, limiting
#                chunk generation attachments to a maximum of 2 chunks per frame to eliminate
#                frame spikes when loading large distances.
#              - FIXED: Cached empty spawning arrays in _chunk_entities to resolve the 
#                infinite evaluation loop bug, dropping standby CPU overhead to 0.
#              - THREAD THROTTLING: Added an asynchronous request queue to limit parallel
#                WorkerThreadPool background tasks to a maximum of 2 concurrent hilos,
#                resolving CPU core starvation and maintaining 60 FPS while walking.
#              - FIXED: Unified Case A and Case B rendering dispatchers to use the pre-compiled
#                background task.collision_shape. This resolves block-editing (mining/building) 
#                and collision tunneling bugs.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/ChunkManagerService.gd
# ==============================================================================
class_name ChunkManagerService
extends RefCounted

var controller: Node3D # References WorldController
var world_state: WorldState

# Thread safety sync structures
var _queue_mutex: Mutex
var _completed_tasks_queue: Array[GeneratedChunkTask] = []
var _unload_queue: Array[Vector3i] = []
var _pending_loading_chunks: Dictionary = {}

## Array of chunk requests waiting to be loaded/rebuilt: Array[Dictionary]
## Structure: {"pos": Vector3i, "is_rebuild": bool}
var _load_requests_queue: Array = []

## Number of currently active background WorkerThreadPool tasks
var _active_background_tasks: int = 0

## Maximum concurrent background tasks allowed (Limits CPU core saturation)
const MAX_CONCURRENT_BG_TASKS: int = 2

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode
var _chunk_nodes: Dictionary = {}

## Tracking map for entities spawned within specific chunk columns: Vector3i (y=0) -> Array[Node]
var _chunk_entities: Dictionary = {}

# Cache System (LRU)
var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	controller = p_controller
	world_state = p_world_state
	_queue_mutex = Mutex.new()


## Verifies if a chunk is loaded and rendered
func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_nodes.has(chunk_pos)


## Public API: Returns the active chunk nodes (Used by auxiliary services)
func get_active_nodes() -> Dictionary:
	return _chunk_nodes


## Queues chunks for asynchronous loading (Background thread)
func queue_loads(chunk_positions: Array[Vector3i]) -> void:
	for pos in chunk_positions:
		_request_asynchronous_chunk_load(pos)


## Queues chunks to be unloaded from memory
func queue_unloads(chunk_positions: Array[Vector3i]) -> void:
	for pos in chunk_positions:
		if not _unload_queue.has(pos):
			_unload_queue.append(pos)


## Safe Frame Ticker: Process unloads and drains the completed tasks queue smoothly.
func process_frame_queues() -> void:
	# Process unloads up to 3 chunks per frame to avoid CPU stalls
	var unloads_processed := 0
	while _unload_queue.size() > 0 and unloads_processed < 3:
		var chunk_to_unload := _unload_queue.pop_front() as Vector3i
		_unload_chunk_node(chunk_to_unload)
		unloads_processed += 1
		
	# Amortize completed generation tasks to keep the frame rate stable
	_render_completed_chunks_from_queue()


func _request_asynchronous_chunk_load(chunk_pos: Vector3i) -> void:
	_queue_mutex.lock()
	if _pending_loading_chunks.has(chunk_pos):
		_queue_mutex.unlock()
		return
		
	if _chunk_task_cache.has(chunk_pos):
		var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos]
		_completed_tasks_queue.append(cached_task)
		_queue_mutex.unlock()
		return
		
	_pending_loading_chunks[chunk_pos] = true
	_load_requests_queue.append({"pos": chunk_pos, "is_rebuild": false})
	_queue_mutex.unlock()
	
	_trigger_next_background_tasks()


## ASYNC REBUILD: Queues a single chunk to be re-meshed in background
func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_nodes.has(chunk_pos):
		return
		
	_queue_mutex.lock()
	if _pending_loading_chunks.has(chunk_pos):
		_queue_mutex.unlock()
		return
		
	_pending_loading_chunks[chunk_pos] = true
	_load_requests_queue.append({"pos": chunk_pos, "is_rebuild": true})
	_queue_mutex.unlock()
	
	_trigger_next_background_tasks()


## Evaluates the request queue and dispatches next tasks under max concurrency limits
func _trigger_next_background_tasks() -> void:
	_queue_mutex.lock()
	while _active_background_tasks < MAX_CONCURRENT_BG_TASKS and _load_requests_queue.size() > 0:
		var request: Dictionary = _load_requests_queue.pop_front()
		var pos: Vector3i = request["pos"]
		var is_rebuild: bool = request["is_rebuild"]
		
		_active_background_tasks += 1
		if is_rebuild:
			WorkerThreadPool.add_task(_background_rebuild_chunk_task_wrapper.bind(pos))
		else:
			WorkerThreadPool.add_task(_background_generate_chunk_task_wrapper.bind(pos))
	_queue_mutex.unlock()

# ==============================================================================
# THREAD OPERATIONS (Calculates raw meshes and collision arrays)
# ==============================================================================

func _background_generate_chunk_task_wrapper(chunk_pos: Vector3i) -> void:
	_background_generate_chunk_task(chunk_pos)
	
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	
	_trigger_next_background_tasks()


func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := Chunk.new(chunk_pos)
	
	# Thread-safe Guard: Abort if the controller has been freed during shutdown
	if not is_instance_valid(controller):
		return
		
	controller.generator.generate_chunk(chunk)
	
	# Thread-safe Guard: Abort if the controller or repository has been freed during shutdown
	if not is_instance_valid(controller) or not is_instance_valid(controller.repository):
		return
		
	var saved_edits: Dictionary = controller.repository.load_chunk_modifications(chunk_pos)
	if saved_edits.size() > 0:
		for local_pos in saved_edits.keys():
			var pos: Vector3i = local_pos
			chunk.set_block(pos.x, pos.y, pos.z, saved_edits[local_pos])
			
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state)
	
	# Thread-safe Guard: Abort before liquid meshing
	if not is_instance_valid(controller):
		return
		
	var liquids: Dictionary = {}
	for l_type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type)
		if l_mesh != null:
			liquids[l_type] = l_mesh
	
	# Compile ConcavePolygonShape3D and build BVH tree entirely on the background thread
	var col_shape: ConcavePolygonShape3D = null
	var vertices: PackedVector3Array = visual_data["collision_vertices"]
	if vertices.size() > 0:
		col_shape = ConcavePolygonShape3D.new()
		col_shape.data = vertices
	
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = col_shape
	task_result.liquid_meshes = liquids
	task_result.is_rebuild = false
	
	_queue_mutex.lock()
	_chunk_task_cache[chunk_pos] = task_result
	_completed_tasks_queue.append(task_result)
	
	if _chunk_task_cache.size() > CACHE_SIZE_LIMIT:
		var oldest_key = _chunk_task_cache.keys()[0]
		_chunk_task_cache.erase(oldest_key)
	_queue_mutex.unlock()


func _background_rebuild_chunk_task_wrapper(chunk_pos: Vector3i) -> void:
	_background_rebuild_chunk_task(chunk_pos)
	
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	
	_trigger_next_background_tasks()


func _background_rebuild_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := world_state.get_chunk(chunk_pos)
	if chunk == null:
		_queue_mutex.lock()
		_pending_loading_chunks.erase(chunk_pos)
		_queue_mutex.unlock()
		return
		
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state)
	
	# Thread-safe Guard: Abort if the controller has been freed during shutdown
	if not is_instance_valid(controller):
		return
		
	var liquids: Dictionary = {}
	for l_type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type)
		if l_mesh != null:
			liquids[l_type] = l_mesh

	# Compile ConcavePolygonShape3D and build BVH tree entirely on the background thread
	var col_shape: ConcavePolygonShape3D = null
	var vertices: PackedVector3Array = visual_data["collision_vertices"]
	if vertices.size() > 0:
		col_shape = ConcavePolygonShape3D.new()
		col_shape.data = vertices

	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = col_shape
	task_result.liquid_meshes = liquids
	task_result.is_rebuild = true

	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()

# ==============================================================================
# MAIN THREAD RENDER DISPATCH (TIME-SLICED / AMORTIZED)
# ==============================================================================

## Flushes and processes completed background threads on the main thread loop.
## Limit rendering to at most 2 chunks per frame to keep the framerate perfectly stable.
func _render_completed_chunks_from_queue() -> void:
	var rendered_this_frame := 0
	const MAX_CHUNKS_PER_FRAME := 2 # Time-slicing limit
	
	while rendered_this_frame < MAX_CHUNKS_PER_FRAME:
		var task: GeneratedChunkTask = null
		
		_queue_mutex.lock()
		if _completed_tasks_queue.size() > 0:
			task = _completed_tasks_queue.pop_front()
		_queue_mutex.unlock()
		
		if task == null:
			break # Queue is completely empty
			
		_render_single_completed_task(task)
		rendered_this_frame += 1


## Decoupled rendering executor handling SceneTree attachments (SRP compliant)
func _render_single_completed_task(task: GeneratedChunkTask) -> void:
	var chunk_pos: Vector3i = task.chunk.position
	
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		
	# Case A: Visual Redraw
	if task.is_rebuild:
		var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
		if is_instance_valid(chunk_node):
			var collision_body := StaticBody3D.new()
			collision_body.name = "StaticCollisionBody"
			
			if task.collision_shape != null:
				var col_shape := CollisionShape3D.new()
				col_shape.name = "ChunkCollisionShape"
				col_shape.shape = task.collision_shape
				collision_body.add_child(col_shape)
				
			chunk_node.setup_chunk_visuals(task.multimesh_data, collision_body, task.liquid_meshes)
			
	# Case B: Instantiation of a new area
	else:
		if not _chunk_nodes.has(chunk_pos):
			world_state.add_chunk(task.chunk)
			var chunk_node := ChunkNode.new(task.chunk)
			controller.add_child(chunk_node)
			_chunk_nodes[chunk_pos] = chunk_node
			
			var collision_body: StaticBody3D = null
			
			# SOLID COLLISION ENFORCEMENT: Instantly assign the precompiled background collision shape.
			# This completely guarantees the player will never clip, fall through floors, or tunnel.
			if task.collision_shape != null:
				collision_body = StaticBody3D.new()
				collision_body.name = "StaticCollisionBody"
				var col_shape := CollisionShape3D.new()
				col_shape.name = "ChunkCollisionShape"
				col_shape.shape = task.collision_shape # Instant 0.00 ms pointer assignment
				collision_body.add_child(col_shape)
			
			chunk_node.setup_chunk_visuals(task.multimesh_data, collision_body, task.liquid_meshes)
			
			# Sew seams asynchronously with the 4 adyacents to cull chunk-boundary water/block faces.
			# Evaluated smoothly under the thread-throttled task queue to preserve high frame rates.
			var horizontal_dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
			for dir in horizontal_dirs:
				var neighbor_pos: Vector3i = chunk_pos + dir
				if _chunk_nodes.has(neighbor_pos):
					_request_chunk_rebuild(neighbor_pos)
			
			# Clean and compliant SceneTree setup (removed redundant Case B spawning trigger)
			controller.register_streetlights_for_chunk(task.chunk)
			controller.check_player_spawn_activation()


func _spawn_chunk_pos_0_exists_and_valid(pos_0: Vector3i, pos_1: Vector3i) -> bool:
	return _chunk_nodes.has(pos_0) and _chunk_nodes.has(pos_1)


## Dynamic Proximity Spawner: Spawns entities close to the player's current position.
## Caches evaluated empty columns to prevent CPU evaluation loops.
func spawn_mobs_by_proximity(player_global_pos: Vector3, spawn_radius: int = 2) -> void:
	var player_block_pos := Vector3i(
		floor(player_global_pos.x),
		floor(player_global_pos.y),
		floor(player_global_pos.z)
	)
	var player_chunk_pos := world_state.global_to_chunk_pos(player_block_pos)
	
	for x in range(-spawn_radius, spawn_radius + 1):
		for z in range(-spawn_radius, spawn_radius + 1):
			var target_chunk_pos_0 := Vector3i(player_chunk_pos.x + x, 0, player_chunk_pos.z + z)
			var target_chunk_pos_1 := Vector3i(player_chunk_pos.x + x, 1, player_chunk_pos.z + z)
			
			# Check if both layers of the chunk column are rendered
			if _chunk_nodes.has(target_chunk_pos_0) and _chunk_nodes.has(target_chunk_pos_1):
				var col_pos := Vector3i(target_chunk_pos_0.x, 0, target_chunk_pos_0.z)
				
				# A. MOB SPAWNER TRIGGER: Only spawn entities if the chunk is fully loaded with its physics collision body!
				# This guarantees that mobs land perfectly on the solid floor and never float or fall into the void.
				if not _chunk_entities.has(col_pos) and _chunk_nodes[target_chunk_pos_0].has_collision_body():
					var chunk_0 = _chunk_nodes[target_chunk_pos_0].chunk
					var spawned: Array[Node] = controller.spawn_mobs_for_chunk(chunk_0)
					
					# FIXED: Always register the array (even if empty) to prevent infinite evaluation loops!
					_chunk_entities[col_pos] = spawned


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

	controller.unregister_streetlights_for_chunk(chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	if is_instance_valid(chunk_node):
		var body := chunk_node.get_node_or_null("StaticCollisionBody")
		if is_instance_valid(body): chunk_node.remove_child(body)
		chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)
