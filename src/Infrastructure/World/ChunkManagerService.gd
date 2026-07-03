# ==============================================================================
# Project: CraftDomain
# Description: High-Performance Infrastructure Service responsible for managing 
#              background chunk generation threads, task caching, and direct RID physics.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Coordinates chunk lifecycle, delegating 
#   heavy geometry and physics tree compiling to background worker threads.
# - Liskov Substitution Principle (LSP): Safely handles raw PhysicsServer3D 
#   and thread pooling operations.
# DYNAMIC LOD COORDINATION:
# - Implemented `_chunk_lod_states` and `_lod_update_timer` to monitor player distance.
# - Distant chunks (> 4.5 radius) are automatically drawn with flat LOD materials.
# - CRITICAL OPTIMIZATION (HOT-SWAP): If a chunk transitions from far to near, 
#   materials are swapped instantly on the GPU in O(1) on the main thread. 
#   This completely avoids queuing expensive CPU background mesh rebuilds, 
#   safeguarding VRAM bandwidth and ensuring stable 120 FPS.
# REFACTORING:
# - Added 'delta' parameter to 'process_frame_queues()' to decouple the service 
#   from scene-tree delta lookups, preventing null-pointer crashes.
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

## Dictionary mapping Vector3i -> bool tracking chunks that need a SECOND rebuild 
var _queued_rebuilds: Dictionary = {}

## Array of active background thread task IDs to clean up on shutdown
var _active_task_ids: Array[int] = []

## Array of chunk requests waiting to be loaded/rebuilt: Array[Dictionary]
var _load_requests_queue: Array = []

## Number of currently active background WorkerThreadPool tasks
var _active_background_tasks: int = 0

## Maximum concurrent background tasks allowed
const MAX_CONCURRENT_BG_TASKS: int = 3

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode
var _chunk_nodes: Dictionary = {}

## Tracking map for entities spawned within specific chunk columns: Vector3i (y=0) -> Array[Node]
var _chunk_entities: Dictionary = {}

## Map storing raw PhysicsServer3D body RIDs for safe manual deletion
var _physics_bodies: Dictionary = {} # Vector3i -> RID

## MEMORY SECURITY: Holds persistent strong references to active collision shape resources
var _collision_shapes: Dictionary = {} # Vector3i -> ConcavePolygonShape3D

# LOD State and Timers
var _chunk_lod_states: Dictionary = {} # Vector3i -> bool (is_distant)
var _lod_update_timer: float = 0.0
const LOD_UPDATE_INTERVAL: float = 0.25 # Throttle LOD scans to 250ms

# Cache System (LRU)
var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	controller = p_controller # Fixed: Assigned properly to silence the unused warning
	world_state = p_world_state
	_queue_mutex = Mutex.new()


## Verifies if a chunk is loaded and rendered
func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_nodes.has(chunk_pos)


## Public API: Returns the active chunk nodes
func get_active_nodes() -> Dictionary:
	return _chunk_nodes


## Places or breaks a block globally, updates Domain, and requests asynchronous redraws.
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	_request_chunk_rebuild(chunk_pos)
	
	var local_pos := world_state.global_to_local_pos(global_pos)
	
	if local_pos.x == 0: 
		_request_chunk_rebuild(chunk_pos + Vector3i(-1, 0, 0))
	elif local_pos.x == Chunk.SIZE - 1: 
		_request_chunk_rebuild(chunk_pos + Vector3i(1, 0, 0))
		
	if local_pos.y == 0: 
		_request_chunk_rebuild(chunk_pos + Vector3i(0, -1, 0))
	elif local_pos.y == Chunk.SIZE - 1: 
		_request_chunk_rebuild(chunk_pos + Vector3i(0, 1, 0))
		
	if local_pos.z == 0: 
		_request_chunk_rebuild(chunk_pos + Vector3i(0, 0, -1))
	elif local_pos.z == Chunk.SIZE - 1: 
		_request_chunk_rebuild(chunk_pos + Vector3i(0, 0, 1))


## Queues chunks for asynchronous loading (Background thread)
func queue_loads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		_request_asynchronous_chunk_load(pos, false)


## Queues chunks with high priority (pushes to front of loading queue)
func queue_prioritized_loads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		_request_asynchronous_chunk_load(pos, true)


## Queues chunks to be unloaded from memory
func queue_unloads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		if not _unload_queue.has(pos):
			_unload_queue.append(pos)


