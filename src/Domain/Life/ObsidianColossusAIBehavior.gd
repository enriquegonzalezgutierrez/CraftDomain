# ==============================================================================
# Pathfile: res://src/Domain/Life/ObsidianColossusAIBehavior.gd
# Description: Specialized AI behavior strategy implementing a multi-phase boss 
#              state machine for the Obsidian Colossus (Act III Boss).
#              Phases: Sleep -> Walk Chase -> Rage Charge -> Volcanic Stomp.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates strictly the mathematical 
#   decision-making and state transitions. Methods kept under 20 lines.
# - Open-Closed Principle (OCP): Extends IAIBehavior, supporting modular 
#   AI expansion.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ObsidianColossusAIBehavior
extends IAIBehavior

# Localized Multi-Phase State Machine
enum State {
	SLEEPING,    # Standing dormant until the player approaches
	CHASING,     # Slow, heavy volcanic march
	CHARGING,    # Fast, rage-fueled charge (active under 50% HP)
	STOMPING     # Channeling an earthquake volcanic ground-pound
}

const SPEED_WALK: float = 1.1
const SPEED_CHARGE: float = 3.2
const RANGE_SIGHT_SQ: float = 400.0 # 20m detection range
const RANGE_STOMP_SQ: float = 16.0  # 4m strike radius
const COOLDOWN_STOMP_SEC: float = 4.5
const DURATION_STOMP_CHANNEL_SEC: float = 1.8
const THRESHOLD_RAGE_HP: int = 12   # Under 50% of 24 max HP

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "colossus_state"
const META_STOMP_COOLDOWN := "colossus_stomp_cooldown"


func _init() -> void:
	overrides_wandering = true # Colossal bosses remain anchored to their arenas


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
			_process_sleeping(host, player_node)
		State.CHASING:
			_process_chasing(host, player_node)
		State.CHARGING:
			_process_charging(host, player_node)
		State.STOMPING:
			_process_stomping(host)


func _update_boss_timers(host: Object, delta: float) -> void:
	var stomp_cd: float = host.get_meta(META_STOMP_COOLDOWN) as float
	if stomp_cd > 0.0:
		host.set_meta(META_STOMP_COOLDOWN, stomp_cd - delta)


func _process_sleeping(host: Object, player_node: Object) -> void:
	_halt_movement(host)
	if is_instance_valid(player_node) and player_node.get("is_active"):
		var p_pos: Vector3 = player_node.get("global_position")
		var host_pos: Vector3 = host.get("global_position")
		if host_pos.distance_squared_to(p_pos) <= RANGE_SIGHT_SQ:
			host.set_meta(META_STATE, State.CHASING)
			if host.has_method("_play_colossus_awaken_growl"):
				host.call("_play_colossus_awaken_growl")


func _process_chasing(host: Object, player_node: Object) -> void:
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		host.set_meta(META_STATE, State.SLEEPING)
		return
		
	var hp := _get_entity_health(host)
	if hp <= THRESHOLD_RAGE_HP and hp > 0:
		host.set_meta(META_STATE, State.CHARGING)
		if host.has_method("_play_rage_ignite_roar"):
			host.call("_play_rage_ignite_roar")
		return
		
	_navigate_or_stomp(host, player_node, SPEED_WALK)


func _process_charging(host: Object, player_node: Object) -> void:
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		host.set_meta(META_STATE, State.SLEEPING)
		return
		
	_navigate_or_stomp(host, player_node, SPEED_CHARGE)


func _process_stomping(host: Object) -> void:
	_halt_movement(host)
	var stomp_timer: float = host.get_meta(META_STOMP_COOLDOWN) as float
	
	# Transition back to active chase after the channeling wind-up expires
	if stomp_timer <= (COOLDOWN_STOMP_SEC - DURATION_STOMP_CHANNEL_SEC):
		var hp := _get_entity_health(host)
		var next_state := State.CHARGING if hp <= THRESHOLD_RAGE_HP else State.CHASING
		host.set_meta(META_STATE, next_state)


func _navigate_or_stomp(host: Object, player_node: Object, speed: float) -> void:
	var host_pos: Vector3 = host.get("global_position")
	var p_pos: Vector3 = player_node.get("global_position")
	var diff := p_pos - host_pos
	diff.y = 0.0
	
	var dist_sq := diff.length_squared()
	var stomp_cd: float = host.get_meta(META_STOMP_COOLDOWN) as float
	
	if dist_sq <= RANGE_STOMP_SQ and stomp_cd <= 0.0:
		_trigger_volcanic_stomp(host, diff.normalized())
	else:
		_apply_movement_vectors(host, diff.normalized(), speed)


func _trigger_volcanic_stomp(host: Object, forward_dir: Vector3) -> void:
	host.set_meta(META_STATE, State.STOMPING)
	host.set_meta(META_STOMP_COOLDOWN, COOLDOWN_STOMP_SEC)
	_halt_movement(host)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("wander_direction", forward_dir)
		ai.set("current_task", TASK_WORKING)
		
	if host.has_method("_execute_lava_stomp_attack"):
		host.call("_execute_lava_stomp_attack")


func _halt_movement(host: Object) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0
	velocity.z = 0.0
	host.set("velocity", velocity)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("wander_direction", Vector3.ZERO)


func _apply_movement_vectors(host: Object, chase_dir: Vector3, speed: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = chase_dir.x * speed
	velocity.z = chase_dir.z * speed
	host.set("velocity", velocity)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("wander_direction", chase_dir)
		ai.set("current_task", TASK_WORKING)


func _get_entity_health(host: Object) -> int:
	var domain: Object = host.get("domain_entity")
	if is_instance_valid(domain):
		return domain.get("health") as int
	return 0


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, State.SLEEPING)
	if not host.has_meta(META_STOMP_COOLDOWN): host.set_meta(META_STOMP_COOLDOWN, 0.0)


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
		State.SLEEPING: return "IDLE"
		State.CHASING:  return "PATROLLING"
		State.CHARGING: return "CHARGE_TO_TARGET"
		State.STOMPING: return "LAUNCH_ATTACK" # Maps to a slam attack string on UI
		_: return "IDLE"
