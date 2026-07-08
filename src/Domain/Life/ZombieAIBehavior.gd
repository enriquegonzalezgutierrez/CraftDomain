# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: ZombieAIBehavior
# Description: Concrete AI behavior strategy implementing hostile zombie routines,
#              including player tracking, wall flanking steering, and coordinate bites.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the hostile pursuit 
#   and combat logic, isolating decision trees from physical simulation layers.
# - Open-Closed Principle (OCP): Extends IAIBehavior. Custom offensive movesets, 
#   rage triggers, or target-scanning limits can be added here without editing entities.
# - Liskov Substitution Principle (LSP): Adheres fully to the base contract, 
#   supporting uniform execution across all CharacterBody3D node hosts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name ZombieAIBehavior
extends IAIBehavior

const SPEED_CHASE: float = 2.2
const SPEED_WANDER: float = 1.1

const RANGE_CHASE_SQ: float = 256.0 # 16.0 meters squared
const RANGE_ATTACK_SQ: float = 1.44 # 1.2 meters squared
const COOLDOWN_ATTACK_SEC: float = 1.5

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "zombie_wander_timer"
const META_WANDER_DIR := "zombie_wander_dir"
const META_COOLDOWN := "zombie_attack_cooldown"
const META_STUCK_TIMER := "zombie_stuck_timer"


func _init() -> void:
	# ==========================================================================
	# OCP FORCEFIELD OVERRIDE
	# Hostiles completely intercept movement, bypassing generic civilian schedules
	# ==========================================================================
	overrides_wandering = true


## Concrete Implementation: Evaluates scent boundaries and drives aggressive pursuit
func evaluate_and_execute(host: CharacterBody3D, ai_component: Node, delta: float) -> void:
	var ai := ai_component as NPCAIComponent
	if ai == null or not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	# Extract trackers from host metadata
	var wander_timer: float = host.get_meta(META_WANDER_TIMER)
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR)
	var cooldown: float = host.get_meta(META_COOLDOWN)
	var stuck_timer: float = host.get_meta(META_STUCK_TIMER)
	
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)
		
	# 1. TACTICAL PLAYER PROXIMITY EVALUATION
	var player_node := host.get_parent().get_node_or_null("Player") as CharacterBody3D
	var is_tracking := false
	
	if is_instance_valid(player_node) and player_node.get("is_active") == true:
		var dist_sq := host.global_position.distance_squared_to(player_node.global_position)
		if dist_sq < RANGE_CHASE_SQ:
			is_tracking = true
			var to_player := (player_node.global_position - host.global_position).normalized()
			to_player.y = 0.0
			wander_dir = to_player
			
			print("[AI DEBUG] [", host.name, "] Scent locked: Pursuing Player! Distance is: ", sprintf("%.1f", sqrt(dist_sq)), "m")
			
			# Flanking Wall Steering
			if host.is_on_wall():
				var wall_normal := host.get_wall_normal()
				var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					var slide_dir := (wander_dir - flat_normal * (wander_dir.dot(flat_normal))).normalized()
					if slide_dir != Vector3.ZERO:
						wander_dir = slide_dir
						print("[AI DEBUG] [", host.name, "] Obstructed by wall. Calculating flanking slide vector: ", wander_dir)
						
			# Jump over obstacle seams
			if host.is_on_wall() and host.is_on_floor():
				host.velocity.y = 5.0
				
			# Attack Trigger
			if dist_sq <= RANGE_ATTACK_SQ:
				host.velocity.x = 0.0
				host.velocity.z = 0.0
				if cooldown <= 0.0:
					_bite_player(host, player_node)
					cooldown = COOLDOWN_ATTACK_SEC
					host.set_meta(META_COOLDOWN, cooldown)
					
					var vis_rep: IEntityVisualRepresentation = host.get("visual_representation") as IEntityVisualRepresentation
					if vis_rep != null:
						vis_rep.trigger_attack_visuals()
						
	# 2. STANDARD RANDOM WANDERING STATE (If player is out of range)
	if not is_tracking:
		wander_timer -= delta
		if wander_timer <= 0.0:
			var is_moving := randf() > 0.4
			if is_moving:
				var angle := randf() * TAU
				wander_dir = Vector3(cos(angle), 0.0, sin(angle))
				wander_timer = randf_range(2.0, 5.0)
				print("[AI DEBUG] [", host.name, "] Wandering to random heading: ", wander_dir)
			else:
				wander_dir = Vector3.ZERO
				wander_timer = randf_range(1.0, 3.0)
				print("[AI DEBUG] [", host.name, "] Resting in place.")
				
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)
		
		# Obstacle jump handling
		if wander_dir != Vector3.ZERO and host.is_on_wall():
			if host.is_on_floor():
				host.velocity.y = 5.0
				
			stuck_timer += delta
			if stuck_timer > 0.4:
				stuck_timer = 0.0
				var wall_normal := host.get_wall_normal()
				var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					wander_dir = wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					host.set_meta(META_WANDER_DIR, wander_dir)
					print("[AI DEBUG] [", host.name, "] Stuck while wandering. Executing path bounce: ", wander_dir)
				else:
					var angle := randf() * TAU
					wander_dir = Vector3(cos(angle), 0.0, sin(angle))
					host.set_meta(META_WANDER_DIR, wander_dir)
			host.set_meta(META_STUCK_TIMER, stuck_timer)
		else:
			stuck_timer = 0.0
			host.set_meta(META_STUCK_TIMER, stuck_timer)

	# 3. APPLY DISPATCHED VELOCITY VECTORS AND AI COMPONENT UPDATE
	# Decoupled visual mesh rotations are managed cleanly inside NPCVisualComponent.gd
	if wander_dir != Vector3.ZERO:
		var active_speed := SPEED_CHASE if is_tracking else SPEED_WANDER
		host.velocity.x = wander_dir.x * active_speed
		host.velocity.z = wander_dir.z * active_speed
		ai.wander_direction = wander_dir
	else:
		host.velocity.x = move_toward(host.velocity.x, 0.0, SPEED_WANDER)
		host.velocity.z = move_toward(host.velocity.z, 0.0, SPEED_WANDER)
		ai.wander_direction = Vector3.ZERO


func _initialize_metadata_if_missing(host: CharacterBody3D) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_STUCK_TIMER):
		host.set_meta(META_STUCK_TIMER, 0.0)


func _bite_player(host: CharacterBody3D, player_node: CharacterBody3D) -> void:
	var dir := (player_node.global_position - host.global_position).normalized()
	var knockback := Vector3(dir.x * 5.5, 0.25, dir.z * 5.5)
	if player_node.has_method("take_damage"):
		player_node.call("take_damage", 1, knockback)
		print("[AI DEBUG] [", host.name, "] COMBAT ACTION: Bite successfully landed on player! Applying knockback.")


func sprintf(format_str: String, val: float) -> String:
	return format_str % val
