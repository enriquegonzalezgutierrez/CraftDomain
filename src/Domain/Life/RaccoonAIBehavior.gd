# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: RaccoonAIBehavior
# Description: Specialized AI behavior strategy implementing nighttime scavenging 
#              routines for the Forest Raccoon. During the day, the Raccoon sleeps 
#              peacefully under tree canopies. At night, it awakens to roam villages, 
#              stalking and actively scratching active loot Barrels or Chests to 
#              procedurally break them and steal food.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the scavenging 
#   schedules, target prop detections, and breakout timers of the Raccoon.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New stealth levels, 
#   item stealing, or dog escape paths can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/RaccoonAIBehavior.gd
# ==============================================================================
class_name RaccoonAIBehavior
extends IAIBehavior

const SPEED_SNEAK: float = 1.1
const SPEED_RUN: float = 2.4
const SCAVENGE_DURATION_SEC: float = 3.0

const RANGE_SENSORY_SQ: float = 225.0 # 15.0 meters squared barrel sensing radius

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "raccoon_wander_timer"
const META_WANDER_DIR := "raccoon_wander_dir"
const META_TARGET_PROP := "raccoon_target_prop"
const META_MINE_TIMER := "raccoon_mine_timer"


func _init() -> void:
	# Raccoons completely manage their coordinate vectors
	overrides_wandering = true


## Concrete Contract: Drives day sleep cycles and nighttime barrel breakouts
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	var target_ref: Object = null
	if host.has_meta(META_TARGET_PROP):
		var val: Variant = host.get_meta(META_TARGET_PROP)
		if typeof(val) == TYPE_OBJECT:
			var obj: Object = val
			if is_instance_valid(obj):
				target_ref = obj
				
	var mine_timer: float = host.get_meta(META_MINE_TIMER) as float
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node
	var is_night: bool = CelestialService.is_night_time_static()

	# ==========================================================================
	# 1. DAYTIME SLEEPY STATE (Halt, rest, and deactivate movement under trees)
	# ==========================================================================
	if not is_night:
		_reset_raccoon_state(host)
		ai.set("current_task", TASK_IDLE)
		velocity.x = 0.0
		velocity.z = 0.0
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)
		return

	# ==========================================================================
	# 2. NIGHTTIME CLEPTOMANIAC SCAVENGER (Breaks active village Barrels/Chests)
	# ==========================================================================
	if is_night:
		# If no active prop is targeted yet, scan the village perimeter
		if target_ref == null:
			var closest_barrel := _detect_closest_village_barrel(host_pos, parent)
			if closest_barrel != null:
				target_ref = closest_barrel
				mine_timer = SCAVENGE_DURATION_SEC
				host.set_meta(META_TARGET_PROP, target_ref)
				host.set_meta(META_MINE_TIMER, mine_timer)
		
		# If a target is active, engage in the scavenging breakout
		if is_instance_valid(target_ref):
			var target_node := target_ref as Node3D
			
			ai.set("current_task", TASK_WORKING)
			
			var target_pos: Vector3 = target_node.global_position
			var diff := target_pos - host_pos
			diff.y = 0.0
			var length := diff.length()
			
			if length > 1.2:
				# Sigilo: Sneak quietly towards the barrel
				var sneak_dir := diff.normalized()
				velocity.x = sneak_dir.x * SPEED_SNEAK
				velocity.z = sneak_dir.z * SPEED_SNEAK
				host.set("velocity", velocity)
				ai.set("wander_direction", sneak_dir)
			else:
				# Arrived: halt, stand on back legs, scratch and play scratching visual/sound
				velocity.x = 0.0
				velocity.z = 0.0
				host.set("velocity", velocity)
				ai.set("wander_direction", diff.normalized())
				
				# Play scratch effect on presenter (and a meow meow warning)
				if host.has_method("_play_scratching_effect"):
					host.call("_play_scratching_effect", target_node)
					
				mine_timer -= delta
				if mine_timer <= 0.0:
					# BREAK BARREL! Symmetrical break call (ID 215 Barrel has interact)
					if target_node.has_method("interact"):
						target_node.call("interact", host) # Breaks barrel and drops food/seeds!
						
					# Symmetrical jump with joy and run away with speed boost
					velocity.y = 5.0
					host.set("velocity", velocity)
					
					_reset_raccoon_state(host)
					return
					
				host.set_meta(META_MINE_TIMER, mine_timer)
			return

	# ==========================================================================
	# 3. NIGHTTIME DEFAULT ROAMING
	# ==========================================================================
	ai.set("current_task", TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		if randf() < 0.5:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		else:
			wander_dir = Vector3.ZERO
			
	host.set_meta(META_WANDER_TIMER, wander_timer)
	host.set_meta(META_WANDER_DIR, wander_dir)

	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_SNEAK * 1.3
		velocity.z = wander_dir.z * SPEED_SNEAK * 1.3
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_SNEAK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_SNEAK)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_TARGET_PROP):
		host.set_meta(META_TARGET_PROP, "")
	if not host.has_meta(META_MINE_TIMER):
		host.set_meta(META_MINE_TIMER, 0.0)


func _reset_raccoon_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_PROP, "")
	host.set_meta(META_MINE_TIMER, 0.0)
	host.set_meta(META_WANDER_TIMER, 1.0)


## Proximity Scanner: Scans for active breakable Props (Barrels or Chests)
func _detect_closest_village_barrel(host_pos: Vector3, world_node: Node) -> Object:
	if not is_instance_valid(world_node):
		return null
		
	var closest_prop: Object = null
	var min_dist_sq: float = RANGE_SENSORY_SQ
	
	for child in world_node.get_children():
		if is_instance_valid(child) and (child.name.begins_with("Prop_BARREL") or child.name.begins_with("Prop_CHEST")):
			var dist_sq: float = host_pos.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_prop = child
				
	return closest_prop
