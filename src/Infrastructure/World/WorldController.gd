# ==============================================================================
# Pathfile: res://src/Infrastructure/World/WorldController.gd
# Description: Central World Controller orchestrating sub-services, timeline warps,
#              chunk lifecycles, and real-time voxel navigation updates.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WorldController
extends Node3D

signal block_modified(global_pos: Vector3i, type: BlockType.Type)

var world_state: WorldState
var generator: WorldGenerator
var loader_service: ChunkLoaderService
var navigation_service: VoxelNavigationService
var repository: WorldRepository
var player: CharacterBody3D
var world_modifier: IWorldModifier

var chunk_lifecycle: ChunkLifecycleService
var persistence_service: WorldPersistenceService
var structural_service: StructuralIntegrityService
var _mob_spawning_service: MobSpawningService
var _prop_spawning_service: PropSpawningService
var _streetlight_service: StreetlightService
var _agriculture_service: AgricultureService
var _fluid_service: FluidSimulationService

var network_spawner: NetworkSpawnerService
var voxel_replicator: VoxelReplicator

var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2

var _target_spawn_chunk_pos: Vector3i = Vector3i.ZERO:
	set(val):
		_target_spawn_chunk_pos = val
		if is_teleport_spawn: _trigger_prioritized_spawn_loads()

var _is_restored_save: bool = false
var _is_startup_phase: bool = true
var is_teleport_spawn: bool = false
var _loaded_inventory_data: Array = []
var _interactive_props: Array[Node3D] = []


func _ready() -> void:
	assert(repository != null, "[WorldController] Fatal: WorldRepository missing!")
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)
	_initialize_world_services()


func _on_child_entered_tree(node: Node) -> void:
	if node is Node3D and _is_unsupported_prop_type(node):
		_interactive_props.append(node)


func _on_child_exiting_tree(node: Node) -> void:
	if node is Node3D and _interactive_props.has(node):
		_interactive_props.erase(node)


func _initialize_world_services() -> void:
	world_state = WorldState.new()
	loader_service = ChunkLoaderService.new()
	navigation_service = VoxelNavigationService.new()
	world_modifier = WorldModifierAdapter.new(self)
	
	_instantiate_domain_sub_services()
	_instantiate_infrastructure_nodes()
	
	CampaignRegistry.initialize_campaign()
	_load_and_restore_global_save()


func _instantiate_domain_sub_services() -> void:
	_mob_spawning_service = MobSpawningService.new()
	_prop_spawning_service = PropSpawningService.new()
	_streetlight_service = StreetlightService.new(self, world_state)
	_agriculture_service = AgricultureService.new(self, world_state)
	_fluid_service = FluidSimulationService.new(self, world_state)
	
	block_modified.connect(_fluid_service._on_block_modified)
	block_modified.connect(_on_block_modified_navigation)


func _instantiate_infrastructure_nodes() -> void:
	chunk_lifecycle = ChunkLifecycleService.new(self, world_state)
	persistence_service = WorldPersistenceService.new(repository)
	
	structural_service = StructuralIntegrityService.new()
	structural_service.name = "StructuralIntegrityService"
	add_child(structural_service)
	structural_service.initialize(self, world_state)
	
	network_spawner = NetworkSpawnerService.new()
	network_spawner.name = "NetworkSpawnerService"
	add_child(network_spawner)
	network_spawner.initialize(self, world_state)
	
	voxel_replicator = VoxelReplicator.new()
	voxel_replicator.name = "VoxelReplicator"
	add_child(voxel_replicator)
	voxel_replicator.initialize(self, world_state)


func _load_and_restore_global_save() -> void:
	var saved_global := repository.load_global_state() as Dictionary
	if saved_global.has("seed"):
		_restore_saved_global_state(saved_global)
	else:
		generator = WorldGenerator.new(42)
		_target_spawn_chunk_pos = world_state.global_to_chunk_pos(Vector3i(8, 0, 8))
		
	_is_startup_phase = true
	ChunkLoaderService.global_view_distance = 1


