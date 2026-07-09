# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: CyberCitizenAIBehavior
# Description: Specialized AI behavior strategy implementing robotic routines for
#              the Cyber Citizen Android NPC. It features high-efficiency road 
#              tracking (prioritizing walking along paved highway blocks) and a 
#              diagnostic security sweep, halting movement to execute high-precision 
#              90-degree rotations while triggering cyan scanning rays.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the robotic decision
#   trees, diagnostic sweeps, and highway alignments of the Cyber Citizen.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New data logging, 
#   hacking overrides, or energy recharges can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/CyberCitizenAIBehavior.gd
# ==============================================================================
class_name CyberCitizenAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.1
const SCAN_INTERVAL_SEC: float = 4.0
const SCAN_DURATION_SEC: float = 1.6 # 4 step-rotations of 0.4s each

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_SCAN_TIMER := "cyber_scan_timer"
const META_ROT_STEP := "cyber_rot_step"
const META_WANDER_TIMER := "cyber_wander_timer"
const META_WANDER_DIR := "cyber_wander_dir"


func _init() -> void:
	# Cyber Citizens completely manage their coordinate vectors
	overrides_wandering = true


## Concrete Contract: Drives high-efficiency road pathing and robotic diagnostics
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Skip routines if talking to the player
	if host.get("is_talking") == true:
		_reset_cyber_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	var scan_timer: float = host.get_meta(META_SCAN_TIMER) as float
	var rot_step: int = host.get_meta(META_ROT_STEP) as int
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node

	# ==========================================================================
	# 1. DIAGNOSTIC SWEEP STATE: ROBOTIC 90-DEGREE STEPS ROTATION
	# ==========================================================================
	var current_task: int = ai.get("current_task") as int
	
	if current_task == TASK_WORKING:
		velocity.x = 0.0
		velocity.z = 0.0
		host.set("velocity", velocity)
		
		scan_timer -= delta
		if scan_timer <= 0.0:
			# Diagnostics finished! Reset to patrol
			_reset_cyber_state(host)
			return
			
		# Step angle calculation: rotate 90 degrees (PI/2 rad) every 0.4 seconds
		var new_step: int = floori((SCAN_DURATION_SEC - scan_timer) / 0.4)
		if new_step != rot_step:
			rot_step = new_step
			host.set_meta(META_ROT_STEP, rot_step)
			
			# Map Cardinal direction vectors based on current step
			var angle: float = float(rot_step) * (PI / 2.0)
			var step_dir := Vector3(cos(angle), 0.0, sin(angle))
			ai.set("wander_direction", step_dir)
			
			# Trigger cyber lasers diagnostic scan inside the presentation layer
			if host.has_method("_play_security_scan"):
				host.call("_play_security_scan")
				
		host.set_meta(META_SCAN_TIMER, scan_timer)
		return

	# ==========================================================================
	# 2. SEAPORT ROAD ALIGNMENT & WANDERING
	# ==========================================================================
	# Countdown until next diagnostic scan is triggered
	scan_timer -= delta
	if scan_timer <= 0.0:
		# Trigger diagnostic sweep
		scan_timer = SCAN_DURATION_SEC
		host.set_meta(META_SCAN_TIMER, scan_timer)
		host.set_meta(META_ROT_STEP, 0)
		ai.set("current_task", TASK_WORKING)
		return
		
	host.set_meta(META_SCAN_TIMER, scan_timer)
	
	ai.set("current_task", TASK_WANDERING)
	
	# Roaming step calculations
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		
		# High-Efficiency scan: search for nearby paved roads (ID 25)
		var road_vector: Vector3 = _scan_for_paved_roads(host_pos, parent)
		
		if road_vector != Vector3.ZERO:
			# Road found! Align velocity strictly along the paved calzada
			wander_dir = road_vector
		else:
			# Fallback: standard cyber ruins roaming
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	# Apply velocities
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_PATROL
		velocity.z = wander_dir.z * SPEED_PATROL
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_PATROL)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_PATROL)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_SCAN_TIMER):
		host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	if not host.has_meta(META_ROT_STEP):
		host.set_meta(META_ROT_STEP, 0)
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)


func _reset_cyber_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)
	host.set_meta(META_ROT_STEP, 0)
	host.set_meta(META_WANDER_TIMER, 1.0)


## Proximity Scanner: Scans for paved ROAD blocks (ID 25) around host feet
func _scan_for_paved_roads(host_pos: Vector3, world_node: Node) -> Vector3:
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return Vector3.ZERO
		
	var ws: WorldState = world_node.world_state
	if ws == null:
		return Vector3.ZERO
		
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	
	# Scans adjacent blocks in a 3D bounding box
	for x: int in range(-2, 3):
		for z: int in range(-2, 3):
			# Checks the block directly underneath the floor coordinate
			var check_coord := my_coord + Vector3i(x, -1, z)
			
			# Block ID 25 is Paved Road (ROAD)
			if ws.get_block(check_coord) == 25:
				var road_pos := Vector3(check_coord) + Vector3(0.5, 1.0, 0.5)
				var diff := road_pos - host_pos
				diff.y = 0.0
				var length := diff.length()
				
				# If close but not exactly on top, return alignment heading vector
				if length > 0.8:
					return diff.normalized()
					
	return Vector3.ZERO
