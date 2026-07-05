# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Coordinator orchestrating high-level world state,
#              delegating chunk compilation, multi-threading, and persistent saving.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): No longer manages threads, 
#   queues, file formatting, or visual compilations. All heavy lifting 
#   is delegated to specialized services.
# - Dependency Inversion Principle (DIP): Exposes a domain-compliant 
#   IWorldModifier adapter, decoupling domain strategies from this 
#   concrete infrastructure coordinator.
# - Open-Closed Principle (OCP): Easily extensible with new auxiliary 
#   services without modifying core coordination loops.
# - Domain-Driven Design (DDD): Defers player spawn height calculations
#   strictly to the WorldState Domain Aggregate.
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

## Domain-level modifier interface exposure (Adapter Pattern)
var world_modifier: IWorldModifier

# Decoupled Private Infrastructure Helper Services (SRP Compliant)
var chunk_manager: ChunkManagerService
var persistence_service: WorldPersistenceService
var _mob_spawning_service: MobSpawningService
var _prop_spawning_service: PropSpawningService
var _streetlight_service: StreetlightService
var _agriculture_service: AgricultureService

# Throttling timer variables
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

# Target chunk coordinate where the player is scheduled to spawn safely
# Reactive Setter: Dispatches high-priority loading tasks exactly once upon teleportation
var _target_spawn_chunk_pos: Vector3i = Vector3i(0, 0, 0):
	set(val):
		_target_spawn_chunk_pos = val
		if is_teleport_spawn:
			_trigger_prioritized_spawn_loads()

# Save game protection flags
var _is_restored_save: bool = false
var _is_startup_phase: bool = true

# Public trigger flag for vertical height recalculations on teleport
var is_teleport_spawn: bool = false

# Cached inventory data loaded from save file, to be deserialized upon player activation
var _loaded_inventory_data: Array = []


func _ready() -> void:
	assert(repository != null, "[WorldController] Fatal: WorldRepository must be injected before _ready()!")
	_initialize_systems()


