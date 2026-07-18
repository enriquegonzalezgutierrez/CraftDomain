# ==============================================================================
# Pathfile: res://src/Domain/Life/VillagerAIBehavior.gd
# Description: Specialized AI behavior strategy implementing social life routines,
#              A* pathfinding gossiping, and smart hazard avoidance for Villagers.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly gossip states, 
#   throttled A* path recalculations, and state machine decisions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior, delegating all physical 
#   kinematics to VoxelKinematicService to keep this class closed to motion changes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VillagerAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	IDLE,             # Resting or indoors
	WANDERING,        # Standard village patrol using safe A* paths
	GOSSIPING,        # Chatting with peers on matched paths
	FLEEING_TO_GUARD  # Tactical panic A* route to closest protector
}

const SPEED_PATROL: float = 1.0
const SPEED_RETREAT: float = 1.6
const SPEED_PANIC: float = 2.4

const COOLDOWN_CHAT_SEC: float = 8.0
const CHAT_DURATION_SEC: float = 4.0
const PATH_RECALC_INTERVAL_SEC: float = 0.4 # Throttles A* path calculations to 2.5Hz

const RANGE_SENSE_SQ: float = 36.0 
const RANGE_GUARD_SEEK_SQ: float = 900.0 # 30m protector scanning radius

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "villager_wander_timer"
const META_WANDER_DIR := "villager_wander_dir"
const META_PEER := "villager_peer_target"
const META_COOLDOWN := "villager_chat_cooldown"
const META_CHAT_TIMER := "villager_chat_timer"
const META_VILLAGER_STATE := "villager_local_state"
const META_PATH_TIMER := "villager_path_recalc_timer"
const META_ACTIVE_PATH := "villager_active_path"
const META_PATH_INDEX := "villager_path_index"


func _init() -> void:
	# Take complete ownership of the Villager's schedules to bypass raw unsafe straight walks
	overrides_wandering = true


## Concrete Contract: Drives daily gossip, tactical retreats, and chat animations
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_villager_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_chat_cooldown(host, delta)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	var host_node := host as CharacterBody3D
	
	# Priority 1: Tactical panic (Fleeing to nearest defender)
	if ai.get("current_task") as int == TASK_PANIC:
		_process_tactical_panic_ast(host_node, ai, delta)
		return
	
	var parent: Node = host_node.get_parent() as Node
	# Priority 2: Nighttime/Storm schedule (Refuge & shelter)
	if _process_shelter_retreat_ast(host_node, ai, parent, delta):
		return
		
	# Priority 3: Daytime business (Gossip & Patrol)
	_process_daytime_social_routines(host_node, ai, delta)


func _update_chat_cooldown(host: Object, delta: float) -> void:
	var chat_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if chat_cooldown > 0.0:
		host.set_meta(META_COOLDOWN, chat_cooldown - delta)


# ==============================================================================
# TACTICAL PANIC ROUTING (A* Guard Seeking)
# ==============================================================================

func _process_tactical_panic_ast(host: CharacterBody3D, ai: Object, delta: float) -> void:
	host.set_meta(META_VILLAGER_STATE, State.FLEEING_TO_GUARD)
	
	var path_timer: float = host.get_meta(META_PATH_TIMER) as float
	path_timer -= delta
	
	var path: Array = host.get_meta(META_ACTIVE_PATH) if host.has_meta(META_ACTIVE_PATH) else []
	var p_idx: int = host.get_meta(META_PATH_INDEX) if host.has_meta(META_PATH_INDEX) else 0
	
	if path_timer <= 0.0 or path.is_empty():
		path_timer = PATH_RECALC_INTERVAL_SEC
		var guard := _scan_for_closest_protector(host)
		path = _recalculate_ast_path(host, guard.global_position if is_instance_valid(guard) else host.global_position)
		p_idx = 0
		host.set_meta(META_ACTIVE_PATH, path)
		host.set_meta(META_PATH_INDEX, p_idx)
		
	host.set_meta(META_PATH_TIMER, path_timer)
	_navigate_along_path(host, ai, path, p_idx, SPEED_PANIC)


