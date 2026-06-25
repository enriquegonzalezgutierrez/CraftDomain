# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure coordinator orchestrating world state, procedural
#              generation, dynamic loading, and saving/loading block modifications.
#              Enforces SOLID and SRP compliance by delegating mob spawning,
#              streetlights toggling, and asynchronous thread pool tasks.
#              IMplements Bi-directional Frame Throttling: Balances the CPU frame
#              budget by strictly loading OR unloading exactly ONE chunk per frame,
#              eliminating Garbage Collection (queue_free) physics stutters.
#              DIP Compliant: Relies on injected WorldRepository abstraction.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/WorldController.gd
# ==============================================================================
class_name WorldController
extends Node3D

## Core World modules
var world_state: WorldState
var generator: WorldGenerator
var loader_service: ChunkLoaderService

## Dependency-injected repository abstraction (DIP compliant)
var repository: WorldRepository

## Dependency-injected player reference
var player: CharacterBody3D

# Decoupled Private helper services (SRP compliant)
var _mob_spawning_service: MobSpawningService
var _streetlight_service: StreetlightService

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode
var _chunk_nodes: Dictionary = {}

## Tracking dictionary to prevent initiating duplicate load threads: Vector3i -> bool
var _pending_loading_chunks: Dictionary = {}

## Tracking map for entities spawned within specific chunks: Vector3i -> Array[CharacterBody3D]
var _chunk_entities: Dictionary = {}

## Thread safety sync structures
var _queue_mutex: Mutex
var _completed_tasks_queue: Array[GeneratedChunkTask] = []
var _unload_queue: Array[Vector3i] = [] # CRITICAL: Unload task queue for frame throttling

## Throttling timer variables to avoid running distance checks on every single frame
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

## Target chunk coordinate where the player is scheduled to spawn safely
var _target_spawn_chunk_pos: Vector3i = Vector3i(0, 0, 0)

# --- CHUNK TASK CACHE SYSTEM (Strict Memory-efficient LRU) ---
var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64 # Cache up to 64 recently processed chunks in RAM

## Subclass containing the completed background generation and rendering results.
class GeneratedChunkTask:
	var chunk: Chunk
	var instance_count: int
	var multimesh_bulk_array: PackedFloat32Array
	var collision_body: StaticBody3D 
	var visual_colors: Array[Color]
	var transforms: Array[Transform3D]

func _ready() -> void:
	assert(repository != null, "[WorldController] Fatal: WorldRepository must be injected before _ready()!")
	_initialize_systems()

func _initialize_systems() -> void:
	world_state = WorldState.new()
	loader_service = ChunkLoaderService.new()
	_queue_mutex = Mutex.new()
	
	_mob_spawning_service = MobSpawningService.new()
	_streetlight_service = StreetlightService.new(self, world_state)
	
	var saved_global := repository.load_global_state()
	var active_seed: int
	var spawn_pos := Vector3(8.5, 14.0, 8.5)
	var spawn_rot := Vector3.ZERO
	
	if saved_global.has("seed"):
		active_seed = saved_global["seed"]
		print("[WorldController] Found saved game! Restoring seed: ", active_seed)
		if saved_global.has("player_pos"):
			spawn_pos = saved_global["player_pos"]
			spawn_rot = saved_global["player_rot"]
	else:
		randomize()
		active_seed = randi()
		print("[WorldController] No save found. Generating new world with unique Seed: ", active_seed)
		
	generator = WorldGenerator.new(active_seed)
	
	var block_pos := Vector3i(int(floor(spawn_pos.x)), int(floor(spawn_pos.y)), int(floor(spawn_pos.z)))
	_target_spawn_chunk_calculation(block_pos)
	
	if is_instance_valid(player):
		player.position = spawn_pos
		player.rotation = spawn_rot