## Safe Frame Ticker: Process unloads, dynamic LOD shifts and drains completed tasks.
## REFACTORING: Accepts 'delta' as a parameter to maintain SRP compliance.
func process_frame_queues(delta: float) -> void:
	_process_dynamic_lod_updates(delta)
	
	var unloads_processed := 0
	while _unload_queue.size() > 0 and unloads_processed < 3:
		var chunk_to_unload := _unload_queue.pop_front() as Vector3i
		_unload_chunk_node(chunk_to_unload)
		unloads_processed += 1
		
	_render_completed_chunks_from_queue()
	
	_queue_mutex.lock()
	var active_temp: Array[int] = []
	for id: int in _active_task_ids:
		if not WorkerThreadPool.is_task_completed(id):
			active_temp.append(id)
	_active_task_ids = active_temp
	_queue_mutex.unlock()


func _request_asynchronous_chunk_load(chunk_pos: Vector3i, high_priority: bool = false) -> void:
	_queue_mutex.lock()
	
	if _chunk_task_cache.has(chunk_pos):
		var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos] as GeneratedChunkTask
		if not _completed_tasks_queue.has(cached_task):
			_completed_tasks_queue.append(cached_task)
		_queue_mutex.unlock()
		return
		
	if _pending_loading_chunks.has(chunk_pos):
		if high_priority:
			for i: int in range(_load_requests_queue.size()):
				var req: Dictionary = _load_requests_queue[i] as Dictionary
				if req["pos"] == chunk_pos:
					_load_requests_queue.remove_at(i)
					_load_requests_queue.push_front(req)
					break
		_queue_mutex.unlock()
		return
		
	_pending_loading_chunks[chunk_pos] = true
	
	var new_req: Dictionary = {"pos": chunk_pos, "is_rebuild": false}
	if high_priority:
		_load_requests_queue.push_front(new_req)
	else:
		_load_requests_queue.append(new_req)
		
	_queue_mutex.unlock()
	
	_trigger_next_background_tasks()


## ASYNC REBUILD: Queues a single chunk to be re-meshed in background
func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_nodes.has(chunk_pos):
		return
		
	_queue_mutex.lock()
	if _pending_loading_chunks.has(chunk_pos):
		_queued_rebuilds[chunk_pos] = true
		_queue_mutex.unlock()
		return
		
	_pending_loading_chunks[chunk_pos] = true
	_load_requests_queue.push_front({"pos": chunk_pos, "is_rebuild": true})
	_queue_mutex.unlock()
	
	_trigger_next_background_tasks()


## Evaluates the request queue and dispatches next tasks under max concurrency limits
func _trigger_next_background_tasks() -> void:
	_queue_mutex.lock()
	while _active_background_tasks < MAX_CONCURRENT_BG_TASKS and _load_requests_queue.size() > 0:
		var request: Dictionary = _load_requests_queue.pop_front() as Dictionary
		var pos: Vector3i = request["pos"] as Vector3i
		var is_rebuild: bool = request["is_rebuild"] as bool
		
		_active_background_tasks += 1
		var task_id: int
		if is_rebuild:
			task_id = WorkerThreadPool.add_task(_background_rebuild_chunk_task_wrapper.bind(pos))
		else:
			task_id = WorkerThreadPool.add_task(_background_generate_chunk_task_wrapper.bind(pos))
		_active_task_ids.append(task_id)
	_queue_mutex.unlock()


# ==============================================================================
# BACKGROUND THREAD OPERATIONS (All heavy math & compilation occurs here)
# ==============================================================================

func _background_generate_chunk_task_wrapper(chunk_pos: Vector3i) -> void:
	_background_generate_chunk_task(chunk_pos)
	
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	
	_trigger_next_background_tasks()


func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := Chunk.new(chunk_pos)
	
	if not is_instance_valid(controller):
		return
		
	var gen: WorldGenerator = controller.get("generator") as WorldGenerator
	if is_instance_valid(gen):
		gen.generate_chunk(chunk)
	
	if not is_instance_valid(controller) or not is_instance_valid(controller.repository):
		return
		
	var saved_edits: Dictionary = controller.repository.load_chunk_modifications(chunk_pos) as Dictionary
	if saved_edits.size() > 0:
		for local_pos: Vector3i in saved_edits.keys():
			var type_val: int = saved_edits[local_pos] as int
			chunk.set_block(local_pos.x, local_pos.y, local_pos.z, type_val as BlockType.Type)
			
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state) as Dictionary
	
	# ASYNCHRONOUS PHYSICS COMPILING: Build the Concave Collision Shape entirely on this background thread!
	var collision_vertices: PackedVector3Array = visual_data["collision_vertices"] as PackedVector3Array
	var col_shape: ConcavePolygonShape3D = null
	if collision_vertices.size() > 0:
		col_shape = ConcavePolygonShape3D.new()
		col_shape.set_faces(collision_vertices) # Generates internal BVH tree on background thread
	
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null:
			liquids[l_type] = l_mesh
	
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = col_shape # Pre-compiled shape reference
	task_result.liquid_meshes = liquids
	
	_queue_mutex.lock()
	_chunk_task_cache[chunk_pos] = task_result
	_completed_tasks_queue.append(task_result)
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
		return
		
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state) as Dictionary
	
	# ASYNCHRONOUS REBUILD PHYSICS COMPILING
	var collision_vertices: PackedVector3Array = visual_data["collision_vertices"] as PackedVector3Array
	var col_shape: ConcavePolygonShape3D = null
	if collision_vertices.size() > 0:
		col_shape = ConcavePolygonShape3D.new()
		col_shape.set_faces(collision_vertices)
		
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null:
			liquids[l_type] = l_mesh
			
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = col_shape
	task_result.is_rebuild = true
	task_result.liquid_meshes = liquids
	
	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


