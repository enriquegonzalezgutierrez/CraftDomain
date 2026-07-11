# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Life & Entities / AI Strategies)
# Class: GolemAIBehavior
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Specialized AI behavior strategy implementing protective military 
#              overwatch routines for the colossus Iron Golem. It coordinates 
#              throttled target scans (Zombies or Outlaw wanted players), sprinting 
#              pursuit vectors, and calls concrete ballistical launcher strikes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): EXTREME REFACTOR. Declares and manages 
#   its own local state machine (IDLE, OVERWATCH, SPRINTING, SLAM_ATTACK) and telemetry,
#   completely independent of monolithic global enums or knight states.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New combat movesets 
#   (like ground-smash, sweeping, or throwing rocks) can be added locally in this file
#   without modifying other scripts.
# - Liskov Substitution Principle (LSP): Fully compatible with the base contract.
# ==============================================================================
class_name GolemAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	IDLE,        # stationary guard stance in the plaza
	OVERWATCH,   # mossy patrol around the village center
	SPRINTING,   # massive heavy charge towards active threats
	SLAM_ATTACK  # double-arm launcher strike execution
}

const SPEED_CHASE_MULT: float = 1.3
const SPEED_PATROL: float = 1.0

const RANGE_SIGHT_SQ: float = 144.0 # 12.0 meters squared overwatch sight
const RANGE_ATTACK_SQ: float = 4.84  # 2.2 meters squared heavy slam radius
const COOLDOWN_ATTACK_SEC: float = 1.8
const SCAN_INTERVAL_SEC: float = 0.25

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_COOLDOWN := "golem_attack_cooldown"
const META_TARGET := "golem_combat_target"
const META_SCAN_TIMER := "golem_scan_timer"
const META_GOLEM_STATE := "golem_local_state"


func _init() -> void:
	# Golems run standard patrols unless actively engaging enemies
	overrides_wandering = false


## Concrete Contract: Drives overwatch sweeps, chasing vectors, and slam triggers
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Freeze decisions if engaged in dialogue
	if host.get("is_talking") == true:
		_reset_golem_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	var scan_timer: float = host.get_meta(META_SCAN_TIMER) as float
	
	var combat_target: Object = null
	if host.has_meta(META_TARGET):
		var val: Variant = host.get_meta(META_TARGET)
		if typeof(val) == TYPE_OBJECT:
			var obj: Object = val
			if is_instance_valid(obj):
				combat_target = obj
				
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return

	# ==========================================================================
	# 1. THROTTLED SENSORY TARGETING (4Hz tick cycle to minimize CPU stress)
	# ==========================================================================
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL_SEC
		
		# If target is dead or went missing, find closest active threat
		if not is_instance_valid(combat_target) or combat_target.get("domain_entity").get("is_dead") == true:
			combat_target = _scan_for_active_hostile_target(host)
			
		host.set_meta(META_SCAN_TIMER, scan_timer)
		
		if combat_target != null:
			host.set_meta(META_TARGET, combat_target)
		else:
			host.set_meta(META_TARGET, "")

	# ==========================================================================
	# 2. ENGAGEMENT AND COMBAT PURSUIT
	# ==========================================================================
	if is_instance_valid(combat_target) and combat_target.get("domain_entity").get("is_dead") != true:
		ai.set("current_task", TASK_WORKING)
		
		var target_node := combat_target as Node3D
		var host_pos: Vector3 = host.get("global_position")
		var target_pos: Vector3 = target_node.global_position
		var diff := target_pos - host_pos
		diff.y = 0.0
		var dist_sq := diff.length_squared()
		
		var velocity: Vector3 = host.get("velocity") as Vector3
		var base_speed: float = 1.3
		if "BASE_SPEED" in host:
			base_speed = host.get("BASE_SPEED") as float
			
		if dist_sq > RANGE_ATTACK_SQ:
			host.set_meta(META_GOLEM_STATE, State.SPRINTING)
			
			# Fast mechanical charge towards threat
			var chase_dir := diff.normalized()
			velocity.x = chase_dir.x * base_speed * SPEED_CHASE_MULT
			velocity.z = chase_dir.z * base_speed * SPEED_CHASE_MULT
			host.set("velocity", velocity)
			ai.set("wander_direction", chase_dir)
		else:
			host.set_meta(META_GOLEM_STATE, State.SLAM_ATTACK)
			
			# Symmetrical stop and strike!
			velocity.x = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
			ai.set("wander_direction", diff.normalized())
			
			if cooldown <= 0.0:
				# Trigger heavy double-arm launch attack on host
				if host.has_method("_execute_heavy_combat_strike"):
					host.call("_execute_heavy_combat_strike", target_node)
					
				cooldown = COOLDOWN_ATTACK_SEC
				host.set_meta(META_COOLDOWN, cooldown)
				
				# Play heavy mechanical arm swinging visual on presenter
				var vis_rep: Object = host.get("visual_representation")
				if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
					vis_rep.call("trigger_attack_visuals")
		return
	else:
		# 3. PEACEFUL VILLAGE PATROL COOLDOWN FALLBACK
		var current_task: int = ai.get("current_task") as int
		if current_task == TASK_WORKING:
			ai.set("current_task", TASK_IDLE)
			host.set_meta(META_GOLEM_STATE, State.IDLE)
			ai.set("task_timer", 1.0)
		else:
			var is_moving := Vector2(host.velocity.x, host.velocity.z).length_squared() > 0.05
			if is_moving:
				host.set_meta(META_GOLEM_STATE, State.OVERWATCH)
			else:
				host.set_meta(META_GOLEM_STATE, State.IDLE)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET):
		host.set_meta(META_TARGET, "")
	if not host.has_meta(META_SCAN_TIMER):
		host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_GOLEM_STATE):
		host.set_meta(META_GOLEM_STATE, State.IDLE)


func _reset_golem_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET, "")
	host.set_meta(META_GOLEM_STATE, State.IDLE)


## Proximity Scanner: Scans for active outlaws or hostile monsters
func _scan_for_active_hostile_target(host: Object) -> Node3D:
	if not host.call("is_inside_tree"):
		return null
		
	var closest_target: Node3D = null
	var min_dist_sq := RANGE_SIGHT_SQ
	var host_pos: Vector3 = host.get("global_position")
	
	# A. Check wanted players (Reputation Outlaws check)
	var rep: Object = VillageReputationService.instance
	if is_instance_valid(rep) and rep.call("is_player_wanted") == true:
		var parent_node: Node = host.call("get_parent") as Node
		if is_instance_valid(parent_node):
			var player_node: Node3D = parent_node.call("get_node_or_null", "Player") as Node3D
			if is_instance_valid(player_node):
				var p_domain: Object = player_node.get("domain_entity")
				if p_domain != null and p_domain.get("is_dead") != true:
					var dist_sq_p := host_pos.distance_squared_to(player_node.global_position)
					if dist_sq_p < min_dist_sq:
						min_dist_sq = dist_sq_p
						closest_target = player_node
						
	# B. Check active monsters (Zombies/Goblins/Gargoyles in "hostiles" group)
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

## Symmetrical Override: Maps the localized, private State enum to 
## human-readable telemetry strings.
func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_GOLEM_STATE):
		return "IDLE"
		
	var state_val: int = host.get_meta(META_GOLEM_STATE) as int
	match state_val:
		State.IDLE:        return "IDLE"
		State.OVERWATCH:   return "OVERWATCH_PATROL"
		State.SPRINTING:   return "CHARGE_TO_TARGET"
		State.SLAM_ATTACK: return "LAUNCH_ATTACK"
		_: return "IDLE"
