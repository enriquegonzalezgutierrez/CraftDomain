# ==============================================================================
# Project: CraftDomain
# Description: High-Performance Infrastructure Service responsible for managing 
#              background chunk generation threads, task caching, and direct RID physics.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Coordinates chunk lifecycle, delegating 
#   heavy geometry and physics tree compiling to background worker threads.
# THREAD-LEAK BUG RESOLUTION:
# - Resolved thread leak deadlock where chunks wiped from the pending queue during 
#   hot-swapping remained permanently locked as "in-flight".
# - Now, `_in_flight_tasks` only registers chunks physically running on background 
#   threads, while `_is_queued` dynamically inspects the waiting buffer.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/ChunkManagerService.gd
# ==============================================================================
class_name ChunkManagerService
extends RefCounted

var controller: Node3D 
var world_state: WorldState

var _queue_mutex: Mutex
var _completed_tasks_queue: Array[GeneratedChunkTask] = []
var _unload_queue: Array[Vector3i] = []

# THREADING TRACKERS: Strictly isolates waiting buffer from active thread executions
var _in_flight_tasks: Dictionary = {} # Vector3i -> bool (Active in WorkerThreadPool)
var _load_requests_queue: Array = [] # Array[Dictionary] (Waiting buffer)

var _queued_rebuilds: Dictionary = {}
var _active_task_ids: Array[int] = []
var _active_background_tasks: int = 0
var _max_concurrent_bg_tasks: int = 4

var _chunk_nodes: Dictionary = {}
var _chunk_entities: Dictionary = {}
var _physics_bodies: Dictionary = {} 
var _collision_shapes: Dictionary = {} 

var _chunk_lod_states: Dictionary = {} 

var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64

# THREAD SAFETY CACHE: Updated by Main Thread, read by Background Threads
var _last_known_viewer_chunk_pos: Vector3i = Vector3i.ZERO

# DIAGNOSTICS TIMERS
var _diagnostic_timer: float = 1.0


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	controller = p_controller
	world_state = p_world_state
	_queue_mutex = Mutex.new()
	
	_max_concurrent_bg_tasks = clampi(OS.get_processor_count() + 1, 4, 16)
	print("[ChunkManagerService] Initialized aggressive multi-threading with pool size: ", _max_concurrent_bg_tasks)


func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_nodes.has(chunk_pos)


func get_active_nodes() -> Dictionary:
	return _chunk_nodes


func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	_request_chunk_rebuild(chunk_pos)
	
	var local_pos := world_state.global_to_local_pos(global_pos)
	
	if local_pos.x == 0: _request_chunk_rebuild(chunk_pos + Vector3i(-1, 0, 0))
	elif local_pos.x == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(1, 0, 0))
		
	if local_pos.y == 0: _request_chunk_rebuild(chunk_pos + Vector3i(0, -1, 0))
	elif local_pos.y == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(0, 1, 0))
		
	if local_pos.z == 0: _request_chunk_rebuild(chunk_pos + Vector3i(0, 0, -1))
	elif local_pos.z == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(0, 0, 1))


## Dynamic Queue Hot-Swapper: Wipes the stale waiting buffer and populates 
## it with the newly prioritized list (ignoring chunks already executing in threads).
func queue_loads(chunk_positions: Array[Vector3i]) -> void:
	_queue_mutex.lock()
	
	# 1. Gather and safeguard high-priority REBUILD requests (like block placements)
	var rebuilds: Array[Dictionary] = []
	for req: Dictionary in _load_requests_queue:
		if req["is_rebuild"] == true:
			rebuilds.append(req)
			
	# 2. Flush and clear all stale, out-of-date pending load requests
	_load_requests_queue.clear()
	
	# 3. Re-populate with the fresh, directionally sorted positions (skip if actively generating on a thread)
	for pos: Vector3i in chunk_positions:
		if _in_flight_tasks.has(pos):
			continue # Already running on background thread, skip!
		_load_requests_queue.append({"pos": pos, "is_rebuild": false})
		
	# 4. Inject high-priority rebuilds back at the absolute front of the queue
	for req: Dictionary in rebuilds:
		_load_requests_queue.push_front(req)
		
	_queue_mutex.unlock()
	
	# 5. Wake up background threads to work on the new prioritized coordinates immediately
	_trigger_next_background_tasks()


