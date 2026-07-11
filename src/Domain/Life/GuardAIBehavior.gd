# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Life & Entities / AI Strategies)
# Class: GuardAIBehavior
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Concrete AI behavior strategy implementing protective guard routines,
#              including threat scanning, alarm intercepts, and physical strikes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): EXTREME REFACTOR. Declares and manages 
#   its own local state machine (IDLE, PATROLLING, SPRINTING, ENGAGING) and telemetry,
#   completely independent of monolithic global enums.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New combat maneuvers 
#   (like shield-block, parrying, or calling archer support) can be added locally 
#   without modifying core components.
# - Liskov Substitution Principle (LSP): Fully compatible with the base contract.
# ==============================================================================
class_name GuardAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	IDLE,       # standing on guard posts / resting
	PATROLLING, # walking around the village borders
	SPRINTING,  # running to intercept a detected threat
	ENGAGING    # actively striking and knocking back hostiles
}

const SPEED_CHASE: float = 2.3
const SPEED_PATROL: float = 1.3

const RANGE_SIGHT_SQ: float = 100.0 # 10.0 meters squared
const RANGE_ATTACK_SQ: float = 2.56 # 1.6 meters squared
const COOLDOWN_ATTACK_SEC: float = 1.2
const SCAN_INTERVAL_SEC: float = 0.25

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_COOLDOWN := "guard_attack_cooldown"
const META_TARGET := "guard_combat_target"
const META_SCAN_TIMER := "guard_scan_timer"
const META_GUARD_STATE := "guard_local_state"


## Concrete Implementation: Executes defensive threat scanning and tactical strikes
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Freeze decisions if engaged in a conversation with the player
	if host.get("is_talking") == true:
		_reset_guard_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	# Safe conversion of primitive types to prevent cast warnings
	var cooldown: float = float(host.get_meta(META_COOLDOWN))
	var scan_timer: float = float(host.get_meta(META_SCAN_TIMER))
	
	var combat_target: Object = null
	if host.has_meta(META_TARGET):
		var target_val: Variant = host.get_meta(META_TARGET)
		if typeof(target_val) == TYPE_OBJECT:
			var target_obj: Object = target_val
			if is_instance_valid(target_obj):
				combat_target = target_obj
				
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	# 1. THROTTLED THREAT SCANNING
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL_SEC
		
		# Locate closest threat if currently unengaged or target has died
		if not is_instance_valid(combat_target) or combat_target.get("domain_entity").get("is_dead") == true:
			combat_target = _scan_for_active_zombie_target(host)
				
		host.set_meta(META_SCAN_TIMER, scan_timer)
		
		# Set metadata safely
		if combat_target != null:
			host.set_meta(META_TARGET, combat_target)
		else:
			host.set_meta(META_TARGET, "")
		
	# 2. COMBAT PURSUIT AND ENGAGEMENT STATE
	if is_instance_valid(combat_target) and combat_target.get("domain_entity").get("is_dead") != true:
		ai.set("current_task", TASK_WORKING)
		
		var host_pos: Vector3 = host.get("global_position")
		var target_pos: Vector3 = combat_target.get("global_position")
		var diff := target_pos - host_pos
		diff.y = 0.0
		var dist_sq := diff.length_squared()
		
		var velocity: Vector3 = host.get("velocity")
		if dist_sq > RANGE_ATTACK_SQ:
			host.set_meta(META_GUARD_STATE, State.SPRINTING)
			
			# Chase threat at sprint speeds
			var chase_dir := diff.normalized()
			velocity.x = chase_dir.x * SPEED_CHASE
			velocity.z = chase_dir.z * SPEED_CHASE
			host.set("velocity", velocity)
			ai.set("wander_direction", chase_dir)
		else:
			host.set_meta(META_GUARD_STATE, State.ENGAGING)
			
			# Target within range: halt movement and strike
			velocity.x = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
			ai.set("wander_direction", diff.normalized())
			
			if cooldown <= 0.0:
				_strike_target(host, combat_target)
				cooldown = COOLDOWN_ATTACK_SEC
				host.set_meta(META_COOLDOWN, cooldown)
				
				var vis_rep: IEntityVisualRepresentation = host.get("visual_representation") as IEntityVisualRepresentation
				if vis_rep != null:
					vis_rep.trigger_attack_visuals()
	else:
		# 3. PATROL STATE: Fall back to standard peaceful wandering routines
		var current_task: int = ai.get("current_task")
		if current_task == TASK_WORKING:
			ai.set("current_task", TASK_IDLE)
			host.set_meta(META_GUARD_STATE, State.IDLE)
			ai.set("task_timer", 1.0)
		else:
			var is_moving := Vector2(host.velocity.x, host.velocity.z).length_squared() > 0.05
			if is_moving:
				host.set_meta(META_GUARD_STATE, State.PATROLLING)
			else:
				host.set_meta(META_GUARD_STATE, State.IDLE)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET):
		host.set_meta(META_TARGET, "")
	if not host.has_meta(META_SCAN_TIMER):
		host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_GUARD_STATE):
		host.set_meta(META_GUARD_STATE, State.IDLE)


func _reset_guard_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET, "")
	host.set_meta(META_GUARD_STATE, State.IDLE)


## Trigonometric Scan: Locates closest active zombie or outlaw player in sight range
func _scan_for_active_zombie_target(host: Object) -> Object:
	if not host.call("is_inside_tree"):
		return null
		
	var closest_target: Object = null
	var min_dist_sq := RANGE_SIGHT_SQ
	var host_pos: Vector3 = host.get("global_position")
	
	# Check if the player is currently WANTED for crimes against the village
	var rep: Object = VillageReputationService.instance
	if is_instance_valid(rep) and rep.call("is_player_wanted") == true:
		var parent_node: Node = null
		if host.has_method("get_parent"):
			parent_node = host.call("get_parent") as Node
			
		if is_instance_valid(parent_node):
			var player_node: Object = parent_node.call("get_node_or_null", "Player")
			if is_instance_valid(player_node):
				var p_domain: Object = player_node.get("domain_entity")
				if p_domain != null and p_domain.get("is_dead") != true:
					var player_pos: Vector3 = player_node.get("global_position")
					var dist_sq_p := host_pos.distance_squared_to(player_pos)
					if dist_sq_p < min_dist_sq:
						min_dist_sq = dist_sq_p
						closest_target = player_node
						
	# Check traditional hostile group targets (Zombies)
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	for child: Object in hostiles:
		if is_instance_valid(child):
			var zombie_entity: Object = child.get("domain_entity")
			if zombie_entity != null and zombie_entity.get("is_dead") != true:
				var child_pos: Vector3 = child.get("global_position")
				var dist_sq_z := host_pos.distance_squared_to(child_pos)
				if dist_sq_z < min_dist_sq:
					min_dist_sq = dist_sq_z
					closest_target = child
					
	return closest_target


## Inflicts standard damage and applies diagonal knockback
func _strike_target(host: Object, target: Object) -> void:
	var host_pos: Vector3 = host.get("global_position")
	var target_pos: Vector3 = target.get("global_position")
	var dir := (target_pos - host_pos).normalized()
	dir.y = 0.0
	
	var knockback := dir * 4.5
	knockback.y = 2.0
	
	if target.has_method("take_damage"):
		target.call("take_damage", 1, knockback, host)


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

## Symmetrical Override: Maps the localized, private State enum to 
## human-readable telemetry strings.
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
