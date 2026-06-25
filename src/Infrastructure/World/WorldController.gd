# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure coordinator orchestrating world state, procedural
#              generation, dynamic loading, and saving/loading block modifications,
#              fully compliant with SOLID and SRP by delegating life and lighting.
#              DIP Compliant: Relies on injected WorldRepository abstraction.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/WorldController.gd
# ==============================================================================
class_name WorldController
extends Node3D

## Core World modules.
var world_state: WorldState
var generator: WorldGenerator
var loader_service: ChunkLoaderService

## Dependency-injected repository abstraction (DIP compliant)
var repository: WorldRepository

## Dependency-injected player reference.
var player: CharacterBody3D

# Decoupled Private helper services (SRP compliant)
var _mob_spawning_service: MobSpawningService
var _streetlight_service: StreetlightService

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode.
var _chunk_nodes: Dictionary = {}

## Tracking dictionary to prevent initiating duplicate load threads: Vector3i -> bool.
var _pending_loading_chunks: Dictionary = {}

## Tracking map for entities spawned within specific chunks: Vector3i -> Array[CharacterBody3D].
var _chunk_entities: Dictionary = {}

## Thread safety sync structures
var _queue_mutex: Mutex
var _completed_tasks_queue: Array[GeneratedChunkTask] = []

## Throttling timer variables to avoid running distance checks on every single frame.
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

## Subclass containing the completed background generation and rendering results. Statically typed.
class GeneratedChunkTask:
	var chunk: Chunk
	var transforms: Array[Transform3D]

func _ready() -> void:
	# Enforce Dependency Injection contract
	assert(repository != null, "[WorldController] Fatal: WorldRepository must be injected before _ready()!")
	
	_initialize_systems()

func _initialize_systems() -> void:
	world_state = WorldState.new()
	loader_service = ChunkLoaderService.new()
	_queue_mutex = Mutex.new()
	
	# Instantiate our helper services (SRP compliant)
	_mob_spawning_service = MobSpawningService.new()
	_streetlight_service = StreetlightService.new(self, world_state)
	
	# Check if a saved world state exists via the injected abstraction
	var saved_global := repository.load_global_state()
	var active_seed: int
	
	if saved_global.has("seed"):
		active_seed = saved_global["seed"]
		print("[WorldController] Found saved game! Restoring seed: ", active_seed)
	else:
		randomize()
		active_seed = randi()
		print("[WorldController] No save found. Generating new world with unique Seed: ", active_seed)
		
	generator = WorldGenerator.new(active_seed)

func _process(delta: float) -> void:
	# Avoid executing logic if the player has not spawned yet
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
	# Locate the sibling CelestialService node dynamically
	var celestial = get_parent().get_node_or_null("CelestialService")
	if not is_instance_valid(celestial) or not celestial.has_method("is_night_time"):
		return
		
	var is_night: bool = celestial.call("is_night_time")
	
	# Delegate light toggling responsibility to the StreetlightService (SRP)
	if is_instance_valid(_streetlight_service):
		_streetlight_service.update_streetlights_state(is_night)