func queue_prioritized_loads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		_request_asynchronous_chunk_load(pos, true)


func queue_unloads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		if not _unload_queue.has(pos):
			_unload_queue.append(pos)


func process_frame_queues(delta: float) -> void:
	# THREAD SAFETY: Cache player position safely on the MAIN THREAD
	if is_instance_valid(controller) and is_instance_valid(controller.get("player")):
		var player_node: Node3D = controller.get("player") as Node3D
		if is_instance_valid(player_node):
			var p_pos := player_node.global_position
			_last_known_viewer_chunk_pos = world_state.global_to_chunk_pos(Vector3i(floori(p_pos.x), floori(p_pos.y), floori(p_pos.z)))
	
	# DIAGNOSTICS: Run throttled telemetric output
	_diagnostic_timer -= delta
	if _diagnostic_timer <= 0.0:
		_diagnostic_timer = 1.0
		_print_diagnostics()
	
	# Throttle LOD scans to avoid heavy main-thread work every single frame
	if Engine.get_frames_drawn() % 15 == 0:
		_execute_lod_scans()
	
	var unloads_processed := 0
	while _unload_queue.size() > 0 and unloads_processed < 5:
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


func _print_diagnostics() -> void:
	_queue_mutex.lock()
	var pending_queue_size := _load_requests_queue.size()
	var completed_queue_size := _completed_tasks_queue.size()
	var active_tasks := _active_background_tasks
	var active_nodes_count := _chunk_nodes.size()
	var unloads_remaining := _unload_queue.size()
	_queue_mutex.unlock()
	
	print("[ChunkTelemetry] Rendered Nodes: %d | Active Threads: %d/%d | Pending Load Queue: %d | Completed Tasks (Waiting GPU): %d | Chunks to Unload: %d" % [
		active_nodes_count,
		active_tasks,
		_max_concurrent_bg_tasks,
		pending_queue_size,
		completed_queue_size,
		unloads_remaining
	])


## Helper: Checks if a chunk coordinate is already waiting in the loading buffer
func _is_queued(pos: Vector3i) -> bool:
	for req: Dictionary in _load_requests_queue:
		if req["pos"] == pos:
			return true
	return false


func _request_asynchronous_chunk_load(chunk_pos: Vector3i, high_priority: bool = false) -> void:
	_queue_mutex.lock()
	
	if _chunk_task_cache.has(chunk_pos):
		var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos] as GeneratedChunkTask
		if not _completed_tasks_queue.has(cached_task):
			_completed_tasks_queue.append(cached_task)
		_queue_mutex.unlock()
		return
		
	# Skip if already generating on a thread OR already waiting in queue
	if _in_flight_tasks.has(chunk_pos) or _is_queued(chunk_pos):
		_queue_mutex.unlock()
		return
	
	var new_req: Dictionary = {"pos": chunk_pos, "is_rebuild": false}
	if high_priority:
		_load_requests_queue.push_front(new_req)
	else:
		_load_requests_queue.append(new_req)
		
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_nodes.has(chunk_pos): return
		
	_queue_mutex.lock()
	if _in_flight_tasks.has(chunk_pos) or _is_queued(chunk_pos):
		_queue_mutex.unlock()
		return
		
	_load_requests_queue.push_front({"pos": chunk_pos, "is_rebuild": true})
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


func _trigger_next_background_tasks() -> void:
	_queue_mutex.lock()
	while _active_background_tasks < _max_concurrent_bg_tasks and _load_requests_queue.size() > 0:
		var request: Dictionary = _load_requests_queue.pop_front() as Dictionary
		var pos: Vector3i = request["pos"] as Vector3i
		var is_rebuild: bool = request["is_rebuild"] as bool
		
		_active_background_tasks += 1
		# LIFECYCLE PINPOINT: Only set as in-flight when the background thread spawns!
		_in_flight_tasks[pos] = true 
		
		var task_id: int
		if is_rebuild:
			task_id = WorkerThreadPool.add_task(_background_rebuild_chunk_task_wrapper.bind(pos))
		else:
			task_id = WorkerThreadPool.add_task(_background_generate_chunk_task_wrapper.bind(pos))
		_active_task_ids.append(task_id)
	_queue_mutex.unlock()


