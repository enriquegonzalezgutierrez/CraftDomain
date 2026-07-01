# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Coordinator orchestrating high-level world state,
#              delegating chunk compilation, multi-threading, and persistent saving.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): No longer manages threads, 
#                queues, file formatting, or visual compilations. All heavy lifting 
#                is delegated to specialized services.
#              - Open-Closed Principle (OCP): Easily extensible with new auxiliary 
#                services without modifying core coordination loops.
#              - OBSERVER PATTERN: Cleaned of manual HUD-sync calls on inventory loads.
#              - Domain-Driven Design (DDD): Defers player spawn height calculations
#                strictly to the WorldState Domain Aggregate, resolving domain leakage.
#              OPTIMIZATIONS:
#              - Integrated the dynamic proximity spawner call inside the throttled 
#                visiblity update check (every 0.2s) and immediately upon player spawn.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/WorldController.gd
# ==============================================================================
class_name WorldController
extends Node3D

## Core World modules (Domain States)
var world_state: WorldState
var generator: WorldGenerator
var loader_service: ChunkLoaderService

## Dependency-injected repository abstraction (DIP compliant)
var repository: WorldRepository

## Dependency-injected player reference
var player: CharacterBody3D

# Decoupled Private Infrastructure Helper Services (SRP Compliant)
var chunk_manager: ChunkManagerService
var persistence_service: WorldPersistenceService
var _mob_spawning_service: MobSpawningService
var _streetlight_service: StreetlightService
var _agriculture_service: AgricultureService

# Throttling timer variables
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

# Target chunk coordinate where the player is scheduled to spawn safely
var _target_spawn_chunk_pos: Vector3i = Vector3i(0, 0, 0)
var _loaded_inventory_data: Array = []


func _ready() -> void:
	assert(repository != null, "[WorldController] Fatal: WorldRepository must be injected before _ready()!")
	_initialize_systems()


## Sets up all procedural world generation elements and delegates sub-services
func _initialize_systems() -> void:
	world_state = WorldState.new()
	loader_service = ChunkLoaderService.new()
	
	_mob_spawning_service = MobSpawningService.new()
	_streetlight_service = StreetlightService.new(self, world_state)
	_agriculture_service = AgricultureService.new(self, world_state)
	
	# Instantiate our specialized SRP Services
	chunk_manager = ChunkManagerService.new(self, world_state)
	persistence_service = WorldPersistenceService.new(repository)
	
	# Attempt to load saved global game parameters from the repository
	var saved_global: Dictionary = repository.load_global_state()
	var active_seed: int
	var spawn_pos := Vector3(8.5, 14.0, 8.5)
	var spawn_rot := Vector3.ZERO
	
	if saved_global.has("seed"):
		active_seed = saved_global["seed"] as int
		print("[WorldController] Found saved game! Restoring seed: ", active_seed)
		if saved_global.has("player_pos"): 
			spawn_pos = saved_global["player_pos"] as Vector3
		if saved_global.has("player_rot"): 
			spawn_rot = saved_global["player_rot"] as Vector3
		if saved_global.has("inventory"): 
			_loaded_inventory_data = saved_global["inventory"] as Array
		
		# Restore campaign quest progression cleanly
		if saved_global.has("active_quest_id"):
			var saved_q_id: String = saved_global["active_quest_id"] as String
			if saved_q_id == "COMPLETED": 
				QuestService.clear_active_quest()
			elif saved_q_id != "": 
				QuestService.set_active_quest(saved_q_id)
	else:
		# Fallback to unique random seed on fresh game start
		randomize()
		active_seed = randi()
		print("[WorldController] No save found. Generating new world with unique Seed: ", active_seed)
		
	generator = WorldGenerator.new(active_seed)
	
	# Determine initial spawn position
	var block_pos := Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z))
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
		
	# Feed delta time to process dynamic crop tick calculations
	if is_instance_valid(_agriculture_service):
		_agriculture_service.process_agriculture_ticks(delta)
		
	# Throttled Dynamic World Update checks
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_process_dynamic_world()
		_process_day_night_lighting()
		
	# Delegate thread rendering queues to our Chunk Manager
	if is_instance_valid(chunk_manager):
		chunk_manager.process_frame_queues()


