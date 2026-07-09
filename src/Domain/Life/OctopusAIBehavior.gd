# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: OctopusAIBehavior
# Description: Specialized AI behavior strategy implementing rhythmic jet-propulsion
#              swimming loops for the Deep-Water Octopus. Features timed propulsion
#              bursts, drift phases, and a defensive ink spray reflex when startled,
#              instating high-speed panic escapes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the cefalopod's 
#   jet-propulsion cycles and defensive alerts, keeping physics decoupled.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New camouflage states,
#   tentacle grab sweeps, or reef hiding can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/OctopusAIBehavior.gd
# ==============================================================================
class_name OctopusAIBehavior
extends IAIBehavior

const SPEED_JET: float = 2.8
const SPEED_DRIFT: float = 0.4
const SPEED_PANIC_JET: float = 4.2

const COOLDOWN_INK_SEC: float = 5.0
const JET_CYCLE_DURATION_SEC: float = 2.0

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5

# Decoupled metadata keys to store state variables safely on the host node
const META_JET_TIMER := "octopus_jet_timer"
const META_WANDER_DIR := "octopus_wander_dir"
const META_INK_COOLDOWN := "octopus_ink_cooldown"
const META_FLEE_TIMER := "octopus_flee_timer"


func _init() -> void:
	# Octopuses manage their 3D aquatic vectors completely
	overrides_wandering = true


## Concrete Contract: Drives pulsing jet propulsion and tactical ink evasion cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Skip routines if talking to the player
	if host.get("is_talking") == true:
		_reset_octopus_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	var jet_timer: float = host.get_meta(META_JET_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var ink_cooldown: float = host.get_meta(META_INK_COOLDOWN) as float
	var flee_timer: float = host.get_meta(META_FLEE_TIMER) as float
	
	if ink_cooldown > 0.0:
		ink_cooldown -= delta
		host.set_meta(META_INK_COOLDOWN, ink_cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var parent: Node = host.call("get_parent") as Node

	# Determine if under panic/startle threat
	var is_panicking := false
	if ai.get("current_task") as int == TASK_PANIC or flee_timer > 0.0:
		is_panicking = true
		if flee_timer <= 0.0:
			flee_timer = 3.5 # flee for 3.5s
			
		flee_timer -= delta
		host.set_meta(META_FLEE_TIMER, flee_timer)

	# ==========================================================================
	# 1. DEFENSIVE INK SPRAY REFLEX (Triggers ink cloud under panic damage)
	# ==========================================================================
	if is_panicking:
		ai.set("current_task", TASK_PANIC)
		
		# Spray dark ink shroud to blind enemies (cooldown 5s)
		if ink_cooldown <= 0.0:
			ink_cooldown = COOLDOWN_INK_SEC
			host.set_meta(META_INK_COOLDOWN, ink_cooldown)
			if host.has_method("_play_ink_spray"):
				host.call("_play_ink_spray")
		
		# Frantic escape: choose random horizontal flight path away from threats
		jet_timer -= delta
		if jet_timer <= 0.0 or wander_dir == Vector3.ZERO:
			jet_timer = 0.8 # Rapid panic jet bursts
			var angle := randf() * TAU
			var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
			
			if _is_direction_safe_octopus(host, candidate_dir, parent):
				wander_dir = candidate_dir
			else:
				wander_dir = Vector3.ZERO
				
		host.set_meta(META_JET_TIMER, jet_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)
		
		# Propel frantically
		if wander_dir != Vector3.ZERO:
			velocity.x = wander_dir.x * SPEED_PANIC_JET
			velocity.z = wander_dir.z * SPEED_PANIC_JET
			velocity.y = randf_range(-0.5, 0.5) # Escape altitude shifts
			host.set("velocity", velocity)
			ai.set("wander_direction", wander_dir)
		return

	# ==========================================================================
	# 2. RHYTHMIC SWIMMING PULSES (Jet Contraction vs Drifting Glides)
	# ==========================================================================
	ai.set("current_task", TASK_WANDERING)
	
	jet_timer -= delta
	if jet_timer <= 0.0:
		# Siphon Reload finished! Trigger next jet contraction heading
		jet_timer = JET_CYCLE_DURATION_SEC
		var angle := randf() * TAU
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		
		if _is_direction_safe_octopus(host, candidate_dir, parent):
			wander_dir = candidate_dir
		else:
			wander_dir = Vector3.ZERO
			
		host.set_meta(META_WANDER_DIR, wander_dir)
		
	host.set_meta(META_JET_TIMER, jet_timer)

	# Pulsing speed coefficient math based on elapsed cycle time
	var speed_coef := SPEED_DRIFT
	var time_elapsed := JET_CYCLE_DURATION_SEC - jet_timer
	
	if time_elapsed <= 0.6:
		# Jet contraction burst: Accelerate rapidly and fade out to glide speed
		var t := time_elapsed / 0.6
		speed_coef = lerp(SPEED_JET, SPEED_DRIFT, t)
	else:
		# Siphon Gliding: drift slowly on the water currents
		speed_coef = SPEED_DRIFT

	# Apply velocities
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * speed_coef
		velocity.z = wander_dir.z * speed_coef
		
		# Symmetrical slow rise/sink current drift
		var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
		velocity.y = sin(time_sec * 1.5) * 0.08
		
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_DRIFT)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_DRIFT)
		
		var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
		velocity.y = sin(time_sec * 1.0) * 0.04
		
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_JET_TIMER):
		host.set_meta(META_JET_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_INK_COOLDOWN):
		host.set_meta(META_INK_COOLDOWN, 0.0)
	if not host.has_meta(META_FLEE_TIMER):
		host.set_meta(META_FLEE_TIMER, 0.0)


## BUG FIX: Corrected state reset keys to match exact octopus parameters
func _reset_octopus_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_JET_TIMER, 0.0)
	host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	host.set_meta(META_FLEE_TIMER, 0.0)


## Safe Check: Ensures the Octopus strictly swims inside Water block coordinates (ID 6)
func _is_direction_safe_octopus(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return true
		
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null:
		return true
		
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below: int = ws.get_block(block_below_coord)
	var block_at: int = ws.get_block(block_at_coord)
	
	# Allowed aquatic block: WATER = 6
	return (block_below == 6 or block_at == 6)
