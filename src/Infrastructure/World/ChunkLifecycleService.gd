# ==============================================================================
# Pathfile: res://src/Infrastructure/World/ChunkLifecycleService.gd
# Description: High-Performance Infrastructure Service managing chunk lifecycles,
#              LOD updates, background threads, and multi-layer entity spawning.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkLifecycleService
extends RefCounted

const CHUNK_MASK: int = 15
const TIME_BUDGET_ACTIVE_USEC: int = 2000  
const TIME_BUDGET_LOADING_USEC: int = 40000 

# Generous 115-degree horizontal field of view to cover wide screens
const FRUSTUM_CULL_THRESHOLD: float = -0.42 
# 36 meters squared (approx 2 chunks radius) safe circle around player
const SAFE_ZONE_DISTANCE_SQ: float = 1296.0 

var controller: Node3D 
var world_state: WorldState
var task_scheduler: ChunkTaskScheduler
var direct_renderer: DirectChunkRenderingService

var _unload_queue: Array[Vector3i] = []
var _chunk_lod_states: Dictionary = {} 
var _chunk_versions: Dictionary = {}
var _chunk_entities: Dictionary = {}

var _last_known_viewer_chunk_pos: Vector3i = Vector3i.ZERO
var _queue_mutex: Mutex


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	_queue_mutex = Mutex.new()
	controller = p_controller
	world_state = p_world_state
	task_scheduler = ChunkTaskScheduler.new(self, _queue_mutex)
	
	var scenario: RID = controller.get_world_3d().scenario if controller.is_inside_tree() else RID()
	var space: RID = controller.get_world_3d().space if controller.is_inside_tree() else RID()
	direct_renderer = DirectChunkRenderingService.new(controller, scenario, space)


func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_lod_states.has(chunk_pos)


func get_active_nodes() -> Dictionary:
	return _chunk_lod_states 


func queue_loads(chunk_positions: Array[Vector3i]) -> void:
	task_scheduler.queue_loads(chunk_positions, _chunk_versions)


func queue_prioritized_loads(chunk_positions: Array[Vector3i]) -> void:
	task_scheduler.queue_prioritized_loads(chunk_positions, _chunk_versions)


func queue_unloads(chunk_positions: Array[Vector3i]) -> void:
	for pos: Vector3i in chunk_positions:
		if not _unload_queue.has(pos):
			_unload_queue.append(pos)


func process_frame_queues(player_active: bool) -> void:
	_update_viewer_chunk_position()
	
	if Engine.get_frames_drawn() % 15 == 0:
		_execute_lod_scans()
		
	_process_unload_queue(player_active)
	_render_completed_chunks_from_queue(player_active)
	task_scheduler.cleanup_completed_threads()


func _update_viewer_chunk_position() -> void:
	if is_instance_valid(controller) and is_instance_valid(controller.get("player")):
		var player_node: Node3D = controller.get("player") as Node3D
		if is_instance_valid(player_node):
			var p_pos := player_node.global_position
			_last_known_viewer_chunk_pos = world_state.global_to_chunk_pos(Vector3i(floori(p_pos.x), floori(p_pos.y), floori(p_pos.z)))


func _process_unload_queue(player_active: bool) -> void:
	var start_time := Time.get_ticks_usec()
	var time_budget := 500 if player_active else 10000 
	
	while _unload_queue.size() > 0:
		if (Time.get_ticks_usec() - start_time) > time_budget: break
		_unload_chunk_direct(_unload_queue.pop_front() as Vector3i)


func _unload_chunk_direct(chunk_pos: Vector3i) -> void:
	direct_renderer.free_chunk(chunk_pos)
	HierarchicalPathingService.unregister_chunk(chunk_pos)
	
	if _chunk_lod_states.has(chunk_pos):
		_chunk_lod_states.erase(chunk_pos)
		
	var entities_key := chunk_pos
	if _chunk_entities.has(entities_key):
		var entities: Array = _chunk_entities[entities_key] as Array
		_chunk_entities.erase(entities_key)
		for ent: Node in entities:
			if is_instance_valid(ent): ent.queue_free()
			
	world_state.remove_chunk(chunk_pos)


func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	_chunk_versions[chunk_pos] = _chunk_versions.get(chunk_pos, 0) + 1
	_rebuild_chunk_instantly(chunk_pos)
	_trigger_adjacent_boundary_redraws(global_pos, chunk_pos, true)