## Calculates coordinates to request chunk loads/unloads and triggers proximity spawning
func _process_dynamic_world() -> void:
	var task: ChunkLoaderService.ChunkUpdateTask = loader_service.check_viewer_position(
		player.global_position, 
		world_state
	)
	
	# Delegate loading and unloading arrays directly to ChunkManagerService
	if is_instance_valid(chunk_manager):
		chunk_manager.queue_unloads(task.to_unload)
		chunk_manager.queue_loads(task.to_load)
		
		# DYNAMIC PROXIMITY SPAWNING: Spawns entities only in chunks close to the player
		chunk_manager.spawn_mobs_by_proximity(player.global_position)


## Coordinates dynamic streetlight updates on day/night transitions
func _process_day_night_lighting() -> void:
	var celestial = get_parent().get_node_or_null("CelestialService")
	if not is_instance_valid(celestial) or not celestial.has_method("is_night_time"):
		return
		
	var is_night: bool = celestial.call("is_night_time") as bool
	if is_instance_valid(_streetlight_service):
		_streetlight_service.update_streetlights_state(is_night)


# ==============================================================================
# COORDINATION DELEGATION APIS (DIP/SRP Compliant)
# ==============================================================================

## Proxy getter to satisfy external systems without violating SRP.
## Returns active, rendered chunk nodes from the ChunkManager.
func get_active_chunk_nodes() -> Dictionary:
	if is_instance_valid(chunk_manager):
		return chunk_manager.get_active_nodes()
	return {}


## Places or breaks a block globally and delegates fast asynchronous redraw queues.
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	if is_instance_valid(chunk_manager):
		chunk_manager.set_block_globally(global_pos, type)


## Triggers the global asynchronous save sequence via WorldPersistenceService.
func save_all() -> void:
	if is_instance_valid(persistence_service):
		persistence_service.save_game(player, world_state)


## Proxy helper allowing ChunkManager to trigger procedural mob spawning
func spawn_mobs_for_chunk(chunk: Chunk) -> Array[Node]:
	if is_instance_valid(_mob_spawning_service):
		return _mob_spawning_service.spawn_mobs_for_chunk(chunk, self, world_state)
	return []


## Proxy helper allowing ChunkManager to register streetlights procedurally
func register_streetlights_for_chunk(chunk: Chunk) -> void:
	if is_instance_valid(_streetlight_service):
		_streetlight_service.register_streetlights_for_chunk(chunk)


## Proxy helper allowing ChunkManager to unregister streetlights on unloads
func unregister_streetlights_for_chunk(chunk_pos: Vector3i) -> void:
	if is_instance_valid(_streetlight_service):
		_streetlight_service.unregister_streetlights_for_chunk(chunk_pos)


## Verifies if spawn area chunks are loaded and coordinates player spawn drops
func check_player_spawn_activation() -> void:
	if is_instance_valid(player) and not player.get("is_active"):
		var spawn_chunk_pos_0_p := Vector3i(_target_spawn_chunk_pos.x, 0, _target_spawn_chunk_pos.z)
		var spawn_chunk_pos_1_p := Vector3i(_target_spawn_chunk_pos.x, 1, _target_spawn_chunk_pos.z)
		
		if is_instance_valid(chunk_manager) and chunk_manager.is_chunk_rendered(spawn_chunk_pos_0_p) and chunk_manager.is_chunk_rendered(spawn_chunk_pos_1_p):
			_activate_player_spawn()


## Safely positions the player on the topmost solid block at spawn coordinates using Domain Rules
func _activate_player_spawn() -> void:
	var block_x := floori(player.position.x)
	var block_z := floori(player.position.z)
	var found_safe_y := 14.0 # Default safe fallback
	
	if is_instance_valid(world_state):
		# Centralized Domain Rule calculation (DDD compliant)
		found_safe_y = world_state.get_highest_solid_y(block_x, block_z)
		
	player.position.y = found_safe_y
	_restore_player_inventory()
	player.set("is_active", true)
	player.velocity = Vector3.ZERO
	
	# Force initial proximity spawning immediately upon spawning, so active regions populate right away
	if is_instance_valid(chunk_manager):
		chunk_manager.spawn_mobs_by_proximity(player.global_position)


## Deserializes cached backpack quantities back into the player's inventory
func _restore_player_inventory() -> void:
	if _loaded_inventory_data.size() > 0 and is_instance_valid(player):
		var inventory = player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			print("[WorldController] Restoring saved player inventory...")
			inventory.deserialize_data(_loaded_inventory_data)
