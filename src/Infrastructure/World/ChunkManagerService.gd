# ==============================================================================
# Project: CraftDomain
# Description: High-Performance Infrastructure Service responsible for managing 
#              background chunk generation threads, task caching, and direct RID physics.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Coordinates chunk lifecycle, 
#                delegating heavy geometry and physics tree compiling to background worker threads.
#              FLYWEIGHT BOXSHAPE3D RESOLUTION:
#              - Completely deprecated raw ConcavePolygonShape3D PhysicsServer3D RIDs.
#              - Implemented the original architectural Flyweight Collision Grid using a single, 
#                shared, static `BoxShape3D` resource across all active solid block transforms.
#              - Physical colliders are instantiated as StaticBody3D nodes and attached directly 
#                to ChunkNodes via `set_collision_body()`, aligning perfectly with SceneTree lifecycles.
#              EXTREME PERFORMANCE UPGRADES (THREADED INSTANTIATION):
#              - Fully offloaded the expensive main-thread `CollisionShape3D` instantiation loop 
#                into the background threads inside `WorkerThreadPool`. 
#              PRIORITY PERSISTENCE OVERHAUL:
#              - Modified `_request_asynchronous_chunk_load` to append a "high_priority" flag.
#              - Updated `queue_loads` to safely extract and preserve high-priority 
#                teleportation/spawn chunks, preventing them from being wiped during 
#                horizon updates.
#              THREAD SAFETY & FLOOD PROTECTION CORRECTION:
#              - Moved all Node instantiations (StaticBody3D and CollisionShape3D) out of the
#                WorkerThreadPool background threads and into the Main Thread renderer queue.
#              - Added a safety check in `_request_asynchronous_chunk_load` to discard
#                redundant rebuild requests on chunks already in the scene tree.
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

## Dictionary mapping Vector3i -> bool tracking chunks that need a SECOND rebuild 
var _queued_rebuilds: Dictionary = {}
var _active_task_ids: Array[int] = []
var _active_background_tasks: int = 0
var _max_concurrent_bg_tasks: int = 4

var _chunk_nodes: Dictionary = {}
var _chunk_entities: Dictionary = {}
var _physics_bodies: Dictionary = {} # Vector3i -> RID (Stored for entity proximity checks)

var _chunk_lod_states: Dictionary = {} 

# THREAD SAFETY CACHE: Updated by Main Thread, read by Background Threads
var _last_known_viewer_chunk_pos: Vector3i = Vector3i.ZERO

# CHUNK REVISION VERSIONING: Maps Vector3i -> int (Increments on edits)
var _chunk_versions: Dictionary = {}

# FLYWEIGHT PATTERN: Single static BoxShape3D shared across millions of block colliders
static var _shared_box_shape: BoxShape3D = null


## Lazy loader for the shared flyweight box shape
static func _get_shared_box_shape() -> BoxShape3D:
	if _shared_box_shape == null:
		_shared_box_shape = BoxShape3D.new()
		_shared_box_shape.size = Vector3(1.0, 1.0, 1.0)
	return _shared_box_shape


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	controller = p_controller
	world_state = p_world_state
	_queue_mutex = Mutex.new()
	
	_max_concurrent_bg_tasks = clampi(OS.get_processor_count() + 1, 4, 16)
	print("[ChunkManagerService] Initialized aggressive multi-threading with pool size: ", _max_concurrent_bg_tasks)


## Checks if a chunk at the given coordinate position is currently loaded and rendered
func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_nodes.has(chunk_pos)


## Returns the active, loaded chunk nodes dictionary mapping
func get_active_nodes() -> Dictionary:
	return _chunk_nodes


