# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: GoblinAIBehavior
# Description: Specialized AI behavior strategy implementing the Goblin's 
#              sneaky hit-and-run skirmishing routines. It features rapid 
#              chasing vectors and a dedicated retreat cycle: immediately 
#              after successfully attacking the player, the Goblin flees at 
#              maximum speed in the opposite direction to hide before stalking again.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the tactical 
#   decision-making of the Goblin, completely decoupled from physics engines.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Custom tactical 
#   skirmish distances or alert frequencies can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the IAIBehavior 
#   contract signatures, making it interchangeable with other strategies.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/GoblinAIBehavior.gd
# ==============================================================================
class_name GoblinAIBehavior
extends IAIBehavior

const SPEED_CHASE: float = 3.5
const SPEED_WANDER: float = 1.6
const SPEED_RETREAT: float = 3.8

const RANGE_CHASE_SQ: float = 256.0 # 16.0 meters squared
const RANGE_ATTACK_SQ: float = 1.44 # 1.2 meters squared
const COOLDOWN_ATTACK_SEC: float = 1.2

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "goblin_wander_timer"
const META_WANDER_DIR := "goblin_wander_dir"
const META_COOLDOWN := "goblin_attack_cooldown"
const META_RETREAT_TIMER := "goblin_retreat_timer"


func _init() -> void:
	# Goblins completely override standard wander schedules
	overrides_wandering = true


## Concrete Contract: Drives the Goblin skirmishing/guerrilla combat loop
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	var retreat_timer: float = host.get_meta(META_RETREAT_TIMER) as float
	
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity")
	var host_pos: Vector3 = host.get("global_position")
	
	# Locate player
	var player_node: Object = null
	var parent: Node = host.call("get_parent") as Node
	if is_instance_valid(parent):
		player_node = parent.call("get_node_or_null", "Player")
		
	var is_player_active: bool = is_instance_valid(player_node) and player_node.get("is_active") == true

	# ==========================================================================
	# 1. ESCAPE GUERRILLA INSTINCT: RETREATING (Runs opposite to player)
	# ==========================================================================
	if retreat_timer > 0.0:
		retreat_timer -= delta
		host.set_meta(META_RETREAT_TIMER, retreat_timer)
		
		ai.set("current_task", TASK_WANDERING) # Uses fast panic run animations
		
		if is_player_active:
			var player_pos: Vector3 = player_node.get("global_position")
			var opposite_dir: Vector3 = (host_pos - player_pos).normalized()
			opposite_dir.y = 0.0
			
			# Repositioning Wall Slides: Bounce off corners while retreating
			if host.call("is_on_wall"):
				var wall_normal: Vector3 = host.call("get_wall_normal")
				opposite_dir = opposite_dir.bounce(wall_normal).normalized()
				
			velocity.x = opposite_dir.x * SPEED_RETREAT
			velocity.z = opposite_dir.z * SPEED_RETREAT
			host.set("velocity", velocity)
			ai.set("wander_direction", opposite_dir)
		return

	# ==========================================================================
	# 2. COMBAT STATE: STALKING & CHARGING
	# ==========================================================================
	var is_tracking := false
	if is_player_active:
		var player_pos: Vector3 = player_node.get("global_position")
		var dist_sq: float = host_pos.distance_squared_to(player_pos)
		
		if dist_sq < RANGE_CHASE_SQ:
			is_tracking = true
			var to_player: Vector3 = (player_pos - host_pos).normalized()
			to_player.y = 0.0
			wander_dir = to_player
			
			ai.set("current_task", TASK_WORKING)
			
			# Inside strike range: Bite player and trigger retreat cycle
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
					
					# TRIGGER HIT-AND-RUN FLIGHT: Retreat for 1.2s!
					retreat_timer = 1.2
					host.set_meta(META_RETREAT_TIMER, retreat_timer)
					
					var vis_rep: Object = host.get("visual_representation")
					if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
						vis_rep.call("trigger_attack_visuals")
				return

	# ==========================================================================
	# 3. WANDERING BASELINE
	# ==========================================================================
	if not is_tracking:
		ai.set("current_task", TASK_WANDERING)
		
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(1.5, 4.0)
			var is_moving := randf() > 0.4
			if is_moving:
				var angle := randf() * TAU
				wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			else:
				wander_dir = Vector3.ZERO
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	# Apply final velocity coordinates
	if wander_dir != Vector3.ZERO:
		var speed_coef: float = SPEED_CHASE if is_tracking else SPEED_WANDER
		velocity.x = wander_dir.x * speed_coef
		velocity.z = wander_dir.z * speed_coef
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WANDER)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WANDER)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_RETREAT_TIMER):
		host.set_meta(META_RETREAT_TIMER, 0.0)
