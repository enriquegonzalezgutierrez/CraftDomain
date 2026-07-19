# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCAIComponent.gd
# Description: Infrastructure NPC Sensory AI Brain. Coordinates task schedules,
#              social gossip, and organic curved pathfinding.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly task states
#   and sensors, delegating steering and kinematics to specialized services.
# - SOLID OCP: Uses the new block model property is_liquid and is_air to perform 
#   boundary checks, eliminating hardcoded block ID lists.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NPCAIComponent
extends Node

enum TaskState {
	IDLE,       
	WANDERING,  
	EXAMINING,  
	GREETING,   
	CHATTIING,  
	PANIC,      
	WORKING     
}

@export var active_behavior: IAIBehavior

var current_task: TaskState = TaskState.IDLE
var wander_direction: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var task_timer: float = 0.0
var social_cooldown: float = 0.0

var is_manual_override: bool = false

var SIGHT_RANGE_SQ: float = 64.0
var SOCIAL_RANGE_SQ: float = 9.0
var GREET_DISTANCE_SQ: float = 12.25
const SOCIAL_COOLDOWN_INTERVAL: float = 8.0

var _active_path: Array[Vector3] = []
var _current_path_index: int = 0

var _host: CharacterBody3D
var _nav_service: Object 
var _ai_timer_accum: float = 0.0
var _ai_tick_rate: float = 0.25 

var _steering_component: NPCObstacleSteering
var _last_pos_for_stuck: Vector3 = Vector3.ZERO


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	_ai_timer_accum = randf_range(0.0, _ai_tick_rate)
	_setup_steering_component()


func _setup_steering_component() -> void:
	_steering_component = NPCObstacleSteering.new()
	add_child(_steering_component)
	_steering_component.initialize(_host, self)


## Refactored Loop: Separates desires, steering, and physical execution
func process_ai(delta: float) -> void:
	if not is_instance_valid(_host) or _host.domain_entity.is_dead: return
		
	if is_instance_valid(AITelemetryService.instance):
		AITelemetryService.instance.process_telemetry_flush(delta)
		
	_calculate_base_desired_direction(delta)
	
	if is_instance_valid(_steering_component):
		_steering_component.process_steering(delta)
		
	_apply_movement_vectors(delta)


func _calculate_base_desired_direction(delta: float) -> void:
	if is_manual_override:
		return
		
	_ai_timer_accum += delta
	if _ai_timer_accum >= _ai_tick_rate:
		_ai_timer_accum = 0.0
		_execute_throttled_ai_tick()


func _execute_throttled_ai_tick() -> void:
	_locate_navigation_service_if_missing()
	
	if current_task == TaskState.WANDERING and _active_path.size() > 0:
		_navigate_along_active_path_no_velocity()
	
	var has_override: bool = _evaluate_active_behavior()
	if not has_override:
		_process_fallback_village_routines()


func _evaluate_active_behavior() -> bool:
	if active_behavior != null:
		active_behavior.evaluate_and_execute(_host, _ai_tick_rate)
		return active_behavior.get("overrides_wandering") == true
	return false


func _process_fallback_village_routines() -> void:
	if task_timer <= 0.0: _select_next_random_task()
		
	if _check_sensory_threats(): return
	if _check_environmental_schedules(): return
	_check_social_interactions()


func _check_sensory_threats() -> bool:
	var closest_hostile: Node3D = _detect_closest_zombie_threat()
	if closest_hostile != null:
		var escape_dir: Vector3 = (_host.global_position - closest_hostile.global_position).normalized()
		escape_dir.y = 0.0
		if _is_direction_safe(escape_dir):
			current_task = TaskState.PANIC
			_active_path.clear() 
			wander_direction = escape_dir
			task_timer = 2.5 
			stuck_timer = 0.0
			return true
	return false


func _check_environmental_schedules() -> bool:
	var is_night: bool = CelestialService.is_night_time_static()
	var is_storming: bool = _is_weather_storming()
			
	var can_take_shelter: bool = _host.call("can_take_shelter") as bool if _host.has_method("can_take_shelter") else false
	if (is_night or is_storming) and can_take_shelter:
		_seek_shelter_routine()
		return true
	return false


func _is_weather_storming() -> bool:
	var world_node: Node = _host.get_parent()
	if is_instance_valid(world_node):
		var weather_node: Node = world_node.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node) and weather_node.get("current_weather") != null:
			var w_type: int = int(weather_node.get("current_weather"))
			return (w_type == 1 or w_type == 2)
	return false


func _check_social_interactions() -> bool:
	var can_socialize: bool = _host.has_method("_can_socialize") and _host.call("_can_socialize") as bool
	if not can_socialize or social_cooldown > 0.0 or current_task == TaskState.PANIC:
		return false
		
	if _greet_nearby_player(): return true
	return _chat_with_nearby_peer()