## Places or breaks a block globally, and instantly updates the visual 
## and physical mesh on the main thread for immediate responsiveness.
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	
	# Increment version of modified chunk immediately on the Main Thread
	_chunk_versions[chunk_pos] = _chunk_versions.get(chunk_pos, 0) + 1
	
	# Trigger the first selection visually
	_rebuild_chunk_instantly(chunk_pos)
	
	# Check if adjacent blocks on the chunk boundaries were affected to rebuild neighbor meshes
	var local_pos := world_state.global_to_local_pos(global_pos)
	
	if local_pos.x == 0:
		var neighbor_pos := chunk_pos + Vector3i(-1, 0, 0)
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		_rebuild_chunk_instantly(neighbor_pos)
	elif local_pos.x == Chunk.SIZE - 1:
		var neighbor_pos := chunk_pos + Vector3i(1, 0, 0)
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		_rebuild_chunk_instantly(neighbor_pos)
		
	if local_pos.y == 0:
		var neighbor_pos := chunk_pos + Vector3i(0, -1, 0)
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		_rebuild_chunk_instantly(neighbor_pos)
	elif local_pos.y == Chunk.SIZE - 1:
		var neighbor_pos := chunk_pos + Vector3i(0, 1, 0)
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		_rebuild_chunk_instantly(neighbor_pos)
		
	if local_pos.z == 0:
		var neighbor_pos := chunk_pos + Vector3i(0, 0, -1)
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		_rebuild_chunk_instantly(neighbor_pos)
	elif local_pos.z == Chunk.SIZE - 1:
		var neighbor_pos := chunk_pos + Vector3i(0, 0, 1)
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		_rebuild_chunk_instantly(neighbor_pos)


## Dynamic Queue Hot-Swapper: Wipes the stale waiting buffer and populates 
## it with the newly prioritized list, preserving existing high-priority and rebuild requests.
func queue_loads(chunk_positions: Array[Vector3i]) -> void:
	_queue_mutex.lock()
	
	# Retain active rebuild requests and high-priority teleport tasks
	var preserved_tasks: Array[Dictionary] = []
	for req: Dictionary in _load_requests_queue:
		if req.get("is_rebuild", false) == true or req.get("high_priority", false) == true:
			preserved_tasks.append(req)
			
	_load_requests_queue.clear()
	
	for pos: Vector3i in chunk_positions:
		if _in_flight_tasks.has(pos):
			continue 
			
		# Avoid duplicate entries for chunks already preserved in the rebuild or high-priority list
		if is_now_distinct_or_queued(pos, preserved_tasks):
			continue
			
		var active_version: int = _chunk_versions.get(pos, 0)
		_load_requests_queue.append({"pos": pos, "is_rebuild": false, "version": active_version})
		
	# Place the preserved and high-priority tasks back at the front of the queue
	for i: int in range(preserved_tasks.size() - 1, -1, -1):
		_load_requests_queue.push_front(preserved_tasks[i])
		
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


## Inlined checker helper to filter out duplicates of preserved tasks
func is_now_distinct_or_queued(pos: Vector3i, list: Array) -> bool:
	for req: Dictionary in list:
		if req["pos"] == pos:
			return true
	return false


## Forces priority loading on a specific list of target chunks (e.g., spawn areas)
func queue_prioritized_loads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		_request_asynchronous_chunk_load(pos, true)


## Schedules a list of chunks to be unloaded as the player translates away
func queue_unloads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		if not _unload_queue.has(pos):
			_unload_queue.append(pos)


## Main thread updater coordinating asynchronous queue processing and thread state checks
func process_frame_queues(_delta: float) -> void:
	var player_active := false
	if is_instance_valid(controller) and is_instance_valid(controller.get("player")):
		var player_node: Node3D = controller.get("player") as Node3D
		if is_instance_valid(player_node):
			player_active = player_node.get("is_active") as bool
			var p_pos := player_node.global_position
			_last_known_viewer_chunk_pos = world_state.global_to_chunk_pos(Vector3i(floori(p_pos.x), floori(p_pos.y), floori(p_pos.z)))
	
	if Engine.get_frames_drawn() % 15 == 0:
		_execute_lod_scans()
	
	var max_unloads := 100 if not player_active else 5
	var unloads_processed := 0
	while _unload_queue.size() > 0 and unloads_processed < max_unloads:
		var chunk_to_unload := _unload_queue.pop_front() as Vector3i
		_unload_chunk_node(chunk_to_unload)
		unloads_processed += 1
		
	_render_completed_chunks_from_queue(player_active)
	
	_queue_mutex.lock()
	var active_temp: Array[int] = []
	for id: int in _active_task_ids:
		if not WorkerThreadPool.is_task_completed(id):
			active_temp.append(id)
	_active_task_ids = active_temp
	_queue_mutex.unlock()


