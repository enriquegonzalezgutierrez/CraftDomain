# ==============================================================================
# Pathfile: res://src/Domain/Life/LithicLurkerAIBehavior.gd
# Description: Specialized AI behavior strategy implementing a multi-phase boss 
#              state machine for the Lithic Lurker (Act I Boss).
#              Phases: Sleep -> Chase -> Ground Pound -> Stunned (Core Exposed).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates strictly the mathematical 
#   decision-making and phase transition timers for the boss.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LithicLurkerAIBehavior
extends IAIBehavior

# Localized Multi-Phase State Machine
enum State {
	SLEEPING,    # Waiting for player proximity in the magma chasm
	CHASING,     # Heavy pursuit
	LAUNCHING,   # Mid-air during a ground-pound attack
	STUNNED      # Recovering from pound, exposing the cyan core
}

const SPEED_CHASE: float = 2.6
const RANGE_SIGHT_SQ: float = 400.0 # 20m detection range
const RANGE_POUND_SQ: float = 25.0  # 5m strike radius
const COOLDOWN_POUND_SEC: float = 6.0
const DURATION_STUN_SEC: float = 3.5

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "lurker_state"
const META_COOLDOWN := "lurker_pound_cooldown"
const META_STUN_TIMER := "lurker_stun_timer"


func _init() -> void:
	overrides_wandering = true # Bosses do not wander, they hunt or sleep


## Concrete Contract: Drives the multi-phase boss logic and state transitions
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_boss_timers(host, delta)
	
	var player_node := _get_player_node(host)
	var state: int = host.get_meta(META_STATE) as int
	
	match state:
		State.SLEEPING:
			_process_sleeping_phase(host, player_node)
		State.CHASING:
			_process_chasing_phase(host, player_node)
		State.LAUNCHING:
			_process_launching_phase(host)
		State.STUNNED:
			_process_stunned_phase(host)


func _update_boss_timers(host: Object, delta: float) -> void:
	var pound_cd: float = host.get_meta(META_COOLDOWN) as float
	if pound_cd > 0.0:
		host.set_meta(META_COOLDOWN, pound_cd - delta)
		
	var stun_timer: float = host.get_meta(META_STUN_TIMER) as float
	if stun_timer > 0.0:
		host.set_meta(META_STUN_TIMER, stun_timer - delta)


func _process_sleeping_phase(host: Object, player_node: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		
	_halt_movement(host)
	
	if is_instance_valid(player_node) and player_node.get("is_active"):
		var p_pos: Vector3 = player_node.get("global_position")
		var host_pos: Vector3 = host.get("global_position")
		if host_pos.distance_squared_to(p_pos) <= RANGE_SIGHT_SQ:
			host.set_meta(META_STATE, State.CHASING)
			if host.has_method("_play_boss_awaken_roar"):
				host.call("_play_boss_awaken_roar")


func _process_chasing_phase(host: Object, player_node: Object) -> void:
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		host.set_meta(META_STATE, State.SLEEPING)
		return
		
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	var host_pos: Vector3 = host.get("global_position")
	var p_pos: Vector3 = player_node.get("global_position")
	var diff := p_pos - host_pos
	diff.y = 0.0
	
	var dist_sq := diff.length_squared()
	var pound_cd: float = host.get_meta(META_COOLDOWN) as float
	
	if dist_sq <= RANGE_POUND_SQ and pound_cd <= 0.0:
		_trigger_ground_pound_launch(host, diff.normalized())
	else:
		_apply_chase_velocity(host, diff.normalized())


func _trigger_ground_pound_launch(host: Object, forward_dir: Vector3) -> void:
	host.set_meta(META_STATE, State.LAUNCHING)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai): ai.set("wander_direction", forward_dir)
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.y = 8.5 # High leap
	velocity.x = forward_dir.x * (SPEED_CHASE * 1.5)
	velocity.z = forward_dir.z * (SPEED_CHASE * 1.5)
	host.set("velocity", velocity)


func _process_launching_phase(host: Object) -> void:
	# Wait until the boss physically lands back on the floor
	if host.call("is_on_floor"):
		host.set_meta(META_STATE, State.STUNNED)
		host.set_meta(META_COOLDOWN, COOLDOWN_POUND_SEC)
		host.set_meta(META_STUN_TIMER, DURATION_STUN_SEC)
		
		_halt_movement(host)
		
		if host.has_method("_execute_ground_pound_impact"):
			host.call("_execute_ground_pound_impact")


func _process_stunned_phase(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		
	_halt_movement(host)
	
	var stun_timer: float = host.get_meta(META_STUN_TIMER) as float
	if stun_timer <= 0.0:
		host.set_meta(META_STATE, State.CHASING)


func _halt_movement(host: Object) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0
	velocity.z = 0.0
	host.set("velocity", velocity)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai): ai.set("wander_direction", Vector3.ZERO)


func _apply_chase_velocity(host: Object, chase_dir: Vector3) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = chase_dir.x * SPEED_CHASE
	velocity.z = chase_dir.z * SPEED_CHASE
	host.set("velocity", velocity)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai): ai.set("wander_direction", chase_dir)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, State.SLEEPING)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_STUN_TIMER): host.set_meta(META_STUN_TIMER, 0.0)


func _get_player_node(host: Object) -> Object:
	if host.has_method("get_parent"):
		var parent: Node = host.call("get_parent") as Node
		if is_instance_valid(parent):
			return parent.call("get_node_or_null", "Player")
	return null


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "SLEEPING"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		State.SLEEPING:  return "IDLE"
		State.CHASING:   return "CHARGE_TO_TARGET"
		State.LAUNCHING: return "LAUNCH_ATTACK"
		State.STUNNED:   return "EXAMINING" # Maps to a vulnerable/resting string on UI
		_: return "IDLE"
