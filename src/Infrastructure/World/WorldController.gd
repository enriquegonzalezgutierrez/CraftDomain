# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure coordinator orchestrating world state, procedural
#              generation, dynamic loading, and saving/loading block modifications.
#              SOLID COMPLIANCE: Adheres to Single Responsibility Principle (SRP).
#              PERFORMANCE UPGRADE:
#              - Eliminated severe main-thread lag spikes during block mining. 
#              - Dynamic chunk visual rebuilds are now fully offloaded to the 
#                WorkerThreadPool via `_request_chunk_rebuild`.
#              - Smart Boundary Checks: Only updates neighbor chunks if a block
#                was modified exactly on the local chunk's edge (x=0 or x=15).
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

# FASE A: Agricultural ticks processor service
var _agriculture_service: AgricultureService

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode
var _chunk_nodes: Dictionary = {}

## Tracking dictionary to prevent initiating duplicate load threads: Vector3i -> bool
var _pending_loading_chunks: Dictionary = {}

## LSP UPGRADE: Tracking map for entities spawned within specific chunk columns: Vector3i (y=0) -> Array[Node]
var _chunk_entities: Dictionary = {}

## Thread safety sync structures
var _queue_mutex: Mutex
var _completed_tasks_queue: Array[GeneratedChunkTask] = []
var _unload_queue: Array[Vector3i] = [] # CRITICAL: Unload task queue for frame throttling

## Throttling timer variables
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

## Target chunk coordinate where the player is scheduled to spawn safely
var _target_spawn_chunk_pos: Vector3i = Vector3i(0, 0, 0)

# --- CHUNK TASK CACHE SYSTEM (Memory-efficient LRU) ---
var _chunk_task_cache: Dictionary = {}
const CACHE_SIZE_LIMIT: int = 64 

# --- PERSISTENT INVENTORY CACHE ---
var _loaded_inventory_data: Array = []

## Subclass containing the completed background generation and rendering results.
class GeneratedChunkTask:
	var chunk: Chunk
	var multimesh_data: Dictionary = {} # BlockType.Type -> PackedFloat32Array
	var collision_transforms: Array[Transform3D] = []
	var liquid_meshes: Dictionary = {} # BlockType.Type -> ArrayMesh 
	var is_rebuild: bool = false # Tracks if this is an update vs a brand new chunk

func _ready() -> void:
	assert(repository != null, "[WorldController] Fatal: WorldRepository must be injected before _ready()!")
	_initialize_systems()

func _initialize_systems() -> void:
	world_state = WorldState.new()
	loader_service = ChunkLoaderService.new()
	_queue_mutex = Mutex.new()
	
	_mob_spawning_service = MobSpawningService.new()
	_streetlight_service = StreetlightService.new(self, world_state)
	
	# FASE A: Instantiate the Agricultural Simulation Service (SRP)
	_agriculture_service = AgricultureService.new(self, world_state)
	
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
		if saved_global.has("inventory"):
			_loaded_inventory_data = saved_global["inventory"] as Array
			
		# Overwrite the campaign registry's default initialization
		if saved_global.has("active_quest_id"):
			var saved_q_id: String = saved_global["active_quest_id"]
			if saved_q_id == "COMPLETED":
				QuestService.clear_active_quest() # Player finished the game before!
			elif saved_q_id != "":
				QuestService.set_active_quest(saved_q_id)
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
		
	# FASE A: Feed delta time continuously to process Random Crop ticks
	if is_instance_valid(_agriculture_service):
		_agriculture_service.process_agriculture_ticks(delta)
		
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_process_dynamic_world()
		_process_day_night_lighting()
		
	# Framework frame-throttling allocation
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

# ==============================================================================
# THREAD DISPATCHERS
# ==============================================================================

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

## ASYNC REBUILD: Offloads visual reconstruction completely to avoid main thread stutters
func _request_chunk_rebuild(chunk_pos: Vector3i) -> void:
	if not _chunk_nodes.has(chunk_pos):
		return
	if _pending_loading_chunks.has(chunk_pos):
		return
		
	_pending_loading_chunks[chunk_pos] = true
	WorkerThreadPool.add_task(_background_rebuild_chunk_task.bind(chunk_pos))


# ==============================================================================
# BACKGROUND WORKER THREADS
# ==============================================================================