func _background_generate_chunk_task_wrapper(chunk_pos: Vector3i) -> void:
	_background_generate_chunk_task(chunk_pos)
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := Chunk.new(chunk_pos)
	if not is_instance_valid(controller): return
		
	var gen: WorldGenerator = controller.get("generator") as WorldGenerator
	if is_instance_valid(gen): gen.generate_chunk(chunk)
	
	if not is_instance_valid(controller) or not is_instance_valid(controller.repository): return
		
	var saved_edits: Dictionary = controller.repository.load_chunk_modifications(chunk_pos) as Dictionary
	if saved_edits.size() > 0:
		for local_pos: Vector3i in saved_edits.keys():
			chunk.set_block(local_pos.x, local_pos.y, local_pos.z, saved_edits[local_pos] as BlockType.Type)
			
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	var build_physics := not is_distant
	
	# Pass build_physics flag to aggressively cull hidden geometry computations
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state, build_physics) as Dictionary
	
	var collision_vertices: PackedVector3Array = visual_data["collision_vertices"] as PackedVector3Array
	var col_shape: ConcavePolygonShape3D = null
	if collision_vertices.size() > 0:
		col_shape = ConcavePolygonShape3D.new()
		col_shape.set_faces(collision_vertices) 
	
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null: liquids[l_type] = l_mesh
	
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = col_shape 
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
	if chunk == null: return
		
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	var build_physics := not is_distant
	
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state, build_physics) as Dictionary
	
	var collision_vertices: PackedVector3Array = visual_data["collision_vertices"] as PackedVector3Array
	var col_shape: ConcavePolygonShape3D = null
	if collision_vertices.size() > 0:
		col_shape = ConcavePolygonShape3D.new()
		col_shape.set_faces(collision_vertices)
		
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null: liquids[l_type] = l_mesh
			
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = col_shape
	task_result.is_rebuild = true
	task_result.liquid_meshes = liquids
	
	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


func _render_completed_chunks_from_queue() -> void:
	var start_time := Time.get_ticks_usec()
	var rendered_this_frame := 0
	const TIME_BUDGET_USEC := 4500 
	
	while true:
		var elapsed := Time.get_ticks_usec() - start_time
		if elapsed > TIME_BUDGET_USEC and rendered_this_frame >= 1: break
			
		var task: GeneratedChunkTask = null
		_queue_mutex.lock()
		if _completed_tasks_queue.size() > 0:
			task = _completed_tasks_queue.pop_front() as GeneratedChunkTask
		_queue_mutex.unlock()
		
		if task == null: break 
		_render_single_completed_task(task)
		rendered_this_frame += 1


func _render_single_completed_task(task: GeneratedChunkTask) -> void:
	var chunk_pos: Vector3i = task.chunk.position
	
	_queue_mutex.lock()
	_in_flight_tasks.erase(chunk_pos) # Mark task as finished
	_queue_mutex.unlock()
	
	if _queued_rebuilds.has(chunk_pos):
		_queued_rebuilds.erase(chunk_pos)
		_request_chunk_rebuild(chunk_pos)
		
	if not task.is_rebuild and is_instance_valid(world_state):
		world_state.add_chunk(task.chunk)
		
	if _physics_bodies.has(chunk_pos):
		var old_rid: RID = _physics_bodies[chunk_pos]
		PhysicsServer3D.free_rid(old_rid)
		_physics_bodies.erase(chunk_pos)
		
	if _collision_shapes.has(chunk_pos): _collision_shapes.erase(chunk_pos) 
		
	if task.collision_shape != null:
		_collision_shapes[chunk_pos] = task.collision_shape
		
		var body_rid: RID = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(body_rid, 1)
		PhysicsServer3D.body_set_collision_mask(body_rid, 1)
		PhysicsServer3D.body_set_space(body_rid, controller.get_world_3d().space)
		
		var chunk_transform := Transform3D(Basis(), Vector3(chunk_pos * Chunk.SIZE))
		PhysicsServer3D.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, chunk_transform)
		PhysicsServer3D.body_add_shape(body_rid, task.collision_shape.get_rid())
		_physics_bodies[chunk_pos] = body_rid
	
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	_chunk_lod_states[chunk_pos] = is_distant
	
	var chunk_node: ChunkNode = null
	if _chunk_nodes.has(chunk_pos):
		chunk_node = _chunk_nodes[chunk_pos] as ChunkNode
		chunk_node.setup_chunk_visuals(task.multimesh_data, null, task.liquid_meshes, is_distant)
	else:
		if task.is_rebuild: return
			
		chunk_node = ChunkNode.new(task.chunk)
		controller.add_child(chunk_node)
		chunk_node.setup_chunk_visuals(task.multimesh_data, null, task.liquid_meshes, is_distant)
		_chunk_nodes[chunk_pos] = chunk_node
		
		if controller.has_method("register_streetlights_for_chunk"): controller.call("register_streetlights_for_chunk", task.chunk)
		if controller.has_method("check_player_spawn_activation"): controller.call("check_player_spawn_activation")


