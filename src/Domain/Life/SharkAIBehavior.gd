# ==============================================================================
# Pathfile: res://src/Domain/Life/SharkAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing hunting and 
#              hydrodynamic patrolling for the hostile Great White Shark.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly shark state 
#   transitions, scent tracking, and attack triggers.
# - Open-Closed Principle (OCP): Extends IAIBehavior, closing existing 
#   movement systems to modification.
# - Volume-Based Navigation: Evaluates fluid/air volume transitability, 
#   completely eliminating floor-bound boundary check bugs for aquatic entities.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SharkAIBehavior
extends IAIBehavior

# Localized State Machine
enum State {
	SWIMMING,      
	STALKING,      
	LEAP_ATTACK    
}

const SPEED_CHASE: float = 4.2
const SPEED_SWIM: float = 1.8

const RANGE_SIGHT_SQ: float = 400.0 
const RANGE_ATTACK_SQ: float = 4.0   
const COOLDOWN_ATTACK_SEC: float = 1.5

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "shark_wander_timer"
const META_WANDER_DIR := "shark_wander_dir"
const META_COOLDOWN := "shark_attack_cooldown"
const META_SHARK_STATE := "shark_local_state"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives the active aquatic hunting and patrolling logic
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_attack_cooldown(host, delta)
	
	var player_node := _get_player_node(host)
	var is_tracking := false
	
	if is_instance_valid(player_node):
		is_tracking = _process_player_hunting(host, player_node, delta)
		
	if not is_tracking:
		_process_aquatic_patrol(host, delta)


func _update_attack_cooldown(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)


func _process_player_hunting(host: Object, player_node: Object, delta: float) -> bool:
	if not player_node.get("is_active"): return false
	
	var host_pos: Vector3 = host.get("global_position")
	var player_pos: Vector3 = player_node.get("global_position")
	var dist_sq: float = host_pos.distance_squared_to(player_pos)
	
	# Predatory constraint: Only hunt if player is swimming/submerged
	var is_player_swimming: bool = player_pos.y <= 10.5
	if dist_sq >= RANGE_SIGHT_SQ or not is_player_swimming:
		return false
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WORKING)
	var to_player := (player_pos - host_pos).normalized()
	
	if dist_sq <= RANGE_ATTACK_SQ:
		_execute_shark_bite(host, ai, player_node, to_player, delta)
	else:
		host.set_meta(META_SHARK_STATE, State.STALKING)
		_apply_computed_movement_vectors(host, ai, to_player, SPEED_CHASE, delta)
	return true


func _execute_shark_bite(host: Object, ai: Object, player_node: Object, to_player: Vector3, delta: float) -> void:
	var _d := delta
	host.set_meta(META_SHARK_STATE, State.LEAP_ATTACK)
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	ai.set("wander_direction", to_player)
	
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_ATTACK_SEC)
		if host.has_method("_bite_player"):
			host.call("_bite_player")
			
		# Propel vertically if player is floating on water surface
		var player_pos: Vector3 = player_node.get("global_position")
		if player_pos.y - host.global_position.y > 0.5:
			velocity.y = 4.5
			
		var vis_rep: Object = host.get("visual_representation")
		if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
			vis_rep.call("trigger_attack_visuals")
			
	host.set("velocity", velocity)


func _process_aquatic_patrol(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	host.set_meta(META_SHARK_STATE, State.SWIMMING)
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		var parent: Node = host.call("get_parent") as Node
		var angle := randf() * TAU
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		
		# Proactively verify transitability of the target coordinate
		wander_dir = candidate_dir if _is_direction_safe_shark(host, candidate_dir, parent) else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, ai, wander_dir, SPEED_SWIM, delta)


func _apply_computed_movement_vectors(host: Object, ai: Object, wander_dir: Vector3, speed: float, delta: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		velocity.y = lerp(velocity.y, sin(time_sec * 2.0) * 0.12, delta * 3.0)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_SWIM)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_SWIM)
		velocity.y = lerp(velocity.y, sin(time_sec * 1.5) * 0.05, delta * 3.0)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_SHARK_STATE): host.set_meta(META_SHARK_STATE, State.SWIMMING)


func _get_player_node(host: Object) -> Object:
	if host.has_method("get_parent"):
		var parent: Node = host.call("get_parent") as Node
		if is_instance_valid(parent):
			return parent.call("get_node_or_null", "Player")
	return null


## Fluid Volume Scanner: Validates if the target coordinate is safely transitable (Water, Lava, or Air during leaps)
func _is_direction_safe_shark(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: 
		return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: 
		return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 2.0
	
	# Map the 3D coordinate the shark wishes to swim into
	var target_coord := Vector3i(floori(check_pos.x), floori(check_pos.y), floori(check_pos.z))
	var target_block := ws.get_block(target_coord)
	
	# Safe to swim if target is fluid (Water 6, Lava 15) or Air (0, for leaps)
	var is_fluid_or_air: bool = (target_block == 6 or target_block == 15 or target_block == 0)
	
	return is_fluid_or_air and not BlockType.is_solid(target_block)