func _is_queued(pos: Vector3i) -> bool:
	for req: Dictionary in _load_requests_queue:
		if req["pos"] == pos:
			return true
	return false


## Dispatches an asynchronous loading task for a specific chunk, allowing priority override
func _request_asynchronous_chunk_load(chunk_pos: Vector3i, high_priority: bool = false) -> void:
	_queue_mutex.lock()
	
	if world_state.get_chunk(chunk_pos) != null:
		if _chunk_nodes.has(chunk_pos):
			# FLOOD PROTECTION: Already loaded and fully rendered in the tree, ignore!
			_queue_mutex.unlock()
			return
		else:
			# Loaded in database but needs visual mesh rebuilding
			_queue_mutex.unlock()
			_request_chunk_rebuild(chunk_pos)
			return
		
	if _in_flight_tasks.has(chunk_pos) or _is_queued(chunk_pos):
		_queue_mutex.unlock()
		return
	
	var active_version: int = _chunk_versions.get(chunk_pos, 0)
	var new_req: Dictionary = {"pos": chunk_pos, "is_rebuild": false, "version": active_version}
	if high_priority:
		new_req["high_priority"] = true
		_load_requests_queue.push_front(new_req)
	else:
		_load_requests_queue.append(new_req)
		
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


## Schedules a background task to rebuild the visual representation of an active chunk
func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_nodes.has(chunk_pos): return
		
	_queue_mutex.lock()
	
	if _in_flight_tasks.has(chunk_pos):
		_queued_rebuilds[chunk_pos] = true
		_queue_mutex.unlock()
		return
		
	if _is_queued(chunk_pos):
		_queue_mutex.unlock()
		return
		
	var active_version: int = _chunk_versions.get(chunk_pos, 0)
	_load_requests_queue.push_front({"pos": chunk_pos, "is_rebuild": true, "version": active_version})
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


## Synchronously rebuilds a chunk on the main thread for zero-latency player edits.
func _rebuild_chunk_instantly(chunk_pos: Vector3i) -> void:
	var chunk := world_state.get_chunk(chunk_pos)
	if chunk == null: return
		
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	var build_physics := not is_distant
	
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state, build_physics) as Dictionary
	
	var static_body: StaticBody3D = null
	if build_physics:
		var solid_positions := PackedVector3Array()
		for x in range(Chunk.SIZE):
			for y in range(Chunk.SIZE):
				for z in range(Chunk.SIZE):
					var block_type := chunk.get_block(x, y, z)
					if BlockType.is_solid(block_type):
						solid_positions.append(Vector3(x, y, z))
						
		if solid_positions.size() > 0:
			static_body = StaticBody3D.new()
			static_body.collision_layer = 1
			static_body.collision_mask = 1
			for local_pos: Vector3 in solid_positions:
				var col := CollisionShape3D.new()
				col.shape = _get_shared_box_shape()
				col.position = local_pos + Vector3(0.5, 0.5, 0.5)
				static_body.add_child(col)
				
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null: liquids[l_type] = l_mesh
			
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = null 
	task_result.is_rebuild = true
	task_result.liquid_meshes = liquids
	
	if static_body != null:
		task_result.set_meta("static_body", static_body)
		
	var current_version: int = _chunk_versions.get(chunk_pos, 0)
	task_result.set_meta("version", current_version)
	
	_render_single_completed_task(task_result)


