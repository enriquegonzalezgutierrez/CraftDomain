# ==============================================================================
# Project: CraftDomain
# Description: Isolated Actor Component managing AI decision-making loops, 
#              threat detection, social wandering, and obstacle avoidance.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Extricates decision-making 
#                and scanning logic from the physical and visual entity wrapper.
#              - Dependency Inversion Principle (DIP): Controls movements on 
#                general CharacterBody3D hosts using abstract vectors.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/NPCAIComponent.gd
# ==============================================================================
class_name NPCAIComponent
extends Node

## AI Behavioral States
enum TaskState {
	IDLE,       # Resting in place
	WANDERING,  # Walking randomly
	EXAMINING,  # Performing a slow local inspection loop
	GREETING,   # Facing and greeting the nearby player
	CHATTIING,  # Socializing with a nearby peer NPC
	PANIC,      # Fleeing rapidly away from nearby hostile threats
	WORKING     # Performing custom sub-class tasks (e.g. harvesting)
}

# AI Settings
const SIGHT_RANGE: float = 8.0
const SOCIAL_RANGE: float = 3.0
const GREET_DISTANCE: float = 3.5

# Active State properties
var current_task: TaskState = TaskState.IDLE
var task_timer: float = 2.0
var wander_direction: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0

# Reference to the controlled physical entity parent
var _host: CharacterBody3D
var _spawn_point: Vector3


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	if is_instance_valid(_host):
		_spawn_point = _host.global_position


## Core AI state-machine tick.
func process_ai(delta: float) -> void:
	if not is_instance_valid(_host):
		return
		
	# Skip standard state-machine calculations if the NPC is locked in dialog
	if _host.get("is_talking") == true:
		current_task = TaskState.IDLE
		wander_direction = Vector3.ZERO
		stuck_timer = 0.0
		return

	# 1. Threat Detection (Highest priority state override: PANIC)
	var closest_hostile := _detect_closest_zombie_threat()
	if closest_hostile != null:
		current_task = TaskState.PANIC
		wander_direction = (_host.global_position - closest_hostile.global_position).normalized()
		wander_direction.y = 0.0
		task_timer = 2.5 
		stuck_timer = 0.0
		_apply_movement_vectors()
		return
	
	# 2. Check Player Greeting Proximity
	var player_node := _host.get_parent().get_node_or_null("Player") as CharacterBody3D
	var distance_to_player: float = 999.0
	if is_instance_valid(player_node):
		distance_to_player = _host.global_position.distance_to(player_node.global_position)
		
	var can_socialize: bool = _host.has_method("_can_socialize") and _host.call("_can_socialize")
	
	if can_socialize and current_task != TaskState.PANIC:
		if distance_to_player <= GREET_DISTANCE:
			current_task = TaskState.GREETING
			var look_dir := (player_node.global_position - _host.global_position).normalized()
			look_dir.y = 0
			if look_dir != Vector3.ZERO:
				wander_direction = look_dir
			_apply_movement_vectors()
			return
		else:
			# Check Peer Social proximity
			var closest_peer := _detect_closest_peer_npc()
			if closest_peer != null:
				current_task = TaskState.CHATTIING
				var look_dir := (closest_peer.global_position - _host.global_position).normalized()
				look_dir.y = 0
				if look_dir != Vector3.ZERO:
					wander_direction = look_dir
				_apply_movement_vectors()
				return

	# 3. Process Standard Timeouts & State Changes
	task_timer -= delta
	if task_timer <= 0.0:
		_select_next_random_task()
		
	_process_movement_avoidance(delta)
	_apply_movement_vectors()