func set_block_globally_async(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	_chunk_versions[chunk_pos] = _chunk_versions.get(chunk_pos, 0) + 1
	_request_chunk_rebuild(chunk_pos) 
	_trigger_adjacent_boundary_redraws(global_pos, chunk_pos, true)


func _trigger_adjacent_boundary_redraws(global_pos: Vector3i, chunk_pos: Vector3i, is_async: bool) -> void:
	var local_pos := world_state.global_to_local_pos(global_pos)
	_check_neighbor_rebuild(local_pos.x == 0, chunk_pos, Vector3i(-1, 0, 0), is_async)
	_check_neighbor_rebuild(local_pos.x == Chunk.SIZE - 1, chunk_pos, Vector3i(1, 0, 0), is_async)
	_check_neighbor_rebuild(local_pos.y == 0, chunk_pos, Vector3i(0, -1, 0), is_async)
	_check_neighbor_rebuild(local_pos.y == Chunk.SIZE - 1, chunk_pos, Vector3i(0, 1, 0), is_async)
	_check_neighbor_rebuild(local_pos.z == 0, chunk_pos, Vector3i(0, 0, -1), is_async)
	_check_neighbor_rebuild(local_pos.z == Chunk.SIZE - 1, chunk_pos, Vector3i(0, 0, 1), is_async)


func _check_neighbor_rebuild(condition: bool, chunk_pos: Vector3i, offset: Vector3i, is_async: bool) -> void:
	if condition:
		var neighbor_pos := chunk_pos + offset
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		if is_async: _request_chunk_rebuild(neighbor_pos)
		else: _rebuild_chunk_instantly(neighbor_pos)


func _rebuild_chunk_instantly(chunk_pos: Vector3i) -> void:
	var chunk := world_state.get_chunk(chunk_pos)
	if chunk == null: return
	
	var task_result := _compile_instant_rebuild_task(chunk)
	_render_single_completed_task(task_result)
	_request_chunk_rebuild(chunk_pos) 


func _compile_instant_rebuild_task(chunk: Chunk) -> GeneratedChunkTask:
	var visual_data := ChunkVisualBuilder.extract_render_data(chunk, world_state, false)
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.is_rebuild = true
	task_result.liquid_meshes = ChunkMesher.generate_special_meshes(chunk, world_state)
	task_result.set_meta("version", _chunk_versions.get(chunk.position, 0))
	task_result.set_meta("nav_nodes", [])
	return task_result


func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_lod_states.has(chunk_pos): return
	task_scheduler.request_chunk_rebuild(chunk_pos, _chunk_versions.get(chunk_pos, 0))


func _render_completed_chunks_from_queue(player_active: bool) -> void:
	var start_time := Time.get_ticks_usec()
	var time_budget := TIME_BUDGET_ACTIVE_USEC if player_active else TIME_BUDGET_LOADING_USEC
	
	while task_scheduler.has_completed_tasks():
		if (Time.get_ticks_usec() - start_time) > time_budget: break 
		var task := task_scheduler.pop_completed_task()
		if task != null: _render_single_completed_task(task)


func _render_single_completed_task(task: GeneratedChunkTask) -> void:
	var chunk_pos: Vector3i = task.chunk.position
	
	if _is_task_version_obsolete(task, chunk_pos):
		_cleanup_task_states(chunk_pos)
		return
		
	_cleanup_task_states(chunk_pos)
	_register_completed_chunk_state(task, chunk_pos)
	
	HierarchicalPathingService.register_chunk(chunk_pos)
	_register_navigation_nodes(task)
	_apply_visuals_direct(task, chunk_pos)


func _register_completed_chunk_state(task: GeneratedChunkTask, chunk_pos: Vector3i) -> void:
	_chunk_lod_states[chunk_pos] = _calculate_is_chunk_distant(chunk_pos)
		
	if not task.is_rebuild and is_instance_valid(world_state):
		world_state.add_chunk(task.chunk)
		var saved_edits: Dictionary = task.get_meta("saved_edits") if task.has_meta("saved_edits") else {}
		if not saved_edits.is_empty():
			world_state.apply_chunk_modifications(chunk_pos, saved_edits)


func _is_task_version_obsolete(task: GeneratedChunkTask, chunk_pos: Vector3i) -> bool:
	var task_version: int = task.get_meta("version") if task.has_meta("version") else 0
	return task_version < _chunk_versions.get(chunk_pos, 0)


func _cleanup_task_states(chunk_pos: Vector3i) -> void:
	task_scheduler.mark_task_completed(chunk_pos)
	if task_scheduler.needs_rebuild(chunk_pos):
		task_scheduler.clear_rebuild_flag(chunk_pos)
		_request_chunk_rebuild(chunk_pos)


func _register_navigation_nodes(task: GeneratedChunkTask) -> void:
	var nav_nodes: Array = task.get_meta("nav_nodes") if task.has_meta("nav_nodes") else []
	if not nav_nodes.is_empty() and is_instance_valid(controller):
		var nav_service: VoxelNavigationService = controller.get("navigation_service") as VoxelNavigationService
		if is_instance_valid(nav_service):
			ChunkNavigationBuilder.register_compiled_nodes_synchronous(nav_nodes, world_state, nav_service)


func _apply_visuals_direct(task: GeneratedChunkTask, chunk_pos: Vector3i) -> void:
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	var collision_shape := task.collision_shape
	
	if task.is_rebuild and collision_shape == null:
		var record: DirectChunkRenderingService.ChunkRIDRecord = direct_renderer._active_chunks.get(chunk_pos) as DirectChunkRenderingService.ChunkRIDRecord
		if record != null: collision_shape = record.collision_shape_ref
			
	direct_renderer.allocate_chunk_visuals(chunk_pos, task.multimesh_data, task.liquid_meshes, collision_shape, is_distant)
	if not task.is_rebuild: _notify_controller_spawn(task.chunk)


func _notify_controller_spawn(_chunk: Chunk) -> void:
	if controller.has_method("check_player_spawn_activation"): 
		controller.call("check_player_spawn_activation")


func spawn_entities_by_proximity(player_global_pos: Vector3, spawn_radius: int = 2) -> void:
	var player_block_pos := Vector3i(floor(player_global_pos.x), floor(player_global_pos.y), floor(player_global_pos.z))
	var current_viewer_chunk_pos := world_state.global_to_chunk_pos(player_block_pos)
	
	for x in range(-spawn_radius, spawn_radius + 1):
		for z in range(-spawn_radius, spawn_radius + 1):
			for y_layer in range(2): 
				_evaluate_entity_spawn_for_chunk(current_viewer_chunk_pos, x, y_layer, z)


func _evaluate_entity_spawn_for_chunk(center: Vector3i, offset_x: int, y_layer: int, offset_z: int) -> void:
	if is_instance_valid(controller):
		var player_node := controller.get("player") as CharacterBody3D
		if is_instance_valid(player_node) and not player_node.get("is_active"): return

	var target_chunk_pos := Vector3i(center.x + offset_x, y_layer, center.z + offset_z)
	if not _chunk_lod_states.has(target_chunk_pos) or not direct_renderer.has_collision_body(target_chunk_pos) or _calculate_is_chunk_distant(target_chunk_pos):
		return
		
	var col_pos := target_chunk_pos
	if not _chunk_entities.has(col_pos):
		var chunk_inst := world_state.get_chunk(target_chunk_pos)
		if chunk_inst != null and controller.has_method("spawn_entities_for_chunk"):
			var raw_array: Array = controller.call("spawn_entities_for_chunk", chunk_inst) as Array
			var typed_nodes: Array[Node] = []
			for n_element: Variant in raw_array:
				if n_element is Node: typed_nodes.append(n_element as Node)
			_chunk_entities[col_pos] = typed_nodes


func _execute_lod_scans() -> void:
	var look_dir := _get_player_look_direction()
	var player_pos := _get_player_position()
	
	for pos: Vector3i in _chunk_lod_states.keys():
		var is_currently_distant := _calculate_is_chunk_distant(pos)
		var was_distant: bool = _chunk_lod_states.get(pos, false) as bool
		
		if is_currently_distant != was_distant:
			_chunk_lod_states[pos] = is_currently_distant
			direct_renderer.update_lod_materials(pos, is_currently_distant)
			if not is_currently_distant and not direct_renderer.has_collision_body(pos):
				_request_chunk_rebuild(pos)
				
		_apply_frustum_culling_to_chunk(pos, player_pos, look_dir)


## Balanced 2D Horizon-Plane Culling + Proximity Safe Zone Check.
func _apply_frustum_culling_to_chunk(chunk_pos: Vector3i, player_pos: Vector3, look_dir: Vector3) -> void:
	if look_dir == Vector3.ZERO: return
		
	var chunk_center := Vector3(chunk_pos * Chunk.SIZE) + Vector3(8.0, 8.0, 8.0)
	var dist_sq := player_pos.distance_squared_to(chunk_center)
	
	# 1. Proximity Safe Zone: Avoid culling chunks immediately surrounding the player (Zero clipping)
	if dist_sq <= SAFE_ZONE_DISTANCE_SQ:
		direct_renderer.set_chunk_visible(chunk_pos, true)
		return
		
	# 2. 2D Horizon-Plane Projection (XZ): Decouples vertical camera pitch angles (looking up/down)
	var flat_look := Vector2(look_dir.x, look_dir.z).normalized()
	var flat_to_chunk := Vector2(chunk_center.x - player_pos.x, chunk_center.z - player_pos.z).normalized()
	
	var is_visible := flat_look.dot(flat_to_chunk) >= FRUSTUM_CULL_THRESHOLD
	direct_renderer.set_chunk_visible(chunk_pos, is_visible)


func _get_player_look_direction() -> Vector3:
	if is_instance_valid(controller) and is_instance_valid(controller.get("player")):
		var p_node := controller.get("player") as CharacterBody3D
		if is_instance_valid(p_node):
			var camera_node := p_node.get_node_or_null("PlayerCamera") as Camera3D
			if is_instance_valid(camera_node):
				return -camera_node.global_transform.basis.z.normalized()
	return Vector3.ZERO


func _get_player_position() -> Vector3:
	if is_instance_valid(controller) and is_instance_valid(controller.get("player")):
		var p_node := controller.get("player") as CharacterBody3D
		if is_instance_valid(p_node): return p_node.global_position
	return Vector3.ZERO


func _calculate_is_chunk_distant(chunk_pos: Vector3i) -> bool:
	var lod_threshold := max(3, ChunkLoaderService.global_view_distance - 3)
	var diff_x := abs(chunk_pos.x - _last_known_viewer_chunk_pos.x)
	var diff_z := abs(chunk_pos.z - _last_known_viewer_chunk_pos.z)
	return diff_x > lod_threshold or diff_z > lod_threshold


func shutdown() -> void:
	task_scheduler.shutdown()
	direct_renderer.clear_all()
