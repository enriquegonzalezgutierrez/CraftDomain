# ==============================================================================
# Pathfile: res://src/Infrastructure/World/ChunkTaskScheduler.gd
# Description: Infrastructure scheduler managing background thread worker pools,
#              active task queues, and asynchronous chunk compiling (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkTaskScheduler
extends RefCounted

# Reference back to the parent lifecycle coordinator
var lifecycle: ChunkLifecycleService

# Thread-safe queue sharing parameters
var _queue_mutex: Mutex
var _load_requests_queue: Array = [] # Array[Dictionary] (Waiting buffer)
var _in_flight_tasks: Dictionary = {} # Vector3i -> bool (Active in WorkerThreadPool)
var _active_task_ids: Array[int] = []

var _active_background_tasks: int = 0
var _max_concurrent_bg_tasks: int = 4


func _init(p_lifecycle: ChunkLifecycleService, p_mutex: Mutex) -> void:
	lifecycle = p_lifecycle
	_queue_mutex = p_mutex
	_max_concurrent_bg_tasks = clampi(OS.get_processor_count() + 1, 4, 16)


## Thread dispatcher: Assigns queued positions to background threads under CPU limits.
func trigger_next_background_tasks() -> void:
	_queue_mutex.lock()
	
	# Evaluate if player is active (restoring full thread pool if active, throttling to 2 if loading/teleporting)
	var is_loading_teleport := true
	if is_instance_valid(lifecycle) and is_instance_valid(lifecycle.controller):
		var raw_player_node: Variant = lifecycle.controller.get("player")
		
		# THREAD SAFETY SHIELD: Validate physical memory instance before casting (DIP compliant)
		if is_instance_valid(raw_player_node):
			var player_node_3d := raw_player_node as Node3D
			if player_node_3d != null:
				is_loading_teleport = not (player_node_3d.get("is_active") as bool)
			
	var active_threads_limit := 2 if is_loading_teleport else _max_concurrent_bg_tasks
	
	while _active_background_tasks < active_threads_limit and _load_requests_queue.size() > 0:
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
	trigger_next_background_tasks()


func _background_generate_chunk_task(chunk_pos: Vector3i, version: int) -> void:
	var chunk := Chunk.new(chunk_pos)
	if not is_instance_valid(lifecycle) or not is_instance_valid(lifecycle.controller): 
		return
		
	var gen: WorldGenerator = lifecycle.controller.get("generator") as WorldGenerator
	if is_instance_valid(gen): 
		gen.generate_chunk(chunk)
	
	if not is_instance_valid(lifecycle.controller) or not is_instance_valid(lifecycle.controller.repository): 
		return
		
	var saved_edits: Dictionary = lifecycle.controller.repository.load_chunk_modifications(chunk_pos) as Dictionary
	if saved_edits.size() > 0:
		for local_pos: Vector3i in saved_edits.keys():
			chunk.set_block(local_pos.x, local_pos.y, local_pos.z, saved_edits[local_pos] as BlockType.Type)
			
	MegaStructureService.apply_mega_structures(chunk)
			
	var is_distant := lifecycle._calculate_is_chunk_distant(chunk_pos)
	var build_physics := not is_distant
	
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, lifecycle.world_state, build_physics) as Dictionary
	var custom_meshes: Dictionary = ChunkMesher.generate_special_meshes(chunk, lifecycle.world_state)
	
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.liquid_meshes = custom_meshes
	task_result.set_meta("version", version) 
	
	if build_physics:
		var collision_verts: PackedVector3Array = visual_data["collision_vertices"] as PackedVector3Array
		if collision_verts.size() > 0:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(collision_verts)
			shape.backface_collision = true
			task_result.collision_shape = shape
			
	var nav_nodes := ChunkNavigationBuilder.compile_walkable_nodes_asynchronous(chunk, lifecycle.world_state)
	task_result.set_meta("nav_nodes", nav_nodes)
	
	_queue_mutex.lock()
	lifecycle._completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


func _background_rebuild_chunk_task_wrapper(chunk_pos: Vector3i, version: int) -> void:
	_background_rebuild_chunk_task(chunk_pos, version)
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	trigger_next_background_tasks()


func _background_rebuild_chunk_task(chunk_pos: Vector3i, version: int) -> void:
	if not is_instance_valid(lifecycle) or lifecycle.world_state == null:
		return
		
	var chunk := lifecycle.world_state.get_chunk(chunk_pos)
	if chunk == null: 
		return
		
	var is_distant := lifecycle._calculate_is_chunk_distant(chunk_pos)
	var build_physics := not is_distant
	
	MegaStructureService.apply_mega_structures(chunk)
	
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, lifecycle.world_state, build_physics) as Dictionary
	var custom_meshes: Dictionary = ChunkMesher.generate_special_meshes(chunk, lifecycle.world_state)
			
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.is_rebuild = true
	task_result.liquid_meshes = custom_meshes
	task_result.set_meta("version", version) 
	
	if build_physics:
		var collision_verts: PackedVector3Array = visual_data["collision_vertices"] as PackedVector3Array
		if collision_verts.size() > 0:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(collision_verts)
			shape.backface_collision = true
			task_result.collision_shape = shape
			
	var nav_nodes := ChunkNavigationBuilder.compile_walkable_nodes_asynchronous(chunk, lifecycle.world_state)
	task_result.set_meta("nav_nodes", nav_nodes)
	
	_queue_mutex.lock()
	lifecycle._completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


func is_queued(pos: Vector3i) -> bool:
	for req: Dictionary in _load_requests_queue:
		if req["pos"] == pos:
			return true
	return false


## Pauses execution and blocks the main thread on exit until background thread workers have finished safely
func shutdown() -> void:
	_queue_mutex.lock()
	_load_requests_queue.clear()
	var tasks_to_wait := _active_task_ids.duplicate()
	_queue_mutex.unlock()
	for id: int in tasks_to_wait:
		WorkerThreadPool.wait_for_task_completion(id)