## Evasion: Calculates and applies velocities to the parent host based on task states.
func _apply_movement_vectors() -> void:
	var base_speed: float = _host.get("BASE_SPEED") if "BASE_SPEED" in _host else 1.3
	
	match current_task:
		TaskState.IDLE, TaskState.GREETING, TaskState.CHATTIING:
			_host.velocity.x = move_toward(_host.velocity.x, 0.0, base_speed)
			_host.velocity.z = move_toward(_host.velocity.z, 0.0, base_speed)
			stuck_timer = 0.0
			
		TaskState.EXAMINING:
			_host.velocity.x = wander_direction.x * (base_speed * 0.25)
			_host.velocity.z = wander_direction.z * (base_speed * 0.25)
			stuck_timer = 0.0
			
		TaskState.WANDERING, TaskState.PANIC:
			var speed_mult := 2.8 if current_task == TaskState.PANIC else 1.0
			_host.velocity.x = wander_direction.x * base_speed * speed_mult
			_host.velocity.z = wander_direction.z * base_speed * speed_mult
			
			# Tethering: Anchor human NPCs so they never wander away from spawn villages
			if _host.name.contains("VILLAGER") or _host.name.contains("MERCHANT") or _host.name.contains("GUARD") or _host.name.contains("FARMER"):
				if _host.global_position.distance_to(_spawn_point) > 12.0:
					wander_direction = (_spawn_point - _host.global_position).normalized()
					wander_direction.y = 0


## AI Pathfinding Avoidance: Jumps over wall collisions or recalculates paths.
func _process_movement_avoidance(delta: float) -> void:
	if current_task != TaskState.WANDERING and current_task != TaskState.PANIC:
		return
		
	if _host.is_on_wall():
		if _host.is_on_floor():
			var jump_vel: float = _host.get("JUMP_VELOCITY") if "JUMP_VELOCITY" in _host else 5.0
			_host.velocity.y = jump_vel
			
		stuck_timer += delta
		if stuck_timer > 0.4: 
			stuck_timer = 0.0
			var wall_normal := _host.get_wall_normal()
			var flat_normal := Vector3(wall_normal.x, 0, wall_normal.z).normalized()
			
			if flat_normal != Vector3.ZERO:
				wander_direction = wander_direction.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.4, 0.4)).normalized()
			else:
				var angle := randf() * TAU
				wander_direction = Vector3(cos(angle), 0, sin(angle))
	else:
		stuck_timer = 0.0


func _select_next_random_task() -> void:
	var roll := randf()
	if roll < 0.35:
		current_task = TaskState.WANDERING
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))
		task_timer = randf_range(3.0, 7.0)
	elif roll < 0.70:
		current_task = TaskState.EXAMINING 
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0, sin(angle))
		task_timer = randf_range(2.0, 5.0)
	else:
		current_task = TaskState.IDLE
		task_timer = randf_range(1.5, 4.0)


func _detect_closest_zombie_threat() -> Node3D:
	var world_node := _host.get_parent()
	if not is_instance_valid(world_node):
		return null
		
	var closest_zombie: Node3D = null
	var min_dist := SIGHT_RANGE
	
	for child in world_node.get_children():
		if child.name.contains("ZOMBIE") and is_instance_valid(child):
			var zombie_entity = child.get("domain_entity")
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist := _host.global_position.distance_to(child.global_position)
				if dist < min_dist:
					min_dist = dist
					closest_zombie = child
					
	return closest_zombie


func _detect_closest_peer_npc() -> Node3D:
	var world_node := _host.get_parent()
	if not is_instance_valid(world_node):
		return null
		
	var closest_peer: Node3D = null
	var min_dist := SOCIAL_RANGE
	
	for child in world_node.get_children():
		if child != _host and child is PassiveEntity and is_instance_valid(child):
			var ai_comp = child.get_node_or_null("NPCAIComponent")
			if is_instance_valid(ai_comp):
				var peer_state: TaskState = ai_comp.current_task
				if peer_state == TaskState.IDLE or peer_state == TaskState.CHATTIING:
					var dist := _host.global_position.distance_to(child.global_position)
					if dist < min_dist:
						min_dist = dist
						closest_peer = child
						
	return closest_peer
