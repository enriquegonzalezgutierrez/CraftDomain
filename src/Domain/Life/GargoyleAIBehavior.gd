# ==============================================================================
# Pathfile: res://src/Domain/Life/GargoyleAIBehavior.gd
# Description: Specialized AI behavior strategy implementing the Gargoyle's 
#              nocturnal state machine. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GargoyleAIBehavior
extends IAIBehavior

const SPEED_CHASE: float = 3.0
const SPEED_WANDER: float = 1.5

const RANGE_SIGHT_SQ: float = 256.0 
const RANGE_ATTACK_SQ: float = 3.0
const COOLDOWN_ATTACK_SEC: float = 1.5

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "gargoyle_nocturnal_state" # 0 = STONE, 1 = AWAKE
const META_WANDER_TIMER := "gargoyle_wander_timer"
const META_WANDER_DIR := "gargoyle_wander_dir"
const META_COOLDOWN := "gargoyle_attack_cooldown"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives the Gargoyle Day/Night flight hunt state machine
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_attack_cooldown(host, delta)
	
	var is_night := CelestialService.is_night_time_static()
	_evaluate_state_transitions(host, is_night)
	
	var state: int = host.get_meta(META_STATE) as int
	if state == 0:
		_process_daytime_petrification(host, delta)
	else:
		var player_node := _get_player_node(host)
		var is_tracking := false
		if is_instance_valid(player_node):
			is_tracking = _process_nighttime_hunt(host, player_node, delta)
			
		if not is_tracking:
			_process_default_soar(host, delta)


func _update_attack_cooldown(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)


func _evaluate_state_transitions(host: Object, is_night: bool) -> void:
	var state: int = host.get_meta(META_STATE) as int
	if is_night and state == 0: 
		host.set_meta(META_STATE, 1) # Stone -> Awake
		if host.has_method("_set_gargoyle_stone_appearance"):
			host.call("_set_gargoyle_stone_appearance", false)
	elif not is_night and state == 1: 
		host.set_meta(META_STATE, 0) # Awake -> Stone
		if host.has_method("_set_gargoyle_stone_appearance"):
			host.call("_set_gargoyle_stone_appearance", true)


func _process_daytime_petrification(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_IDLE)
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = move_toward(velocity.x, 0.0, SPEED_CHASE * delta)
	velocity.z = move_toward(velocity.z, 0.0, SPEED_CHASE * delta)
	host.set("velocity", velocity)
	ai.set("wander_direction", Vector3.ZERO)


func _process_nighttime_hunt(host: Object, player_node: Object, delta: float) -> bool:
	if not player_node.get("is_active"): return false
	
	var host_pos: Vector3 = host.get("global_position")
	var player_pos: Vector3 = player_node.get("global_position")
	var dist_sq: float = host_pos.distance_squared_to(player_pos)
	
	if dist_sq >= RANGE_SIGHT_SQ: return false
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WORKING)
	var to_player := (player_pos - host_pos).normalized()
	to_player.y = 0.0
	
	if dist_sq <= RANGE_ATTACK_SQ:
		_execute_gargoyle_strike(host, ai, to_player, delta)
	else:
		_apply_computed_movement_vectors(host, to_player, true)
	return true


func _execute_gargoyle_strike(host: Object, ai: Object, to_player: Vector3, delta: float) -> void:
	# Avoid unused parameters warning in the overridden contract
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
			
		var vis_rep: Object = host.get("visual_representation")
		if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
			vis_rep.call("trigger_attack_visuals")


func _process_default_soar(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		wander_dir = Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU)) if randf() > 0.4 else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, wander_dir, false)


func _apply_computed_movement_vectors(host: Object, wander_dir: Vector3, is_chasing: bool) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		var speed := SPEED_CHASE if is_chasing else SPEED_WANDER
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WANDER)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WANDER)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, 0) 
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)


func _get_player_node(host: Object) -> Object:
	if host.has_method("get_parent"):
		var parent: Node = host.call("get_parent") as Node
		if is_instance_valid(parent):
			return parent.call("get_node_or_null", "Player")
	return null
