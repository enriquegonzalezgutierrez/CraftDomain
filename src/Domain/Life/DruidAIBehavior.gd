# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Life & Entities / AI Strategies)
# Class: DruidAIBehavior
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Specialized AI behavior strategy implementing the Forest Druid's 
#              mystical protector routines. It scans the surroundings for injured 
#              peaceful animals, navigating to them to channel a botanical 
#              healing spell that spawns emerald ether particles and restores health.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the dynamic scanning, 
#   spellcasting timers, and botanical targeting of the Druid, keeping physics decoupled.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New druidic spells, 
#   nature barriers, or floral portals can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# ==============================================================================
class_name DruidAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.1
const COOLDOWN_SPELL_SEC: float = 6.0
const CAST_DURATION_SEC: float = 2.0

const RANGE_SENSE_SQ: float = 64.0 # 8.0 meters squared sensory radius for injured fauna

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "druid_wander_timer"
const META_WANDER_DIR := "druid_wander_dir"
const META_COOLDOWN := "druid_spell_cooldown"
const META_TARGET_ANIMAL := "druid_heal_target"
const META_CAST_TIMER := "druid_cast_timer"


func _init() -> void:
	# Druids override standard wander schedules during magical rituals
	overrides_wandering = false


## Concrete Contract: Drives the wildlife scanning and channeling of healing magic
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	# Skip routines if talking to the player
	if host.get("is_talking") == true:
		_reset_druid_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var spell_cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	var target_ref: Object = null
	if host.has_meta(META_TARGET_ANIMAL):
		var val: Variant = host.get_meta(META_TARGET_ANIMAL)
		if typeof(val) == TYPE_OBJECT:
			var obj: Object = val
			if is_instance_valid(obj):
				target_ref = obj
				
	var cast_timer: float = host.get_meta(META_CAST_TIMER) as float
	
	if spell_cooldown > 0.0:
		spell_cooldown -= delta
		host.set_meta(META_COOLDOWN, spell_cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")

	# ==========================================================================
	# 1. CHANNELING STATE: BOTANICAL HEALING SPELLCAST
	# ==========================================================================
	if is_instance_valid(target_ref):
		var target_node := target_ref as Node3D
		var target_domain: Object = target_node.get("domain_entity")
		
		# Cancel heal if animal dies or reaches full health before we finish
		if target_domain == null or target_domain.get("is_dead") == true:
			_reset_druid_state(host)
			return
			
		ai.set("current_task", TASK_WORKING)
		
		var target_pos: Vector3 = target_node.global_position
		var diff := target_pos - host_pos
		diff.y = 0.0
		var dist_sq := diff.length_squared()
		
		if dist_sq > 2.0:
			# Walk towards the injured animal
			var creep_dir := diff.normalized()
			velocity.x = creep_dir.x * SPEED_PATROL
			velocity.z = creep_dir.z * SPEED_PATROL
			host.set("velocity", velocity)
			ai.set("wander_direction", creep_dir)
		else:
			# Arrived! Lock gaze onto target, halt movement, and channel spell
			velocity.x = 0.0
			velocity.z = 0.0
			host.set("velocity", velocity)
			ai.set("wander_direction", diff.normalized())
			
			# Trigger staff swing animations on presenter
			var vis_rep: Object = host.get("visual_representation")
			if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
				vis_rep.call("trigger_attack_visuals")
				
			# Spawn continuous éter particles from báculo
			if host.has_method("_play_healing_visuals"):
				host.call("_play_healing_visuals", target_node)
				
			cast_timer -= delta
			if cast_timer <= 0.0:
				# SPELL FINISHED: Heal animal completely (restore to full HP = max_hp)
				if "health" in target_domain:
					target_domain.set("health", 6) # Symmetrical full health restoration
					
				# Symmetrical finish: spark burst and jump with joy
				velocity.y = 4.0
				host.set("velocity", velocity)
				
				# Reset state with a 6-second cooldown on next spellcast
				host.set_meta(META_COOLDOWN, COOLDOWN_SPELL_SEC)
				_reset_druid_state(host)
				return
				
			host.set_meta(META_CAST_TIMER, cast_timer)
		return

	# ==========================================================================
	# 2. PROXIMITY SCANNING: SEEK INJURED FAUNA (Only when spell is off cooldown)
	# ==========================================================================
	if spell_cooldown <= 0.0:
		var injured_creature := _scan_for_injured_animals(host)
		if injured_creature != null:
			host.set_meta(META_TARGET_ANIMAL, injured_creature)
			host.set_meta(META_CAST_TIMER, CAST_DURATION_SEC)
			return

	# ==========================================================================
	# 3. STANDARD PATROL STATE (Peaceful wandering)
	# ==========================================================================
	ai.set("current_task", TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		if randf() < 0.45:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		else:
			wander_dir = Vector3.ZERO
			
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

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
	if not host.has_meta(META_TARGET_ANIMAL):
		host.set_meta(META_TARGET_ANIMAL, "")
	if not host.has_meta(META_CAST_TIMER):
		host.set_meta(META_CAST_TIMER, 0.0)


func _reset_druid_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_ANIMAL, "")
	host.set_meta(META_CAST_TIMER, 0.0)


## Proximity Scanner: Identifies injured peaceful creatures inside range
func _scan_for_injured_animals(host: Object) -> Node3D:
	if not host.call("is_inside_tree"):
		return null
		
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_injured: Node3D = null
	var min_dist_sq: float = RANGE_SENSE_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var domain: Object = child.get("domain_entity")
			
			if domain != null and not domain.get("is_dead"):
				var current_hp: int = domain.get("health") as int
				
				# Identify if the animal is hurt (health < initial/max baseline, typically pigs/sheep have 2 to 6 max hp)
				var is_hurt := false
				var child_name: String = child.get("name")
				
				if child_name.contains("PIG") or child_name.contains("SHEEP") or child_name.contains("CHICKEN"):
					is_hurt = current_hp < 2 # Max health is 2 (1 heart)
				elif child_name.contains("COW") or child_name.contains("GROWLITHE") or child_name.contains("OCTOPUS"):
					is_hurt = current_hp < 6 # Max health is 6 (3 hearts)
				else:
					is_hurt = current_hp < 4 # Max health is 4 (2 hearts)
					
				if is_hurt:
					var child_pos: Vector3 = child.global_position
					var dist_sq: float = host_pos.distance_squared_to(child_pos)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_injured = child as Node3D
						
	return closest_injured
