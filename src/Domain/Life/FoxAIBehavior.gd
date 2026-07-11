# ==============================================================================
# Pathfile: res://src/Domain/Life/FoxAIBehavior.gd
# Description: Specialized AI behavior strategy implementing stealth predator routines
#              for the Forest Fox. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FoxAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.1
const SPEED_SNEAK: float = 0.7
const SPEED_POUNCE: float = 4.5
const COOLDOWN_POUNCE_SEC: float = 4.0

const RANGE_SIGHT_SQ: float = 144.0  
const RANGE_POUNCE_SQ: float = 20.25 

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "fox_wander_timer"
const META_WANDER_DIR := "fox_wander_dir"
const META_TARGET_PREY := "fox_prey_target"
const META_COOLDOWN := "fox_pounce_cooldown"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives sneaking stalk approaches, pounce leaps, and barks
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var pounce_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if pounce_cooldown > 0.0:
		pounce_cooldown -= delta
		host.set_meta(META_COOLDOWN, pounce_cooldown)
		
	var target_ref: Object = null
	if host.has_meta(META_TARGET_PREY):
		var val: Variant = host.get_meta(META_TARGET_PREY)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			target_ref = val as Object
			
	if is_instance_valid(target_ref):
		_process_prey_hunting(host, target_ref, delta)
	else:
		_process_prey_scanning(host, pounce_cooldown)
		_process_default_patrol(host, delta)


func _process_prey_hunting(host: Object, target_ref: Object, _delta: float) -> bool:
	var target_node := target_ref as Node3D
	var target_domain: Object = target_node.get("domain_entity") if is_instance_valid(target_node) else null
	var host_node := host as Node3D
	
	if target_domain == null or target_domain.get("is_dead") == true or not is_instance_valid(host_node):
		_reset_fox_state(host)
		return true
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WORKING)
	var diff: Vector3 = target_node.global_position - host_node.global_position
	diff.y = 0.0
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if diff.length_squared() > RANGE_POUNCE_SQ:
		var stalk_dir: Vector3 = diff.normalized()
		velocity.x = stalk_dir.x * SPEED_SNEAK
		velocity.z = stalk_dir.z * SPEED_SNEAK
		host.set("velocity", velocity)
		ai.set("wander_direction", stalk_dir)
		if host.has_method("_set_crouch_height"):
			host.call("_set_crouch_height", true)
	else:
		_execute_pounce_leap(host, target_node, diff)
		
	return true


func _execute_pounce_leap(host: Object, target_node: Node3D, diff: Vector3) -> void:
	var pounce_cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	if host.call("is_on_floor") and pounce_cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_POUNCE_SEC)
		
		var velocity: Vector3 = host.get("velocity") as Vector3
		var leap_dir := diff.normalized()
		velocity.x = leap_dir.x * SPEED_POUNCE
		velocity.z = leap_dir.z * SPEED_POUNCE
		velocity.y = 5.8 
		host.set("velocity", velocity)
		
		if host.has_method("_execute_pounce_strike"):
			host.call("_execute_pounce_strike", target_node)
			
		_reset_fox_state(host)


func _process_prey_scanning(host: Object, pounce_cooldown: float) -> void:
	if host.has_method("_set_crouch_height"):
		host.call("_set_crouch_height", false)
		
	if pounce_cooldown <= 0.0:
		var closest_prey := _scan_for_peaceful_prey(host)
		if closest_prey != null:
			host.set_meta(META_TARGET_PREY, closest_prey)


func _process_default_patrol(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai) or ai.get("current_task") as int == TASK_WORKING: return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.5)
		var angle := randf() * TAU
		var parent: Node = host.call("get_parent") as Node
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		wander_dir = candidate_dir if _is_direction_safe_fox(host, candidate_dir, parent) else Vector3.ZERO
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
	if not host.has_meta(META_TARGET_PREY): host.set_meta(META_TARGET_PREY, "")


func _reset_fox_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_PREY, "")
	host.set_meta(META_WANDER_TIMER, 1.0)


func _scan_for_peaceful_prey(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_prey: Node3D = null
	var min_dist_sq := RANGE_SIGHT_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var name_str: String = child.get("name")
			if name_str.contains("CHICKEN") or name_str.contains("BIRD"):
				var domain: Object = child.get("domain_entity")
				if domain != null and not domain.get("is_dead"):
					var dist_sq := host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_prey = child as Node3D
	return closest_prey


func _is_direction_safe_fox(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	return ws.get_block(block_below_coord) != 6 and ws.get_block(block_at_coord) != 6 and ws.get_block(block_below_coord) != 0
