# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: GargoyleAIBehavior
# Description: Specialized AI behavior strategy implementing the Gargoyle's 
#              nocturnal state machine. It manages transitions between daytime 
#              solid stone (motionless) and nighttime awakened flight, player 
#              airborne hunting, and attack coordinate bite triggers.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the tactical 
#   decision-making of the Gargoyle, completely decoupled from physics engines.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Custom flight 
#   patterns, hover offsets, or rage mechanics can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the IAIBehavior 
#   contract signatures, making it interchangeable with other strategies.
# - Dependency Inversion Principle (DIP): Communicates through abstract Object 
#   getters/setters to avoid strict compile-time locks with concrete scenes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/GargoyleAIBehavior.gd
# ==============================================================================
class_name GargoyleAIBehavior
extends IAIBehavior

const SPEED_CHASE: float = 3.0
const SPEED_WANDER: float = 1.5

const RANGE_SIGHT_SQ: float = 256.0 # 16.0 meters squared
const RANGE_ATTACK_SQ: float = 3.0
const COOLDOWN_ATTACK_SEC: float = 1.5

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_STATE := "gargoyle_nocturnal_state" # 0 = STONE, 1 = AWAKE
const META_WANDER_TIMER := "gargoyle_wander_timer"
const META_WANDER_DIR := "gargoyle_wander_dir"
const META_COOLDOWN := "gargoyle_attack_cooldown"


func _init() -> void:
	# Gargoyles completely override standard wander schedules
	overrides_wandering = true


## Concrete Contract: Drives the Gargoyle Day/Night flight hunt state machine
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var state: int = host.get_meta(META_STATE) as int
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)
		
	var is_night: bool = CelestialService.is_night_time_static()
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity")

	# ==========================================================================
	# 1. STATE TRANSITIONS (Symmetrical checks)
	# ==========================================================================
	if is_night and state == 0: # Stone -> Awake
		state = 1
		host.set_meta(META_STATE, state)
		if host.has_method("_set_gargoyle_stone_appearance"):
			host.call("_set_gargoyle_stone_appearance", false)
			
	elif not is_night and state == 1: # Awake -> Stone
		state = 0
		host.set_meta(META_STATE, state)
		if host.has_method("_set_gargoyle_stone_appearance"):
			host.call("_set_gargoyle_stone_appearance", true)

	# ==========================================================================
	# 2. BEHAVIOR EXECUTION
	# ==========================================================================
	if state == 0: # STONE (Motionless statue, affected by gravity in physics)
		ai.set("current_task", TASK_IDLE)
		velocity.x = move_toward(velocity.x, 0.0, SPEED_CHASE * delta)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_CHASE * delta)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)
		return

	# AWAKE STATE (Active airborne predator hunt)
	var is_tracking := false
	var player_node: Object = null
	
	if host.has_method("get_parent"):
		var parent: Node = host.call("get_parent") as Node
		if is_instance_valid(parent):
			player_node = parent.call("get_node_or_null", "Player")

	# A. Gaze tracking & sensory sweep
	if is_instance_valid(player_node) and player_node.get("is_active") == true:
		var host_pos: Vector3 = host.get("global_position")
		var player_pos: Vector3 = player_node.get("global_position")
		var dist_sq: float = host_pos.distance_squared_to(player_pos)
		
		if dist_sq < RANGE_SIGHT_SQ:
			is_tracking = true
			var to_player := (player_pos - host_pos).normalized()
			to_player.y = 0.0 # Maintain horizontal focus
			wander_dir = to_player
			
			ai.set("current_task", TASK_WORKING)
			
			# Attack trigger
			if dist_sq <= RANGE_ATTACK_SQ:
				velocity.x = 0.0
				velocity.z = 0.0
				host.set("velocity", velocity)
				ai.set("wander_direction", to_player)
				
				if cooldown <= 0.0:
					if host.has_method("_bite_player"):
						host.call("_bite_player")
					cooldown = COOLDOWN_ATTACK_SEC
					host.set_meta(META_COOLDOWN, cooldown)
					
					var vis_rep: Object = host.get("visual_representation")
					if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
						vis_rep.call("trigger_attack_visuals")
				return

	# B. Standard passive wandering if player is out of range
	if not is_tracking:
		ai.set("current_task", TASK_WANDERING)
		
		wander_timer -= delta
		if wander_timer <= 0.0:
			var is_moving := randf() > 0.4
			if is_moving:
				var angle := randf() * TAU
				wander_dir = Vector3(cos(angle), 0.0, sin(angle))
				wander_timer = randf_range(2.0, 5.0)
			else:
				wander_dir = Vector3.ZERO
				wander_timer = randf_range(1.0, 3.0)
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	# C. Apply computed flight velocity vectors
	if wander_dir != Vector3.ZERO:
		var speed_mult: float = SPEED_CHASE if is_tracking else SPEED_WANDER
		velocity.x = wander_dir.x * speed_mult
		velocity.z = wander_dir.z * speed_mult
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WANDER)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WANDER)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE):
		host.set_meta(META_STATE, 0) # Starts as STONE
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
