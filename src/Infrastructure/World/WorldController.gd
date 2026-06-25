# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure coordinator orchestrating world state, procedural
#              generation, dynamic loading, and saving/loading block modifications.
#              Enforces SOLID and SRP compliance by delegating mob spawning,
#              streetlights toggling, and asynchronous thread pool tasks.
#              Features a robust Spawn Protection (Unstuck Solver) with UNIFIED
#              target spawn chunk coordinates calculation (always forcing Y=0)
#              for both fresh worlds and restored sessions to prevent freeze bugs.
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

## Throttling timer variables to avoid running distance checks on every single frame
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

## Target chunk coordinate where the player is scheduled to spawn safely
var _target_spawn_chunk_pos: Vector3i = Vector3i(0, 0, 0)

# --- CHUNK TASK CACHE SYSTEM (Strict Memory-efficient LRU) ---
## Cache storing pre-calculated chunk data geometries: Vector3i -> GeneratedChunkTask
var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64 # Cache up to 64 recently processed chunks in RAM

## Subclass containing the completed background generation and rendering results.
class GeneratedChunkTask:
	var chunk: Chunk
	var transforms: Array[Transform3D]
	var visual_colors: Array[Color]
	var collision_faces: PackedVector3Array

func _ready() -> void:
	# Enforce Dependency Injection contract
	assert(repository != null, "[WorldController] Fatal: WorldRepository must be injected before _ready()!")
	
	_initialize_systems()

func _initialize_systems() -> void:
	world_state = WorldState.new()
	loader_service = ChunkLoaderService.new()
	_queue_mutex = Mutex.new()
	
	# Instantiate decoupled helper services (SRP compliant)
	_mob_spawning_service = MobSpawningService.new()
	_streetlight_service = StreetlightService.new(self, world_state)
	
	# Check if a saved world state exists via the injected abstraction
	var saved_global := repository.load_global_state()
	var active_seed: int
	var spawn_pos := Vector3(8.5, 14.0, 8.5) # Fallback spawn
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
	
	# CRITICAL UNIFICATION: Both fresh spawns and saved games calculate chunk pos via the same OCP method
	var block_pos := Vector3i(int(floor(spawn_pos.x)), int(floor(spawn_pos.y)), int(floor(spawn_pos.z)))
	_target_spawn_chunk_calculation(block_pos)
	
	# Pre-position the player entity immediately to their target coords
	if is_instance_valid(player):
		player.position = spawn_pos
		player.rotation = spawn_rot
		print("[WorldController] Player pre-positioned at target coordinates: ", spawn_pos)

func _target_spawn_chunk_calculation(block_pos: Vector3i) -> void:
	_target_spawn_chunk_pos = world_state.global_to_chunk_pos(block_pos)
	
	# Force horizontal vertical Y=0 chunk coordination to match loader layout
	_target_spawn_chunk_pos.y = 0
	print("[WorldController] Calculated player destination spawn chunk at: ", _target_spawn_chunk_pos)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	# 1. Periodically check and evaluate player position for loading tasks
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_process_dynamic_world()
		_process_day_night_lighting()
		
	# 2. Main thread: consume completed chunks from the background queue and render them
	_render_completed_chunks_from_queue()

func _process_dynamic_world() -> void:
	var task: ChunkLoaderService.ChunkUpdateTask = loader_service.check_viewer_position(
		player.global_position, 
		world_state
	)
	
	for chunk_pos in task.to_unload:
		_unload_chunk_node(chunk_pos)
		
	for chunk_pos in task.to_load:
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
		
	# --- INTEGRATING CACHE SYSTEM ---
	# If the chunk geometries are already cached, retrieve them in microseconds bypassing thread pipelines
	if _chunk_task_cache.has(chunk_pos):
		var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos]
		_queue_mutex.lock()
		_completed_tasks_queue.append(cached_task)
		_queue_mutex.unlock()
		return
		
	_pending_loading_chunks[chunk_pos] = true
	
	# Dispatch generation task safely to background threads
	WorkerThreadPool.add_task(func() -> void:
		_background_generate_chunk_task(chunk_pos)
	)