func _target_spawn_chunk_calculation(block_pos: Vector3i) -> void:
	_target_spawn_chunk_pos = world_state.global_to_chunk_pos(block_pos)
	_target_spawn_chunk_pos.y = 0

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_process_dynamic_world()
		_process_day_night_lighting()
		
	# --- PERFECT FRAME BUDGET DISTRIBUTION ---
	# To maintain 60+ FPS, we either unload ONE chunk OR load ONE chunk per frame.
	# This absolutely prevents physics BVH destruction/creation stutters.
	if _unload_queue.size() > 0:
		var chunk_to_unload := _unload_queue.pop_front() as Vector3i
		_unload_chunk_node(chunk_to_unload)
	else:
		_render_completed_chunks_from_queue()

func _process_dynamic_world() -> void:
	var task: ChunkLoaderService.ChunkUpdateTask = loader_service.check_viewer_position(
		player.global_position, 
		world_state
	)
	
	for chunk_pos in task.to_unload:
		if not _unload_queue.has(chunk_pos):
			_unload_queue.append(chunk_pos)
		
	for chunk_pos in task.to_load:
		# If a chunk is scheduled to be unloaded but the player turned back, cancel the unload!
		if _unload_queue.has(chunk_pos):
			_unload_queue.erase(chunk_pos)
		else:
			_request_asynchronous_chunk_load(chunk_pos)

func _process_day_night_lighting() -> void:
	var celestial = get_parent().get_node_or_null("CelestialService")
	if not is_instance_valid(celestial) or not celestial.has_method("is_night_time"):
		return
		
	var is_night: bool = celestial.call("is_night_time")
	
	if is_instance_valid(_streetlight_service):
		_streetlight_service.update_streetlights_state(is_night)

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

func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	# 1. Procedural generation (Polymorphic OCP call)
	var chunk := Chunk.new(chunk_pos)
	generator.generate_chunk(chunk)
	
	# 2. Disk I/O load modifications
	var saved_edits := repository.load_chunk_modifications(chunk_pos)
	if saved_edits.size() > 0:
		for local_pos in saved_edits.keys():
			var pos: Vector3i = local_pos
			chunk.set_block(pos.x, pos.y, pos.z, saved_edits[local_pos])
			
	# 3. Pre-compile transforms coordinates
	var collision_transforms: Array[Transform3D] = []
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if BlockType.is_solid(chunk.get_block(x, y, z)):
					var local_pos := Vector3(x, y, z)
					var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
					collision_transforms.append(Transform3D(Basis(), transform_pos))
	
	# 4. --- ASYNCHRONOUS OFF-THREAD PHYSICAL ASSEMBLY ---
	var collision_body := StaticBody3D.new()
	collision_body.name = "StaticCollisionBody"
	var shared_box_shape := BoxShape3D.new()
	
	for t in collision_transforms:
		var local_pos := t.origin - Vector3(0.5, 0.5, 0.5)
		var block_x := int(round(local_pos.x))
		var block_y := int(round(local_pos.y))
		var block_z := int(round(local_pos.z))
		var block_type_id: int = chunk.get_block(block_x, block_y, block_z)
		
		if BlockType.is_solid(block_type_id):
			var owner_id := collision_body.create_shape_owner(collision_body)
			collision_body.shape_owner_add_shape(owner_id, shared_box_shape)
			collision_body.shape_owner_set_transform(owner_id, t)
				
	# 5. Background ambient shading
	var visual_colors: Array[Color] = []
	visual_colors.resize(collision_transforms.size())
	
	for i in range(collision_transforms.size()):
		var t := collision_transforms[i]
		var local_pos := t.origin - Vector3(0.5, 0.5, 0.5)
		var block_x := int(round(local_pos.x))
		var block_y := int(round(local_pos.y))
		var block_z := int(round(local_pos.z))
		var block_type := chunk.get_block(block_x, block_y, block_z)
		var block_def := BlockLibrary.get_definition(block_type)
		var shade_noise: float = 0.9 + 0.1 * sin(float(block_x) * 1.4 + float(block_y) * 2.3 + float(block_z) * 3.7)
		visual_colors[i] = block_def.color_top * shade_noise
	
	# 6. --- ADVANCED BINARY BULK VISUAL ARRAY COMPILATION ---
	var bulk_array := PackedFloat32Array()
	bulk_array.resize(collision_transforms.size() * 16)
	
	for i in range(collision_transforms.size()):
		var t := collision_transforms[i]
		var c := visual_colors[i]
		var offset := i * 16
		bulk_array[offset + 0] = t.basis.x.x
		bulk_array[offset + 1] = t.basis.y.x
		bulk_array[offset + 2] = t.basis.z.x
		bulk_array[offset + 3] = t.origin.x
		bulk_array[offset + 4] = t.basis.x.y
		bulk_array[offset + 5] = t.basis.y.y
		bulk_array[offset + 6] = t.basis.z.y
		bulk_array[offset + 7] = t.origin.y
		bulk_array[offset + 8] = t.basis.x.z
		bulk_array[offset + 9] = t.basis.y.z
		bulk_array[offset + 10] = t.basis.z.z
		bulk_array[offset + 11] = t.origin.z
		bulk_array[offset + 12] = c.r
		bulk_array[offset + 13] = c.g
		bulk_array[offset + 14] = c.b
		bulk_array[offset + 15] = c.a
						
	# 7. Queue the task result
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.instance_count = collision_transforms.size()
	task_result.multimesh_bulk_array = bulk_array
	task_result.collision_body = collision_body
	task_result.visual_colors = visual_colors
	task_result.transforms = collision_transforms
	
	_queue_mutex.lock()
	_chunk_task_cache[chunk_pos] = task_result
	_completed_tasks_queue.append(task_result)
	
	if _chunk_task_cache.size() > CACHE_SIZE_LIMIT:
		var oldest_key = _chunk_task_cache.keys()[0]
		var oldest_task: GeneratedChunkTask = _chunk_task_cache[oldest_key]
		if is_instance_valid(oldest_task.collision_body):
			oldest_task.collision_body.queue_free()
		_chunk_task_cache.erase(oldest_key)
		
	_queue_mutex.unlock()

