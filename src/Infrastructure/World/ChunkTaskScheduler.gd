# ==============================================================================
# Pathfile: res://src/Infrastructure/World/ChunkTaskScheduler.gd
# Description: Infrastructure scheduler managing background thread worker pools,
#              asynchronous multi-threaded collision shape compilation, and
#              safe ThreadPool cleanup without C++ Invalid Task ID errors.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkTaskScheduler
extends RefCounted

var lifecycle: ChunkLifecycleService
var _queue_mutex: Mutex

var _load_requests_queue: Array[Dictionary] = []
var _in_flight_tasks: Dictionary = {}
var _active_task_ids: Array[int] = []
var _queued_rebuilds: Dictionary = {}
var _completed_tasks_queue: Array[GeneratedChunkTask] = []

var _active_background_tasks: int = 0
var _max_concurrent_bg_tasks: int = 4


func _init(p_lifecycle: ChunkLifecycleService, p_mutex: Mutex) -> void:
	_queue_mutex = p_mutex
	lifecycle = p_lifecycle
	_max_concurrent_bg_tasks = clampi(OS.get_processor_count() + 1, 4, 16)


## Queues standard chunk generation loads, maintaining high-priority rebuild requests
func queue_loads(chunk_positions: Array[Vector3i], versions: Dictionary) -> void:
	_queue_mutex.lock()
	var preserved_tasks := _extract_preserved_tasks()
	_load_requests_queue.clear()
	
	for pos: Vector3i in chunk_positions:
		_enqueue_if_eligible(pos, false, preserved_tasks, versions)
		
	for i: int in range(preserved_tasks.size() - 1, -1, -1):
		_load_requests_queue.push_front(preserved_tasks[i])
		
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


## Queues high-priority chunk loads (e.g. immediate spawn loading zones)
func queue_prioritized_loads(chunk_positions: Array[Vector3i], versions: Dictionary) -> void:
	_queue_mutex.lock()
	for pos: Vector3i in chunk_positions:
		_enqueue_if_eligible(pos, true, _load_requests_queue, versions)
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


## Enqueues an asynchronous chunk rebuild request dynamically when voxel edits occur
func request_chunk_rebuild(pos: Vector3i, version: int) -> void:
	if not lifecycle.is_chunk_rendered(pos): 
		return
		
	_queue_mutex.lock()
	if _in_flight_tasks.has(pos):
		_queued_rebuilds[pos] = true
	elif not _is_pos_in_queue(pos, _load_requests_queue):
		_load_requests_queue.push_front({"pos": pos, "is_rebuild": true, "version": version, "high_priority": true})
	_queue_mutex.unlock()
	_trigger_next_background_tasks()


func _extract_preserved_tasks() -> Array[Dictionary]:
	var preserved: Array[Dictionary] = []
	for req: Dictionary in _load_requests_queue:
		if req.get("is_rebuild", false) == true or req.get("high_priority", false) == true:
			preserved.append(req)
	return preserved


func _enqueue_if_eligible(pos: Vector3i, is_high_priority: bool, preserved: Array[Dictionary], versions: Dictionary) -> void:
	if _in_flight_tasks.has(pos) or _is_pos_in_queue(pos, preserved):
		return
		
	var version: int = versions.get(pos, 0) as int
	var req: Dictionary = {"pos": pos, "is_rebuild": false, "version": version, "high_priority": is_high_priority}
	
	if is_high_priority:
		_load_requests_queue.push_front(req)
	else:
		_load_requests_queue.append(req)


func _is_pos_in_queue(pos: Vector3i, list: Array[Dictionary]) -> bool:
	for req: Dictionary in list:
		var q_pos: Vector3i = req["pos"] as Vector3i
		if q_pos == pos:
			return true
	return false


func _trigger_next_background_tasks() -> void:
	_queue_mutex.lock()
	var active_threads_limit := _get_dynamic_thread_limit()
	
	while _active_background_tasks < active_threads_limit and _load_requests_queue.size() > 0:
		var request: Dictionary = _load_requests_queue.pop_front() as Dictionary
		_dispatch_task(request)
		
	_queue_mutex.unlock()


func _get_dynamic_thread_limit() -> int:
	var is_loading_teleport := true
	if is_instance_valid(lifecycle) and is_instance_valid(lifecycle.controller):
		var raw_player: Variant = lifecycle.controller.get("player")
		if typeof(raw_player) == TYPE_OBJECT and is_instance_valid(raw_player as Node3D):
			is_loading_teleport = not (raw_player.get("is_active") as bool)
			
	var gameplay_threads_limit := clampi(int(float(_max_concurrent_bg_tasks) / 4.0), 1, 2)
	return _max_concurrent_bg_tasks if is_loading_teleport else gameplay_threads_limit


func _dispatch_task(request: Dictionary) -> void:
	var pos: Vector3i = request["pos"] as Vector3i
	var is_rebuild: bool = request.get("is_rebuild", false) as bool
	var target_version: int = request.get("version", 0) as int
	
	_active_background_tasks += 1
	_in_flight_tasks[pos] = true 
	
	var task_id: int = -1
	if is_rebuild:
		task_id = WorkerThreadPool.add_task(_background_rebuild_task.bind(pos, target_version))
	else:
		task_id = WorkerThreadPool.add_task(_background_generate_task.bind(pos, target_version))
		
	if task_id >= 0:
		_active_task_ids.append(task_id)


func _background_generate_task(chunk_pos: Vector3i, version: int) -> void:
	var chunk := Chunk.new(chunk_pos)
	_apply_generator(chunk)
	
	var saved_edits := _apply_saved_modifications(chunk)
	_compile_and_submit_task(chunk, version, false, saved_edits)
	_finish_task_execution()