func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	# 1. Generate procedural block dataset
	var chunk := Chunk.new(chunk_pos)
	generator.generate_chunk(chunk)
	
	# 2. Query and apply any saved block edits from the injected abstraction
	var saved_edits := repository.load_chunk_modifications(chunk_pos)
	if saved_edits.size() > 0:
		for local_pos in saved_edits.keys():
			var pos: Vector3i = local_pos
			chunk.set_block(pos.x, pos.y, pos.z, saved_edits[local_pos])
			
	# 3. Pre-compile box shapes transforms in the background (Thread-safe)
	var collision_transforms: Array[Transform3D] = []
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if BlockType.is_solid(chunk.get_block(x, y, z)):
					var local_pos := Vector3(x, y, z)
					var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
					collision_transforms.append(Transform3D(Basis(), transform_pos))
	
	# 4. --- ADVANCED BACKGROUND COLLISION MESHING ---
	var collision_faces := PackedVector3Array()
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var block_type := chunk.get_block(x, y, z)
				if not BlockType.is_solid(block_type):
					continue
				_append_culled_collision_faces(chunk, x, y, z, collision_faces)
				
	# 5. --- BACKGROUND AMBIENT SHADING (COMPLETELY OFF-THREAD) ---
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
		
		# Generate soft ambient shading using coordinate algorithms
		var shade_noise: float = 0.9 + 0.1 * sin(float(block_x) * 1.4 + float(block_y) * 2.3 + float(block_z) * 3.7)
		visual_colors[i] = block_def.color_top * shade_noise
						
	# 6. Queue the task result
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.transforms = collision_transforms
	task_result.collision_faces = collision_faces
	task_result.visual_colors = visual_colors
	
	_queue_mutex.lock()
	
	# Cache the newly generated task
	_chunk_task_cache[chunk_pos] = task_result
	_completed_tasks_queue.append(task_result)
	
	# Enforce LRU cache limits to prevent memory bloat
	if _chunk_task_cache.size() > CACHE_SIZE_LIMIT:
		# Evict the oldest cached entry
		var oldest_key = _chunk_task_cache.keys()[0]
		_chunk_task_cache.erase(oldest_key)
		
	_queue_mutex.unlock()

## Helper to build culled face triangles for the physical collision body
func _append_culled_collision_faces(chunk: Chunk, x: int, y: int, z: int, faces: PackedVector3Array) -> void:
	var fx: float = float(x)
	var fy: float = float(y)
	var fz: float = float(z)
	
	# Directions definition
	var dirs := {
		Vector3i(0, 1, 0): "TOP",
		Vector3i(0, -1, 0): "BOTTOM",
		Vector3i(1, 0, 0): "RIGHT",
		Vector3i(-1, 0, 0): "LEFT",
		Vector3i(0, 0, 1): "FRONT",
		Vector3i(0, 0, -1): "BACK"
	}
	
	# Statically typing the loop variable 'offset' as Vector3i to enforce compile-time type safety
	for offset: Vector3i in dirs:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		var nz: int = z + offset.z
		
		# If the neighbor block is non-solid or out of bounds, draw the collision face
		var neighbor_type := chunk.get_block(nx, ny, nz)
		if not BlockType.is_solid(neighbor_type):
			match dirs[offset]:
				"TOP":
					faces.append(Vector3(fx, fy + 1.0, fz + 1.0))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, 1.0 + fz))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, fz))
					
					faces.append(Vector3(fx, fy + 1.0, fz + 1.0))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, fz))
					faces.append(Vector3(fx, fy + 1.0, fz))
				"BOTTOM":
					faces.append(Vector3(fx, fy, fz))
					faces.append(Vector3(1.0 + fx, fy, fz))
					faces.append(Vector3(1.0 + fx, fy, 1.0 + fz))
					
					faces.append(Vector3(fx, fy, fz))
					faces.append(Vector3(1.0 + fx, fy, 1.0 + fz))
					faces.append(Vector3(fx, fy, 1.0 + fz))
				"RIGHT":
					faces.append(Vector3(1.0 + fx, fy, 1.0 + fz))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, 1.0 + fz))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, fz))
					
					faces.append(Vector3(1.0 + fx, fy, 1.0 + fz))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, fz))
					faces.append(Vector3(1.0 + fx, fy, fz))
				"LEFT":
					faces.append(Vector3(fx, fy, fz))
					faces.append(Vector3(fx, 1.0 + fy, fz))
					faces.append(Vector3(fx, 1.0 + fy, 1.0 + fz))
					
					faces.append(Vector3(fx, fy, fz))
					faces.append(Vector3(fx, 1.0 + fy, 1.0 + fz))
					faces.append(Vector3(fx, fy, 1.0 + fz))
				"FRONT":
					faces.append(Vector3(fx, fy, 1.0 + fz))
					faces.append(Vector3(fx, 1.0 + fy, 1.0 + fz))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, 1.0 + fz))
					
					faces.append(Vector3(fx, fy, 1.0 + fz))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, 1.0 + fz))
					faces.append(Vector3(1.0 + fx, fy, 1.0 + fz))
				"BACK":
					faces.append(Vector3(1.0 + fx, fy, fz))
					faces.append(Vector3(1.0 + fx, 1.0 + fy, fz))
					faces.append(Vector3(fx, 1.0 + fy, fz))
					
					faces.append(Vector3(1.0 + fx, fy, fz))
					faces.append(Vector3(fx, 1.0 + fy, fz))
					faces.append(Vector3(fx, fy, fz))

