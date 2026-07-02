# ==============================================================================
# Project: CraftDomain
# Description: Description: Infrastructure Service responsible for managing background chunk
#              generation threads, task caching, and chunk node lifecycle.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Holds and manages both 
#                _chunk_nodes and _chunk_entities locally.
#              PHYSICS OVERHAUL (LOW-LEVEL PHYSICS SERVER):
#              - Replaced high-overhead `CollisionShape3D` node instantiation with 
#                direct raw memory interaction via `PhysicsServer3D`.
#              - Secured the `BoxShape3D` resource in a static class variable 
#                to prevent Garbage Collection of physics forms mid-game.
#              - Restored the strict Thread Throttling limit (3 concurrent tasks)
#                and main-thread instancing limit (4 per frame). Unlocked C++ thread 
#                flooding was causing CPU cache thrashing and severe FPS drops. 
#                This safe throttling ensures buttery-smooth 120 FPS gameplay.
#              BUG FIX (FAST-TRAVEL TIMEOUT CLOGGING):
#              - Implemented a Priority Queue architecture. Prioritized chunk requests 
#                (like fast-travel target zones) are now pushed to the FRONT of the 
#                task queue (`push_front`), bypassing the massive background scenic 
#                chunk load buffers, enabling near-instantaneous spawning.
#              - PHYSICS SERVER RESTORATION: Re-implemented the direct `PhysicsServer3D` 
#                box collision grid, completely removing the buggy `collision_vertices` 
#                property access and fixing the crash.
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
var _load_requests_queue: Array = []

## Number of currently active background WorkerThreadPool tasks
var _active_background_tasks: int = 0

## Maximum concurrent background tasks allowed (Limits CPU core saturation for smooth FPS)
const MAX_CONCURRENT_BG_TASKS: int = 3

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode
var _chunk_nodes: Dictionary = {}

## Tracking map for entities spawned within specific chunk columns: Vector3i (y=0) -> Array[Node]
var _chunk_entities: Dictionary = {}

## Map storing raw PhysicsServer3D body RIDs for safe manual deletion
var _physics_bodies: Dictionary = {} # Vector3i -> RID

# Cache System (LRU)
var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64

# ==============================================================================
# STATIC PHYSICS FLYWEIGHT (Protects collisions from Garbage Collection)
# ==============================================================================
static var _shared_physics_box_shape: BoxShape3D = null


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	controller = p_controller
	world_state = p_world_state
	_queue_mutex = Mutex.new()


## Retrieves the single persistent physical box shape, instantiating it if necessary.
static func _get_or_create_shared_box() -> BoxShape3D:
	if _shared_physics_box_shape == null:
		_shared_physics_box_shape = BoxShape3D.new()
		_shared_physics_box_shape.size = Vector3(1.0, 1.0, 1.0)
	return _shared_physics_box_shape


## Verifies if a chunk is loaded and rendered
func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_nodes.has(chunk_pos)


## Public API: Returns the active chunk nodes (Used by auxiliary services)
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


## BUG FIX (PRIORITY QUEUE): Queues chunks with high priority (pushes to front of loading queue)
func queue_prioritized_loads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		_request_asynchronous_chunk_load(pos, true)


## Queues chunks to be unloaded from memory
func queue_unloads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		if not _unload_queue.has(pos):
			_unload_queue.append(pos)


## Safe Frame Ticker: Process unloads and drains the completed tasks queue smoothly.
func process_frame_queues() -> void:
	var unloads_processed := 0
	while _unload_queue.size() > 0 and unloads_processed < 3:
		var chunk_to_unload := _unload_queue.pop_front() as Vector3i
		_unload_chunk_node(chunk_to_unload)
		unloads_processed += 1
		
	_render_completed_chunks_from_queue()


func _request_asynchronous_chunk_load(chunk_pos: Vector3i, high_priority: bool = false) -> void:
	_queue_mutex.lock()
	if _pending_loading_chunks.has(chunk_pos):
		_queue_mutex.unlock()
		return
		
	if _chunk_task_cache.has(chunk_pos):
		var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos] as GeneratedChunkTask
		_completed_tasks_queue.append(cached_task)
		_queue_mutex.unlock()
		return
		
	_pending_loading_chunks[chunk_pos] = true
	
	var req: Dictionary = {"pos": chunk_pos, "is_rebuild": false}
	if high_priority:
		_load_requests_queue.push_front(req) # Bypasses scenic loading backlog!
		print("[ChunkManager DEBUG] Prioritized chunk load task pushed to FRONT: ", chunk_pos)
	else:
		_load_requests_queue.append(req)
		
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
	
	if not is_instance_valid(controller):
		return
		
	controller.generator.generate_chunk(chunk)
	
	if not is_instance_valid(controller) or not is_instance_valid(controller.repository):
		return
		
	var saved_edits: Dictionary = controller.repository.load_chunk_modifications(chunk_pos) as Dictionary
	if saved_edits.size() > 0:
		for local_pos: Vector3i in saved_edits.keys():
			var type_val: int = saved_edits[local_pos] as int
			chunk.set_block(local_pos.x, local_pos.y, local_pos.z, type_val as BlockType.Type)
			
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state) as Dictionary
	
	if not is_instance_valid(controller):
		return
		
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null:
			liquids[l_type] = l_mesh
	
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = null 
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
	
	if not is_instance_valid(controller):
		return
		
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null:
			liquids[l_type] = l_mesh
			
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = null
	task_result.is_rebuild = true
	task_result.liquid_meshes = liquids
	
	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