func spawn_entities_by_proximity(player_global_pos: Vector3, spawn_radius: int = 2) -> void:
	var player_block_pos := Vector3i(floor(player_global_pos.x), floor(player_global_pos.y), floor(player_global_pos.z))
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
							if n_element is Node: typed_nodes.append(n_element as Node)
						_chunk_entities[col_pos] = typed_nodes


func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	_queue_mutex.lock()
	_in_flight_tasks.erase(chunk_pos)
	if _queued_rebuilds.has(chunk_pos): _queued_rebuilds.erase(chunk_pos)
	_queue_mutex.unlock()
	
	var col_pos := Vector3i(chunk_pos.x, 0, chunk_pos.z)
	if _chunk_entities.has(col_pos):
		var entities: Array = _chunk_entities[col_pos] as Array
		for entity: Node in entities:
			if is_instance_valid(entity): entity.queue_free()
		_chunk_entities.erase(col_pos)

	if controller.has_method("unregister_streetlights_for_chunk"):
		controller.call("unregister_streetlights_for_chunk", chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos) as ChunkNode
	if is_instance_valid(chunk_node): chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)
	
	if _chunk_lod_states.has(chunk_pos): _chunk_lod_states.erase(chunk_pos)
	
	if _physics_bodies.has(chunk_pos):
		PhysicsServer3D.free_rid(_physics_bodies[chunk_pos])
		_physics_bodies.erase(chunk_pos)
		
	if _collision_shapes.has(chunk_pos): _collision_shapes.erase(chunk_pos) 


func _execute_lod_scans() -> void:
	for chunk_pos: Vector3i in _chunk_nodes.keys():
		var chunk_node: ChunkNode = _chunk_nodes[chunk_pos] as ChunkNode
		if not is_instance_valid(chunk_node): continue
			
		var is_now_distant := _calculate_is_chunk_distant(chunk_pos)
		var last_known_state: bool = _chunk_lod_states.get(chunk_pos, false)
		
		if is_now_distant != last_known_state:
			_chunk_lod_states[chunk_pos] = is_now_distant
			chunk_node.update_lod_materials(is_now_distant)
			
			if not is_now_distant and not _physics_bodies.has(chunk_pos):
				_request_chunk_rebuild(chunk_pos)


func _calculate_is_chunk_distant(chunk_pos: Vector3i) -> bool:
	var p_chunk_pos: Vector3i = _last_known_viewer_chunk_pos
	var dist := Vector2(chunk_pos.x - p_chunk_pos.x, chunk_pos.z - p_chunk_pos.z).length()
	
	var currently_distant: bool = _chunk_lod_states.get(chunk_pos, true)
	if currently_distant: return dist > 3.5 
	else: return dist > 4.5 


func shutdown() -> void:
	_queue_mutex.lock()
	_load_requests_queue.clear()
	var tasks_to_wait := _active_task_ids.duplicate()
	_queue_mutex.unlock()
	for id: int in tasks_to_wait:
		WorkerThreadPool.wait_for_task_completion(id)
