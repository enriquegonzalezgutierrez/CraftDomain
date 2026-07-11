# ==============================================================================
# Pathfile: res://src/Domain/Life/RaccoonAIBehavior.gd
# Description: Specialized AI behavior strategy implementing nighttime scavenging 
#              routines for the Forest Raccoon. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RaccoonAIBehavior
extends IAIBehavior

const SPEED_SNEAK: float = 1.1
const SPEED_RUN: float = 2.4
const SCAVENGE_DURATION_SEC: float = 3.0
const RANGE_SENSORY_SQ: float = 225.0 

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "raccoon_wander_timer"
const META_WANDER_DIR := "raccoon_wander_dir"
const META_TARGET_PROP := "raccoon_target_prop"
const META_MINE_TIMER := "raccoon_mine_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives day sleep cycles and nighttime barrel breakouts
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var is_night := CelestialService.is_night_time_static()
	if not is_night:
		_process_daytime_sleep(host)
		return
		
	var parent: Node = host.call("get_parent") as Node
	var is_scavenging := _process_nighttime_scavenge(host, parent, delta)
	
	if not is_scavenging:
		_process_default_roam(host, delta)


func _process_daytime_sleep(host: Object) -> void:
	_reset_raccoon_state(host)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	
	if is_instance_valid(ai):
		ai.set("wander_direction", Vector3.ZERO)


func _process_nighttime_scavenge(host: Object, parent: Node, delta: float) -> bool:
	var target_ref: Object = null
	if host.has_meta(META_TARGET_PROP):
		var val: Variant = host.get_meta(META_TARGET_PROP)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			target_ref = val as Object
			
	var host_pos: Vector3 = host.get("global_position")
	if target_ref == null:
		var closest_barrel := _detect_closest_village_barrel(host_pos, parent)
		if closest_barrel != null:
			target_ref = closest_barrel
			host.set_meta(META_TARGET_PROP, target_ref)
			host.set_meta(META_MINE_TIMER, SCAVENGE_DURATION_SEC)
			
	if is_instance_valid(target_ref):
		_execute_barrel_breakout(host, target_ref, delta)
		return true
		
	return false


func _execute_barrel_breakout(host: Object, target_ref: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WORKING)
	var target_node := target_ref as Node3D
	var host_node := host as Node3D
	
	if not is_instance_valid(target_node) or not is_instance_valid(host_node):
		return
		
	var diff: Vector3 = target_node.global_position - host_node.global_position
	diff.y = 0.0
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if diff.length() > 1.2:
		var sneak_dir: Vector3 = diff.normalized()
		velocity.x = sneak_dir.x * SPEED_SNEAK
		velocity.z = sneak_dir.z * SPEED_SNEAK
		host.set("velocity", velocity)
		ai.set("wander_direction", sneak_dir)
	else:
		_scratch_and_deplete_barrel(host, ai, target_node, diff, delta)


func _scratch_and_deplete_barrel(host: Object, ai: Object, target_node: Node3D, diff: Vector3, delta: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	ai.set("wander_direction", diff.normalized())
	
	if host.has_method("_play_scratching_effect"):
		host.call("_play_scratching_effect", target_node)
		
	var mine_timer: float = host.get_meta(META_MINE_TIMER) as float
	mine_timer -= delta
	if mine_timer <= 0.0:
		_complete_barrel_break(host, ai, target_node)
	else:
		host.set_meta(META_MINE_TIMER, mine_timer)


func _complete_barrel_break(host: Object, _ai: Object, target_node: Node3D) -> void:
	if target_node.has_method("interact"):
		target_node.call("interact", host) 
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.y = 5.0
	host.set("velocity", velocity)
	
	_reset_raccoon_state(host)


func _process_default_roam(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		var angle := randf() * TAU
		var parent: Node = host.call("get_parent") as Node
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		wander_dir = candidate_dir if _is_direction_safe_raccoon(host, candidate_dir, parent) else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, wander_dir)


func _apply_computed_movement_vectors(host: Object, wander_dir: Vector3) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_SNEAK * 1.3
		velocity.z = wander_dir.z * SPEED_SNEAK * 1.3
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_SNEAK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_SNEAK)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_TARGET_PROP): host.set_meta(META_TARGET_PROP, "")
	if not host.has_meta(META_MINE_TIMER): host.set_meta(META_MINE_TIMER, 0.0)


func _reset_raccoon_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_PROP, "")
	host.set_meta(META_MINE_TIMER, 0.0)
	host.set_meta(META_WANDER_TIMER, 1.0)


func _detect_closest_village_barrel(host_pos: Vector3, world_node: Node) -> Object:
	if not is_instance_valid(world_node): return null
	var closest_prop: Object = null
	var min_dist_sq: float = RANGE_SENSORY_SQ
	
	for child in world_node.get_children():
		if is_instance_valid(child) and (child.name.begins_with("Prop_BARREL") or child.name.begins_with("Prop_CHEST")):
			var dist_sq: float = host_pos.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_prop = child
	return closest_prop


func _is_direction_safe_raccoon(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	return ws.get_block(block_below_coord) != 6 and ws.get_block(block_at_coord) != 6 and ws.get_block(block_below_coord) != 0