func _scan_for_closest_protector(host: CharacterBody3D) -> Node3D:
	if not host.is_inside_tree(): return null
	var passives: Array = []
	var tree := host.get_tree() as SceneTree
	if is_instance_valid(tree): passives = tree.get_nodes_in_group("passives")
			
	var host_pos: Vector3 = host.global_position
	var closest_protector: Node3D = null
	var min_dist_sq := RANGE_GUARD_SEEK_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var name_str: String = child.name
			if name_str.contains("GUARD") or name_str.contains("GOLEM"):
				var domain := child.get("domain_entity") as VoxelEntity
				if domain != null and not domain.is_dead:
					var dist_sq := host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_protector = child as Node3D
	return closest_protector


# ==============================================================================
# NIGHTTIME SHELTER ROUTINES (A* Room Retreat)
# ==============================================================================

func _process_shelter_retreat_ast(host: CharacterBody3D, ai: Object, parent: Node, delta: float) -> bool:
	var is_night := CelestialService.is_night_time_static()
	var is_storming := _is_weather_storming(parent)
			
	if not is_night and not is_storming:
		return false
		
	_reset_villager_state(host)
	var host_pos: Vector3 = host.global_position
	var nav_service := parent.get("navigation_service") as VoxelNavigationService if is_instance_valid(parent) else null
	
	if _is_inside_shelter(host_pos, nav_service):
		_execute_shelter_idle(host, ai)
	else:
		_route_shelter_retreat(host, ai, nav_service, host_pos, delta)
	return true


func _is_weather_storming(parent: Node) -> bool:
	if is_instance_valid(parent):
		var weather_node := parent.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node) and weather_node.get("current_weather") != null:
			var w_val := int(weather_node.get("current_weather"))
			return (w_val == 1 or w_val == 2)
	return false


func _is_inside_shelter(host_pos: Vector3, nav_service: VoxelNavigationService) -> bool:
	if is_instance_valid(nav_service) and "_indoor_nodes" in nav_service:
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		var indoor_nodes: Array = nav_service.get("_indoor_nodes") as Array
		return indoor_nodes.has(my_coord)
	return false


func _execute_shelter_idle(host: CharacterBody3D, ai: Object) -> void:
	host.set_meta(META_VILLAGER_STATE, State.IDLE)
	ai.set("current_task", TASK_IDLE)
	VoxelKinematicService.halt_movement(host, ai)
	
	var gold_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if gold_cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_CHAT_SEC)
		if host.has_method("_play_gossip_chatter"):
			host.call("_play_gossip_chatter")


func _route_shelter_retreat(host: CharacterBody3D, ai: Object, nav_service: VoxelNavigationService, host_pos: Vector3, delta: float) -> void:
	host.set_meta(META_VILLAGER_STATE, State.WANDERING)
	ai.set("current_task", TASK_WANDERING)
	
	var path_timer: float = host.get_meta(META_PATH_TIMER) as float
	path_timer -= delta
	
	var path: Array = host.get_meta(META_ACTIVE_PATH) if host.has_meta(META_ACTIVE_PATH) else []
	var p_idx: int = host.get_meta(META_PATH_INDEX) if host.has_meta(META_PATH_INDEX) else 0
	
	if path_timer <= 0.0 or path.is_empty():
		path_timer = PATH_RECALC_INTERVAL_SEC
		if is_instance_valid(nav_service) and nav_service.has_method("find_closest_shelter_node"):
			var shelter_pos: Vector3 = nav_service.call("find_closest_shelter_node", host_pos) as Vector3
			path = nav_service.find_path(host_pos, shelter_pos)
			p_idx = 0
			host.set_meta(META_ACTIVE_PATH, path)
			host.set_meta(META_PATH_INDEX, p_idx)
			
	host.set_meta(META_PATH_TIMER, path_timer)
	_navigate_along_path(host, ai, path, p_idx, SPEED_RETREAT)


# ==============================================================================
# DAYTIME SOCIAL ROUTINES (A* Gossip & Patrol)
# ==============================================================================