func _background_rebuild_task(chunk_pos: Vector3i, version: int) -> void:
	if not is_instance_valid(lifecycle) or lifecycle.world_state == null:
		_finish_task_execution()
		return
		
	var chunk := lifecycle.world_state.get_chunk(chunk_pos)
	if chunk == null:
		_finish_task_execution()
		return
		
	_compile_and_submit_task(chunk, version, true, {})
	_finish_task_execution()


func _apply_generator(chunk: Chunk) -> void:
	if not is_instance_valid(lifecycle) or not is_instance_valid(lifecycle.controller): 
		return
	var gen: WorldGenerator = lifecycle.controller.get("generator") as WorldGenerator
	if is_instance_valid(gen): 
		gen.generate_chunk(chunk)


func _apply_saved_modifications(chunk: Chunk) -> Dictionary:
	if not is_instance_valid(lifecycle) or not is_instance_valid(lifecycle.controller): return {}
	var repo := lifecycle.controller.get("repository") as WorldRepository
	if not is_instance_valid(repo): return {}
	
	var saved_edits := repo.load_chunk_modifications(chunk.position)
	var ws := lifecycle.world_state
	var key := "present" if ws.active_timeline == WorldState.Timeline.PRESENT else "past"
	
	var in_memory_mods := ws.get_chunk_modifications(chunk.position)
	var active_mods: Dictionary = {}
	if saved_edits.has(key) and saved_edits[key] is Dictionary:
		active_mods = (saved_edits[key] as Dictionary).duplicate()
	elif not saved_edits.has("present") and not saved_edits.has("past"):
		active_mods = saved_edits.duplicate()
		
	for local_pos: Vector3i in in_memory_mods.keys():
		active_mods[local_pos] = in_memory_mods[local_pos]
		
	for local_pos: Vector3i in active_mods.keys():
		chunk.set_block(local_pos.x, local_pos.y, local_pos.z, active_mods[local_pos] as BlockType.Type)
		
	var merged_edits := saved_edits.duplicate()
	merged_edits[key] = active_mods
	return merged_edits


func _compile_and_submit_task(chunk: Chunk, version: int, is_rebuild: bool, saved_edits: Dictionary) -> void:
	var is_distant := lifecycle.call("_calculate_is_chunk_distant", chunk.position) as bool
	var build_physics := not is_distant
	var ws := lifecycle.world_state
	
	var visual_data: Dictionary = _compile_visual_data(chunk, is_distant, build_physics)
	var custom_meshes: Dictionary = ChunkMesher.generate_special_meshes(chunk, ws)
	
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.liquid_meshes = custom_meshes
	task_result.is_rebuild = is_rebuild
	task_result.set_meta("version", version) 
	
	if not saved_edits.is_empty():
		task_result.set_meta("saved_edits", saved_edits)
	if build_physics:
		_compile_collision_shape(task_result, visual_data)
		
	task_result.set_meta("nav_nodes", ChunkNavigationBuilder.compile_walkable_nodes_asynchronous(chunk, ws))
	
	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()


func _compile_visual_data(chunk: Chunk, is_distant: bool, build_physics: bool) -> Dictionary:
	if is_distant:
		return {
			"multimesh": LODMesher.generate_decimated_mesh_data(chunk, lifecycle.world_state),
			"collision_vertices": PackedVector3Array()
		}
	return ChunkVisualBuilder.extract_render_data(chunk, lifecycle.world_state, build_physics) as Dictionary


func _compile_collision_shape(task_result: GeneratedChunkTask, visual_data: Dictionary) -> void:
	var collision_verts: PackedVector3Array = visual_data.get("collision_vertices", PackedVector3Array()) as PackedVector3Array
	if collision_verts.size() > 0:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_verts)
		shape.backface_collision = true
		task_result.collision_shape = shape


func _finish_task_execution() -> void:
	_queue_mutex.lock()
	_active_background_tasks -= 1
	_queue_mutex.unlock()
	call_deferred("_trigger_next_background_tasks")


## C++ SAFE CLEANUP: Joins completed tasks cleanly without Invalid Task ID errors
func cleanup_completed_threads() -> void:
	_queue_mutex.lock()
	var remaining_tasks: Array[int] = []
	
	for id: int in _active_task_ids:
		if id < 0:
			continue
			
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
		else:
			remaining_tasks.append(id)
			
	_active_task_ids = remaining_tasks
	_queue_mutex.unlock()


func has_completed_tasks() -> bool:
	_queue_mutex.lock()
	var has_tasks := _completed_tasks_queue.size() > 0
	_queue_mutex.unlock()
	return has_tasks


func pop_completed_task() -> GeneratedChunkTask:
	_queue_mutex.lock()
	var task: GeneratedChunkTask = null
	if _completed_tasks_queue.size() > 0:
		task = _completed_tasks_queue.pop_front() as GeneratedChunkTask
	_queue_mutex.unlock()
	return task


func mark_task_completed(pos: Vector3i) -> void:
	_queue_mutex.lock()
	_in_flight_tasks.erase(pos)
	_queue_mutex.unlock()


func needs_rebuild(pos: Vector3i) -> bool:
	_queue_mutex.lock()
	var has_flag := _queued_rebuilds.has(pos)
	_queue_mutex.unlock()
	return has_flag


func clear_rebuild_flag(pos: Vector3i) -> void:
	_queue_mutex.lock()
	_queued_rebuilds.erase(pos)
	_queue_mutex.unlock()


func shutdown() -> void:
	_queue_mutex.lock()
	_load_requests_queue.clear()
	var tasks_to_wait := _active_task_ids.duplicate()
	_active_task_ids.clear()
	_queue_mutex.unlock()
	
	for id: int in tasks_to_wait:
		if id >= 0 and not WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