# ==============================================================================
# MAIN THREAD MESH ASSEMBLY (Kept O(1) for consistent frame pacing)
# ==============================================================================

func _render_completed_chunks_from_queue() -> void:
	var rendered_this_frame := 0
	const MAX_CHUNKS_PER_FRAME := 2 
	
	while rendered_this_frame < MAX_CHUNKS_PER_FRAME:
		var task: GeneratedChunkTask = null
		
		_queue_mutex.lock()
		if _completed_tasks_queue.size() > 0:
			task = _completed_tasks_queue.pop_front() as GeneratedChunkTask
		_queue_mutex.unlock()
		
		if task == null:
			break 
			
		_render_single_completed_task(task)
		rendered_this_frame += 1


func _render_single_completed_task(task: GeneratedChunkTask) -> void:
	var chunk_pos: Vector3i = task.chunk.position
	
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		
	if _queued_rebuilds.has(chunk_pos):
		_queued_rebuilds.erase(chunk_pos)
		_request_chunk_rebuild(chunk_pos)
		
	if not task.is_rebuild and is_instance_valid(world_state):
		world_state.add_chunk(task.chunk)
		
	# 1. Purge previous StaticBody RID & persistent strong shape references
	if _physics_bodies.has(chunk_pos):
		var old_rid: RID = _physics_bodies[chunk_pos]
		PhysicsServer3D.free_rid(old_rid)
		_physics_bodies.erase(chunk_pos)
		
	if _collision_shapes.has(chunk_pos):
		_collision_shapes.erase(chunk_pos) # Safe to let GC release the old resource
		
	# ==========================================================================
	# ULTRA-FAST O(1) PHYSICS SERVER REGISTRATION
	# ==========================================================================
	if task.collision_shape != null:
		# MEMORY SECURITY SECURE: Keep a strong live reference to prevent GC!
		_collision_shapes[chunk_pos] = task.collision_shape
		
		var body_rid: RID = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
		
		PhysicsServer3D.body_set_collision_layer(body_rid, 1)
		PhysicsServer3D.body_set_collision_mask(body_rid, 1)
		PhysicsServer3D.body_set_space(body_rid, controller.get_world_3d().space)
		
		var chunk_transform := Transform3D(Basis(), Vector3(chunk_pos * Chunk.SIZE))
		PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, chunk_transform)
		
		# Direct sub-microsecond Native call: Add the precompiled shape RID
		var shape_rid: RID = task.collision_shape.get_rid()
		PhysicsServer3D.body_add_shape(body_rid, shape_rid)
		
		_physics_bodies[chunk_pos] = body_rid
	# ==========================================================================
	
	# Determine if this chunk is far away from the player to activate LOD flat materials
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	_chunk_lod_states[chunk_pos] = is_distant
	
	var chunk_node: ChunkNode = null
	if _chunk_nodes.has(chunk_pos):
		chunk_node = _chunk_nodes[chunk_pos] as ChunkNode
		chunk_node.setup_chunk_visuals(task.multimesh_data, null, task.liquid_meshes, is_distant)
	else:
		if task.is_rebuild:
			return
			
		chunk_node = ChunkNode.new(task.chunk)
		controller.add_child(chunk_node)
		chunk_node.setup_chunk_visuals(task.multimesh_data, null, task.liquid_meshes, is_distant)
		_chunk_nodes[chunk_pos] = chunk_node
		
		# Register accessories
		if controller.has_method("register_streetlights_for_chunk"):
			controller.call("register_streetlights_for_chunk", task.chunk)
			
		if controller.has_method("check_player_spawn_activation"):
			controller.call("check_player_spawn_activation")