## Thread dispatcher: Assigns queued positions to background threads under CPU limits
func _trigger_next_background_tasks() -> void:
	_queue_mutex.lock()
	while _active_background_tasks < _max_concurrent_bg_tasks and _load_requests_queue.size() > 0:
		var request: Dictionary = _load_requests_queue.pop_front() as Dictionary
		var pos: Vector3i = request["pos"] as Vector3i
		var is_rebuild: bool = request["is_rebuild"] as bool
		var target_version: int = request.get("version", 0) as int
		
		_active_background_tasks += 1
		_in_flight_tasks[pos] = true 
		
		var task_id: int
		if is_rebuild:
			task_id = WorkerThreadPool.add_task(_background_rebuild_chunk_task_wrapper.bind(pos, target_version))
		else:
			task_id = WorkerThreadPool.add_task(_background_generate_chunk_task_wrapper.bind(pos, target_version))
		_active_task_ids.append(task_id)
	_queue_mutex.unlock()


func _background_generate_chunk_task_wrapper(chunk_pos: Vector3i, version: int) -> void:
	_background_generate_chunk_task(chunk_pos, version)
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


func _background_generate_chunk_task(chunk_pos: Vector3i, version: int) -> void:
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
	
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state, build_physics) as Dictionary
	
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null: liquids[l_type] = l_mesh
	
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = null 
	task_result.liquid_meshes = liquids
	task_result.set_meta("version", version) 
	
	# Pass the raw collision vertices to the main thread instead of creating Nodes here
	if build_physics:
		task_result.set_meta("collision_vertices", visual_data["collision_vertices"])
	
	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


func _background_rebuild_chunk_task_wrapper(chunk_pos: Vector3i, version: int) -> void:
	_background_rebuild_chunk_task(chunk_pos, version)
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


func _background_rebuild_chunk_task(chunk_pos: Vector3i, version: int) -> void:
	var chunk := world_state.get_chunk(chunk_pos)
	if chunk == null: return
		
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	var build_physics := not is_distant
	
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state, build_physics) as Dictionary
	
	var liquids: Dictionary = {}
	for l_type: BlockType.Type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type) as ArrayMesh
		if l_mesh != null: liquids[l_type] = l_mesh
			
	var task_result: GeneratedChunkTask = GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_shape = null
	task_result.is_rebuild = true
	task_result.liquid_meshes = liquids
	task_result.set_meta("version", version) 
	
	if build_physics:
		task_result.set_meta("collision_vertices", visual_data["collision_vertices"])
	
	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


func _render_completed_chunks_from_queue(player_active: bool) -> void:
	var start_time := Time.get_ticks_usec()
	var rendered_this_frame := 0
	var time_budget_usec := 50000 if not player_active else 4500
	
	while true:
		var elapsed := Time.get_ticks_usec() - start_time
		if elapsed > time_budget_usec and rendered_this_frame >= 1: break
			
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
	
	var task_version: int = task.get_meta("version") if task.has_meta("version") else 0
	var current_version: int = _chunk_versions.get(chunk_pos, 0)
	
	if task_version < current_version:
		# Memory Leak Shield: Destroy orphaned precompiled static bodies if task is discarded
		var orphaned_body: Node = task.get_meta("static_body") if task.has_meta("static_body") else null
		if is_instance_valid(orphaned_body):
			orphaned_body.queue_free()
		return
	
	_queue_mutex.lock()
	_in_flight_tasks.erase(chunk_pos) 
	_queue_mutex.unlock()
	
	if _queued_rebuilds.has(chunk_pos):
		_queued_rebuilds.erase(chunk_pos)
		_request_chunk_rebuild(chunk_pos)
		
	if not task.is_rebuild and is_instance_valid(world_state):
		world_state.add_chunk(task.chunk)
		
	# Native Node memory delegation: Do not use free_rid on Nodes
	_physics_bodies.erase(chunk_pos)
	
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	_chunk_lod_states[chunk_pos] = is_distant
	
	# Safe main thread instantiation of the StaticBody3D physics body
	var static_body: StaticBody3D = task.get_meta("static_body") if task.has_meta("static_body") else null
	
	# If the static body wasn't pre-compiled on the main thread, construct it now from raw vertices
	if static_body == null and task.has_meta("collision_vertices"):
		var solid_positions: PackedVector3Array = task.get_meta("collision_vertices") as PackedVector3Array
		if solid_positions.size() > 0:
			static_body = StaticBody3D.new()
			static_body.collision_layer = 1
			static_body.collision_mask = 1
			
			var step_count := int(solid_positions.size() / 6)
			for i: int in range(step_count):
				var offset := i * 6
				var sum := Vector3.ZERO
				for j: int in range(6):
					sum += solid_positions[offset + j]
				var block_center := sum / 6.0
				
				var col := CollisionShape3D.new()
				col.shape = _get_shared_box_shape()
				col.position = block_center
				static_body.add_child(col)
	
	if is_instance_valid(static_body):
		_physics_bodies[chunk_pos] = static_body.get_rid()
	
	var chunk_node: ChunkNode = null
	if _chunk_nodes.has(chunk_pos):
		chunk_node = _chunk_nodes[chunk_pos] as ChunkNode
		chunk_node.setup_chunk_visuals(task.multimesh_data, static_body, task.liquid_meshes, is_distant)
	else:
		if task.is_rebuild: 
			if is_instance_valid(static_body): static_body.queue_free()
			return
			
		chunk_node = ChunkNode.new(task.chunk)
		controller.add_child(chunk_node)
		chunk_node.setup_chunk_visuals(task.multimesh_data, static_body, task.liquid_meshes, is_distant)
		_chunk_nodes[chunk_pos] = chunk_node
		
		if controller.has_method("register_streetlights_for_chunk"): controller.call("register_streetlights_for_chunk", task.chunk)
		if controller.has_method("check_player_spawn_activation"): controller.call("check_player_spawn_activation")


