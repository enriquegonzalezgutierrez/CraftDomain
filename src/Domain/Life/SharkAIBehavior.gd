# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: SharkAIBehavior
# Description: Specialized AI behavior strategy implementing the Great White 
#              Shark's aquatic predator routines. It scans the water volume for 
#              swimming players, accelerating into a high-speed chase vector, 
#              and executes coordinate bites. If the player is floating on 
#              the surface, it triggers a dynamic vertical leap attack.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): EXTREME REFACTOR. Declares and manages 
#   its own local state machine (SWIMMING, STALKING, LEAP_ATTACK) and telemetry reporting,
#   completely independent of monolithic global enums or zombie states.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. You can add new shark 
#   states (like resting, circling, biting boats) locally in this file without 
#   modifying any other AI system or the parent presenter.
# - Liskov Substitution Principle (LSP): Fully compatible with the IAIBehavior 
#   contract signatures.
# ==============================================================================
class_name SharkAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	SWIMMING,      # Standard passive ocean patrolling
	STALKING,      # Aggressive coordinate scent pursuit
	LEAP_ATTACK    # Executing vertical surface leaps and bites
}

const SPEED_CHASE: float = 4.2
const SPEED_SWIM: float = 1.8

const RANGE_SIGHT_SQ: float = 400.0 # 20.0 meters squared sensory radius
const RANGE_ATTACK_SQ: float = 4.0   # 2.0 meters squared bite radius
const COOLDOWN_ATTACK_SEC: float = 1.5

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "shark_wander_timer"
const META_WANDER_DIR := "shark_wander_dir"
const META_COOLDOWN := "shark_attack_cooldown"
const META_SHARK_STATE := "shark_local_state"


func _init() -> void:
	# Aquatic predators completely override standard wander schedules
	overrides_wandering = true


## Concrete Contract: Drives the active aquatic hunting and patrolling logic
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	
	# ==========================================================================
	# 1. ACUTE SCENT TRACKING (Detect player inside water)
	# ==========================================================================
	var is_tracking := false
	var player_node: Object = null
	var parent: Node = host.call("get_parent") as Node
	if is_instance_valid(parent):
		player_node = parent.call("get_node_or_null", "Player")
		
	var is_player_active: bool = is_instance_valid(player_node) and player_node.get("is_active") == true
	
	if is_player_active:
		var host_pos: Vector3 = host.get("global_position")
		var player_pos: Vector3 = player_node.get("global_position")
		var dist_sq: float = host_pos.distance_squared_to(player_pos)
		
		# Predatory rule: only track player if submerged or near water surface (Y <= 10.5)
		var is_player_swimming: bool = player_pos.y <= 10.5
		
		if dist_sq < RANGE_SIGHT_SQ and is_player_swimming:
			is_tracking = true
			var to_player: Vector3 = (player_pos - host_pos).normalized()
			wander_dir = to_player
			
			# Inside bite range: execute combat strike and apply leap momentum if needed
			if dist_sq <= RANGE_ATTACK_SQ:
				host.set_meta(META_SHARK_STATE, State.LEAP_ATTACK)
				ai.set("current_task", TASK_WORKING) # Set active task to clear REST/IDLE state!
				
				velocity.x = 0.0
				velocity.z = 0.0
				ai.set("wander_direction", to_player)
				
				if cooldown <= 0.0:
					cooldown = COOLDOWN_ATTACK_SEC
					host.set_meta(META_COOLDOWN, cooldown)
					
					# Attack bite
					if host.has_method("_bite_player"):
						host.call("_bite_player")
						
					# DYNAMIC LEAP ATTACK: Propel vertically upward if player is floating on top
					var vertical_diff: float = player_pos.y - host_pos.y
					if vertical_diff > 0.5:
						velocity.y = 4.5 # Symmetrical leap out of water!
						
					host.set("velocity", velocity)
					
					var vis_rep: Object = host.get("visual_representation")
					if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
						vis_rep.call("trigger_attack_visuals")
				else:
					host.set("velocity", velocity)
				return
			else:
				host.set_meta(META_SHARK_STATE, State.STALKING)
				ai.set("current_task", TASK_WORKING) # Set active task to clear REST/IDLE state!

	# ==========================================================================
	# 2. PATROLLING OCEAN REEFS (Standard wandering)
	# ==========================================================================
	if not is_tracking:
		host.set_meta(META_SHARK_STATE, State.SWIMMING)
		ai.set("current_task", TASK_WANDERING) # Set active task to clear REST/IDLE state!
		
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(2.0, 5.0)
			if randf() < 0.65:
				var angle := randf() * TAU
				var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
				
				if _is_direction_safe_shark(host, candidate_dir, parent):
					wander_dir = candidate_dir
				else:
					wander_dir = Vector3.ZERO
			else:
				wander_dir = Vector3.ZERO
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	# ==========================================================================
	# 3. APPLY TRANSLATION VECTORS
	# ==========================================================================
	if wander_dir != Vector3.ZERO:
		var speed_coef: float = SPEED_CHASE if is_tracking else SPEED_SWIM
		velocity.x = wander_dir.x * speed_coef
		velocity.z = wander_dir.z * speed_coef
		
		# Wave-riding horizontal tilt
		var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
		velocity.y = lerp(velocity.y, sin(time_sec * 2.0) * 0.12, delta * 3.0)
		
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_SWIM)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_SWIM)
		
		var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
		velocity.y = lerp(velocity.y, sin(time_sec * 1.5) * 0.05, delta * 3.0)
		
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_SHARK_STATE):
		host.set_meta(META_SHARK_STATE, State.SWIMMING)


## Safe Check: Ensures the shark remains strictly inside water blocks, avoiding shores and solid cliffs
func _is_direction_safe_shark(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true
		
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null:
		return true
		
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 2.0
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below: int = ws.get_block(block_below_coord)
	var block_at: int = ws.get_block(block_at_coord)
	
	# Restrict pathing from choosing routes straight into solid underwater block barriers
	if BlockType.is_solid(block_at as BlockType.Type):
		return false
		
	# Strict Aquatic Rule: The next targeted voxel must be Water (ID 6)
	return (block_below == 6 or block_at == 6)


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

## Symmetrical Override: Maps the localized, private State enum to 
## human-readable telemetry strings.
func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_SHARK_STATE):
		return "SWIMMING"
		
	var state_val: int = host.get_meta(META_SHARK_STATE) as int
	match state_val:
		State.SWIMMING:    return "SWIMMING"
		State.STALKING:    return "STALKING"
		State.LEAP_ATTACK: return "LEAP_ATTACK"
		_: return "SWIMMING"