func _process_daytime_social_routines(host: CharacterBody3D, ai: Object, delta: float) -> void:
	var target_peer := _get_metadata_object(host, META_PEER) as Node3D
	if is_instance_valid(target_peer):
		_process_gossip_chatter_ast(host, ai, target_peer, delta)
	else:
		_process_gossip_scanning(host)
		_process_default_patrol_ast(host, ai, delta)


func _process_gossip_chatter_ast(host: CharacterBody3D, ai: Object, target_peer: Node3D, delta: float) -> void:
	var target_domain := target_peer.get("domain_entity") as VoxelEntity
	if target_domain == null or target_domain.is_dead:
		_reset_villager_state(host)
		return
		
	var host_pos: Vector3 = host.global_position
	var diff := target_peer.global_position - host_pos
	diff.y = 0.0
	var dist_sq := diff.length_squared()
	
	if dist_sq > 2.5:
		host.set_meta(META_VILLAGER_STATE, State.WANDERING)
		_process_ast_pursuit(host, ai, target_peer.global_position, delta)
	else:
		host.set_meta(META_VILLAGER_STATE, State.GOSSIPING)
		_execute_social_gossip(host, ai, diff.normalized(), delta)


func _execute_social_gossip(host: CharacterBody3D, ai: Object, attack_dir: Vector3, delta: float) -> void:
	VoxelKinematicService.halt_movement(host, ai)
	ai.set("wander_direction", attack_dir)
	
	var chat_timer: float = host.get_meta(META_CHAT_TIMER) as float
	chat_timer -= delta
	if chat_timer <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_CHAT_SEC)
		_reset_villager_state(host)
		return
		
	if int(round(chat_timer * 10.0)) % 15 == 0:
		if host.has_method("_play_gossip_chatter"):
			host.call("_play_gossip_chatter")
			
	host.set_meta(META_CHAT_TIMER, chat_timer)


func _process_gossip_scanning(host: CharacterBody3D) -> void:
	var chat_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if chat_cooldown <= 0.0:
		var peer_citizen := _scan_for_nearby_peer(host)
		if peer_citizen != null:
			host.set_meta(META_PEER, peer_citizen)
			host.set_meta(META_CHAT_TIMER, CHAT_DURATION_SEC)


func _process_default_patrol_ast(host: CharacterBody3D, ai: Object, delta: float) -> void:
	ai.set("current_task", TASK_WANDERING)
	host.set_meta(META_VILLAGER_STATE, State.WANDERING)
	
	var path_timer: float = host.get_meta(META_PATH_TIMER) as float
	path_timer -= delta
	
	var path: Array = host.get_meta(META_ACTIVE_PATH) if host.has_meta(META_ACTIVE_PATH) else []
	var p_idx: int = host.get_meta(META_PATH_INDEX) if host.has_meta(META_PATH_INDEX) else 0
	
	if path.is_empty() or p_idx >= path.size() or path_timer <= 0.0:
		path_timer = randf_range(4.0, 8.0) # Repath every few seconds
		path = _generate_random_safe_patrol_path(host)
		p_idx = 0
		host.set_meta(META_ACTIVE_PATH, path)
		host.set_meta(META_PATH_INDEX, p_idx)
		
	host.set_meta(META_PATH_TIMER, path_timer)
	_navigate_along_path(host, ai, path, p_idx, SPEED_PATROL)


func _generate_random_safe_patrol_path(host: CharacterBody3D) -> Array:
	var parent: Node = host.get_parent() as Node
	if is_instance_valid(parent) and "navigation_service" in parent:
		var nav: VoxelNavigationService = parent.get("navigation_service") as VoxelNavigationService
		if is_instance_valid(nav):
			var rx := randf_range(-8.0, 8.0)
			var rz := randf_range(-8.0, 8.0)
			var target_pos := host.global_position + Vector3(rx, 0.0, rz)
			return nav.find_path(host.global_position, target_pos)
	return []


# ==============================================================================
# NAVIGATION MOVEMENT WRITERS (A* Processing)
# ==============================================================================

