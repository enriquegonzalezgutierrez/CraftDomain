# ==============================================================================
# Pathfile: res://src/Domain/Life/ZombieAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing hostile zombie routines,
#              including player tracking, glitched spotted roars, and wall flanking.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly zombie state 
#   transitions, alert roaring periods, and flanking vectors.
# - Layered DDD Compliance: Pure logical state calculations with zero framework 
#   leakage, keeping physical translations and audio players in Infrastructure.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ZombieAIBehavior
extends IAIBehavior

# Localized State Machine
enum State {
	WANDERING,  # Standard passive roaming
	ALERTED,    # Spotted player: freezing and roaring for 0.8s
	CHASING,    # Aggressive player pursuit
	ATTACKING   # Executing coordinate bites
}

const SPEED_CHASE: float = 2.2
const SPEED_WANDER: float = 1.1

const RANGE_CHASE_SQ: float = 256.0 # 16.0 meters squared
const RANGE_ATTACK_SQ: float = 1.44 # 1.2 meters squared
const COOLDOWN_ATTACK_SEC: float = 1.5
const ALERT_DURATION_SEC: float = 0.8

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "zombie_wander_timer"
const META_WANDER_DIR := "zombie_wander_dir"
const META_COOLDOWN := "zombie_attack_cooldown"
const META_STUCK_TIMER := "zombie_stuck_timer"
const META_ZOMBIE_STATE := "zombie_local_state"
const META_SPOTTED_PLAYER := "zombie_spotted_player"
const META_ALERT_TIMER := "zombie_alert_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives scent-tracking alert roars, pursuit, and attack cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_cooldowns(host, delta)
	
	var state: int = host.get_meta(META_ZOMBIE_STATE) as int
	if state == State.ALERTED:
		_process_alert_state(host, delta)
		return
		
	var player_node := _get_player_node(host)
	var is_tracking := false
	
	if is_instance_valid(player_node) and player_node.get("is_active") == true:
		is_tracking = _process_active_combat_decisions(host, player_node, state)
		
	if not is_tracking:
		_process_passive_wandering(host, delta)


func _update_cooldowns(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_COOLDOWN, cooldown - delta)


func _process_alert_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WORKING) # Disables autonomous wander animations
	ai.set("wander_direction", Vector3.ZERO)
	
	var alert_timer: float = host.get_meta(META_ALERT_TIMER) as float
	alert_timer -= delta
	
	if alert_timer <= 0.0:
		# Alert roar finished, proceed to active chase
		host.set_meta(META_ZOMBIE_STATE, State.CHASING)
	else:
		host.set_meta(META_ALERT_TIMER, alert_timer)


func _process_active_combat_decisions(host: Object, player_node: Object, current_state: int) -> bool:
	var host_pos: Vector3 = host.get("global_position")
	var player_pos: Vector3 = player_node.get("global_position")
	var dist_sq := host_pos.distance_squared_to(player_pos)
	
	if dist_sq >= RANGE_CHASE_SQ:
		host.set_meta(META_SPOTTED_PLAYER, false)
		return false
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	var is_spotted: bool = host.get_meta(META_SPOTTED_PLAYER) as bool
	if not is_spotted:
		# Trigger the initial glitched spotted roar phase
		host.set_meta(META_SPOTTED_PLAYER, true)
		host.set_meta(META_ZOMBIE_STATE, State.ALERTED)
		host.set_meta(META_ALERT_TIMER, ALERT_DURATION_SEC)
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
		
		if host.has_method("_play_spotted_roar"):
			host.call("_play_spotted_roar", player_node)
		return true
		
	# Determine if within bite reach
	if dist_sq <= RANGE_ATTACK_SQ:
		host.set_meta(META_ZOMBIE_STATE, State.ATTACKING)
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	else:
		if current_state != State.ALERTED:
			host.set_meta(META_ZOMBIE_STATE, State.CHASING)
			var to_player := (player_pos - host_pos).normalized()
			to_player.y = 0.0
			host.set_meta(META_WANDER_DIR, to_player)
			
	return true


func _process_passive_wandering(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WANDERING)
	host.set_meta(META_ZOMBIE_STATE, State.WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		var is_moving := randf() > 0.4
		if is_moving:
			var angle := randf() * TAU
			host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0, sin(angle)))
			host.set_meta(META_WANDER_TIMER, randf_range(2.0, 5.0))
		else:
			host.set_meta(META_WANDER_DIR, Vector3.ZERO)
			host.set_meta(META_WANDER_TIMER, randf_range(1.0, 3.0))
	else:
		host.set_meta(META_WANDER_TIMER, wander_timer)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_STUCK_TIMER): host.set_meta(META_STUCK_TIMER, 0.0)
	if not host.has_meta(META_ZOMBIE_STATE): host.set_meta(META_ZOMBIE_STATE, State.WANDERING)
	if not host.has_meta(META_SPOTTED_PLAYER): host.set_meta(META_SPOTTED_PLAYER, false)
	if not host.has_meta(META_ALERT_TIMER): host.set_meta(META_ALERT_TIMER, 0.0)


func _get_player_node(host: Object) -> Object:
	if host.has_method("get_parent"):
		var parent: Node = host.call("get_parent") as Node
		if is_instance_valid(parent):
			return parent.call("get_node_or_null", "Player")
	return null


func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_ZOMBIE_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_ZOMBIE_STATE) as int
	match state_val:
		State.ALERTED: return "EXAMINE"  # Maps to "EXAMINING ENTORNO" on UI
		State.CHASING: return "CHASING"  # Maps to "CHASING" on UI
		State.ATTACKING: return "ATTACKING"
		_: return "WANDER"