## Scans the coordinates of the newly rendered chunk to spawn wildlife or outpost populations
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
	if _chunk_nodes.has(chunk_pos):
		var node: ChunkNode = _chunk_nodes[chunk_pos] as ChunkNode
		_chunk_nodes.erase(chunk_pos)
		if is_instance_valid(node):
			node.queue_free()
			
	if _chunk_lod_states.has(chunk_pos):
		_chunk_lod_states.erase(chunk_pos)
		
	# Unload associated NPCs and entities to free systems memory
	var entities_key := Vector3i(chunk_pos.x, 0, chunk_pos.z)
	if _chunk_entities.has(entities_key):
		var entities: Array = _chunk_entities[entities_key] as Array
		_chunk_entities.erase(entities_key)
		for ent: Node in entities:
			if is_instance_valid(ent):
				ent.queue_free()
				
	_physics_bodies.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)


func _execute_lod_scans() -> void:
	for pos: Vector3i in _chunk_nodes.keys():
		var is_currently_distant := _calculate_is_chunk_distant(pos)
		var was_distant: bool = _chunk_lod_states.get(pos, false) as bool
		
		if is_currently_distant != was_distant:
			_chunk_lod_states[pos] = is_currently_distant
			var node: ChunkNode = _chunk_nodes[pos] as ChunkNode
			if is_instance_valid(node):
				node.update_lod_materials(is_currently_distant)
				
				# Rebuild solid block physics when moving closer
				if not is_currently_distant and not node.has_collision_body():
					_request_chunk_rebuild(pos)


func _calculate_is_chunk_distant(chunk_pos: Vector3i) -> bool:
	var current_distance := ChunkLoaderService.global_view_distance
	
	# Determine distance threshold (LOD shifts on the outer 3 rings of view distance)
	var lod_threshold := max(3, current_distance - 3)
	
	var diff_x := abs(chunk_pos.x - _last_known_viewer_chunk_pos.x)
	var diff_z := abs(chunk_pos.z - _last_known_viewer_chunk_pos.z)
	
	return diff_x > lod_threshold or diff_z > lod_threshold


## Pauses execution and blocks the main thread on exit until background thread workers have finished safely
func shutdown() -> void:
	_queue_mutex.lock()
	_load_requests_queue.clear()
	var tasks_to_wait := _active_task_ids.duplicate()
	_queue_mutex.unlock()
	for id: int in tasks_to_wait:
		WorkerThreadPool.wait_for_task_completion(id)
