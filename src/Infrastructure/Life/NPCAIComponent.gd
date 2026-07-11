# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCAIComponent.gd
# Description: Infrastructure NPC Sensory AI Brain. Coordinates task schedules,
#              social gossip, and A* pathfinding.
#              Delegates physical obstacle steering to NPCObstacleSteering (SRP).
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

# Decoupled physical steering sub-component
var _steering_component: NPCObstacleSteering


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	_ai_timer_accum = randf_range(0.0, _ai_tick_rate)
	
	_setup_steering_component()


func _setup_steering_component() -> void:
	_steering_component = NPCObstacleSteering.new()
	add_child(_steering_component)
	_steering_component.initialize(_host, self)


## Core processing tick executing decision throttling (4Hz)
func process_ai(delta: float) -> void:
	if not is_instance_valid(_host) or _host.domain_entity.is_dead:
		return
		
	if is_instance_valid(AITelemetryService.instance):
		AITelemetryService.instance.process_telemetry_flush(delta)
		
	# Execute un-throttled physical steering (120Hz)
	if is_instance_valid(_steering_component):
		_steering_component.process_steering(delta)
	
	var has_override := false
	_ai_timer_accum += delta
	if _ai_timer_accum < _ai_tick_rate:
		if active_behavior != null and active_behavior.get("overrides_wandering") == true:
			has_override = true
		if not has_override:
			_apply_movement_vectors()
		return
		
	_ai_timer_accum = 0.0
	_locate_navigation_service_if_missing()
	
	# Execute active behavior strategy (SRP/OCP)
	if active_behavior != null:
		active_behavior.evaluate_and_execute(_host, _ai_tick_rate)
		has_override = active_behavior.get("overrides_wandering") == true

	if not has_override:
		_process_fallback_village_routines()
		_apply_movement_vectors()
		
	_dispatch_active_telemetry()


func _process_fallback_village_routines() -> void:
	if task_timer <= 0.0:
		_select_next_random_task()
		
	if _check_sensory_threats():
		_apply_movement_vectors()
		return
		
	if _check_environmental_schedules():
		_apply_movement_vectors()
		return
		
	if _check_social_interactions():
		_apply_movement_vectors()


func _check_sensory_threats() -> bool:
	var closest_hostile := _detect_closest_zombie_threat()
	if closest_hostile != null:
		var escape_dir := (_host.global_position - closest_hostile.global_position).normalized()
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
	var is_storming := false
	var world_node := _host.get_parent()
	if is_instance_valid(world_node):
		var weather_node := world_node.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node) and weather_node.get("current_weather") != null:
			var w_val := int(weather_node.get("current_weather"))
			is_storming = (w_val == 1 or w_val == 2)
			
	var can_take_shelter: bool = _host.call("can_take_shelter") as bool if _host.has_method("can_take_shelter") else false
	if (is_night or is_storming) and can_take_shelter:
		_seek_shelter_routine()
		return true
	return false


func _check_social_interactions() -> bool:
	var can_socialize: bool = _host.has_method("_can_socialize") and _host.call("_can_socialize") as bool
	if not can_socialize or social_cooldown > 0.0 or current_task == TaskState.PANIC:
		return false
		
	var world_node := _host.get_parent()
	var actual_player: CharacterBody3D = world_node.get_node_or_null("Player") if is_instance_valid(world_node) else null
	if is_instance_valid(actual_player):
		var dist_p_sq := _host.global_position.distance_squared_to(actual_player.global_position)
		if dist_p_sq <= GREET_DISTANCE_SQ: 
			current_task = TaskState.GREETING
			_active_path.clear()
			var look_dir := (actual_player.global_position - _host.global_position).normalized()
			look_dir.y = 0
			if look_dir != Vector3.ZERO: wander_direction = look_dir
			task_timer = randf_range(2.0, 4.0)
			social_cooldown = SOCIAL_COOLDOWN_INTERVAL
			return true
			
	var closest_peer := _detect_closest_peer_npc()
	if closest_peer != null and randf() < 0.15:
		current_task = TaskState.CHATTIING
		_active_path.clear()
		var look_dir := (closest_peer.global_position - _host.global_position).normalized()
		look_dir.y = 0
		if look_dir != Vector3.ZERO: wander_direction = look_dir
		task_timer = randf_range(2.0, 4.0)
		social_cooldown = SOCIAL_COOLDOWN_INTERVAL
		return true
	return false