func _restore_saved_global_state(saved_global: Dictionary) -> void:
	_is_restored_save = true
	var active_seed: int = saved_global.get("seed", 42)
	var spawn_pos: Vector3 = saved_global.get("player_pos", Vector3(8.5, 14.0, 8.5))
	var spawn_rot: Vector3 = saved_global.get("player_rot", Vector3.ZERO)
	
	_loaded_inventory_data = saved_global.get("inventory", []) as Array
	generator = WorldGenerator.new(active_seed)
	
	_apply_saved_celestial_and_quest_state(saved_global)
	_target_spawn_chunk_pos = world_state.global_to_chunk_pos(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
	
	if is_instance_valid(player):
		player.position = spawn_pos
		player.rotation = spawn_rot


func _apply_saved_celestial_and_quest_state(saved_global: Dictionary) -> void:
	if is_instance_valid(CelestialService.instance):
		CelestialService.instance.set("_current_time", float(saved_global.get("celestial_time", 0.5)))
		CelestialService.instance.set("_calendar_days", int(saved_global.get("calendar_day", 14)))
		
	var q_id: String = saved_global.get("active_quest_id", "") as String
	if q_id == "COMPLETED": QuestService.clear_active_quest()
	elif q_id != "": QuestService.set_active_quest(q_id)


func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	if not player.get("is_active") as bool and (_is_startup_phase or is_teleport_spawn):
		check_player_spawn_activation()
		
	if is_instance_valid(_agriculture_service): _agriculture_service.process_agriculture_ticks(delta)
	if is_instance_valid(_fluid_service): _fluid_service.process_fluid_simulation(delta)
	if is_instance_valid(chunk_lifecycle):
		chunk_lifecycle.process_frame_queues(player.get("is_active") as bool if is_instance_valid(player) else false)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_process_dynamic_world() 
		_process_day_night_lighting()


func _exit_tree() -> void:
	if is_instance_valid(chunk_lifecycle):
		chunk_lifecycle.shutdown()


func _process_dynamic_world() -> void:
	var look_dir := -player.transform.basis.z.normalized()
	if is_instance_valid(player):
		var camera_node: Camera3D = player.get("camera") as Camera3D
		if is_instance_valid(camera_node):
			look_dir = -camera_node.global_transform.basis.z.normalized()
			
	var task := loader_service.check_viewer_position(player.global_position, look_dir, world_state)
	if is_instance_valid(chunk_lifecycle):
		chunk_lifecycle.queue_unloads(task.to_unload)
		if not task.to_load.is_empty(): chunk_lifecycle.queue_loads(task.to_load)
		chunk_lifecycle.spawn_entities_by_proximity(player.global_position)


func _process_day_night_lighting() -> void:
	if is_instance_valid(_streetlight_service):
		_streetlight_service.update_streetlights_state(CelestialService.is_night_time_static())


func get_active_chunk_nodes() -> Dictionary:
	return chunk_lifecycle.get_active_nodes() if is_instance_valid(chunk_lifecycle) else {}


func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
	if is_instance_valid(chunk_lifecycle): chunk_lifecycle.set_block_globally(global_pos, type)
	_apply_procedural_gravity_on_block_broken(global_pos, type)
	block_modified.emit(global_pos, type)


func set_block_globally_async(global_pos: Vector3i, type: BlockType.Type) -> void:
	if is_instance_valid(chunk_lifecycle): chunk_lifecycle.set_block_globally_async(global_pos, type)
	_apply_procedural_gravity_on_block_broken(global_pos, type)
	block_modified.emit(global_pos, type)


func _apply_procedural_gravity_on_block_broken(global_pos: Vector3i, type: BlockType.Type) -> void:
	if type == BlockType.Type.AIR:
		_check_and_resolve_floating_props(global_pos)


func _check_and_resolve_floating_props(mined_pos: Vector3i) -> void:
	for prop_node: Node3D in _interactive_props:
		if is_instance_valid(prop_node) and _is_prop_at_coord(prop_node, mined_pos):
			_resolve_unsupported_prop(prop_node)


func _is_prop_at_coord(prop_node: Node3D, mined_pos: Vector3i) -> bool:
	var c_pos := prop_node.global_position
	var match_x := floori(c_pos.x) == mined_pos.x
	var match_z := floori(c_pos.z) == mined_pos.z
	var match_y := absf(c_pos.y - (float(mined_pos.y) + 1.0)) <= 0.4
	return match_x and match_z and match_y


func _is_unsupported_prop_type(node: Node) -> bool:
	return node is BarrelEntity or node is ChestEntity or node is CampfireEntity or node is WishingWellEntity or node is StreetlightEntity or node is VegetationProp


func _resolve_unsupported_prop(prop: Node3D) -> void:
	if prop is BarrelEntity or prop is ChestEntity or prop is CampfireEntity:
		if prop.has_method("interact") and is_instance_valid(player):
			prop.call("interact", player)
	else:
		var target_y := world_state.get_highest_solid_y(floori(prop.global_position.x), floori(prop.global_position.z)) - 1.0
		var tween := create_tween()
		tween.tween_property(prop, "global_position:y", target_y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(func() -> void: _play_prop_impact_sound(prop))


func _play_prop_impact_sound(prop: Node3D) -> void:
	if is_instance_valid(prop):
		var sound := "footstep_grass" if prop is VegetationProp else "footstep_stone"
		AudioService.play_sfx_static(sound, prop.global_position)


func save_all() -> void:
	if is_instance_valid(persistence_service):
		persistence_service.save_game(player, world_state)


func spawn_entities_for_chunk(chunk: Chunk) -> Array[Node]:
	var spawned_nodes: Array[Node] = []
	if _mob_spawning_service != null: spawned_nodes.append_array(_mob_spawning_service.spawn_mobs_for_chunk(chunk, self, world_state))
	if _prop_spawning_service != null: spawned_nodes.append_array(_prop_spawning_service.spawn_props_for_chunk(chunk, self, world_state))
	return spawned_nodes


func check_player_spawn_activation() -> void:
	if not (_is_startup_phase or is_teleport_spawn): return
	if is_instance_valid(player) and not player.get("is_active") as bool and _are_spawn_chunks_rendered():
		_activate_player_spawn()


func _are_spawn_chunks_rendered() -> bool:
	if not is_instance_valid(chunk_lifecycle): return false
	for x in range(-1, 2):
		for z in range(-1, 2):
			var pos_0 := Vector3i(_target_spawn_chunk_pos.x + x, 0, _target_spawn_chunk_pos.z + z)
			var pos_1 := Vector3i(_target_spawn_chunk_pos.x + x, 1, _target_spawn_chunk_pos.z + z)
			if not chunk_lifecycle.is_chunk_rendered(pos_0) or not chunk_lifecycle.is_chunk_rendered(pos_1):
				return false
	return true


func _activate_player_spawn() -> void:
	if not _is_restored_save or is_teleport_spawn:
		is_teleport_spawn = false 
		player.position.y = world_state.get_highest_solid_y(floori(player.position.x), floori(player.position.z))
		
	_restore_player_inventory()
	player.set("is_active", true)
	player.velocity = Vector3.ZERO
	if is_instance_valid(chunk_lifecycle): chunk_lifecycle.spawn_entities_by_proximity(player.global_position)
		
	if _is_startup_phase:
		_is_startup_phase = false
		var settings := SettingsRepository.load_settings() as Dictionary
		ChunkLoaderService.global_view_distance = int(settings.get("render_distance", 8))


func _restore_player_inventory() -> void:
	if _loaded_inventory_data.size() > 0 and is_instance_valid(player):
		var inventory_comp := player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory_comp): inventory_comp.deserialize_data(_loaded_inventory_data)


func _trigger_prioritized_spawn_loads() -> void:
	if is_instance_valid(chunk_lifecycle):
		var target_spawn_chunks: Array[Vector3i] = []
		for x in range(-1, 2):
			for z in range(-1, 2):
				target_spawn_chunks.append(Vector3i(_target_spawn_chunk_pos.x + x, 0, _target_spawn_chunk_pos.z + z))
				target_spawn_chunks.append(Vector3i(_target_spawn_chunk_pos.x + x, 1, _target_spawn_chunk_pos.z + z))
		chunk_lifecycle.queue_prioritized_loads(target_spawn_chunks)


func swap_world_timeline(timeline_val: int) -> void:
	var target := timeline_val as WorldState.Timeline
	if is_instance_valid(world_state):
		world_state.swap_timeline(target)
		is_teleport_spawn = true 
		if is_instance_valid(player):
			player.set("is_active", false)
			player.position.y = world_state.get_highest_solid_y(floori(player.position.x), floori(player.position.z))
			var p_pos := player.global_position
			_target_spawn_chunk_pos = world_state.global_to_chunk_pos(Vector3i(floori(p_pos.x), floori(p_pos.y), floori(p_pos.z)))
			
			var hud_node: PlayerHUD = player.get("hud") as PlayerHUD
			if is_instance_valid(hud_node): hud_node.show_loading_screen()
			AudioService.play_sfx_static("chest_open", p_pos)


func open_hacking_terminal() -> void:
	if is_instance_valid(player):
		var hud_node: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud_node): hud_node.toggle_hacking_terminal(true)