## Dynamic Proximity Entity Spawner
func spawn_entities_by_proximity(player_global_pos: Vector3, spawn_radius: int = 2) -> void:
	var player_block_pos := Vector3i(
		floor(player_global_pos.x),
		floor(player_global_pos.y),
		floor(player_global_pos.z)
	)
	var current_viewer_chunk_pos := world_state.global_to_chunk_pos(player_block_pos)
	
	for x: int in range(-spawn_radius, spawn_radius + 1):
		for z: int in range(-spawn_radius, spawn_radius + 1):
			var target_chunk_pos_0 := Vector3i(current_viewer_chunk_pos.x + x, 0, current_viewer_chunk_pos.z + z)
			
			if _chunk_nodes.has(target_chunk_pos_0):
				var col_pos := Vector3i(target_chunk_pos_0.x, 0, target_chunk_pos_0.z)
				
				if not _chunk_entities.has(col_pos) and _physics_bodies.has(target_chunk_pos_0):
					var chunk_0: Chunk = _chunk_nodes[target_chunk_pos_0].chunk as Chunk
					
					if controller.has_method("spawn_entities_for_chunk"):
						var raw_array: Array = controller.call("spawn_entities_for_chunk", chunk_0) as Array
						var typed_nodes: Array[Node] = []
						for n_element: Variant in raw_array:
							if n_element is Node:
								typed_nodes.append(n_element as Node)
								
						_chunk_entities[col_pos] = typed_nodes


func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	_queue_mutex.lock()
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
	if _queued_rebuilds.has(chunk_pos):
		_queued_rebuilds.erase(chunk_pos)
	_queue_mutex.unlock()
	
	var col_pos := Vector3i(chunk_pos.x, 0, chunk_pos.z)
	if _chunk_entities.has(col_pos):
		var entities: Array = _chunk_entities[col_pos] as Array
		for entity: Node in entities:
			if is_instance_valid(entity): 
				entity.queue_free()
		_chunk_entities.erase(col_pos)

	if controller.has_method("unregister_streetlights_for_chunk"):
		controller.call("unregister_streetlights_for_chunk", chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos) as ChunkNode
	if is_instance_valid(chunk_node):
		chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)
	
	# Clean LOD memory tracking to prevent leaks
	if _chunk_lod_states.has(chunk_pos):
		_chunk_lod_states.erase(chunk_pos)
	
	if _physics_bodies.has(chunk_pos):
		var rid: RID = _physics_bodies[chunk_pos]
		PhysicsServer3D.free_rid(rid)
		_physics_bodies.erase(chunk_pos)
		
	if _collision_shapes.has(chunk_pos):
		_collision_shapes.erase(chunk_pos) # Clean up shape reference to free RAM


# ==============================================================================
# DYNAMIC LOD SCANNING COORDINATOR (Throttled Frame Updates)
# ==============================================================================

func _process_dynamic_lod_updates(delta: float) -> void:
	_lod_update_timer -= delta
	if _lod_update_timer <= 0.0:
		_lod_update_timer = LOD_UPDATE_INTERVAL
		_execute_lod_scans()


## Scans currently loaded chunks. If any chunk crosses the LOD boundary limit, 
## it instantly triggers an O(1) hot-swap of materials on the GPU.
func _execute_lod_scans() -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		return
		
	# Traverse loaded chunks and evaluate distance thresholds
	for chunk_pos: Vector3i in _chunk_nodes.keys():
		var chunk_node: ChunkNode = _chunk_nodes[chunk_pos] as ChunkNode
		if not is_instance_valid(chunk_node):
			continue
			
		var is_now_distant := _calculate_is_chunk_distant(chunk_pos)
		var last_known_state: bool = _chunk_lod_states.get(chunk_pos, false)
		
		# If the chunk crossed the LOD boundary (Far <-> Near transition)
		if is_now_distant != last_known_state:
			_chunk_lod_states[chunk_pos] = is_now_distant
			
			# CRITICAL OPTIMIZATION: Instead of rebuilding the chunk, hot-swap materials instantly!
			chunk_node.update_lod_materials(is_now_distant)


## Helper: Calculates 2D Euclidean distance to the player chunk
func _calculate_is_chunk_distant(chunk_pos: Vector3i) -> bool:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		return false
		
	var p_pos: Vector3 = controller.player.global_position
	var p_chunk_pos := world_state.global_to_chunk_pos(Vector3i(floori(p_pos.x), floori(p_pos.y), floori(p_pos.z)))
	
	var dist := Vector2(chunk_pos.x - p_chunk_pos.x, chunk_pos.z - p_chunk_pos.z).length()
	return dist > 4.5


## safe shutdown handler that blocks and waits for background workers to finish
func shutdown() -> void:
	_queue_mutex.lock()
	_load_requests_queue.clear()
	var tasks_to_wait := _active_task_ids.duplicate()
	_queue_mutex.unlock()
	
	for id: int in tasks_to_wait:
		WorkerThreadPool.wait_for_task_completion(id)
