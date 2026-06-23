# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure coordinator that orchestrates the World State, 
#              procedural generation, dynamic chunk loading, village houses,
#              and passive animal/villager/merchant entity lifecycles with 
#              zero main-thread rendering overhead.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/WorldController.gd
# ==============================================================================
class_name WorldController
extends Node3D

## Core World modules.
var world_state: WorldState
var generator: WorldGenerator
var loader_service: ChunkLoaderService

## Dependency-injected player reference.
var player: PlayerController

## Tracking map for active ChunkNode representations: Vector3i -> ChunkNode.
var _chunk_nodes: Dictionary = {}

## Tracking dictionary to prevent initiating duplicate load threads: Vector3i -> bool.
var _pending_loading_chunks: Dictionary = {}

## Tracking map for entities spawned within specific chunks: Vector3i -> Array[PassiveEntity].
var _chunk_entities: Dictionary = {}

## Thread safety sync structures
var _queue_mutex: Mutex
var _completed_tasks_queue: Array[GeneratedChunkTask] = []

## Throttling timer variables to avoid running distance checks on every single frame.
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

## Subclass containing the completed background generation and rendering results.
class GeneratedChunkTask:
	var chunk: Chunk
	var transforms: Array[Transform3D]
	var colors: Array[Color]

func _ready() -> void:
	_initialize_systems()

func _initialize_systems() -> void:
	# Randomize Godot's primary RNG system to get unique seeds
	randomize()
	var random_world_seed: int = randi()
	print("[WorldController] Spawning new world with unique Seed: ", random_world_seed)
	
	world_state = WorldState.new()
	generator = WorldGenerator.new(random_world_seed)
	loader_service = ChunkLoaderService.new()
	_queue_mutex = Mutex.new()

func _process(delta: float) -> void:
	# Avoid executing logic if the player has not spawned yet
	if not is_instance_valid(player):
		return
		
	# 1. Periodically check and evaluate player position for loading tasks
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_process_dynamic_world()
		
	# 2. Main thread: consume completed chunks from the background queue and render them
	_render_completed_chunks_from_queue()

func _process_dynamic_world() -> void:
	# Query the loader service for required changes based on the player's position
	var task: ChunkLoaderService.ChunkUpdateTask = loader_service.check_viewer_position(
		player.global_position, 
		world_state
	)
	
	# Unload out-of-range chunks (Freeing RAM/VRAM)
	for chunk_pos in task.to_unload:
		_unload_chunk_node(chunk_pos)
		
	# Dispatch newly approached chunks to background threads
	for chunk_pos in task.to_load:
		_request_asynchronous_chunk_load(chunk_pos)

