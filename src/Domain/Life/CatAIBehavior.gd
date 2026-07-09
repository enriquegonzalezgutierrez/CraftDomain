# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: CatAIBehavior
# Description: Specialized AI behavior strategy implementing cozy domestic routines
#              for the Domestic Cat. Features player tracking when holding food
#              (Fried Chicken), autonomous campfire snuggle seeking, and acute
#              zombie detection: hisses to warn defenders and flees to shelters.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the felid decision
#   trees, target attractions, and alarms, keeping physics decoupled.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New domestic gifts,
#   mouse hunting, or follow speeds can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/CatAIBehavior.gd
# ==============================================================================
class_name CatAIBehavior
extends IAIBehavior

const SPEED_RUN: float = 2.2
const SPEED_WALK: float = 1.0
const SPEED_CREEP: float = 0.6

const RANGE_ATTRACTION_SQ: float = 100.0 # 10.0 meters player sight
const RANGE_ZOMBIE_SQ: float = 64.0       # 8.0 meters zombie alarm
const RANGE_CAMPFIRE_SQ: float = 144.0   # 12.0 meters cozy fire snuggle

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "cat_wander_timer"
const META_WANDER_DIR := "cat_wander_dir"
const META_COOLDOWN := "cat_hiss_cooldown"


func _init() -> void:
	# Cats fully override generic schedules to run domestic cycles
	overrides_wandering = true