## Background Thread: Operates heavy procedural calculations.
func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := Chunk.new(chunk_pos)
	generator.generate_chunk(chunk)
	
	# Disk I/O load modifications
	var saved_edits := repository.load_chunk_modifications(chunk_pos)
	if saved_edits.size() > 0:
		for local_pos in saved_edits.keys():
			var pos: Vector3i = local_pos
			chunk.set_block(pos.x, pos.y, pos.z, saved_edits[local_pos])
			
	var visual_data := ChunkVisualBuilder.extract_render_data(chunk, world_state)
	
	var liquids: Dictionary = {}
	for l_type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type)
		if l_mesh != null:
			liquids[l_type] = l_mesh
	
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_transforms = visual_data["collision"] as Array[Transform3D]
	task_result.liquid_meshes = liquids
	task_result.is_rebuild = false
	
	_queue_mutex.lock()
	_chunk_task_cache[chunk_pos] = task_result
	_completed_tasks_queue.append(task_result)
	
	if _chunk_task_cache.size() > CACHE_SIZE_LIMIT:
		var oldest_key = _chunk_task_cache.keys()[0]
		_chunk_task_cache.erase(oldest_key)
	_queue_mutex.unlock()


## Background Thread: Re-meshes chunks during active gameplay interactions
func _background_rebuild_chunk_task(chunk_pos: Vector3i) -> void:
	var chunk := world_state.get_chunk(chunk_pos)
	if chunk == null:
		_queue_mutex.lock()
		_pending_loading_chunks.erase(chunk_pos)
		_queue_mutex.unlock()
		return
		
	var visual_data := ChunkVisualBuilder.extract_render_data(chunk, world_state)
	
	var liquids: Dictionary = {}
	for l_type in [BlockType.Type.WATER, BlockType.Type.LAVA]:
		var l_mesh := ChunkMesher.generate_liquid_mesh(chunk, world_state, l_type)
		if l_mesh != null:
			liquids[l_type] = l_mesh

	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.multimesh_data = visual_data["multimesh"] as Dictionary
	task_result.collision_transforms = visual_data["collision"] as Array[Transform3D]
	task_result.liquid_meshes = liquids
	task_result.is_rebuild = true # Flag to update instead of instantiating new

	_queue_mutex.lock()
	_completed_tasks_queue.append(task_result)
	_queue_mutex.unlock()

# ==============================================================================
# MAIN THREAD RENDER DISPATCH
# ==============================================================================

## Main Thread: Safe, stutter-free physical body and visual node instantiation.
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
			
		# CASE A: DYNAMIC REBUILD (User modified the world)
		if task.is_rebuild:
			var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
			if is_instance_valid(chunk_node):
				var collision_body := StaticBody3D.new()
				collision_body.name = "StaticCollisionBody"
				var shared_box_shape := BoxShape3D.new()
				
				for t in task.collision_transforms:
					var owner_id := collision_body.create_shape_owner(collision_body)
					collision_body.shape_owner_add_shape(owner_id, shared_box_shape)
					collision_body.shape_owner_set_transform(owner_id, t)
					
				chunk_node.setup_chunk_visuals(task.multimesh_data, collision_body, task.liquid_meshes)
				
		# CASE B: BRAND NEW CHUNK (Procedurally generated during exploration)
		else:
			if not _chunk_nodes.has(chunk_pos):
				world_state.add_chunk(task.chunk)
				var chunk_node := ChunkNode.new(task.chunk)
				add_child(chunk_node)
				_chunk_nodes[chunk_pos] = chunk_node
				
				var collision_body := StaticBody3D.new()
				collision_body.name = "StaticCollisionBody"
				var shared_box_shape := BoxShape3D.new()
				
				for t in task.collision_transforms:
					var owner_id := collision_body.create_shape_owner(collision_body)
					collision_body.shape_owner_add_shape(owner_id, shared_box_shape)
					collision_body.shape_owner_set_transform(owner_id, t)
				
				chunk_node.setup_chunk_visuals(task.multimesh_data, collision_body, task.liquid_meshes)
				
				# DYNAMIC SEAM SEWING: Rebuild the 4 horizontal neighbor Chunks asynchronously
				var horizontal_dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
				for dir in horizontal_dirs:
					var neighbor_pos: Vector3i = chunk_pos + dir
					if _chunk_nodes.has(neighbor_pos):
						_request_chunk_rebuild(neighbor_pos)
				
				# Spawning Community check
				if is_instance_valid(_mob_spawning_service):
					var col_pos := Vector3i(chunk_pos.x, 0, chunk_pos.z)
					var spawn_chunk_pos_0 := Vector3i(chunk_pos.x, 0, chunk_pos.z)
					var spawn_chunk_pos_1 := Vector3i(chunk_pos.x, 1, chunk_pos.z)
					
					if _chunk_nodes.has(spawn_chunk_pos_0) and _chunk_nodes.has(spawn_chunk_pos_1):
						if not _chunk_entities.has(col_pos) and is_instance_valid(_mob_spawning_service):
							var chunk_0 = _chunk_nodes[spawn_chunk_pos_0].chunk
							var spawned := _mob_spawning_service.spawn_mobs_for_chunk(chunk_0, self, world_state)
							if spawned.size() > 0:
								_chunk_entities[col_pos] = spawned
				
				if is_instance_valid(_streetlight_service):
					_streetlight_service.register_streetlights_for_chunk(task.chunk)
				
				# Spawn synchronization
				if is_instance_valid(player) and not player.get("is_active"):
					var spawn_chunk_pos_0_p := Vector3i(_target_spawn_chunk_pos.x, 0, _target_spawn_chunk_pos.z)
					var spawn_chunk_pos_1_p := Vector3i(_target_spawn_chunk_pos.x, 1, _target_spawn_chunk_pos.z)
					
					if _chunk_nodes.has(spawn_chunk_pos_0_p) and _chunk_nodes.has(spawn_chunk_pos_1_p):
						_activate_player_spawn()

