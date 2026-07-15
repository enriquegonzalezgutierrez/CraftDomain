# ==============================================================================
# Pathfile: res://src/Infrastructure/World/ChunkLifecycleService.gd
# Description: High-Performance Infrastructure Service responsible for managing 
#              chunk instantiation, garbage collection, and physics Rid assignment.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly chunk instantiations, 
#   recyling pool, and LOD switches, offloading threading to ChunkTaskScheduler.
# - Open-Closed Principle (OCP): Integrates dual-timeline synchronization.
# 120 FPS GUARDRAIL FIX: 
# - Adjacent boundary redraws and A* Navigation generation have been strictly
#   decoupled from the synchronous Main-Thread loop and routed to background workers.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChunkLifecycleService
extends RefCounted

const CHUNK_MASK: int = 15

var controller: Node3D 
var world_state: WorldState
var task_scheduler: ChunkTaskScheduler

var _unload_queue: Array[Vector3i] = []
var _chunk_nodes: Dictionary = {}
var _chunk_entities: Dictionary = {}
var _physics_bodies: Dictionary = {}

var _chunk_lod_states: Dictionary = {} 
var _last_known_viewer_chunk_pos: Vector3i = Vector3i.ZERO
var _chunk_versions: Dictionary = {}

var _chunk_node_pool: Array[ChunkNode] = []
static var _frictionless_material: PhysicsMaterial = null

# Mutex binding required for scheduler callback synch flags
var _queue_mutex: Mutex


static func _get_frictionless_material() -> PhysicsMaterial:
	if _frictionless_material == null:
		_frictionless_material = PhysicsMaterial.new()
		_frictionless_material.rough = false
		_frictionless_material.bounce = 0.0
	return _frictionless_material


func _init(p_controller: Node3D, p_world_state: WorldState) -> void:
	_queue_mutex = Mutex.new()
	controller = p_controller
	world_state = p_world_state
	task_scheduler = ChunkTaskScheduler.new(self, _queue_mutex)
	print("[ChunkLifecycle] Initialized lifecycle service and thread pool scheduler.")


func is_chunk_rendered(chunk_pos: Vector3i) -> bool:
	return _chunk_nodes.has(chunk_pos)


func get_active_nodes() -> Dictionary:
	return _chunk_nodes


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
			var active_pos := world_state.global_to_chunk_pos(Vector3i(floori(p_pos.x), floori(p_pos.y), floori(p_pos.z)))
			_last_known_viewer_chunk_pos = active_pos


func _process_unload_queue(player_active: bool) -> void:
	var max_unloads := 100 if not player_active else 5
	var unloads_processed := 0
	while _unload_queue.size() > 0 and unloads_processed < max_unloads:
		var chunk_to_unload := _unload_queue.pop_front() as Vector3i
		_unload_chunk_node(chunk_to_unload)
		unloads_processed += 1


func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	
	_chunk_versions[chunk_pos] = _chunk_versions.get(chunk_pos, 0) + 1
	_rebuild_chunk_instantly(chunk_pos)
	_trigger_adjacent_boundary_redraws(global_pos, chunk_pos)


func _trigger_adjacent_boundary_redraws(global_pos: Vector3i, chunk_pos: Vector3i) -> void:
	var local_pos := world_state.global_to_local_pos(global_pos)
	_check_neighbor_rebuild(local_pos.x == 0, chunk_pos, Vector3i(-1, 0, 0))
	_check_neighbor_rebuild(local_pos.x == Chunk.SIZE - 1, chunk_pos, Vector3i(1, 0, 0))
	_check_neighbor_rebuild(local_pos.y == 0, chunk_pos, Vector3i(0, -1, 0))
	_check_neighbor_rebuild(local_pos.y == Chunk.SIZE - 1, chunk_pos, Vector3i(0, 1, 0))
	_check_neighbor_rebuild(local_pos.z == 0, chunk_pos, Vector3i(0, 0, -1))
	_check_neighbor_rebuild(local_pos.z == Chunk.SIZE - 1, chunk_pos, Vector3i(0, 0, 1))


func _check_neighbor_rebuild(condition: bool, chunk_pos: Vector3i, offset: Vector3i) -> void:
	if condition:
		var neighbor_pos := chunk_pos + offset
		_chunk_versions[neighbor_pos] = _chunk_versions.get(neighbor_pos, 0) + 1
		# 120 FPS FIX: Adjacent border chunks MUST be offloaded to background threads.
		# Synchronous rebuilding caused extreme lag spikes when mining near edges.
		_request_chunk_rebuild(neighbor_pos)


