# ==============================================================================
# Pathfile: res://src/Domain/Life/WeaverMalakorAIBehavior.gd
# Description: Specialized AI behavior strategy implementing a multi-phase boss 
#              state machine for Weaver Malakor, the final boss (Act IV).
#              Phases: Sleep -> Static Beams -> Gravity Inversion -> Arena Fracture.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates strictly the mathematical 
#   decision-making and state transitions. Methods kept under 20 lines.
# - Open-Closed Principle (OCP): Extends IAIBehavior, supporting modular 
#   AI expansion.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WeaverMalakorAIBehavior
extends IAIBehavior

# Localized Multi-Phase State Machine
enum State {
	SLEEPING,    # Waiting for the player to reach the Cloud Loom
	CHASING,     # Phase 1: Slow hover-drift firing static laser beams
	ORBITING,    # Phase 2: High circular flight, inverted gravity, summoning gargoyles
	FRACTURING   # Phase 3: Total arena collapse, shields active, voxel mutations
}

const SPEED_HOVER: float = 1.6
const SPEED_ORBIT: float = 3.5
const RANGE_SIGHT_SQ: float = 576.0 # 24m arena detection range

const COOLDOWN_BEAM_SEC: float = 3.5
const COOLDOWN_SUMMON_SEC: float = 7.0
const COOLDOWN_MUTATION_SEC: float = 5.0

const THRESHOLD_PHASE_2_HP: int = 16 # Trigger orbit at 66% of 24 max HP
const THRESHOLD_PHASE_3_HP: int = 8  # Trigger fracture at 33% of 24 max HP

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "malakor_state"
const META_BEAM_COOLDOWN := "malakor_beam_cooldown"
const META_SUMMON_COOLDOWN := "malakor_summon_cooldown"
const META_MUTATION_COOLDOWN := "malakor_mutation_cooldown"


func _init() -> void:
	overrides_wandering = true # The final weaver remains bound to the Chrono-Loom


## Concrete Contract: Drives the final boss phases and cinematic transitions
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
		State.ORBITING:
			_process_orbiting(host, player_node)
		State.FRACTURING:
			_process_fracturing(host, player_node)


func _update_boss_timers(host: Object, delta: float) -> void:
	var beam_cd: float = host.get_meta(META_BEAM_COOLDOWN) as float
	if beam_cd > 0.0:
		host.set_meta(META_BEAM_COOLDOWN, beam_cd - delta)
		
	var summon_cd: float = host.get_meta(META_SUMMON_COOLDOWN) as float
	if summon_cd > 0.0:
		host.set_meta(META_SUMMON_COOLDOWN, summon_cd - delta)
		
	var mutation_cd: float = host.get_meta(META_MUTATION_COOLDOWN) as float
	if mutation_cd > 0.0:
		host.set_meta(META_MUTATION_COOLDOWN, mutation_cd - delta)


func _process_sleeping(host: Object, player_node: Object) -> void:
	_halt_movement(host)
	if is_instance_valid(player_node) and player_node.get("is_active"):
		var p_pos: Vector3 = player_node.get("global_position")
		var host_pos: Vector3 = host.get("global_position")
		if host_pos.distance_squared_to(p_pos) <= RANGE_SIGHT_SQ:
			host.set_meta(META_STATE, State.CHASING)
			if host.has_method("_play_malakor_awaken_voice"):
				host.call("_play_malakor_awaken_voice")


func _process_chasing(host: Object, player_node: Object) -> void:
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		host.set_meta(META_STATE, State.SLEEPING)
		return
		
	var hp := _get_entity_health(host)
	if hp <= THRESHOLD_PHASE_2_HP and hp > 0:
		_trigger_phase_2_orbit(host)
		return
		
	_hover_and_shoot_beam(host, player_node)


func _trigger_phase_2_orbit(host: Object) -> void:
	host.set_meta(META_STATE, State.ORBITING)
	_halt_movement(host)
	
	if host.has_method("_trigger_gravity_inversion"):
		host.call("_trigger_gravity_inversion")


func _process_orbiting(host: Object, player_node: Object) -> void:
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		host.set_meta(META_STATE, State.SLEEPING)
		return
		
	var hp := _get_entity_health(host)
	if hp <= THRESHOLD_PHASE_3_HP and hp > 0:
		host.set_meta(META_STATE, State.FRACTURING)
		_halt_movement(host)
		if host.has_method("_trigger_arena_fracture"):
			host.call("_trigger_arena_fracture")
		return
		
	_circular_flight_and_summon(host, player_node)


