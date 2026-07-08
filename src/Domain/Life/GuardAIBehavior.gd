# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: GuardAIBehavior
# Description: Concrete AI behavior strategy implementing protective guard routines,
#              including threat scanning, alarm intercepts, and physical strikes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates protective overwatch 
#   and combat logic, isolating security routines from the character mesh.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Patrol vectors and 
#   shield-blocking stance triggers can be added without modifying physics layers.
# - Liskov Substitution Principle (LSP): Fully interchangeable with other behaviors, 
#   operating seamlessly on any valid CharacterBody3D host.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name GuardAIBehavior
extends IAIBehavior

const SPEED_CHASE: float = 2.3
const SPEED_PATROL: float = 1.3

const RANGE_SIGHT_SQ: float = 100.0 # 10.0 meters squared
const RANGE_ATTACK_SQ: float = 2.56 # 1.6 meters squared
const COOLDOWN_ATTACK_SEC: float = 1.2
const SCAN_INTERVAL_SEC: float = 0.25

# Decoupled metadata keys to store state variables safely on the host node
const META_COOLDOWN := "guard_attack_cooldown"
const META_TARGET := "guard_combat_target"
const META_SCAN_TIMER := "guard_scan_timer"


## Concrete Implementation: Executes defensive threat scanning and tactical strikes
func evaluate_and_execute(host: CharacterBody3D, ai_component: Node, delta: float) -> void:
	var ai := ai_component as NPCAIComponent
	if ai == null or not is_instance_valid(host):
		return
		
	# Freeze decisions if engaged in a conversation with the player
	if host.get("is_talking") == true:
		_reset_guard_state(host, ai)
		return
		
	_initialize_metadata_if_missing(host)
	
	# Safe functional conversion of primitive types to prevent cast warnings
	var cooldown: float = float(host.get_meta(META_COOLDOWN, 0.0))
	var scan_timer: float = float(host.get_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC))
	
	var combat_target: CharacterBody3D = null
	if host.has_meta(META_TARGET):
		var target_val: Variant = host.get_meta(META_TARGET)
		if typeof(target_val) == TYPE_OBJECT:
			var target_obj: Object = target_val
			if is_instance_valid(target_obj) and target_obj is CharacterBody3D:
				combat_target = target_obj as CharacterBody3D
				
	if cooldown > 0.0:
		cooldown -= delta
		host.set_meta(META_COOLDOWN, cooldown)
		
	# 1. THROTTLED THREAT SCANNING
	scan_timer -= delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL_SEC
		
		# Locate closest threat if currently unengaged or target has died
		if not is_instance_valid(combat_target) or combat_target.get("domain_entity").is_dead:
			combat_target = _scan_for_active_zombie_target(host)
				
		host.set_meta(META_SCAN_TIMER, scan_timer)
		
		# Set metadata to empty string instead of null if no target was found to prevent C++ deletions
		if combat_target != null:
			host.set_meta(META_TARGET, combat_target)
		else:
			host.set_meta(META_TARGET, "")
		
	# 2. COMBAT PURSUIT AND ENGAGEMENT STATE
	if is_instance_valid(combat_target) and not combat_target.get("domain_entity").is_dead:
		ai.current_task = NPCAIComponent.TaskState.WORKING
		
		var target_pos := combat_target.global_position
		var diff := target_pos - host.global_position
		diff.y = 0.0
		var dist_sq := diff.length_squared()
		
		if dist_sq > RANGE_ATTACK_SQ:
			# Chase threat at sprint speeds
			var chase_dir := diff.normalized()
			host.velocity.x = chase_dir.x * SPEED_CHASE
			host.velocity.z = chase_dir.z * SPEED_CHASE
			ai.wander_direction = chase_dir
			
			# Jump over blocks while chasing
			if host.is_on_wall() and host.is_on_floor():
				host.velocity.y = 5.0 
		else:
			# Target within range: halt movement and strike
			host.velocity.x = 0.0
			host.velocity.z = 0.0
			ai.wander_direction = diff.normalized()
			
			if cooldown <= 0.0:
				_strike_target(host, combat_target)
				cooldown = COOLDOWN_ATTACK_SEC
				host.set_meta(META_COOLDOWN, cooldown)
				
				var vis_rep: IEntityVisualRepresentation = host.get("visual_representation") as IEntityVisualRepresentation
				if vis_rep != null:
					vis_rep.trigger_attack_visuals()
	else:
		# 3. PATROL STATE: Fall back to standard peaceful wandering routines
		if ai.current_task == NPCAIComponent.TaskState.WORKING:
			ai.current_task = NPCAIComponent.TaskState.IDLE
			ai.task_timer = 1.0


func _initialize_metadata_if_missing(host: CharacterBody3D) -> void:
	if not host.has_meta(META_COOLDOWN):
		host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET):
		# Initialized with empty string to maintain key definition in C++
		host.set_meta(META_TARGET, "")
	if not host.has_meta(META_SCAN_TIMER):
		host.set_meta(META_SCAN_TIMER, SCAN_INTERVAL_SEC)


func _reset_guard_state(host: CharacterBody3D, ai: NPCAIComponent) -> void:
	ai.current_task = NPCAIComponent.TaskState.IDLE
	ai.wander_direction = Vector3.ZERO
	host.set_meta(META_TARGET, "")


## Trigonometric Scan: Locates the closest active zombie or outlaw player in sight range
func _scan_for_active_zombie_target(host: CharacterBody3D) -> CharacterBody3D:
	if not host.is_inside_tree():
		return null
		
	var closest_target: CharacterBody3D = null
	var min_dist_sq := RANGE_SIGHT_SQ
	
	# Check if the player is currently WANTED for crimes against the village
	var rep := VillageReputationService.instance
	if is_instance_valid(rep) and rep.is_player_wanted():
		var parent_node := host.get_parent()
		if is_instance_valid(parent_node):
			var player_node := parent_node.get_node_or_null("Player") as CharacterBody3D
			if is_instance_valid(player_node):
				var p_domain := player_node.get("domain_entity") as VoxelEntity
				if p_domain != null and not p_domain.is_dead:
					var dist_sq_p: float = host.global_position.distance_squared_to(player_node.global_position)
					if dist_sq_p < min_dist_sq:
						min_dist_sq = dist_sq_p
						closest_target = player_node
						
	# Check traditional hostile group targets (Zombies)
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		var zombie_body := child as CharacterBody3D
		if is_instance_valid(zombie_body):
			var zombie_entity := zombie_body.get("domain_entity") as VoxelEntity
			if zombie_entity != null and not zombie_entity.is_dead:
				var dist_sq_z: float = zombie_body.global_position.distance_squared_to(host.global_position)
				if dist_sq_z < min_dist_sq:
					min_dist_sq = dist_sq_z
					closest_target = zombie_body
					
	return closest_target


## Inflicts standard damage and applies diagonal knockback
func _strike_target(host: CharacterBody3D, target: CharacterBody3D) -> void:
	var dir := (target.global_position - host.global_position).normalized()
	dir.y = 0.0
	
	var knockback := dir * 4.5
	knockback.y = 2.0
	
	if target.has_method("take_damage"):
		target.call("take_damage", 1, knockback, host)


func sprintf(format_str: String, val: float) -> String:
	return format_str % val