func _get_player_node() -> Node3D:
	var world_node: Node = _host.get_parent()
	if is_instance_valid(world_node):
		return world_node.get_node_or_null("Player") as Node3D
	return null


func _greet_nearby_player() -> bool:
	var player_node: Node3D = _get_player_node()
	if is_instance_valid(player_node):
		var dist_p_sq: float = _host.global_position.distance_squared_to(player_node.global_position)
		if dist_p_sq <= GREET_DISTANCE_SQ: 
			_transition_to_task(TaskState.GREETING, (player_node.global_position - _host.global_position).normalized())
			return true
	return false


func _chat_with_nearby_peer() -> bool:
	var closest_peer: Node3D = _detect_closest_peer_npc()
	if closest_peer != null and randf() < 0.15:
		_transition_to_task(TaskState.CHATTIING, (closest_peer.global_position - _host.global_position).normalized())
		return true
	return false


func _transition_to_task(task: TaskState, look_dir: Vector3) -> void:
	current_task = task
	_active_path.clear()
	look_dir.y = 0.0
	if look_dir != Vector3.ZERO: wander_direction = look_dir
	task_timer = randf_range(2.0, 4.0)
	social_cooldown = SOCIAL_COOLDOWN_INTERVAL


func _apply_movement_vectors(delta: float) -> void:
	var base_speed: float = 1.3
	if "BASE_SPEED" in _host: base_speed = _host.get("BASE_SPEED")
		
	match current_task:
		TaskState.IDLE, TaskState.GREETING, TaskState.CHATTIING:
			_host.velocity.x = move_toward(_host.velocity.x, 0.0, base_speed)
			_host.velocity.z = move_toward(_host.velocity.z, 0.0, base_speed)
			stuck_timer = 0.0
		TaskState.EXAMINING:
			_host.velocity.x = wander_direction.x * (base_speed * 0.25)
			_host.velocity.z = wander_direction.z * (base_speed * 0.25)
			stuck_timer = 0.0
		TaskState.WANDERING, TaskState.PANIC:
			_execute_linear_or_sway_walk(base_speed, delta)


func _execute_linear_or_sway_walk(base_speed: float, delta: float) -> void:
	var final_dir := wander_direction
	
	if not _is_navigating_path_local() and current_task == TaskState.WANDERING:
		var elapsed := float(Time.get_ticks_msec()) / 1000.0
		var seed_val := float(_host.npc_seed) * 0.12
		var sway_angle := sin(elapsed * 1.5 + seed_val) * 0.22 
		final_dir = wander_direction.rotated(Vector3.UP, sway_angle).normalized()
		
	var speed_mult: float = 2.8 if current_task == TaskState.PANIC else 1.0
	_host.velocity.x = final_dir.x * base_speed * speed_mult
	_host.velocity.z = final_dir.z * base_speed * speed_mult
	
	_evaluate_stuck_state(delta)
	_keep_gaze_within_tether()


func _is_navigating_path_local() -> bool:
	if _host.has_meta("guard_active_path"):
		var path: Array = _host.get_meta("guard_active_path") as Array
		return not path.is_empty()
	if _host.has_meta("villager_active_path"):
		var path: Array = _host.get_meta("villager_active_path") as Array
		return not path.is_empty()
	return _active_path.size() > 0


func _evaluate_stuck_state(delta: float) -> void:
	var is_trying_to_move := wander_direction.length_squared() > 0.05
	
	if _last_pos_for_stuck == Vector3.ZERO:
		_last_pos_for_stuck = _host.global_position
		
	# DDD Collision Avoidance: Check actual displacement over the AI tick step
	var dist_moved := _host.global_position.distance_to(_last_pos_for_stuck)
	_last_pos_for_stuck = _host.global_position
	
	if is_trying_to_move and dist_moved < 0.04 and _host.is_on_floor():
		stuck_timer += delta
		if stuck_timer >= 1.0: 
			_resolve_stuck_state()
	else:
		stuck_timer = 0.0


func _resolve_stuck_state() -> void:
	_active_path.clear()
	_current_path_index = 0
	
	var reverse_dir := -wander_direction.normalized()
	reverse_dir = reverse_dir.rotated(Vector3.UP, randf_range(-0.8, 0.8)).normalized()
	
	wander_direction = reverse_dir
	current_task = TaskState.WANDERING
	task_timer = randf_range(1.5, 3.5)
	stuck_timer = 0.0
	
	_host.velocity.y = 4.0


## Decoupled: Pathfinder ONLY calculates direction, never writes directly to velocity
func _navigate_along_active_path_no_velocity() -> void:
	if _current_path_index < _active_path.size():
		var target_node: Vector3 = _active_path[_current_path_index]
		var diff: Vector3 = target_node - _host.global_position
		diff.y = 0.0 
		if diff.length_squared() < 0.16:
			_current_path_index += 1
			return
		wander_direction = diff.normalized()
	else:
		_halt_pathfinding_task()


