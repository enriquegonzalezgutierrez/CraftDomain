# ==============================================================================
# Pathfile: res://src/Domain/Life/GolemAIBehavior.gd
# Description: Specialized AI behavior strategy implementing protective military 
#              overwatch routines for the colossus Iron Golem. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GolemAIBehavior
extends IAIBehavior

# Localized State Machine
enum State {
	IDLE,        
	OVERWATCH,   
	SPRINTING,   
	SLAM_ATTACK  
}

const SPEED_CHASE_MULT: float = 1.3
const SPEED_PATROL: float = 1.0

const RANGE_SIGHT_SQ: float = 144.0 
const RANGE_ATTACK_SQ: float = 4.84  
const COOLDOWN_ATTACK_SEC: float = 1.8
const SCAN_INTERVAL_SEC: float = 0.25

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys
const META_COOLDOWN := "golem_attack_cooldown"
const META_TARGET := "golem_combat_target"
const META_SCAN_TIMER := "golem_scan_timer"
const META_GOLEM_STATE := "golem_local_state"


func _init() -> void:
	overrides_wandering = false


## Concrete Contract: Drives overwatch sweeps, chasing vectors, and slam triggers
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_golem_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_attack_cooldown(host, delta)
	
	_process_active_scanning(host, delta)
	
	var combat_target: Object = null
	if host.has_meta(META_TARGET):
		var val: Variant = host.get_meta(META_TARGET)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			combat_target = val as Object
			
	var is_tracking := false
	if is_instance_valid(combat_target):
		is_tracking = _process_threat_pursuit(host, combat_target, delta)
		
	if not is_tracking:
		_process_golem_patrol(host)


func _update_attack_cooldown(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)


func _process_active_scanning(host: Object, delta: float) -> void:
	var scan_timer: float = host.get_meta(META_SCAN_TIMER) as float
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL_SEC
		var combat_target := _scan_for_active_hostile_target(host)
		if combat_target != null:
			host.set_meta(META_TARGET, combat_target)
		else:
			host.set_meta(META_TARGET, "")
	host.set_meta(META_SCAN_TIMER, scan_timer)


func _process_threat_pursuit(host: Object, combat_target: Object, delta: float) -> bool:
	var target_node := combat_target as Node3D
	var target_domain: Object = target_node.get("domain_entity") if is_instance_valid(target_node) else null
	
	if target_domain == null or target_domain.get("is_dead") == true:
		_reset_golem_state(host)
		return false
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WORKING)
	var host_pos: Vector3 = host.get("global_position")
	var target_pos: Vector3 = target_node.global_position
	var diff := target_pos - host_pos
	diff.y = 0.0
	var dist_sq := diff.length_squared()
	
	if dist_sq > RANGE_ATTACK_SQ:
		_apply_sprint_locomotion(host, ai, diff)
	else:
		_execute_golem_slam(host, ai, target_node, diff, delta)
		
	return true


func _execute_golem_slam(host: Object, ai: Object, target_node: Node3D, diff: Vector3, delta: float) -> void:
	# Avoid unused parameters warning in the contract
	var _d := delta
	
	host.set_meta(META_GOLEM_STATE, State.SLAM_ATTACK)
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	ai.set("wander_direction", diff.normalized())
	
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_ATTACK_SEC)
		if host.has_method("_execute_heavy_combat_strike"):
			host.call("_execute_heavy_combat_strike", target_node)
			
		var vis_rep: Object = host.get("visual_representation")
		if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
			vis_rep.call("trigger_attack_visuals")


func _apply_sprint_locomotion(host: Object, ai: Object, diff: Vector3) -> void:
	host.set_meta(META_GOLEM_STATE, State.SPRINTING)
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	var base_speed: float = 1.3
	if "BASE_SPEED" in host:
		base_speed = host.get("BASE_SPEED") as float
		
	var chase_dir := diff.normalized()
	velocity.x = chase_dir.x * base_speed * SPEED_CHASE_MULT
	velocity.z = chase_dir.z * base_speed * SPEED_CHASE_MULT
	host.set("velocity", velocity)
	ai.set("wander_direction", chase_dir)


func _process_golem_patrol(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var current_task: int = ai.get("current_task") as int
	if current_task == TASK_WORKING:
		ai.set("current_task", TASK_IDLE)
		host.set_meta(META_GOLEM_STATE, State.IDLE)
		ai.set("task_timer", 1.0)
	else:
		var is_moving := Vector2(host.velocity.x, host.velocity.z).length_squared() > 0.05
		host.set_meta(META_GOLEM_STATE, State.OVERWATCH if is_moving else State.IDLE)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET): host.set_meta(META_TARGET, "")
	if not host.has_meta(META_SCAN_TIMER): host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_GOLEM_STATE): host.set_meta(META_GOLEM_STATE, State.IDLE)


func _reset_golem_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET, "")
	host.set_meta(META_GOLEM_STATE, State.IDLE)


func _scan_for_active_hostile_target(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var closest_target: Node3D = null
	var min_dist_sq := RANGE_SIGHT_SQ
	var host_pos: Vector3 = host.get("global_position")
	
	var rep := VillageReputationService.instance
	if is_instance_valid(rep) and rep.call("is_player_wanted") == true:
		var parent_node: Node = host.call("get_parent") as Node
		if is_instance_valid(parent_node):
			var player_node: Node3D = parent_node.call("get_node_or_null", "Player") as Node3D
			if is_instance_valid(player_node):
				var p_domain := player_node.get("domain_entity") as VoxelEntity
				if p_domain != null and p_domain.is_dead != true:
					var dist_sq_p := host_pos.distance_squared_to(player_node.global_position)
					if dist_sq_p < min_dist_sq:
						min_dist_sq = dist_sq_p
						closest_target = player_node
						
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	for child: Object in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain: Object = child.get("domain_entity")
			if domain != null and domain.get("is_dead") != true:
				var child_pos: Vector3 = child.global_position
				var dist_sq_z := host_pos.distance_squared_to(child_pos)
				if dist_sq_z < min_dist_sq:
					min_dist_sq = dist_sq_z
					closest_target = child as Node3D
	return closest_target


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_GOLEM_STATE):
		return "IDLE"
	var state_val: int = host.get_meta(META_GOLEM_STATE) as int
	match state_val:
		State.IDLE: return "IDLE"
		State.OVERWATCH: return "OVERWATCH_PATROL"
		State.SPRINTING: return "CHARGE_TO_TARGET"
		State.SLAM_ATTACK: return "LAUNCH_ATTACK"
		_: return "IDLE"