func _render_completed_chunks_from_queue() -> void:
	var task: GeneratedChunkTask = null
	
	_queue_mutex.lock()
	if _completed_tasks_queue.size() > 0:
		task = _completed_tasks_queue.pop_front()
	_queue_mutex.unlock()
	
	if task != null:
		var chunk_pos: Vector3i = task.chunk.position
		
		if _pending_loading_chunks.has(chunk_pos):
			_pending_loading_chunks.erase(chunk_pos)
			
		if not _chunk_nodes.has(chunk_pos):
			world_state.add_chunk(task.chunk)
			var chunk_node := ChunkNode.new(task.chunk)
			add_child(chunk_node)
			_chunk_nodes[chunk_pos] = chunk_node
			
			chunk_node.setup_chunk_visuals(
				task.instance_count, 
				task.multimesh_bulk_array, 
				task.collision_body
			)
			
			if is_instance_valid(_mob_spawning_service):
				var spawned := _mob_spawning_service.spawn_mobs_for_chunk(task.chunk, self)
				if spawned.size() > 0:
					_chunk_entities[chunk_pos] = spawned
			
			if is_instance_valid(_streetlight_service):
				_streetlight_service.register_streetlights_for_chunk(task.chunk)
			
			if chunk_pos == _target_spawn_chunk_pos and is_instance_valid(player) and not player.get("is_active"):
				_activate_player_spawn()

func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		return

	if _chunk_entities.has(chunk_pos):
		var entities: Array = _chunk_entities[chunk_pos]
		for entity in entities:
			if is_instance_valid(entity):
				entity.queue_free()
		_chunk_entities.erase(chunk_pos)

	if is_instance_valid(_streetlight_service):
		_streetlight_service.unregister_streetlights_for_chunk(chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	if is_instance_valid(chunk_node):
		var body := chunk_node.get_node_or_null("StaticCollisionBody")
		if is_instance_valid(body):
			chunk_node.remove_child(body) # Preserve body for cache
		chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)

func save_all() -> void:
	print("[WorldController] Executing clean save operations...")
	for chunk_pos in world_state._chunk_modifications.keys():
		var modifications: Dictionary = world_state.get_chunk_modifications(chunk_pos)
		repository.save_chunk_modifications(chunk_pos, modifications)
		
	if is_instance_valid(player):
		repository.save_global_state(
			player.global_position, 
			player.rotation, 
			generator._terrain_noise.seed
		)
	print("[WorldController] All data serialized and saved successfully.")