## Sets up all procedural world generation elements and delegates sub-services
func _initialize_systems() -> void:
	world_state = WorldState.new()
	loader_service = ChunkLoaderService.new()
	
	# Instantiate our domain modifier adapter to protect layering rules (DIP)
	world_modifier = WorldModifierAdapter.new(self)
	
	# Instantiate our specialized spawning services (SRP)
	_mob_spawning_service = MobSpawningService.new()
	_prop_spawning_service = PropSpawningService.new()
	
	_setup_persistence()
	
	# Load dialogue trees
	DialogueRegistry.initialize_dialogue_database()
	
	# Load dynamic crafting recipes
	RecipeRegistry.initialize_recipes()
	
	# Fixed constructor parameters: both services require references to the world controller and world state
	_streetlight_service = StreetlightService.new(self, world_state)
	_agriculture_service = AgricultureService.new(self, world_state)
	
	# Create the RefCounted Chunk Manager Service (Not a Node, do not call add_child)
	chunk_manager = ChunkManagerService.new(self, world_state)
	persistence_service = WorldPersistenceService.new(repository)
	
	# Reset and initialize the campaign dynamically on World load
	CampaignRegistry.initialize_campaign()
	
	# Attempt to load saved global game parameters from the repository
	var saved_global: Dictionary = repository.load_global_state() as Dictionary
	var active_seed: int
	var spawn_pos: Vector3 = Vector3(8.5, 14.0, 8.5)
	var spawn_rot: Vector3 = Vector3.ZERO
	
	# Celestial restoration parameters
	var current_time := 0.5
	var calendar_days := 14 # Start at day 14 (Full Moon) for immediate visual feedback!
	
	if saved_global.has("seed"):
		_is_restored_save = true # Mark as active save to protect Y coordinates on load
		active_seed = saved_global["seed"] as int
		if saved_global.has("player_pos"): 
			spawn_pos = saved_global["player_pos"] as Vector3
		if saved_global.has("player_rot"): 
			spawn_rot = saved_global["player_rot"] as Vector3
		if saved_global.has("inventory"): 
			_loaded_inventory_data = saved_global["inventory"] as Array
			
		# Restore celestial timeline
		if saved_global.has("celestial_time"):
			current_time = float(saved_global["celestial_time"])
		if saved_global.has("calendar_day"):
			calendar_days = int(saved_global["calendar_day"])
			
		# Restore campaign quest progression cleanly
		if saved_global.has("active_quest_id"):
			var saved_q_id: String = saved_global["active_quest_id"] as String
			if saved_q_id == "COMPLETED": 
				QuestService.clear_active_quest()
			elif saved_q_id != "":
				QuestService.set_active_quest(saved_q_id)
	else:
		_is_restored_save = false
		randomize()
		active_seed = randi()
		
	generator = WorldGenerator.new(active_seed)
	
	# Injects loaded parameters into global singletons
	var celestial := CelestialService.instance
	if is_instance_valid(celestial):
		celestial.set("_current_time", current_time)
		celestial.set("_calendar_days", calendar_days)
			
	_target_spawn_chunk_pos = world_state.global_to_chunk_pos(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
	
	if is_instance_valid(player):
		player.position = spawn_pos
		player.rotation = spawn_rot
		
		# Deserialize player inventory safely
		var inv := player.get("inventory") as InventoryComponent
		if is_instance_valid(inv) and _loaded_inventory_data.size() > 0:
			inv.deserialize_data(_loaded_inventory_data)
			
	# Disable real-time physics until spawn chunks are built and populated
	_is_startup_phase = true
	ChunkLoaderService.global_view_distance = 1 


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	if not player.get("is_active") and (_is_startup_phase or is_teleport_spawn):
		check_player_spawn_activation()
		
	# 1. Agriculture Tick
	if is_instance_valid(_agriculture_service):
		_agriculture_service.process_agriculture_ticks(delta)
	
	# 2. World and Visibility Updates (Throttled)
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_process_dynamic_world()
		_process_day_night_lighting()
		
	# 3. Main-Thread Rendering Queue dispatching (Dynamic frame-pacing)
	if is_instance_valid(chunk_manager):
		chunk_manager.process_frame_queues(delta)


## Clears requests and blocks the main thread on exit until background thread workers have finished safely
func _exit_tree() -> void:
	if is_instance_valid(chunk_manager):
		chunk_manager.shutdown()


## Calculates coordinates to request chunk loads/unloads and triggers proximity spawning
func _process_dynamic_world() -> void:
	var look_dir := -player.transform.basis.z.normalized()
	if is_instance_valid(player):
		var camera_node: Camera3D = player.get("camera") as Camera3D
		if is_instance_valid(camera_node):
			look_dir = -camera_node.global_transform.basis.z.normalized()
			
	var task := loader_service.check_viewer_position(player.global_position, look_dir, world_state)
	
	if is_instance_valid(chunk_manager):
		chunk_manager.queue_unloads(task.to_unload)
		
		# Only update the horizon queue if the loader detected movement or changes
		if not task.to_load.is_empty():
			chunk_manager.queue_loads(task.to_load)
			
		chunk_manager.spawn_entities_by_proximity(player.global_position)


## Coordinates dynamic streetlight updates on day/night transitions
func _process_day_night_lighting() -> void:
	var is_night: bool = CelestialService.is_night_time_static()
	if is_instance_valid(_streetlight_service):
		_streetlight_service.update_streetlights_state(is_night)


# ==============================================================================
# COORDINATION DELEGATION APIS (DIP/SRP Compliant)
# ==============================================================================

## Proxy getter to satisfy external systems without violating SRP
func get_active_chunk_nodes() -> Dictionary:
	if is_instance_valid(chunk_manager):
		return chunk_manager.get_active_nodes()
	return {}


## Places or breaks a block globally and delegates fast asynchronous redraw queues
func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	if is_instance_valid(chunk_manager):
		chunk_manager.set_block_globally(global_pos, type)


## Triggers the global save sequence via WorldPersistenceService
func save_all() -> void:
	if is_instance_valid(persistence_service):
		persistence_service.save_game(player, world_state)


## Proxy helper allowing ChunkManager to trigger procedural entity spawning (mobs + props)
## SOLID SRP COMPLIANCE: Gathers and merges both living beings and scenery decorations.
func spawn_entities_for_chunk(chunk: Chunk) -> Array[Node]:
	var spawned_nodes: Array[Node] = []
	
	if is_instance_valid(_mob_spawning_service):
		spawned_nodes.append_array(_mob_spawning_service.spawn_mobs_for_chunk(chunk, self, world_state))
		
	if is_instance_valid(_prop_spawning_service):
		spawned_nodes.append_array(_prop_spawning_service.spawn_props_for_chunk(chunk, self, world_state))
		
	return spawned_nodes


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
		if is_instance_valid(chunk_manager):
			var _all_rendered: bool = true
			
			for x in range(-1, 2):
				for z in range(-1, 2):
					var pos_0 := Vector3i(_target_spawn_chunk_pos.x + x, 0, _target_spawn_chunk_pos.z + z)
					var pos_1 := Vector3i(_target_spawn_chunk_pos.x + x, 1, _target_spawn_chunk_pos.z + z)
					
					if not chunk_manager.is_chunk_rendered(pos_0) or not chunk_manager.is_chunk_rendered(pos_1):
						_all_rendered = false
						break
				if not _all_rendered:
					break
					
			if _all_rendered:
				_activate_player_spawn()


## Safely positions the player on the topmost solid block at spawn coordinates using Domain Rules
func _activate_player_spawn() -> void:
	if not _is_restored_save or is_teleport_spawn:
		is_teleport_spawn = false # Reset the trigger flag
		
		var block_x: int = floori(player.position.x)
		var block_z: int = floori(player.position.z)
		var found_safe_y: float = 14.0 # Fallback
		
		if is_instance_valid(world_state):
			found_safe_y = world_state.get_highest_solid_y(block_x, block_z)
			
		player.position.y = found_safe_y
		
	_restore_player_inventory()
	player.set("is_active", true)
	player.velocity = Vector3.ZERO
	
	if is_instance_valid(chunk_manager):
		chunk_manager.spawn_entities_by_proximity(player.global_position)
		
	if _is_startup_phase:
		_is_startup_phase = false
		var settings: Dictionary = SettingsRepository.load_settings() as Dictionary
		var target_distance: int = 8 # Default
		if settings.has("render_distance"):
			target_distance = int(settings["render_distance"])
		
		ChunkLoaderService.global_view_distance = target_distance


## Deserializes cached backpack quantities back into the player's inventory
func _restore_player_inventory() -> void:
	if _loaded_inventory_data.size() > 0 and is_instance_valid(player):
		var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			inventory.deserialize_data(_loaded_inventory_data)


func _setup_persistence() -> void:
	pass


## Triggers high-priority spawn area loads exactly once upon teleportation
func _trigger_prioritized_spawn_loads() -> void:
	if is_instance_valid(chunk_manager):
		var target_spawn_chunks: Array[Vector3i] = []
		for x in range(-1, 2):
			for z in range(-1, 2):
				target_spawn_chunks.append(Vector3i(_target_spawn_chunk_pos.x + x, 0, _target_spawn_chunk_pos.z + z))
				target_spawn_chunks.append(Vector3i(_target_spawn_chunk_pos.x + x, 1, _target_spawn_chunk_pos.z + z))
		
		chunk_manager.queue_prioritized_loads(target_spawn_chunks)


# ==============================================================================
# ADAPTER PATTERN: Inner class implementing the Domain IWorldModifier contract.
#                  This decouples Domain layer strategies from the SceneTree-dependent 
#                  WorldController class, resolving the DIP violation.
# ==============================================================================
class WorldModifierAdapter:
	extends IWorldModifier
	
	var _controller: WorldController
	var last_hit_fractional_y: float = 0.5
	
	func _init(controller: WorldController) -> void:
		_controller = controller
		
	func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
		if is_instance_valid(_controller):
			_controller.set_block_globally(global_pos, type)


	func get_block_globally(global_pos: Vector3i) -> BlockType.Type:
		if is_instance_valid(_controller) and is_instance_valid(_controller.world_state):
			return _controller.world_state.get_block(global_pos)
		return BlockType.Type.AIR


	func get_last_hit_fractional_y() -> float:
		return last_hit_fractional_y