func _request_asynchronous_chunk_load(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		return
		
	_pending_loading_chunks[chunk_pos] = true
	
	# Dispatch task
	WorkerThreadPool.add_task(func() -> void:
		_background_generate_chunk_task(chunk_pos)
	)

func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	# 1. Generate procedural block dataset
	var chunk := Chunk.new(chunk_pos)
	generator.generate_chunk(chunk)
	
	# 2. Asynchronous Load Integration: Query and apply any saved block edits from abstraction
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
						
	# 4. Queue the task result
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.transforms = collision_transforms
	
	# Also register saved edits into active state modifications tracker
	if saved_edits.size() > 0:
		world_state.apply_chunk_modifications(chunk_pos, saved_edits)
	
	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()

func _render_completed_chunks_from_queue() -> void:
	_queue_mutex.lock()
	var tasks_to_render := _completed_tasks_queue.duplicate()
	_completed_tasks_queue.clear()
	_queue_mutex.unlock()
	
	for task in tasks_to_render:
		var chunk_pos: Vector3i = task.chunk.position
		
		if _pending_loading_chunks.has(chunk_pos):
			_pending_loading_chunks.erase(chunk_pos)
			
			world_state.add_chunk(task.chunk)
			
			var chunk_node := ChunkNode.new(task.chunk)
			add_child(chunk_node)
			_chunk_nodes[chunk_pos] = chunk_node
			
			# Send pre-compiled background physics transforms
			chunk_node.setup_chunk_visuals(task.transforms, _pre_shaded_colors_of_chunk(task.chunk, task.transforms), task.transforms)
			
			# Delegate animal and villager spawning responsibility to MobSpawningService (SRP)
			if is_instance_valid(_mob_spawning_service):
				var spawned := _mob_spawning_service.spawn_mobs_for_chunk(task.chunk, self)
				if spawned.size() > 0:
					_chunk_entities[chunk_pos] = spawned
			
			# Delegate streetlight registration responsibility to StreetlightService (SRP)
			if is_instance_valid(_streetlight_service):
				_streetlight_service.register_streetlights_for_chunk(task.chunk)
			
			# Safe spawn activation: Activate player once the home chunk is rendered
			if chunk_pos == Vector3i(0, 0, 0) and is_instance_valid(player) and not player.get("is_active"):
				_activate_player_spawn()

func _pre_shaded_colors_of_chunk(chunk: Chunk, transforms: Array[Transform3D]) -> Array[Color]:
	# Re-construct visual color lists based on transforms
	var colors: Array[Color] = []
	colors.resize(transforms.size())
	
	for i in range(transforms.size()):
		var t := transforms[i]
		var local_pos := t.origin - Vector3(0.5, 0.5, 0.5)
		var block_type := chunk.get_block(int(local_pos.x), int(local_pos.y), int(local_pos.z))
		var block_def := BlockLibrary.get_definition(block_type)
		var shade_noise: float = 0.9 + 0.1 * sin(local_pos.x * 1.4 + local_pos.y * 2.3 + local_pos.z * 3.7)
		colors[i] = block_def.color_top * shade_noise
		
	return colors

func _activate_player_at_coord(spawn_y: float) -> void:
	player.position = Vector3(8.5, spawn_y, 8.5)
	player.set("is_active", true)
	print("[World] Home chunk loaded. Player activated safely.")

func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		return

	# Dynamic Auto-Saving: Write any chunk modification deltas to disk before unloading
	var modifications := world_state.get_chunk_modifications(chunk_pos)
	if modifications.size() > 0:
		repository.save_chunk_modifications(chunk_pos, modifications)

	if _chunk_entities.has(chunk_pos):
		var entities: Array = _chunk_entities[chunk_pos]
		for entity in entities:
			if is_instance_valid(entity):
				entity.queue_free()
		_chunk_entities.erase(chunk_pos)

	# Delegate active streetlights cleanup responsibility to StreetlightService (SRP)
	if is_instance_valid(_streetlight_service):
		_streetlight_service.unregister_streetlights_for_chunk(chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	if is_instance_valid(chunk_node):
		chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)

## Public API: Performs a clean, manual save of all active chunks and player positions
func save_all() -> void:
	print("[WorldController] Executing manual save of all world state elements...")
	
	# 1. Save all active chunk modifications via abstraction
	for chunk_pos in world_state._chunk_modifications.keys():
		var modifications: Dictionary = world_state.get_chunk_modifications(chunk_pos)
		repository.save_chunk_modifications(chunk_pos, modifications)
		
	# 2. Save global metadata (seed, position, look direction) via abstraction
	if is_instance_valid(player):
		repository.save_global_state(
			player.global_position, 
			player.rotation, 
			generator._terrain_noise.seed
		)
	print("[WorldController] Manual save complete.")

func _activate_player_spawn() -> void:
	var saved_global := repository.load_global_state()
	
	if saved_global.has("player_pos"):
		# Restore player coordinates and camera look angles from last save session
		player.position = saved_global["player_pos"]
		player.rotation = saved_global["player_rot"]
		player.set("is_active", true)
		print("[WorldController] Restored player spawn position from save: ", player.position)
	else:
		# Fresh spawn: default safe coordinates
		player.position = Vector3(8.5, 14.0, 8.5)
		player.set("is_active", true)
		print("[WorldController] Fresh world spawn created.")

## Exposes a public, real-time API to edit blocks globally from anywhere.
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
		
		# Update rendering and physics instantly on main thread
		chunk_node.setup_chunk_visuals(
			collision_transforms, 
			_pre_shaded_colors_of_chunk(chunk_node.chunk, collision_transforms), 
			collision_transforms
		)