func _on_block_modified_navigation(global_pos: Vector3i, type: BlockType.Type) -> void:
	if is_instance_valid(navigation_service):
		ChunkNavigationBuilder.update_navigation_on_block_modified(global_pos, type, world_state, navigation_service)


# ==============================================================================
# ADAPTER PATTERN: Inner class implementing the Domain IWorldModifier contract.
# ==============================================================================
class WorldModifierAdapter extends IWorldModifier:
	var _controller: Node3D 
	var last_hit_fractional_y: float = 0.5
	
	func _init(controller: Node3D) -> void:
		_controller = controller
		
	func set_block_globally(global_pos: Vector3i, type: BlockType.Type) -> void:
		if is_instance_valid(_controller) and _controller.has_method("set_block_globally"):
			_controller.call("set_block_globally", global_pos, type)

	func get_block_globally(global_pos: Vector3i) -> BlockType.Type:
		if is_instance_valid(_controller):
			var world_state_ref := _controller.get("world_state") as WorldState
			if is_instance_valid(world_state_ref):
				return world_state_ref.get_block(global_pos)
		return BlockType.Type.AIR

	func get_last_hit_fractional_y() -> float:
		return last_hit_fractional_y
		
	func get_active_timeline() -> int:
		if is_instance_valid(_controller):
			var ws := _controller.get("world_state") as WorldState
			if is_instance_valid(ws): return int(ws.active_timeline)
		return 0

	func swap_world_timeline(timeline: int) -> void:
		if is_instance_valid(_controller) and _controller.has_method("swap_world_timeline"):
			_controller.call("swap_world_timeline", timeline)

	func open_hacking_terminal() -> void:
		if is_instance_valid(_controller) and _controller.has_method("open_hacking_terminal"):
			_controller.call("open_hacking_terminal")