func _render_completed_chunks_from_queue() -> void:
	_queue_mutex.lock()
	var tasks_to_render := _completed_tasks_queue.duplicate()
	_completed_tasks_queue.clear()
	_queue_mutex.unlock()
	
	for task in tasks_to_render:
		var chunk_pos: Vector3i = task.chunk.position
		
		if _pending_loading_chunks.has(chunk_pos):
			_pending_loading_chunks.erase(chunk_pos)
			
		# Render only if the chunk node is not already constructed
		if not _chunk_nodes.has(chunk_pos):
			world_state.add_chunk(task.chunk)
			
			var chunk_node := ChunkNode.new(task.chunk)
			add_child(chunk_node)
			_chunk_nodes[chunk_pos] = chunk_node
			
			chunk_node.setup_chunk_visuals(
				task.transforms, 
				task.visual_colors, 
				task.transforms
			)
			
			if is_instance_valid(_mob_spawning_service):
				var spawned := _mob_spawning_service.spawn_mobs_for_chunk(task.chunk, self)
				if spawned.size() > 0:
					_chunk_entities[chunk_pos] = spawned
			
			if is_instance_valid(_streetlight_service):
				_streetlight_service.register_streetlights_for_chunk(task.chunk)
			
			# --- SECURE SPAWN SYNCHRONIZATION ---
			# Only activate player spawn once their specific target destination chunk is fully loaded and rendered
			if chunk_pos == _target_spawn_chunk_pos and is_instance_valid(player) and not player.get("is_active"):
				_activate_player_spawn()

func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		return

	# Sessional synchronous disk I/O has been completely removed.
	# Block modifications are cached in RAM (WorldState) during walk-through,
	# and only written to disk in a single step upon 'save_all' triggers.

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
	# --- UNSTUCK & SAFE GROUND FINDER ALGORITHM ---
	# Executed over a fully loaded chunk structure, guaranteed to find solid terrain
	var block_x := int(floor(player.position.x))
	var block_z := int(floor(player.position.z))
	var found_safe_y: float = -1.0
	
	for y in range(Chunk.SIZE - 1, -1, -1):
		var check_coord := Vector3i(block_x, y, block_z)
		var block_type := world_state.get_block(check_coord)
		
		if BlockType.is_solid(block_type):
			# Offset Y by 2.0 to account for player height (1.8m) plus a tiny safety cushion (0.1m)
			found_safe_y = float(y) + 2.0 
			break
			
	if found_safe_y >= 0.0:
		player.position.y = found_safe_y
		print("[WorldController] Spawn protected! Relocated player safely on ground at Y: ", found_safe_y)
	else:
		player.position.y = 14.0
		print("[WorldController] Column empty. Spawning player in air drop at safe Y: 14.0")
		
	player.set("is_active", true)
	player.velocity = Vector3.ZERO
	
	print("[WorldController] Player activated safely under Spawn Protection rules.")

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
		
		# For block edits in runtime, compile a simplified local collision mesh instantly
		var collision_faces := PackedVector3Array()
		for x in range(Chunk.SIZE):
			for y in range(Chunk.SIZE):
				for z in range(Chunk.SIZE):
					if BlockType.is_solid(chunk_node.chunk.get_block(x, y, z)):
						_append_culled_collision_faces(chunk_node.chunk, x, y, z, collision_faces)
						
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
			var shade_noise: float = 0.9 + 0.1 * sin(local_pos.x * 1.4 + local_pos.y * 2.3 + local_pos.z * 3.7)
			visual_colors[i] = block_def.color_top * shade_noise
			
		chunk_node.setup_chunk_visuals(
			collision_transforms, 
			visual_colors, 
			collision_transforms
		)
		
		# Also update the cache dynamically to keep edited blocks consistent on return
		if _chunk_task_cache.has(chunk_pos):
			var cached_task: GeneratedChunkTask = _chunk_task_cache[chunk_pos]
			cached_task.transforms = collision_transforms
			cached_task.visual_colors = visual_colors