func _halt_pathfinding_task() -> void:
	_active_path.clear()
	current_task = TaskState.IDLE
	task_timer = randf_range(0.4, 1.2)
	_host.velocity.x = 0.0
	_host.velocity.z = 0.0
	stuck_timer = 0.0


func _keep_gaze_within_tether() -> void:
	if _host.has_method("_has_ui_decorations") and _host.call("_has_ui_decorations") as bool:
		var spawn_pt: Vector3 = _host.get("_spawn_point") if "_spawn_point" in _host else _host.global_position
		if _host.global_position.distance_squared_to(spawn_pt) > 144.0: 
			_active_path.clear()
			wander_direction = (spawn_pt - _host.global_position).normalized()
			wander_direction.y = 0.0


func _select_next_random_task() -> void:
	var roll: float = randf()
	if roll < 0.70:
		_start_random_wander_task()
	elif roll < 0.85:
		_start_examine_task()
	else:
		_start_idle_task()


func _start_random_wander_task() -> void:
	current_task = TaskState.WANDERING
	_active_path.clear()
	if is_instance_valid(_nav_service) and _nav_service.has_method("find_path"):
		var target_pos: Vector3 = _host.global_position + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
		var path: Array = _nav_service.call("find_path", _host.global_position, target_pos) as Array
		if path.size() > 1:
			_load_navigation_path(path)
			return
	var angle: float = randf() * TAU
	wander_direction = Vector3(cos(angle), 0, sin(angle))
	task_timer = randf_range(3.0, 7.0)


func _load_navigation_path(path: Array) -> void:
	_active_path.clear()
	for node: Vector3 in path: _active_path.append(node)
	_current_path_index = 0
	task_timer = randf_range(5.0, 10.0)


func _start_examine_task() -> void:
	current_task = TaskState.EXAMINING 
	_active_path.clear()
	var angle: float = randf() * TAU
	wander_direction = Vector3(cos(angle), 0, sin(angle))
	task_timer = randf_range(1.0, 2.5)


func _start_idle_task() -> void:
	current_task = TaskState.IDLE
	_active_path.clear()
	task_timer = randf_range(0.4, 1.2)


func _seek_shelter_routine() -> void:
	if current_task == TaskState.IDLE and _active_path.is_empty() and _is_inside_valid_shelter():
		return
		
	if not _active_path.is_empty() and current_task == TaskState.WANDERING:
		return 
		
	_route_to_closest_shelter()


func _is_inside_valid_shelter() -> bool:
	var my_coord: Vector3i = Vector3i(floori(_host.global_position.x), floori(_host.global_position.y), floori(_host.global_position.z))
	if is_instance_valid(_nav_service) and "_indoor_nodes" in _nav_service:
		var indoor_nodes: Array = _nav_service.get("_indoor_nodes") as Array
		return indoor_nodes.has(my_coord)
	return false


func _route_to_closest_shelter() -> void:
	if is_instance_valid(_nav_service) and _nav_service.has_method("find_closest_shadow_shelter"):
		var shelter_pos: Vector3 = _nav_service.call("find_closest_shadow_shelter", _host.global_position) as Vector3
		if pointer_to_null_safeguard(shelter_pos) != Vector3.ZERO:
			var path: Array = _nav_service.call("find_path", _host.global_position, shelter_pos) as Array
			if path.size() > 1:
				_load_shelter_path(path)
				return
	current_task = TaskState.IDLE
	_active_path.clear()
	task_timer = randf_range(1.5, 3.0)


func pointer_to_null_safeguard(pos: Vector3) -> Vector3:
	return pos


func _load_shelter_path(path: Array) -> void:
	_active_path.clear()
	for node: Vector3 in path: _active_path.append(node)
	_current_path_index = 0
	current_task = TaskState.WANDERING
	task_timer = 15.0


func _is_direction_safe(dir: Vector3) -> bool:
	if not is_instance_valid(_host): return false
	var world_node: Node = _host.get_parent()
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.world_state
	if ws == null: return true
		
	var check_pos: Vector3 = _host.global_position + dir * 1.5
	var block_at_coord: Vector3i = Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	if BlockType.is_solid(ws.get_block(block_at_coord)): return false
	return _evaluate_habitat_safety(ws, check_pos)