## Concrete Contract: Drives follow food, campfire cozy, and zombie alarm states
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var hiss_cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	if hiss_cooldown > 0.0:
		hiss_cooldown -= delta
		host.set_meta(META_COOLDOWN, hiss_cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node

	# ==========================================================================
	# 1. ACUTE ZOMBIE SENSORY ALARM (startles, hisses, and flees to shelters)
	# ==========================================================================
	var closest_zombie := _detect_closest_zombie_threat(host)
	if closest_zombie != null:
		ai.set("current_task", TASK_PANIC)
		
		# Hiss with custom sparks/puff warning to alert village defenders (cooldown 4s)
		if hiss_cooldown <= 0.0:
			hiss_cooldown = 4.0
			host.set_meta(META_COOLDOWN, hiss_cooldown)
			if host.has_method("_play_alarm_hiss"):
				host.call("_play_alarm_hiss", closest_zombie)
				
		# Sledge-hammer safety: immediately compute A* paths inside shelters
		var nav_service: Object = parent.get("navigation_service") if is_instance_valid(parent) else null
		if is_instance_valid(nav_service) and nav_service.has_method("find_closest_shelter_node"):
			var shelter_pos: Vector3 = nav_service.call("find_closest_shelter_node", host_pos)
			if shelter_pos != Vector3.ZERO:
				var diff := (shelter_pos - host_pos)
				diff.y = 0.0
				if diff.length() > 0.8:
					var run_dir := diff.normalized()
					velocity.x = run_dir.x * SPEED_RUN
					velocity.z = run_dir.z * SPEED_RUN
					host.set("velocity", velocity)
					ai.set("wander_direction", run_dir)
					return
					
		# If no shelter is generated nearby, run away straight opposite of the zombie
		# BUG FIX: Safely cast the generic Object to a Node3D to ensure type inference is strictly defined
		var zombie_node := closest_zombie as Node3D
		if is_instance_valid(zombie_node):
			var escape_dir: Vector3 = (host_pos - zombie_node.global_position).normalized()
			escape_dir.y = 0.0
			velocity.x = escape_dir.x * SPEED_RUN
			velocity.z = escape_dir.z * SPEED_RUN
			host.set("velocity", velocity)
			ai.set("wander_direction", escape_dir)
		return

	# ==========================================================================
	# 2. FOOD FOLLOW ROUTINE (Holding Fried Chicken ID 16)
	# ==========================================================================
	var player_node: Object = null
	if is_instance_valid(parent):
		player_node = parent.call("get_node_or_null", "Player")
		
	var is_attracted := false
	if is_instance_valid(player_node) and player_node.get("is_active") == true:
		var p_pos: Vector3 = player_node.get("global_position")
		var dist_sq: float = host_pos.distance_squared_to(p_pos)
		
		if dist_sq < RANGE_ATTRACTION_SQ:
			# Scan if player is holding Fried Chicken in active slot
			var is_holding_chicken := false
			var inventory := player_node.get("inventory")
			if is_instance_valid(inventory):
				var active_slot: int = player_node.get("active_slot_index") as int
				var slot_data: Object = inventory.call("get_slot_data", active_slot)
				if is_instance_valid(slot_data) and slot_data.get("item_id") == 16:
					is_holding_chicken = true
					
			if is_holding_chicken:
				is_attracted = true
				ai.set("current_task", TASK_WORKING)
				
				var diff := (p_pos - host_pos)
				diff.y = 0.0
				var length := diff.length()
				
				if length > 1.5:
					# Trot and maow towards player
					var creep_dir := diff.normalized()
					velocity.x = creep_dir.x * SPEED_WALK * 1.5
					velocity.z = creep_dir.z * SPEED_WALK * 1.5
					host.set("velocity", velocity)
					ai.set("wander_direction", creep_dir)
				else:
					# Arrived! Sit at player feet and look up
					velocity.x = 0.0
					velocity.z = 0.0
					var look_dir := diff.normalized()
					host.set("velocity", velocity)
					ai.set("wander_direction", look_dir)
				return

	# ==========================================================================
	# 3. CAMPFIRE SNUGGLE SEEKING (Seeks active campfires)
	# ==========================================================================
	if not is_attracted:
		var closest_campfire := _detect_closest_village_campfire(host_pos, parent)
		if closest_campfire != null:
			ai.set("current_task", TASK_WORKING)
			
			var fire_pos: Vector3 = closest_campfire.global_position
			var diff := (fire_pos - host_pos)
			diff.y = 0.0
			var length := diff.length()
			
			if length > 1.8:
				# Walk relaxed to the warmth
				var walk_dir := diff.normalized()
				velocity.x = walk_dir.x * SPEED_CREEP
				velocity.z = walk_dir.z * SPEED_CREEP
				host.set("velocity", velocity)
				ai.set("wander_direction", walk_dir)
			else:
				# Arrived: Curl down, rest and purr comfortably next to campfire!
				velocity.x = 0.0
				velocity.z = 0.0
				host.set("velocity", velocity)
				ai.set("wander_direction", diff.normalized())
			return

	# ==========================================================================
	# 4. DEFAULT WANDERING BASELINE (Village roaming)
	# ==========================================================================
	ai.set("current_task", TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		if randf() < 0.4:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		else:
			wander_dir = Vector3.ZERO
			
	host.set_meta(META_WANDER_TIMER, wander_timer)
	host.set_meta(META_WANDER_DIR, wander_dir)

	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_WALK
		velocity.z = wander_dir.z * SPEED_WALK
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WALK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WALK)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)


## Proximity Scanner: Locates nearest active Campfire props in the seaport or villages
func _detect_closest_village_campfire(host_pos: Vector3, world_node: Node) -> Object:
	if not is_instance_valid(world_node):
		return null
		
	var closest_fire: Object = null
	var min_dist_sq: float = RANGE_CAMPFIRE_SQ
	
	for child in world_node.get_children():
		if is_instance_valid(child) and child.name.begins_with("Prop_CAMPFIRE"):
			var dist_sq: float = host_pos.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_fire = child
				
	return closest_fire


## Proximity Scanner: Locates nearest hostile threats (Zombies)
func _detect_closest_zombie_threat(host: Object) -> Object:
	if not host.call("is_inside_tree"):
		return null
		
	var closest_threat: Object = null
	var min_dist_sq: float = RANGE_ZOMBIE_SQ
	
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	var host_pos: Vector3 = host.get("global_position")
	for child: Object in hostiles:
		if is_instance_valid(child):
			var zombie_domain: Object = child.get("domain_entity")
			if zombie_domain != null and not zombie_domain.get("is_dead"):
				var child_pos: Vector3 = child.get("global_position")
				var dist_sq := host_pos.distance_squared_to(child_pos)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_threat = child
					
	return closest_threat
