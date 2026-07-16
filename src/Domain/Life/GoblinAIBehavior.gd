# ==============================================================================
# Pathfile: res://src/Domain/Life/GoblinAIBehavior.gd
# Description: Specialized AI behavior strategy implementing the Goblin's 
#              sneaky hit-and-run skirmishing routines. Decomposed into short methods (SRP).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates guerrilla tracking logic, 
#   retreat timers, and directional flanking parameters.
# - Asymmetrical Tactics: The goblin is significantly faster when running away 
#   (SPEED_RETREAT) than when approaching (SPEED_CHASE), enhancing its elusive nature.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GoblinAIBehavior
extends IAIBehavior

# Localized State Machine
enum State {
	WANDERING,  # Standard passive roaming
	CHASING,    # Aggressive player pursuit
	RETREATING, # Running away rapidly after landing a hit
	ATTACKING   # Executing coordinate bites
}

const SPEED_CHASE: float = 3.5
const SPEED_WANDER: float = 1.6
const SPEED_RETREAT: float = 4.5

const RANGE_CHASE_SQ: float = 256.0 # 16.0 meters squared
const RANGE_ATTACK_SQ: float = 1.44 # 1.2 meters squared
const COOLDOWN_ATTACK_SEC: float = 1.2

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "goblin_wander_timer"
const META_WANDER_DIR := "goblin_wander_dir"
const META_COOLDOWN := "goblin_attack_cooldown"
const META_RETREAT_TIMER := "goblin_retreat_timer"
const META_GOBLIN_STATE := "goblin_local_state"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives the Goblin skirmishing/guerrilla combat loop
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_attack_cooldown(host, delta)
	
	var player_node := _get_player_node(host)
	
	# Priority 1: Retreat
	if _process_guerrilla_retreat(host, player_node, delta):
		return
		
	# Priority 2: Chase and Attack
	var is_tracking := false
	if is_instance_valid(player_node):
		is_tracking = _process_active_combat(host, player_node, delta)
		
	# Priority 3: Default wandering
	if not is_tracking:
		_process_default_roam(host, delta)


func _update_attack_cooldown(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)


func _process_guerrilla_retreat(host: Object, player_node: Object, delta: float) -> bool:
	var retreat_timer: float = host.get_meta(META_RETREAT_TIMER) as float
	if retreat_timer <= 0.0:
		return false
		
	retreat_timer -= delta
	host.set_meta(META_RETREAT_TIMER, retreat_timer)
	host.set_meta(META_GOBLIN_STATE, State.RETREATING)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return true
	
	ai.set("current_task", TASK_WANDERING) # Uses fast panic run animations
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if is_instance_valid(player_node) and player_node.get("is_active"):
		var player_pos: Vector3 = player_node.get("global_position")
		var opposite_dir: Vector3 = (host.global_position - player_pos).normalized()
		opposite_dir.y = 0.0
		
		# Proactive Wall Bounce: If trapped against a wall while retreating, bounce sideways
		if host.call("is_on_wall"):
			var wall_normal: Vector3 = host.call("get_wall_normal")
			var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
			if flat_normal != Vector3.ZERO:
				opposite_dir = opposite_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
				
		velocity.x = opposite_dir.x * SPEED_RETREAT
		velocity.z = opposite_dir.z * SPEED_RETREAT
		host.set("velocity", velocity)
		ai.set("wander_direction", opposite_dir)
		
	return true


func _process_active_combat(host: Object, player_node: Object, delta: float) -> bool:
	if not player_node.get("is_active"): return false
	
	var host_pos: Vector3 = host.get("global_position")
	var player_pos: Vector3 = player_node.get("global_position")
	var dist_sq: float = host_pos.distance_squared_to(player_pos)
	
	if dist_sq >= RANGE_CHASE_SQ: return false
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WORKING)
	var to_player := (player_pos - host_pos).normalized()
	to_player.y = 0.0
	
	if dist_sq <= RANGE_ATTACK_SQ:
		host.set_meta(META_GOBLIN_STATE, State.ATTACKING)
		_execute_goblin_strike(host, ai, to_player, delta)
	else:
		host.set_meta(META_GOBLIN_STATE, State.CHASING)
		_apply_computed_movement_vectors(host, to_player, SPEED_CHASE)
	return true


func _execute_goblin_strike(host: Object, ai: Object, to_player: Vector3, delta: float) -> void:
	# Avoid unused parameters warning in the contract
	var _d := delta
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	ai.set("wander_direction", to_player)
	
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_ATTACK_SEC)
		if host.has_method("_bite_player"):
			host.call("_bite_player")
			
		host.set_meta(META_RETREAT_TIMER, 1.4) # Trigger agile retreat sequence for 1.4s
		
		var vis_rep: Object = host.get("visual_representation")
		if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
			vis_rep.call("trigger_attack_visuals")


func _process_default_roam(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	host.set_meta(META_GOBLIN_STATE, State.WANDERING)
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		var angle := randf() * TAU
		var parent: Node = host.call("get_parent") as Node
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		wander_dir = candidate_dir if _is_direction_safe_goblin(host, candidate_dir, parent) else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, wander_dir, SPEED_WANDER)


func _apply_computed_movement_vectors(host: Object, wander_dir: Vector3, speed: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WANDER)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WANDER)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_RETREAT_TIMER): host.set_meta(META_RETREAT_TIMER, 0.0)
	if not host.has_meta(META_GOBLIN_STATE): host.set_meta(META_GOBLIN_STATE, State.WANDERING)


func _get_player_node(host: Object) -> Object:
	if host.has_method("get_parent"):
		var parent: Node = host.call("get_parent") as Node
		if is_instance_valid(parent):
			return parent.call("get_node_or_null", "Player")
	return null


func _is_direction_safe_goblin(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	return ws.get_block(block_below_coord) != 6 and ws.get_block(block_at_coord) != 6 and ws.get_block(block_below_coord) != 0


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_GOBLIN_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_GOBLIN_STATE) as int
	match state_val:
		State.WANDERING: return "WANDERING"
		State.CHASING:   return "CHASING"  
		State.ATTACKING: return "ATTACKING"
		State.RETREATING: return "PANIC" # Maps to the "ESCAPE" UI task string
		_: return "WANDER"