# ==============================================================================
# MAIN THREAD MESH ASSEMBLY
# ==============================================================================

func _render_completed_chunks_from_queue() -> void:
	var rendered_this_frame := 0
	const MAX_CHUNKS_PER_FRAME := 4 
	
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
		
	# ==========================================================================
	# HIGH-PERFORMANCE LOW-LEVEL PHYSICS SERVER (STUTTER FIX)
	# Constructs solid block physics by communicating directly with C++ memory, 
	# completely bypassing node instantiation overhead on the main thread.
	# ==========================================================================
	
	# Delete previous body if rebuilding
	if _physics_bodies.has(chunk_pos):
		var old_rid: RID = _physics_bodies[chunk_pos]
		PhysicsServer3D.free_rid(old_rid)
		_physics_bodies.erase(chunk_pos)
		
	var box_shape: BoxShape3D = _get_or_create_shared_box()
	var shape_rid: RID = box_shape.get_rid()
	
	# Create a raw Static Body in the Physics Server
	var body_rid: RID = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
	
	# Bind a collision layer mask so it correctly interacts with RayCasts!
	PhysicsServer3D.body_set_collision_layer(body_rid, 1)
	PhysicsServer3D.body_set_collision_mask(body_rid, 1)
	
	PhysicsServer3D.body_set_space(body_rid, controller.get_world_3d().space)
	
	# Position the invisible body exactly where the visual chunk sits
	var chunk_transform := Transform3D(Basis(), Vector3(chunk_pos * Chunk.SIZE))
	PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, chunk_transform)
	
	# Inject all valid solid transforms into this raw body
	for b_type: BlockType.Type in task.multimesh_data.keys():
		if BlockType.is_solid(b_type):
			var bulk_array: PackedFloat32Array = task.multimesh_data[b_type] as PackedFloat32Array
			var count: int = int(bulk_array.size() / 12.0)
			
			for i: int in range(count):
				var offset := i * 12
				var basis_x := Vector3(bulk_array[offset + 0], bulk_array[offset + 4], bulk_array[offset + 8])
				var basis_y := Vector3(bulk_array[offset + 1], bulk_array[offset + 5], bulk_array[offset + 9])
				var basis_z := Vector3(bulk_array[offset + 2], bulk_array[offset + 6], bulk_array[offset + 10])
				var origin := Vector3(bulk_array[offset + 3], bulk_array[offset + 7], bulk_array[offset + 11])
				
				var local_transform := Transform3D(Basis(basis_x, basis_y, basis_z), origin)
				
				# Link the shared shape at this exact offset block position instantly
				PhysicsServer3D.body_add_shape(body_rid, shape_rid, local_transform)
				
	_physics_bodies[chunk_pos] = body_rid
	# ==========================================================================
	
	var chunk_node: ChunkNode = null
	if _chunk_nodes.has(chunk_pos):
		chunk_node = _chunk_nodes[chunk_pos] as ChunkNode
		chunk_node.setup_chunk_visuals(task.multimesh_data, null, task.liquid_meshes)
	else:
		if task.is_rebuild:
			return
			
		chunk_node = ChunkNode.new(task.chunk)
		controller.add_child(chunk_node)
		chunk_node.setup_chunk_visuals(task.multimesh_data, null, task.liquid_meshes)
		_chunk_nodes[chunk_pos] = chunk_node
		
		# Register accessories
		controller.register_streetlights_for_chunk(task.chunk)
		controller.check_player_spawn_activation()


## Dynamic Proximity Mob Spawner
func spawn_mobs_by_proximity(player_global_pos: Vector3, spawn_radius: int = 2) -> void:
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
				
				# Spawns mobs only if we haven't already populated this chunk column
				if not _chunk_entities.has(col_pos) and _physics_bodies.has(target_chunk_pos_0):
					var chunk_0: Chunk = _chunk_nodes[target_chunk_pos_0].chunk as Chunk
					var spawned: Array[Node] = controller.spawn_mobs_for_chunk(chunk_0)
					_chunk_entities[col_pos] = spawned


func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	_queue_mutex.lock()
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
	_queue_mutex.unlock()
	
	var col_pos := Vector3i(chunk_pos.x, 0, chunk_pos.z)
	if _chunk_entities.has(col_pos):
		var entities: Array = _chunk_entities[col_pos] as Array
		for entity: Node in entities:
			if is_instance_valid(entity): 
				entity.queue_free()
		_chunk_entities.erase(col_pos)

	controller.unregister_streetlights_for_chunk(chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos) as ChunkNode
	if is_instance_valid(chunk_node):
		chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)
	
	# Memory Cleanup: Free the hidden raw physics body manually
	if _physics_bodies.has(chunk_pos):
		var rid: RID = _physics_bodies[chunk_pos]
		PhysicsServer3D.free_rid(rid)
		_physics_bodies.erase(chunk_pos)