func _activate_player_spawn() -> void:
	var block_x := int(floor(player.position.x))
	var block_z := int(floor(player.position.z))
	var found_safe_y: float = -1.0
	
	for y in range(Chunk.SIZE - 1, -1, -1):
		var check_coord := Vector3i(block_x, y, block_z)
		var block_type := world_state.get_block(check_coord)
		
		if BlockType.is_solid(block_type):
			found_safe_y = float(y) + 2.0 
			break
			
	if found_safe_y >= 0.0:
		player.position.y = found_safe_y
	else:
		player.position.y = 14.0
		
	player.set("is_active", true)
	player.velocity = Vector3.ZERO

func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	world_state.set_block(global_pos, type)
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	
	if is_instance_valid(chunk_node):
		var collision_transforms: Array[Transform3D] = []
		for x in range(Chunk.SIZE):
			for y in range(Chunk.SIZE):
				for z in range(Chunk.SIZE):
					if BlockType.is_solid(chunk_node.chunk.get_block(x, y, z)):
						var local_pos := Vector3(x, y, z)
						var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
						collision_transforms.append(Transform3D(Basis(), transform_pos))
						
		var visual_colors: Array[Color] = []
		visual_colors.resize(collision_transforms.size())
		for i in range(collision_transforms.size()):
			var t := collision_transforms[i]
			var local_pos := t.origin - Vector3(0.5, 0.5, 0.5)
			var block_x := int(round(local_pos.x))
			var block_y := int(round(local_pos.y))
			var block_z := int(round(local_pos.z))
			var block_type_at := chunk_node.chunk.get_block(block_x, block_y, block_z)
			var block_def := BlockLibrary.get_definition(block_type_at)
			var shade_noise: float = 0.9 + 0.1 * sin(float(block_x) * 1.4 + float(block_y) * 2.3 + float(block_z) * 3.7)
			visual_colors[i] = block_def.color_top * shade_noise
			
		var bulk_array := PackedFloat32Array()
		bulk_array.resize(collision_transforms.size() * 16)
		for i in range(collision_transforms.size()):
			var t := collision_transforms[i]
			var c := visual_colors[i]
			var offset := i * 16
			bulk_array[offset + 0] = t.basis.x.x
			bulk_array[offset + 1] = t.basis.y.x
			bulk_array[offset + 2] = t.basis.z.x
			bulk_array[offset + 3] = t.origin.x
			bulk_array[offset + 4] = t.basis.x.y
			bulk_array[offset + 5] = t.basis.y.y
			bulk_array[offset + 6] = t.basis.z.y
			bulk_array[offset + 7] = t.origin.y
			bulk_array[offset + 8] = t.basis.x.z
			bulk_array[offset + 9] = t.basis.y.z
			bulk_array[offset + 10] = t.basis.z.z
			bulk_array[offset + 11] = t.origin.z
			bulk_array[offset + 12] = c.r
			bulk_array[offset + 13] = c.g
			bulk_array[offset + 14] = c.b
			bulk_array[offset + 15] = c.a
			
		var collision_body := StaticBody3D.new()
		collision_body.name = "StaticCollisionBody"
		var shared_box_shape := BoxShape3D.new()
		for t in collision_transforms:
			var owner_id := collision_body.create_shape_owner(collision_body)
			collision_body.shape_owner_add_shape(owner_id, shared_box_shape)
			collision_body.shape_owner_set_transform(owner_id, t)
			
		var old_body := chunk_node.get_node_or_null("StaticCollisionBody")
		if is_instance_valid(old_body):
			chunk_node.remove_child(old_body)
			old_body.queue_free()
			
		chunk_node.setup_chunk_visuals(
			collision_transforms.size(), 
			bulk_array, 
			collision_body
		)
		
		if _chunk_task_cache.has(chunk_pos):
			var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos]
			cached_task.transforms = collision_transforms
			cached_task.visual_colors = visual_colors
			cached_task.collision_body = collision_body
			cached_task.multimesh_bulk_array = bulk_array
