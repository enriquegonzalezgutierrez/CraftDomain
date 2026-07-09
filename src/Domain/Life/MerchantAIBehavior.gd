# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: MerchantAIBehavior
# Description: Specialized AI behavior strategy implementing mercantile routines for
#              the Village Merchant. During the day, it tends the marketplace stall,
#              greeting customers. At night, it navigates into indoor shelters to
#              securely count gold coins, triggering glittering golden coin sparks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the mercantile schedules,
#   night shelters, and gold counting timers, keeping physical rigs separated.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New bartering tables,
#   discounts gestures, or coin-purse visual meshes can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/MerchantAIBehavior.gd
# ==============================================================================
class_name MerchantAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.0
const SPEED_RETREAT: float = 1.6
const COOLDOWN_COINS_SEC: float = 2.5

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "merchant_wander_timer"
const META_WANDER_DIR := "merchant_wander_dir"
const META_COOLDOWN := "merchant_gold_cooldown"


func _init() -> void:
	# Merchants manage their pathing schedules completely
	overrides_wandering = true


## Concrete Contract: Drives daily sales, night retreats, and gold counting cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Skip routines if engaged in dialogue
	if host.get("is_talking") == true:
		_reset_merchant_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var gold_cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	if gold_cooldown > 0.0:
		gold_cooldown -= delta
		host.set_meta(META_COOLDOWN, gold_cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node
	var is_night: bool = CelestialService.is_night_time_static()

	# ==========================================================================
	# 1. NIGHTTIME TAVERN / INN RETREAT (Counting coin profits inside shelter)
	# ==========================================================================
	if is_night:
		# Check if the merchant is already inside a roofed shelter node
		var is_inside := false
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		var nav_service: Object = parent.get("navigation_service") if is_instance_valid(parent) else null
		
		if is_instance_valid(nav_service) and "_indoor_nodes" in nav_service:
			var indoor_nodes: Array = nav_service.get("_indoor_nodes") as Array
			is_inside = indoor_nodes.has(my_coord)
			
		if is_inside:
			# Arrived at safety! Halt, rest, and trigger gold coin counting visuals
			ai.set("current_task", TASK_IDLE)
			velocity.x = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
			ai.set("wander_direction", Vector3.BACK) # Face comfortable sitting focus
			
			if gold_cooldown <= 0.0:
				gold_cooldown = COOLDOWN_COINS_SEC
				host.set_meta(META_COOLDOWN, gold_cooldown)
				
				# Call gold coin counting visual effect in presentation layer
				if host.has_method("_play_counting_coins"):
					host.call("_play_counting_coins")
			return
		else:
			# Not inside yet: Calculate A* route to the nearest village tavern/house
			if is_instance_valid(nav_service) and nav_service.has_method("find_closest_shelter_node"):
				var shelter_pos: Vector3 = nav_service.call("find_closest_shelter_node", host_pos)
				if shelter_pos != Vector3.ZERO:
					var diff := shelter_pos - host_pos
					diff.y = 0.0
					if diff.length() > 0.8:
						var retreat_dir := diff.normalized()
						velocity.x = retreat_dir.x * SPEED_RETREAT
						velocity.z = retreat_dir.z * SPEED_RETREAT
						host.set("velocity", velocity)
						ai.set("wander_direction", retreat_dir)
						ai.set("current_task", TASK_WANDERING)
						return
						
		# Fallback: if no shelters exist, halt movement
		velocity.x = 0.0
		velocity.z = 0.0
		host.set("velocity", velocity)
		return

	# ==========================================================================
	# 2. DAYTIME BUSINESS STATE (Tending stall within tight 5m perimeter)
	# ==========================================================================
	ai.set("current_task", TASK_WORKING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		
		# Tethering check: Keep merchant tethered tight to their registered spawn point (X: -136.5, Z: -3.5)
		var spawn_point: Vector3 = host.get("_spawn_point") as Vector3
		var dist_to_spawn := host_pos.distance_to(spawn_point)
		
		if dist_to_spawn > 5.0:
			# Symmetrical pull-back to counter
			wander_dir = (spawn_point - host_pos).normalized()
			wander_dir.y = 0.0
		else:
			# Roam short steps around the table
			if randf() < 0.4:
				var angle := randf() * TAU
				wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			else:
				wander_dir = Vector3.ZERO
				
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
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)


func _reset_merchant_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_WANDER_TIMER, 1.0)