func _process_ast_pursuit(host: CharacterBody3D, ai: Object, target_pos: Vector3, delta: float) -> void:
	var path_timer: float = host.get_meta(META_PATH_TIMER) as float
	path_timer -= delta
	
	var path: Array = host.get_meta(META_ACTIVE_PATH) if host.has_meta(META_ACTIVE_PATH) else []
	var p_idx: int = host.get_meta(META_PATH_INDEX) if host.has_meta(META_PATH_INDEX) else 0
	
	if path_timer <= 0.0 or path.is_empty():
		path_timer = PATH_RECALC_INTERVAL_SEC
		path = _recalculate_ast_path(host, target_pos)
		p_idx = 0
		host.set_meta(META_ACTIVE_PATH, path)
		host.set_meta(META_PATH_INDEX, p_idx)
		
	host.set_meta(META_PATH_TIMER, path_timer)
	_navigate_along_path(host, ai, path, p_idx, SPEED_PATROL)


func _recalculate_ast_path(host: CharacterBody3D, target_pos: Vector3) -> Array:
	var parent: Node = host.get_parent() as Node
	if is_instance_valid(parent) and "navigation_service" in parent:
		var nav: VoxelNavigationService = parent.get("navigation_service") as VoxelNavigationService
		if is_instance_valid(nav):
			return nav.find_path(host.global_position, target_pos)
	return []


func _navigate_along_path(host: CharacterBody3D, ai: Object, path: Array, p_idx: int, speed: float) -> void:
	# Delegate spatial navigation entirely to VoxelKinematicService
	var _unused_idx := VoxelKinematicService.navigate_along_path(host, ai, path, p_idx, speed, META_PATH_INDEX)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PEER): host.set_meta(META_PEER, "")
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_CHAT_TIMER): host.set_meta(META_CHAT_TIMER, 0.0)
	if not host.has_meta(META_VILLAGER_STATE): host.set_meta(META_VILLAGER_STATE, State.IDLE)
	if not host.has_meta(META_PATH_TIMER): host.set_meta(META_PATH_TIMER, 0.0)
	if not host.has_meta(META_ACTIVE_PATH): host.set_meta(META_ACTIVE_PATH, [])
	if not host.has_meta(META_PATH_INDEX): host.set_meta(META_PATH_INDEX, 0)


func _reset_villager_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_PEER, "")
	host.set_meta(META_CHAT_TIMER, 0.0)
	host.set_meta(META_WANDER_TIMER, 1.0)
	host.set_meta(META_ACTIVE_PATH, [])
	host.set_meta(META_PATH_INDEX, 0)
	host.set_meta(META_VILLAGER_STATE, State.IDLE)


func _get_metadata_object(host: Object, key: String) -> Object:
	if host.has_meta(key):
		var val: Variant = host.get_meta(key)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			return val as Object
	return null


func _scan_for_nearby_peer(host: CharacterBody3D) -> Node3D:
	if not host.is_inside_tree(): return null
	var passives: Array = []
	var tree := host.get_tree() as SceneTree
	if is_instance_valid(tree): passives = tree.get_nodes_in_group("passives")
			
	var host_pos: Vector3 = host.global_position
	var closest_peer: Node3D = null
	var min_dist_sq: float = RANGE_SENSE_SQ # FIXED: Explicit typesafe binding to float and correct constant name
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var name_str: String = child.name
			if name_str.contains("VILLAGER") or name_str.contains("MERCHANT") or name_str.contains("FARMER") or name_str.contains("MINER") or name_str.contains("DRUID"):
				var domain := child.get("domain_entity") as VoxelEntity
				if domain != null and not domain.is_dead:
					var dist_sq := host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_peer = child as Node3D
	return closest_peer


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_VILLAGER_STATE):
		return "IDLE"
		
	var state_val: int = host.get_meta(META_VILLAGER_STATE) as int
	match state_val:
		State.IDLE: return "IDLE"
		State.WANDERING: return "WANDERING"
		State.GOSSIPING: return "CHATTING" # Maps correctly to the active social gossip state
		State.FLEEING_TO_GUARD: return "SPRINTING_TO_THREAT" 
		_: return "IDLE"