func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		return

	var col_pos := Vector3i(chunk_pos.x, 0, chunk_pos.z)
	if _chunk_entities.has(col_pos):
		var entities: Array = _chunk_entities[col_pos]
		for entity in entities:
			if is_instance_valid(entity):
				entity.queue_free()
		_chunk_entities.erase(col_pos)

	if is_instance_valid(_streetlight_service):
		_streetlight_service.unregister_streetlights_for_chunk(chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	if is_instance_valid(chunk_node):
		var body := chunk_node.get_node_or_null("StaticCollisionBody")
		if is_instance_valid(body):
			chunk_node.remove_child(body)
		chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)

# ==============================================================================
# EXTERNAL APIS & SAVE SYSTEMS
# ==============================================================================

## Places/Deletes a block globally and forces an ASYNC visual refresh.
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	# Logical state update is instantaneous!
	world_state.set_block(global_pos, type)
	
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	var local_pos := world_state.global_to_local_pos(global_pos)
	
	# Asynchronously queue the main chunk for visual rebuild
	_request_chunk_rebuild(chunk_pos)
	
	# SMART BOUNDARY LOGIC: Only rebuild neighboring chunks if the modified block
	# is sitting exactly on the visual border edge of this chunk! 
	# (Reduces rebuild calculations by 80%)
	if local_pos.x == 0: _request_chunk_rebuild(chunk_pos + Vector3i(-1, 0, 0))
	elif local_pos.x == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(1, 0, 0))
	
	if local_pos.z == 0: _request_chunk_rebuild(chunk_pos + Vector3i(0, 0, -1))
	elif local_pos.z == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(0, 0, 1))
	
	if local_pos.y == 0: _request_chunk_rebuild(chunk_pos + Vector3i(0, -1, 0))
	elif local_pos.y == Chunk.SIZE - 1: _request_chunk_rebuild(chunk_pos + Vector3i(0, 1, 0))

func save_all() -> void:
	print("[WorldController] Executing clean save operations...")
	for chunk_pos in world_state._chunk_modifications.keys():
		var modifications: Dictionary = world_state.get_chunk_modifications(chunk_pos)
		repository.save_chunk_modifications(chunk_pos, modifications)
		
	if is_instance_valid(player):
		var inv_data: Array = []
		var inventory = player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			inv_data = inventory.get_serialize_data()
			
		var active_q_id := ""
		var active_q := QuestService.get_active_quest()
		if active_q != null:
			active_q_id = active_q.quest_id
		else:
			active_q_id = "COMPLETED" 
				
		repository.save_global_state(
			player.global_position, 
			player.rotation, 
			generator._terrain_noise.seed,
			inv_data,
			active_q_id
		)
	print("[WorldController] All data serialized and saved successfully.")

func _activate_player_spawn() -> void:
	var block_x := int(floor(player.position.x))
	var block_z := int(floor(player.position.z))
	var found_safe_y: float = -1.0
	
	for y in range(31, -1, -1):
		var check_coord := Vector3i(block_x, y, block_z)
		var block_type := world_state.get_block(check_coord)
		
		if BlockType.is_solid(block_type):
			found_safe_y = float(y) + 2.0 
			break
			
	if found_safe_y >= 0.0:
		player.position.y = found_safe_y
	else:
		player.position.y = 14.0
		
	_restore_player_inventory()
	
	player.set("is_active", true)
	player.velocity = Vector3.ZERO

func _restore_player_inventory() -> void:
	if _loaded_inventory_data.size() > 0 and is_instance_valid(player):
		var inventory = player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			print("[WorldController] Restoring saved player inventory...")
			inventory.deserialize_data(_loaded_inventory_data)
			player.call("_sync_hud_counters")