func _apply_movement_vectors() -> void:
	var base_speed: float = 1.3
	if "BASE_SPEED" in _host:
		base_speed = _host.get("BASE_SPEED")
		
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
			_process_pathfinding_navigation(base_speed)


func _process_pathfinding_navigation(base_speed: float) -> void:
	if current_task == TaskState.WANDERING and _active_path.size() > 0:
		if _current_path_index < _active_path.size():
			var target_node: Vector3 = _active_path[_current_path_index]
			var diff := target_node - _host.global_position
			diff.y = 0.0 
			if diff.length_squared() < 0.16:
				_current_path_index += 1
				_process_pathfinding_navigation(base_speed)
				return
			wander_direction = diff.normalized()
		else:
			_active_path.clear()
			current_task = TaskState.IDLE
			task_timer = randf_range(0.4, 1.2)
			_host.velocity.x = 0.0
			_host.velocity.z = 0.0
			stuck_timer = 0.0
			return
			
	var speed_mult := 2.8 if current_task == TaskState.PANIC else 1.0
	_host.velocity.x = wander_direction.x * base_speed * speed_mult
	_host.velocity.z = wander_direction.z * base_speed * speed_mult
	
	if _host.has_method("_has_ui_decorations") and _host.call("_has_ui_decorations") as bool:
		var spawn_pt: Vector3 = _host.get("_spawn_point") if "_spawn_point" in _host else _host.global_position
		if _host.global_position.distance_squared_to(spawn_pt) > 144.0: 
			_active_path.clear()
			wander_direction = (spawn_pt - _host.global_position).normalized()
			wander_direction.y = 0


func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.70:
		current_task = TaskState.WANDERING
		_active_path.clear()
		if is_instance_valid(_nav_service) and _nav_service.has_method("find_path"):
			var target_pos := _host.global_position + Vector3(randf_range(-8.0, 8.0), 0.0, randf_range(-8.0, 8.0))
			var path: Array = _nav_service.call("find_path", _host.global_position, target_pos)
			if path.size() > 1:
				_active_path.clear()
				for node: Vector3 in path:
					_active_path.append(node)
				_current_path_index = 0
				task_timer = randf_range(5.0, 10.0)
				return
				
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))
		task_timer = randf_range(3.0, 7.0)
	elif roll < 0.85:
		current_task = TaskState.EXAMINING 
		_active_path.clear()
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))
		task_timer = randf_range(1.0, 2.5)
	else:
		current_task = TaskState.IDLE
		_active_path.clear()
		task_timer = randf_range(0.4, 1.2)


func _seek_shelter_routine() -> void:
	if current_task == TaskState.IDLE and _active_path.is_empty():
		var my_coord := Vector3i(floori(_host.global_position.x), floori(_host.global_position.y), floori(_host.global_position.z))
		if is_instance_valid(_nav_service) and "_indoor_nodes" in _nav_service:
			var indoor_nodes: Array = _nav_service.get("_indoor_nodes")
			if indoor_nodes.has(my_coord): return 
			
	if not _active_path.is_empty() and current_task == TaskState.WANDERING:
		return 
		
	if is_instance_valid(_nav_service) and _nav_service.has_method("find_closest_shelter_node"):
		var shelter_pos: Vector3 = _nav_service.call("find_closest_shelter_node", _host.global_position)
		if shelter_pos != Vector3.ZERO:
			var path: Array = _nav_service.call("find_path", _host.global_position, shelter_pos)
			if path.size() > 1:
				_active_path.clear()
				for node: Vector3 in path: _active_path.append(node)
				_current_path_index = 0
				current_task = TaskState.WANDERING
				task_timer = 15.0 
				return
	current_task = TaskState.IDLE
	_active_path.clear()
	task_timer = randf_range(1.5, 3.0)


