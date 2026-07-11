# ==============================================================================
# Pathfile: res://src/Domain/Life/DruidAIBehavior.gd
# Description: Specialized AI behavior strategy implementing the Forest Druid's 
#              mystical protector routines. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DruidAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.1
const COOLDOWN_SPELL_SEC: float = 6.0
const CAST_DURATION_SEC: float = 2.0
const RANGE_SENSE_SQ: float = 64.0 

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "druid_wander_timer"
const META_WANDER_DIR := "druid_wander_dir"
const META_COOLDOWN := "druid_spell_cooldown"
const META_TARGET_ANIMAL := "druid_heal_target"
const META_CAST_TIMER := "druid_cast_timer"


func _init() -> void:
	overrides_wandering = false


## Concrete Contract: Drives the wildlife scanning and channeling of healing magic
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_druid_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_spell_cooldown(host, delta)
	
	var target_ref: Object = null
	if host.has_meta(META_TARGET_ANIMAL):
		var val: Variant = host.get_meta(META_TARGET_ANIMAL)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			target_ref = val as Object
			
	if is_instance_valid(target_ref):
		_process_healing_ritual(host, target_ref, delta)
	else:
		_process_fauna_scanning(host)
		_process_default_patrol(host, delta)


func _update_spell_cooldown(host: Object, delta: float) -> void:
	var spell_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if spell_cooldown > 0.0:
		spell_cooldown -= delta
		host.set_meta(META_COOLDOWN, spell_cooldown)


func _process_healing_ritual(host: Object, target_ref: Object, delta: float) -> void:
	var target_node := target_ref as Node3D
	var target_domain: Object = target_node.get("domain_entity") if is_instance_valid(target_node) else null
	
	if target_domain == null or target_domain.get("is_dead") == true:
		_reset_druid_state(host)
		return
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WORKING)
	var host_pos: Vector3 = host.get("global_position")
	var diff := target_node.global_position - host_pos
	diff.y = 0.0
	
	if diff.length_squared() > 2.0:
		var walk_dir := diff.normalized()
		_apply_computed_movement_vectors(host, walk_dir)
	else:
		_execute_healing_channel(host, ai, target_node, diff, delta)


func _execute_healing_channel(host: Object, ai: Object, target_node: Node3D, diff: Vector3, delta: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	ai.set("wander_direction", diff.normalized())
	
	var vis_rep: Object = host.get("visual_representation")
	if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
		vis_rep.call("trigger_attack_visuals")
		
	if host.has_method("_play_healing_visuals"):
		host.call("_play_healing_visuals", target_node)
		
	var cast_timer: float = host.get_meta(META_CAST_TIMER) as float
	cast_timer -= delta
	if cast_timer <= 0.0:
		_complete_healing_spell(host, target_node)
	else:
		host.set_meta(META_CAST_TIMER, cast_timer)


func _complete_healing_spell(host: Object, target_node: Node3D) -> void:
	var target_domain: Object = target_node.get("domain_entity")
	if target_domain != null:
		target_domain.set("health", 6) # Restore to full health
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.y = 4.0 
	host.set("velocity", velocity)
	
	host.set_meta(META_COOLDOWN, COOLDOWN_SPELL_SEC)
	_reset_druid_state(host)


func _process_fauna_scanning(host: Object) -> void:
	var spell_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if spell_cooldown <= 0.0:
		var injured_creature := _scan_for_injured_animals(host)
		if injured_creature != null:
			host.set_meta(META_TARGET_ANIMAL, injured_creature)
			host.set_meta(META_CAST_TIMER, CAST_DURATION_SEC)


func _process_default_patrol(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai) or ai.get("current_task") as int == TASK_WORKING: return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		wander_dir = Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU)) if randf() < 0.45 else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, wander_dir)


func _apply_computed_movement_vectors(host: Object, wander_dir: Vector3) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_PATROL
		velocity.z = wander_dir.z * SPEED_PATROL
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_PATROL)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_PATROL)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET_ANIMAL): host.set_meta(META_TARGET_ANIMAL, "")
	if not host.has_meta(META_CAST_TIMER): host.set_meta(META_CAST_TIMER, 0.0)


func _reset_druid_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_ANIMAL, "")
	host.set_meta(META_CAST_TIMER, 0.0)


func _scan_for_injured_animals(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_injured: Node3D = null
	var min_dist_sq := RANGE_SENSE_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var domain: Object = child.get("domain_entity")
			if domain != null and not domain.get("is_dead"):
				var current_hp: int = domain.get("health") as int
				var is_hurt := false
				var child_name: String = child.get("name")
				
				if child_name.contains("PIG") or child_name.contains("SHEEP") or child_name.contains("CHICKEN"):
					is_hurt = current_hp < 2 
				elif child_name.contains("COW") or child_name.contains("GROWLITHE") or child_name.contains("OCTOPUS"):
					is_hurt = current_hp < 6 
				else:
					is_hurt = current_hp < 4 
					
				if is_hurt:
					var child_pos: Vector3 = child.global_position
					var dist_sq: float = host_pos.distance_squared_to(child_pos)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_injured = child as Node3D
	return closest_injured