func _request_asynchronous_chunk_load(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		return
		
	_pending_loading_chunks[chunk_pos] = true
	
	# Dispatch task
	WorkerThreadPool.add_task(func() -> void:
		_background_generate_chunk_task(chunk_pos)
	)

func _background_generate_chunk_task(chunk_pos: Vector3i) -> void:
	# 1. Generate core block dataset
	var chunk := Chunk.new(chunk_pos)
	generator.generate_chunk(chunk)
	
	# 2. Pre-compile visual/physical transforms and shaded colors in the background (Thread-safe)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var block_type: BlockType.Type = chunk.get_block(x, y, z)
				if BlockType.is_solid(block_type):
					var local_pos := Vector3(x, y, z)
					# Offset by 0.5 to align precisely with the MultiMesh BoxMesh center
					var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
					transforms.append(Transform3D(Basis(), transform_pos))
					
					# Pre-calculate block shading in the background thread
					var block_def := BlockLibrary.get_definition(block_type)
					var shade_noise: float = 0.9 + 0.1 * sin(local_pos.x * 1.4 + local_pos.y * 2.3 + local_pos.z * 3.7)
					colors.append(block_def.color_top * shade_noise)
						
	# 3. Queue the task result
	var task_result := GeneratedChunkTask.new()
	task_result.chunk = chunk
	task_result.transforms = transforms
	task_result.colors = colors
	
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
			
			# Send pre-compiled background visual and physics data
			chunk_node.setup_chunk_visuals(task.transforms, task.colors, task.transforms)
			
			# Spawn animals and villagers for this chunk dynamically
			_spawn_entities_for_chunk(task.chunk)
			
			# Safe spawn activation: Activate player once the home chunk is rendered
			if chunk_pos == Vector3i(0, 0, 0) and is_instance_valid(player) and not player.is_active:
				player.position = Vector3(8.5, 14.0, 8.5)
				player.is_active = true
				print("[World] Home chunk generated and rendered. Player activated safely.")

func _spawn_entities_for_chunk(chunk: Chunk) -> void:
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	var entities_list: Array[PassiveEntity] = []
	
	# 1. Spawn a Villager and a Merchant if the chunk generated a rustic cabin
	var has_house: bool = (abs(chunk_pos.x) + abs(chunk_pos.z)) % 3 == 2 and chunk_pos.y == 0
	if has_house:
		# Place the Villager safely above ground in front of the house doorway (local coordinates x=7, z=5)
		var spawn_pos_global := chunk_offset + Vector3(7.5, 14.0, 5.5)
		var villager := PassiveEntity.new(PassiveEntity.Type.VILLAGER, spawn_pos_global)
		add_child(villager)
		entities_list.append(villager)
		
		# Place the Merchant on the side of the house (local coordinates x=5, z=7)
		var merchant_pos_global := chunk_offset + Vector3(5.5, 14.0, 7.5)
		var merchant := PassiveEntity.new(PassiveEntity.Type.MERCHANT, merchant_pos_global)
		add_child(merchant)
		entities_list.append(merchant)
		
	# 2. Spawn local animals (Pigs / Chickens) deterministically based on coordinates
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
		var animal_type := PassiveEntity.Type.PIG if (chunk_pos.x + chunk_pos.z) % 2 == 0 else PassiveEntity.Type.CHICKEN
		var spawn_pos_global := chunk_offset + Vector3(8.5, 14.0, 8.5) # Center of chunk
		var animal := PassiveEntity.new(animal_type, spawn_pos_global)
		add_child(animal)
		entities_list.append(animal)
		
	if entities_list.size() > 0:
		_chunk_entities[chunk_pos] = entities_list

func _unload_chunk_node(chunk_pos: Vector3i) -> void:
	if _pending_loading_chunks.has(chunk_pos):
		_pending_loading_chunks.erase(chunk_pos)
		return

	# Delete associated active entities to prevent memory leaks or floating mobs
	if _chunk_entities.has(chunk_pos):
		var entities: Array = _chunk_entities[chunk_pos]
		for entity in entities:
			if is_instance_valid(entity):
				entity.queue_free()
		_chunk_entities.erase(chunk_pos)

	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	if is_instance_valid(chunk_node):
		chunk_node.queue_free()
		
	_chunk_nodes.erase(chunk_pos)
	world_state.remove_chunk(chunk_pos)

## Exposes a public, real-time API to edit blocks globally from anywhere.
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	# Update the underlying logical domain state
	world_state.set_block(global_pos, type)
	
	# Query which chunk manages this block
	var chunk_pos := world_state.global_to_chunk_pos(global_pos)
	var chunk_node: ChunkNode = _chunk_nodes.get(chunk_pos)
	
	# Recompile only that chunk's physical shape instantly on the main thread
	if is_instance_valid(chunk_node):
		var transforms: Array[Transform3D] = []
		var colors: Array[Color] = []
		
		for x in range(Chunk.SIZE):
			for y in range(Chunk.SIZE):
				for z in range(Chunk.SIZE):
					var block_type: BlockType.Type = chunk_node.chunk.get_block(x, y, z)
					if BlockType.is_solid(block_type):
						var local_pos := Vector3(x, y, z)
						var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
						transforms.append(Transform3D(Basis(), transform_pos))
						
						var block_def := BlockLibrary.get_definition(block_type)
						var shade_noise: float = 0.9 + 0.1 * sin(local_pos.x * 1.4 + local_pos.y * 2.3 + local_pos.z * 3.7)
						colors.append(block_def.color_top * shade_noise)
		
		# Set visual and physical updates (0ms main thread)
		chunk_node.setup_chunk_visuals(transforms, colors, transforms)