func _is_direction_safe(dir: Vector3) -> bool:
	if not is_instance_valid(_host): return false
	var world_node := _host.get_parent()
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.world_state
	if ws == null: return true
	
	var check_pos := _host.global_position + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	var block_below := ws.get_block(block_below_coord)
	var block_at := ws.get_block(block_at_coord)
	
	if BlockType.is_solid(block_at): return false
	
	var habitat: int = _host.call("_get_habitat") if _host.has_method("_get_habitat") else 0
	if habitat == 2: # AQUATIC
		return block_below == 6 or block_at == 6
	elif habitat == 1: # AMPHIBIOUS
		return block_below == 6 or block_at == 6 or block_below == 7 or block_below == 11
	else: # TERRESTRIAL
		var is_liquid := block_below == 6 or block_below == 15 or block_at == 6
		var is_void := block_below == 0
		if is_void:
			var block_2_below := ws.get_block(block_below_coord + Vector3i(0, -1, 0))
			if block_2_below != 0 and block_2_below != 6 and block_2_below != 15: is_void = false
		return not is_liquid and not is_void


func _detect_closest_zombie_threat() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree(): return null
	var closest_zombie: Node3D = null
	var min_dist_sq := SIGHT_RANGE_SQ
	var hostiles := _host.get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if child == _host or not is_instance_valid(child): continue
		var zombie_entity := child.get("domain_entity") as VoxelEntity
		if zombie_entity != null and not zombie_entity.is_dead:
			var dist_sq := _host.global_position.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_zombie = child as Node3D
	return closest_zombie


func _detect_closest_peer_npc() -> Node3D:
	if not is_instance_valid(_host) or not _host.is_inside_tree(): return null
	var closest_peer: Node3D = null
	var min_dist_sq := SOCIAL_RANGE_SQ
	var passives := _host.get_tree().get_nodes_in_group("passives")
	for child: Node in passives:
		if child != _host and is_instance_valid(child):
			var ai_comp := child.get_node_or_null("NPCAIComponent") as NPCAIComponent
			if is_instance_valid(ai_comp):
				var peer_state := ai_comp.current_task
				if peer_state == TaskState.IDLE or peer_state == TaskState.CHATTIING:
					var dist_sq := _host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_peer = child as Node3D
	return closest_peer


func _locate_navigation_service_if_missing() -> void:
	if _nav_service == null and is_instance_valid(_host):
		var parent := _host.get_parent()
		if is_instance_valid(parent) and "navigation_service" in parent:
			_nav_service = parent.get("navigation_service")


func _dispatch_active_telemetry() -> void:
	if is_instance_valid(AITelemetryService.instance) and is_instance_valid(_host):
		var active_task_name := "IDLE"
		if active_behavior != null and active_behavior.has_method("get_active_state_name"):
			active_task_name = str(active_behavior.call("get_active_state_name", _host))
		else:
			active_task_name = _get_task_state_name(current_task)
			
		var waypoints_left := _active_path.size() - _current_path_index if _active_path.size() > 0 else 0
		var lookup_key := active_task_name
		if lookup_key == "WANDERING": lookup_key = "WANDER"
		elif lookup_key == "CHATTING": lookup_key = "CHAT"
		
		AITelemetryService.log_movement(
			_host.name, _host.global_position, _host.velocity, wander_direction,
			tr("SHOWCASE_TASK_" + lookup_key).to_upper(), _host.is_on_wall(), _host.is_on_floor(), waypoints_left
		)


func _get_task_state_name(task_val: int) -> String:
	var names := ["IDLE", "WANDERING", "EXAMINING", "GREETING", "CHATTING", "PANIC", "WORKING"]
	if task_val >= 0 and task_val < names.size(): return names[task_val]
	return "IDLE"