func _evaluate_habitat_safety(ws: WorldState, check_pos: Vector3) -> bool:
	var block_below_coord: Vector3i = Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord: Vector3i = Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	var block_below: BlockType.Type = ws.get_block(block_below_coord)
	var block_at: BlockType.Type = ws.get_block(block_at_coord)
	
	var def_below := BlockLibrary.get_definition(block_below)
	var is_below_liquid := def_below != null and def_below.is_liquid
	
	if _host.has_method("_is_block_type_habitable"):
		var is_feet_safe: bool = _host.call("_is_block_type_habitable", block_at) as bool
		var is_below_safe: bool = _host.call("_is_block_type_habitable", block_below) as bool
		
		var habitat: int = _host.get("entity_habitat") if "entity_habitat" in _host else 0
		if habitat == 0:
			return _check_terrestrial_void_safety(ws, block_below_coord, block_below)
		return is_feet_safe or is_below_safe
	return true


func _check_terrestrial_void_safety(ws: WorldState, block_below_coord: Vector3i, block_below: BlockType.Type) -> bool:
	var def_below := BlockLibrary.get_definition(block_below)
	var is_below_liquid := def_below != null and def_below.is_liquid
	var is_below_air := def_below != null and def_below.is_air
	
	if is_below_liquid: return false
	
	if is_below_air:
		var block_2_below: BlockType.Type = ws.get_block(block_below_coord + Vector3i(0, -1, 0))
		return BlockType.is_solid(block_2_below)
	return true


func _detect_closest_zombie_threat() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree(): return null
	
	var closest_zombie: Node3D = null
	var min_dist_sq: float = SIGHT_RANGE_SQ
	var hostiles: Array = _host.get_tree().get_nodes_in_group("hostiles")
	var host_pos: Vector3 = _host.global_position
	
	for child: Node in hostiles:
		if child == _host or not is_instance_valid(child): continue
		var zombie_entity: VoxelEntity = child.get("domain_entity") as VoxelEntity
		if zombie_entity != null and not zombie_entity.is_dead:
			var dist_sq: float = host_pos.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_zombie = child as Node3D
	return closest_zombie


func _detect_closest_peer_npc() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree(): return null
	
	var passives: Array = _host.get_tree().get_nodes_in_group("passives")
	var closest: Node3D = null
	var min_dist_sq: float = SOCIAL_RANGE_SQ
	var host_pos: Vector3 = _host.global_position
	
	for child: Node in passives:
		if child == _host or not is_instance_valid(child): continue
		if _is_peer_available_for_social(child):
			var dist_sq: float = host_pos.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest = child as Node3D
	return closest


func _is_peer_available_for_social(child: Node) -> bool:
	var ai_comp: NPCAIComponent = child.get_node_or_null("NPCAIComponent") as NPCAIComponent
	if is_instance_valid(ai_comp):
		var peer_state: TaskState = ai_comp.current_task as TaskState
		return peer_state == TaskState.IDLE or peer_state == TaskState.CHATTIING
	return false


func _locate_navigation_service_if_missing() -> void:
	if _nav_service == null and is_instance_valid(_host):
		var parent: Node = _host.get_parent()
		if is_instance_valid(parent) and "navigation_service" in parent:
			_nav_service = parent.get("navigation_service")


func _dispatch_active_telemetry() -> void:
	if is_instance_valid(AITelemetryService.instance) and is_instance_valid(_host):
		var active_task_name: String = "IDLE"
		if active_behavior != null and active_behavior.has_method("get_active_state_name"):
			active_task_name = str(active_behavior.call("get_active_state_name", _host))
		else:
			active_task_name = _get_task_state_name(current_task as int)
			
		var waypoints_left: int = _active_path.size() - _current_path_index if _active_path.size() > 0 else 0
		var lookup_key: String = active_task_name
		if lookup_key == "WANDERING": lookup_key = "WANDER"
		elif lookup_key == "CHATTING": lookup_key = "CHAT"
		
		AITelemetryService.log_movement(
			_host.name, _host.global_position, _host.velocity, wander_direction,
			tr("SHOWCASE_TASK_" + lookup_key).to_upper(), _host.is_on_wall(), _host.is_on_floor(), waypoints_left
		)


func _get_task_state_name(task_val: int) -> String:
	var names: Array[String] = ["IDLE", "WANDERING", "EXAMINING", "GREETING", "CHATTING", "PANIC", "WORKING"]
	if task_val >= 0 and task_val < names.size(): return names[task_val]
	return "IDLE"


## Forces the AI component into a manual task state, disabling automated schedules
func force_manual_task(task_state_id: int) -> void:
	is_manual_override = true
	current_task = task_state_id as TaskState
	_active_path.clear()
	
	if current_task == TaskState.WANDERING or current_task == TaskState.PANIC or current_task == TaskState.EXAMINING:
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	else:
		wander_direction = Vector3.ZERO


## Restores the entity's autonomy, returning it to standard procedural AI behaviors
func disable_manual_override() -> void:
	is_manual_override = false
	current_task = TaskState.IDLE
	wander_direction = Vector3.ZERO
	task_timer = 0.0