func _rebuild_chunk_instantly(chunk_pos: Vector3i) -> void:
	var chunk := world_state.get_chunk(chunk_pos)
	if chunk == null: return
		
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	var visual_data: Dictionary = ChunkVisualBuilder.extract_render_data(chunk, world_state, not is_distant) as Dictionary
	var static_body := _build_physics_body_for_rebuild(visual_data, is_distant)
	
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.is_rebuild = true
	task_result.liquid_meshes = ChunkMesher.generate_special_meshes(chunk, world_state)
	task_result.set_meta("version", _chunk_versions.get(chunk_pos, 0))
	
	if static_body != null:
		task_result.set_meta("static_body", static_body)
		
	# 120 FPS FIX: Bypass the heavy 4096-iteration A* Navigation generation on the main thread!
	# We pass an empty array to render the mesh/physics instantly with zero latency.
	task_result.set_meta("nav_nodes", [])
	_render_single_completed_task(task_result)
	
	# Immediately dispatch a background task to compile the missing A* navigation 
	# graph and optimized data silently without stuttering the game.
	_request_chunk_rebuild(chunk_pos)


func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_nodes.has(chunk_pos): return
	task_scheduler.request_chunk_rebuild(chunk_pos, _chunk_versions.get(chunk_pos, 0))


func _build_physics_body_for_rebuild(visual_data: Dictionary, is_distant: bool) -> StaticBody3D:
	if is_distant: return null
	var solid_positions: PackedVector3Array = visual_data["collision_vertices"] as PackedVector3Array
	if solid_positions.size() == 0: return null
		
	var static_body := StaticBody3D.new()
	static_body.collision_layer = 1
	static_body.collision_mask = 1
	static_body.physics_material_override = _get_frictionless_material()
	
	var col := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(solid_positions)
	shape.backface_collision = true
	col.shape = shape
	static_body.add_child(col)
	return static_body


func _render_completed_chunks_from_queue(player_active: bool) -> void:
	var start_time := Time.get_ticks_usec()
	var time_budget_usec := 40000 if not player_active else 3000
	var rendered_this_frame := 0
	
	while task_scheduler.has_completed_tasks():
		if (Time.get_ticks_usec() - start_time) > time_budget_usec and rendered_this_frame >= 1: 
			break
			
		var task := task_scheduler.pop_completed_task()
		if task != null:
			_render_single_completed_task(task)
			rendered_this_frame += 1


func _render_single_completed_task(task: GeneratedChunkTask) -> void:
	var chunk_pos: Vector3i = task.chunk.position
	
	if _is_task_version_obsolete(task, chunk_pos):
		return
		
	_cleanup_task_states(chunk_pos)
	
	var is_distant := _calculate_is_chunk_distant(chunk_pos)
	_chunk_lod_states[chunk_pos] = is_distant
	
	var static_body := _ensure_physics_body(task)
	if is_instance_valid(static_body):
		_physics_bodies[chunk_pos] = static_body.get_rid()
		
	if not task.is_rebuild and is_instance_valid(world_state):
		world_state.add_chunk(task.chunk)
		
		# Symmetrical dual-timeline registration from compiler metadata
		var saved_edits: Dictionary = task.get_meta("saved_edits") if task.has_meta("saved_edits") else {}
		if not saved_edits.is_empty():
			world_state.apply_chunk_modifications(chunk_pos, saved_edits)
		
	_register_navigation_nodes(task)
	_apply_visuals_to_chunk_node(task, chunk_pos, static_body, is_distant)


func _is_task_version_obsolete(task: GeneratedChunkTask, chunk_pos: Vector3i) -> bool:
	var task_version: int = task.get_meta("version") if task.has_meta("version") else 0
	var current_version: int = _chunk_versions.get(chunk_pos, 0)
	
	if task_version < current_version:
		var orphaned_body: Node = task.get_meta("static_body") if task.has_meta("static_body") else null
		if is_instance_valid(orphaned_body):
			orphaned_body.queue_free()
		return true
	return false


func _cleanup_task_states(chunk_pos: Vector3i) -> void:
	task_scheduler.mark_task_completed(chunk_pos)
	
	if task_scheduler.needs_rebuild(chunk_pos):
		task_scheduler.clear_rebuild_flag(chunk_pos)
		_request_chunk_rebuild(chunk_pos)
		
	_physics_bodies.erase(chunk_pos)


func _ensure_physics_body(task: GeneratedChunkTask) -> StaticBody3D:
	var static_body: StaticBody3D = task.get_meta("static_body") if task.has_meta("static_body") else null
	if static_body == null and task.collision_shape != null:
		static_body = StaticBody3D.new()
		static_body.collision_layer = 1
		static_body.collision_mask = 1
		static_body.physics_material_override = _get_frictionless_material()
		
		var col := CollisionShape3D.new()
		col.shape = task.collision_shape
		static_body.add_child(col)
	return static_body


func _register_navigation_nodes(task: GeneratedChunkTask) -> void:
	var nav_nodes: Array = task.get_meta("nav_nodes") if task.has_meta("nav_nodes") else []
	if not nav_nodes.is_empty() and is_instance_valid(controller):
		var nav_service: VoxelNavigationService = controller.get("navigation_service") as VoxelNavigationService
		if is_instance_valid(nav_service):
			ChunkNavigationBuilder.register_compiled_nodes_synchronous(nav_nodes, world_state, nav_service)


