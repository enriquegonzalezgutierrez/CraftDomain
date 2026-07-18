# ==============================================================================
# Pathfile: res://src/Domain/Life/GuardAIBehavior.gd
# Description: Specialized AI behavior strategy implementing protective village 
#              overwatch, A* pathfinding pursuit, and smart obstacle avoidance.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly defensive sweeps, 
#   throttled A* path recalculations, and state machine decisions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior, delegating all physical 
#   kinematics to VoxelKinematicService to keep this class closed to motion changes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GuardAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	IDLE,       # Standing on guard posts / resting
	PATROLLING, # Walking around the village borders using safe A* paths
	SPRINTING,  # Running to intercept a detected threat using pathfinding
	ENGAGING    # Actively striking and knocking back hostiles
}

const SPEED_CHASE: float = 2.3
const SPEED_PATROL: float = 1.3

const RANGE_SIGHT_SQ: float = 100.0 # 10.0 meters squared
const RANGE_ATTACK_SQ: float = 2.56 # 1.6 meters squared
const COOLDOWN_ATTACK_SEC: float = 1.2
const SCAN_INTERVAL_SEC: float = 0.25
const PATH_RECALC_INTERVAL_SEC: float = 0.4 # Throttles A* path calculations to 2.5Hz

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys
const META_COOLDOWN := "guard_attack_cooldown"
const META_TARGET := "guard_combat_target"
const META_SCAN_TIMER := "guard_scan_timer"
const META_GUARD_STATE := "guard_local_state"
const META_PATH_TIMER := "guard_path_recalc_timer"
const META_ACTIVE_PATH := "guard_active_path"
const META_PATH_INDEX := "guard_path_index"


func _init() -> void:
	# Take complete ownership of the Guard's schedules to bypass raw unsafe straight walks
	overrides_wandering = true


## Concrete Implementation: Executes defensive threat scanning and tactical A* strikes
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_guard_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_guard_timers(host, delta)
	_process_threat_scanning(host, delta)
	
	var ai: Object = host.get("ai_component")
	var combat_target: Object = _get_metadata_object(host, META_TARGET)
	
	if is_instance_valid(ai):
		if is_instance_valid(combat_target) and combat_target.get("domain_entity").get("is_dead") != true:
			_process_combat_engagement(host, ai, combat_target as Node3D, delta)
		else:
			_process_safe_patrol(host, ai, delta)


func _update_guard_timers(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_COOLDOWN, cooldown - delta)


func _process_threat_scanning(host: Object, delta: float) -> void:
	var scan_timer: float = host.get_meta(META_SCAN_TIMER) as float
	scan_timer -= delta
	
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL_SEC
		var combat_target := _get_metadata_object(host, META_TARGET)
		
		if not is_instance_valid(combat_target) or combat_target.get("domain_entity").get("is_dead") == true:
			combat_target = _scan_for_active_zombie_target(host)
			if combat_target != null:
				host.set_meta(META_TARGET, combat_target)
			else:
				host.set_meta(META_TARGET, "")
				
	host.set_meta(META_SCAN_TIMER, scan_timer)


func _process_combat_engagement(host: Object, ai: Object, target: Node3D, delta: float) -> void:
	ai.set("current_task", TASK_WORKING)
	
	var host_node := host as CharacterBody3D
	var host_pos: Vector3 = host_node.global_position
	var target_pos: Vector3 = target.global_position
	var diff: Vector3 = target_pos - host_pos
	var dist_sq := diff.length_squared()
	
	if dist_sq > RANGE_ATTACK_SQ:
		host.set_meta(META_GUARD_STATE, State.SPRINTING)
		_process_ast_pursuit(host_node, ai, target_pos, delta)
	else:
		host.set_meta(META_GUARD_STATE, State.ENGAGING)
		_execute_proximity_strike(host_node, ai, target, diff.normalized())


func _process_ast_pursuit(host: CharacterBody3D, ai: Object, target_pos: Vector3, delta: float) -> void:
	var path_timer: float = host.get_meta(META_PATH_TIMER) as float
	path_timer -= delta
	
	var path: Array = host.get_meta(META_ACTIVE_PATH) if host.has_meta(META_ACTIVE_PATH) else []
	var p_idx: int = host.get_meta(META_PATH_INDEX) if host.has_meta(META_PATH_INDEX) else 0
	
	if path_timer <= 0.0 or path.is_empty():
		path_timer = PATH_RECALC_INTERVAL_SEC
		path = _recalculate_ast_path(host, target_pos)
		path = _validate_pursuit_path(path, target_pos)
		p_idx = 0
		host.set_meta(META_ACTIVE_PATH, path)
		host.set_meta(META_PATH_INDEX, p_idx)
		
	host.set_meta(META_PATH_TIMER, path_timer)
	_navigate_along_pursuit_path(host, ai, path, p_idx)


func _validate_pursuit_path(raw_path: Array, target_pos: Vector3) -> Array:
	# If the path ends more than 3 meters away from the actual target (different floor glitch), discard it
	if raw_path.size() > 0 and raw_path.back().distance_squared_to(target_pos) > 9.0:
		return []
	return raw_path


func _recalculate_ast_path(host: CharacterBody3D, target_pos: Vector3) -> Array:
	var parent: Node = host.get_parent() as Node
	if is_instance_valid(parent) and "navigation_service" in parent:
		var nav: VoxelNavigationService = parent.get("navigation_service") as VoxelNavigationService
		if is_instance_valid(nav):
			return nav.find_path(host.global_position, target_pos)
	return []