func _process_fracturing(host: Object, player_node: Object) -> void:
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		host.set_meta(META_STATE, State.SLEEPING)
		return
		
	_apply_unstable_shaking_physics(host)
	_trigger_periodic_block_mutations(host)


func _hover_and_shoot_beam(host: Object, player_node: Object) -> void:
	var host_pos: Vector3 = host.get("global_position")
	var p_pos: Vector3 = player_node.get("global_position")
	var diff := p_pos - host_pos
	diff.y = 0.0
	
	_apply_movement_vectors(host, diff.normalized(), SPEED_HOVER)
	
	var beam_cd: float = host.get_meta(META_BEAM_COOLDOWN) as float
	if beam_cd <= 0.0:
		host.set_meta(META_BEAM_COOLDOWN, COOLDOWN_BEAM_SEC)
		if host.has_method("_fire_static_laser_beam"):
			host.call("_fire_static_laser_beam", player_node)


func _circular_flight_and_summon(host: Object, player_node: Object) -> void:
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	# Calculate wide circular orbit centered on coordinates [0, Y, 0]
	var orbit_dir := Vector3(sin(time_sec * 0.5), 0.0, cos(time_sec * 0.5)).normalized()
	
	var host_pos: Vector3 = host.get("global_position")
	var vertical_drift: float = (24.5 - host_pos.y) * 0.12 # Maintain Y=24.5 altitude
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = orbit_dir.x * SPEED_ORBIT
	velocity.z = orbit_dir.z * SPEED_ORBIT
	velocity.y = lerp(velocity.y, vertical_drift, 0.12)
	host.set("velocity", velocity)
	
	_trigger_periodic_gargoyle_summon(host, player_node)


func _trigger_periodic_gargoyle_summon(host: Object, player_node: Object) -> void:
	var summon_cd: float = host.get_meta(META_SUMMON_COOLDOWN) as float
	if summon_cd <= 0.0:
		host.set_meta(META_SUMMON_COOLDOWN, COOLDOWN_SUMMON_SEC)
		if host.has_method("_spawn_gargoyle_servant"):
			host.call("_spawn_gargoyle_servant", player_node)


func _apply_unstable_shaking_physics(host: Object) -> void:
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var velocity: Vector3 = host.get("velocity") as Vector3
	
	# Fast vibration to simulate structural shield strain
	velocity.x = sin(time_sec * 25.0) * 0.25
	velocity.z = cos(time_sec * 25.0) * 0.25
	velocity.y = sin(time_sec * 4.0) * 0.08
	host.set("velocity", velocity)


func _trigger_periodic_block_mutations(host: Object) -> void:
	var mutation_cd: float = host.get_meta(META_MUTATION_COOLDOWN) as float
	if mutation_cd <= 0.0:
		host.set_meta(META_MUTATION_COOLDOWN, COOLDOWN_MUTATION_SEC)
		if host.has_method("_trigger_arena_voxel_shift"):
			host.call("_trigger_arena_voxel_shift")


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
	
	# Smoothly hover/glide at Y=23.5 altitude
	var host_pos: Vector3 = host.get("global_position")
	var vertical_drift: float = (23.5 - host_pos.y) * 0.12
	velocity.y = lerp(velocity.y, vertical_drift, 0.12)
	
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
	if not host.has_meta(META_BEAM_COOLDOWN): host.set_meta(META_BEAM_COOLDOWN, 0.0)
	if not host.has_meta(META_SUMMON_COOLDOWN): host.set_meta(META_SUMMON_COOLDOWN, 0.0)
	if not host.has_meta(META_MUTATION_COOLDOWN): host.set_meta(META_MUTATION_COOLDOWN, 0.0)


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
		State.SLEEPING:   return "IDLE"
		State.CHASING:    return "SCANNING_TREES" # Maps to a scanning/channeling string
		State.ORBITING:   return "BACKFLIP_PLAY"  # Maps to aerial acrobatics string
		State.FRACTURING: return "LAUNCH_ATTACK"  # Maps to seismic attack on UI
		_: return "IDLE"