func _apply_visuals_to_chunk_node(task: GeneratedChunkTask, chunk_pos: Vector3i, static_body: StaticBody3D, is_distant: bool) -> void:
	var chunk_node: ChunkNode = null
	if _chunk_nodes.has(chunk_pos):
		chunk_node = _chunk_nodes[chunk_pos] as ChunkNode
	else:
		if task.is_rebuild: 
			if is_instance_valid(static_body): static_body.queue_free()
			return
		chunk_node = _acquire_chunk_node_from_pool(task.chunk)
		_chunk_nodes[chunk_pos] = chunk_node
		
		if controller.has_method("register_streetlights_for_chunk"): 
			controller.call("register_streetlights_for_chunk", task.chunk)
		if controller.has_method("check_player_spawn_activation"): 
			controller.call("check_player_spawn_activation")
			
	chunk_node.setup_chunk_visuals(task.multimesh_data, static_body, task.liquid_meshes, is_distant)


func _acquire_chunk_node_from_pool(chunk: Chunk) -> ChunkNode:
	var chunk_node: ChunkNode
	if _chunk_node_pool.size() > 0:
		chunk_node = _chunk_node_pool.pop_back() as ChunkNode
		chunk_node.chunk = chunk
		chunk_node.name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
		chunk_node.position = Vector3(chunk.position * Chunk.SIZE)
		chunk_node.visible = true
	else:
		chunk_node = ChunkNode.new(chunk)
		controller.add_child(chunk_node)
	return chunk_node


func spawn_entities_by_proximity(player_global_pos: Vector3, spawn_radius: int = 2) -> void:
	var player_block_pos := Vector3i(floor(player_global_pos.x), floor(player_global_pos.y), floor(player_global_pos.z))
	var current_viewer_chunk_pos := world_state.global_to_chunk_pos(player_block_pos)
	
	for x: int in range(-spawn_radius, spawn_radius + 1):
		for z: int in range(-spawn_radius, spawn_radius + 1):
			_evaluate_entity_spawn_for_chunk(current_viewer_chunk_pos, x, z)


func _evaluate_entity_spawn_for_chunk(center: Vector3i, offset_x: int, offset_z: int) -> void:
	var target_chunk_pos := Vector3i(center.x + offset_x, 0, center.z + offset_z)
	if not _chunk_nodes.has(target_chunk_pos) or not _physics_bodies.has(target_chunk_pos):
		return
		
	var col_pos := Vector3i(target_chunk_pos.x, 0, target_chunk_pos.z)
	if not _chunk_entities.has(col_pos):
		var chunk_0: Chunk = _chunk_nodes[target_chunk_pos].chunk as Chunk
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
		_recycle_chunk_node(node)
		
	if _chunk_lod_states.has(chunk_pos):
		_chunk_lod_states.erase(chunk_pos)
		
	var entities_key := Vector3i(chunk_pos.x, 0, chunk_pos.z)
	if _chunk_entities.has(entities_key):
		var entities: Array = _chunk_entities[entities_key] as Array
		_chunk_entities.erase(entities_key)
		for ent: Node in entities:
			if is_instance_valid(ent): ent.queue_free()
				
	_physics_bodies.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)


func _recycle_chunk_node(node: ChunkNode) -> void:
	if is_instance_valid(node):
		node.visible = false
		if node.has_method("set_collision_body"):
			node.call("set_collision_body", null)
		if node.has_method("setup_chunk_visuals"):
			node.call("setup_chunk_visuals", {}, null, {})
		_chunk_node_pool.append(node)


func _execute_lod_scans() -> void:
	for pos: Vector3i in _chunk_nodes.keys():
		var is_currently_distant := _calculate_is_chunk_distant(pos)
		var was_distant: bool = _chunk_lod_states.get(pos, false) as bool
		
		if is_currently_distant != was_distant:
			_chunk_lod_states[pos] = is_currently_distant
			var node: ChunkNode = _chunk_nodes[pos] as ChunkNode
			if is_instance_valid(node):
				if node.has_method("update_lod_materials"):
					node.call("update_lod_materials", is_currently_distant)
				
				if not is_currently_distant and node.has_method("has_collision_body"):
					if not node.call("has_collision_body") as bool:
						_request_chunk_rebuild(pos)


func _calculate_is_chunk_distant(chunk_pos: Vector3i) -> bool:
	var current_distance := ChunkLoaderService.global_view_distance
	var lod_threshold := max(3, current_distance - 3)
	
	var diff_x := abs(chunk_pos.x - _last_known_viewer_chunk_pos.x)
	var diff_z := abs(chunk_pos.z - _last_known_viewer_chunk_pos.z)
	
	return diff_x > lod_threshold or diff_z > lod_threshold


func shutdown() -> void:
	task_scheduler.shutdown()
