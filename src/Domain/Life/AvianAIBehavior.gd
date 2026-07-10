# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: AvianAIBehavior
# Description: Specialized AI behavior strategy implementing realistic flight loops
#              for Avian Mobs (Birds and Parrots). It features smooth thermal 
#              gliding circles, autonomous perching on top of leaves blocks, and 
#              immediate panic takeoffs upon zombie threats.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates flight vectors, 
#   perching target checks, and takeoff/landing states. Restored to be 100% 
#   independent of presentation audio/vocalization timers.
# - Open-Closed Principle (OCP): Shared by both Bird and Parrot entities polymorphically.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/AvianAIBehavior.gd
# ==============================================================================
class_name AvianAIBehavior
extends IAIBehavior

const SPEED_SOAR: float = 1.4
const SPEED_GLIDE: float = 1.8
const PERCH_DURATION_SEC: float = 5.0

const RANGE_SENSORY_SQ: float = 225.0 # 15.0 meters squared leaf sensing radius

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Flight State machine: 0 = SOARING, 1 = LANDING_TO_PERCH, 2 = PERCHED
const STATE_SOARING = 0
const STATE_LANDING = 1
const STATE_PERCHED = 2

# Decoupled metadata keys to store state variables safely on the host node
const META_STATE := "avian_flight_state"
const META_WANDER_TIMER := "avian_wander_timer"
const META_WANDER_DIR := "avian_wander_dir"
const META_TARGET_LEAF := "avian_leaf_target"
const META_REST_TIMER := "avian_rest_timer"


func _init() -> void:
	# Avians completely override standard wander schedules
	overrides_wandering = true


## Concrete Contract: Drives circular soaring, landing glide, and perched rest
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var state: int = host.get_meta(META_STATE) as int
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var target_leaf: Vector3i = host.get_meta(META_TARGET_LEAF) as Vector3i
	var rest_timer: float = host.get_meta(META_REST_TIMER) as float
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node

	# Check panic takeoff conditions (If hit by zombies/player)
	var is_panicking := false
	if ai.get("current_task") as int == TASK_PANIC:
		is_panicking = true
		if state == STATE_PERCHED:
			# Take off startled! Set state to soaring immediately
			state = STATE_SOARING
			host.set_meta(META_STATE, state)
			target_leaf = Vector3i(0, -999, 0)
			host.set_meta(META_TARGET_LEAF, target_leaf)

	# ==========================================================================
	# STATE 2: PERCHED / RESTING (Halted on top of tree canopies)
	# ==========================================================================
	if state == STATE_PERCHED:
		ai.set("current_task", TASK_IDLE)
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.1 # keep anchored down
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)
		
		rest_timer -= delta
		if rest_timer <= 0.0:
			# Rest finished! Take off to soar
			state = STATE_SOARING
			host.set_meta(META_STATE, state)
			target_leaf = Vector3i(0, -999, 0)
			host.set_meta(META_TARGET_LEAF, target_leaf)
			
			# Ascend upward thrust
			velocity.y = 4.5
			host.set("velocity", velocity)
		else:
			host.set_meta(META_REST_TIMER, rest_timer)
		return

	# ==========================================================================
	# STATE 1: LANDING GLIDE (Descending towards targeted Leaves block)
	# ==========================================================================
	if state == STATE_LANDING and target_leaf.y != -999:
		ai.set("current_task", TASK_WORKING)
		
		# Target is slightly above leaf top face
		var target_pos := Vector3(target_leaf) + Vector3(0.5, 1.1, 0.5)
		var diff := target_pos - host_pos
		var dist_sq := diff.length_squared()
		
		if dist_sq > 0.64: # ~0.8m distance threshold
			# Glide towards the tree canopy top
			var glide_dir := diff.normalized()
			velocity.x = glide_dir.x * SPEED_GLIDE
			velocity.z = glide_dir.z * SPEED_GLIDE
			
			# Symmetrical descent angle
			velocity.y = move_toward(velocity.y, glide_dir.y * SPEED_GLIDE, delta * 3.0)
			
			host.set("velocity", velocity)
			ai.set("wander_direction", Vector3(glide_dir.x, 0.0, glide_dir.z).normalized())
		else:
			# Arrived! Settle down and rest
			velocity.x = 0.0
			velocity.y = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
			ai.set("wander_direction", Vector3.FORWARD)
			
			state = STATE_PERCHED
			rest_timer = PERCH_DURATION_SEC
			host.set_meta(META_STATE, state)
			host.set_meta(META_REST_TIMER, rest_timer)
		return

	# ==========================================================================
	# STATE 0: THERMAL SOARING (Wide smooth circles at Y = 16 to 24)
	# ==========================================================================
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	# Glide circle calculations
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(3.0, 6.0)
		
		# Search for perching leaves dynamically (only when not panicking)
		var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
		if ws != null and not is_panicking and randf() < 0.35:
			var leaves_coord := _scan_for_nest_leaves(host_pos, ws)
			if leaves_coord.y != -999:
				target_leaf = leaves_coord
				state = STATE_LANDING
				host.set_meta(META_STATE, state)
				host.set_meta(META_TARGET_LEAF, target_leaf)
				return
				
		host.set_meta(META_WANDER_TIMER, wander_timer)

	# Thermal circle math: trace visual ring vectors based on sine of elapsed time
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var soar_freq := 0.6 if is_panicking else 0.35
	
	# Trigonometric horizontal vector ring
	wander_dir = Vector3(sin(time_sec * soar_freq), 0.0, cos(time_sec * soar_freq)).normalized()
	
	# Smooth vertical altitude corrections: drift towards Y range [16..24]
	var current_y: float = host_pos.y
	var target_y := 21.0 if is_panicking else 18.0
	var vertical_drift: float = (target_y - current_y) * 0.12
	
	velocity.x = wander_dir.x * (SPEED_SOAR * (2.2 if is_panicking else 1.0))
	velocity.z = wander_dir.z * (SPEED_SOAR * (2.2 if is_panicking else 1.0))
	velocity.y = lerp(velocity.y, vertical_drift + sin(time_sec * 2.5) * 0.15, delta * 4.0)
	
	host.set("velocity", velocity)
	ai.set("wander_direction", wander_dir)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE):
		host.set_meta(META_STATE, STATE_SOARING)
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_TARGET_LEAF):
		host.set_meta(META_TARGET_LEAF, Vector3i(0, -999, 0))
	if not host.has_meta(META_REST_TIMER):
		host.set_meta(META_REST_TIMER, 0.0)


## Proximity Scanner: Scans adjacent blocks looking for free tree leaves (ID 5) to land on
func _scan_for_nest_leaves(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	
	# Scans in a wide 11x9x11 volume
	for x: int in range(-5, 6):
		for y: int in range(-4, 5):
			for z: int in range(-5, 6):
				var check_coord := my_coord + Vector3i(x, y, z)
				
				# Block ID 5 is Leaves
				if ws.get_block(check_coord) == 5:
					# Check clearance: the space directly above the leaf must be AIR
					if ws.get_block(check_coord + Vector3i(0, 1, 0)) == 0:
						return check_coord
						
	return Vector3i(0, -999, 0)