func _navigate_along_pursuit_path(host: CharacterBody3D, ai: Object, path: Array, p_idx: int) -> void:
	# Delegate spatial navigation entirely to VoxelKinematicService
	VoxelKinematicService.navigate_along_path(host, ai, path, p_idx, SPEED_CHASE, META_PATH_INDEX)


func _execute_proximity_strike(host: CharacterBody3D, ai: Object, target: Node3D, attack_dir: Vector3) -> void:
	VoxelKinematicService.halt_movement(host, ai)
	ai.set("wander_direction", attack_dir)
	
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_ATTACK_SEC)
		_strike_target(host, target)
		
		var vis_rep: IEntityVisualRepresentation = host.get("visual_representation") as IEntityVisualRepresentation
		if is_instance_valid(vis_rep):
			vis_rep.trigger_attack_visuals()


func _process_safe_patrol(host: Object, ai: Object, _delta: float) -> void:
	ai.set("current_task", TASK_WANDERING)
	
	var host_node := host as CharacterBody3D
	var path: Array = host_node.get_meta(META_ACTIVE_PATH) if host_node.has_meta(META_ACTIVE_PATH) else []
	var p_idx: int = host_node.get_meta(META_PATH_INDEX) if host_node.has_meta(META_PATH_INDEX) else 0
	
	if path.is_empty() or p_idx >= path.size():
		path = _generate_random_safe_patrol_path(host_node)
		p_idx = 0
		host_node.set_meta(META_ACTIVE_PATH, path)
		host_node.set_meta(META_PATH_INDEX, p_idx)
		
	var is_moving := path.size() > 0 and p_idx < path.size()
	host_node.set_meta(META_GUARD_STATE, State.PATROLLING if is_moving else State.IDLE)
	_navigate_along_patrol_path(host_node, ai, path, p_idx)


func _generate_random_safe_patrol_path(host: CharacterBody3D) -> Array:
	var parent: Node = host.get_parent() as Node
	if is_instance_valid(parent) and "navigation_service" in parent:
		var nav: VoxelNavigationService = parent.get("navigation_service") as VoxelNavigationService
		if is_instance_valid(nav):
			var rx := randf_range(-10.0, 10.0)
			var rz := randf_range(-10.0, 10.0)
			var target_pos: Vector3 = host.global_position + Vector3(rx, 0.0, rz)
			return nav.find_path(host.global_position, target_pos)
	return []


func _navigate_along_patrol_path(host: CharacterBody3D, ai: Object, path: Array, p_idx: int) -> void:
	# Delegate spatial navigation entirely to VoxelKinematicService
	VoxelKinematicService.navigate_along_path(host, ai, path, p_idx, SPEED_PATROL, META_PATH_INDEX)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET): host.set_meta(META_TARGET, "")
	if not host.has_meta(META_SCAN_TIMER): host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_GUARD_STATE): host.set_meta(META_GUARD_STATE, State.IDLE)
	if not host.has_meta(META_PATH_TIMER): host.set_meta(META_PATH_TIMER, 0.0)
	if not host.has_meta(META_ACTIVE_PATH): host.set_meta(META_ACTIVE_PATH, [])
	if not host.has_meta(META_PATH_INDEX): host.set_meta(META_PATH_INDEX, 0)


func _reset_guard_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET, "")
	host.set_meta(META_ACTIVE_PATH, [])
	host.set_meta(META_PATH_INDEX, 0)
	host.set_meta(META_GUARD_STATE, State.IDLE)


func _scan_for_active_zombie_target(host: Object) -> Object:
	if not host.call("is_inside_tree"): return null
	var closest_target: Object = null
	var min_dist_sq := RANGE_SIGHT_SQ
	var host_node := host as CharacterBody3D
	var host_pos: Vector3 = host_node.global_position
	
	var rep: Object = VillageReputationService.instance
	if is_instance_valid(rep) and rep.call("is_player_wanted") == true:
		var parent_node := host.call("get_parent") as Node
		if is_instance_valid(parent_node):
			var player_node := parent_node.call("get_node_or_null", "Player") as Node3D
			if is_instance_valid(player_node) and player_node.get("is_active"):
				min_dist_sq = host_pos.distance_squared_to(player_node.global_position)
				closest_target = player_node
				
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree := host.call("get_tree") as SceneTree
		if is_instance_valid(tree): hostiles = tree.get_nodes_in_group("hostiles")
			
	for child: Object in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var zombie_entity := child.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_target = child as Node3D
	return closest_target


func _strike_target(host: CharacterBody3D, target: Object) -> void:
	var host_pos: Vector3 = host.global_position
	var target_pos: Vector3 = target.get("global_position")
	var dir := (target_pos - host_pos).normalized()
	dir.y = 0.0
	
	var knockback := dir * 4.5
	knockback.y = 2.0
	
	if target.has_method("take_damage"):
		target.call("take_damage", 1, knockback, host)


func _get_metadata_object(host: Object, key: String) -> Object:
	if host.has_meta(key):
		var val: Variant = host.get_meta(key)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			return val as Object
	return null


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_GUARD_STATE):
		return "IDLE"
		
	var state_val: int = host.get_meta(META_GUARD_STATE) as int
	match state_val:
		State.IDLE:       return "IDLE"
		State.PATROLLING: return "PATROLLING"
		State.SPRINTING:  return "SPRINTING_TO_THREAT"
		State.ENGAGING:   return "ENGAGING_THREAT"
		_: return "IDLE"
