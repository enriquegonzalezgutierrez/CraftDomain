# ==============================================================================
# Pathfile: res://src/Domain/Life/CatAIBehavior.gd
# Description: Specialized AI behavior strategy implementing cozy domestic routines
#              for the Domestic Cat. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CatAIBehavior
extends IAIBehavior

const SPEED_RUN: float = 2.2
const SPEED_WALK: float = 1.0
const SPEED_CREEP: float = 0.6

const RANGE_ATTRACTION_SQ: float = 100.0 
const RANGE_ZOMBIE_SQ: float = 64.0       
const RANGE_CAMPFIRE_SQ: float = 144.0   

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "cat_wander_timer"
const META_WANDER_DIR := "cat_wander_dir"
const META_COOLDOWN := "cat_hiss_cooldown"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives follow food, campfire cozy, and zombie alarm states
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var hiss_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if hiss_cooldown > 0.0:
		hiss_cooldown -= delta
		host.set_meta(META_COOLDOWN, hiss_cooldown)
		
	var parent: Node = host.call("get_parent") as Node
	
	if _process_zombie_alarm(host, delta):
		return
	if _process_food_following(host, parent):
		return
	if _process_campfire_snuggle(host, parent):
		return
		
	_process_default_wandering(host, delta)


func _process_zombie_alarm(host: Object, _delta: float) -> bool:
	var closest_zombie := _detect_closest_zombie_threat(host)
	if closest_zombie == null:
		return false
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_PANIC)
	_handle_hiss_warning(host, closest_zombie)
	
	var parent: Node = host.call("get_parent") as Node
	var nav_service: Object = parent.get("navigation_service") if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	
	if is_instance_valid(nav_service) and nav_service.has_method("find_closest_shadow_shelter"):
		var shelter_pos: Vector3 = nav_service.call("find_closest_shadow_shelter", host_pos)
		if shelter_pos != Vector3.ZERO:
			var diff := shelter_pos - host_pos
			diff.y = 0.0
			if diff.length() > 0.8:
				_apply_flee_physics(host, diff.normalized())
				return true
				
	var escape_dir: Vector3 = (host_pos - closest_zombie.global_position).normalized()
	escape_dir.y = 0.0
	_apply_flee_physics(host, escape_dir)
	return true


func _handle_hiss_warning(host: Object, closest_zombie: Object) -> void:
	var hiss_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if hiss_cooldown <= 0.0:
		host.set_meta(META_COOLDOWN, 4.0)
		if host.has_method("_play_alarm_hiss"):
			host.call("_play_alarm_hiss", closest_zombie)


func _apply_flee_physics(host: Object, run_dir: Vector3) -> void:
	var ai: Object = host.get("ai_component")
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = run_dir.x * SPEED_RUN
	velocity.z = run_dir.z * SPEED_RUN
	host.set("velocity", velocity)
	if is_instance_valid(ai):
		ai.set("wander_direction", run_dir)


func _process_food_following(host: Object, parent: Node) -> bool:
	var player_node: Object = parent.call("get_node_or_null", "Player") if is_instance_valid(parent) else null
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	var p_pos: Vector3 = player_node.get("global_position")
	var dist_sq: float = host_pos.distance_squared_to(p_pos)
	
	if dist_sq >= RANGE_ATTRACTION_SQ or not _player_holds_chicken(player_node):
		return false
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WORKING)
	var diff := p_pos - host_pos
	diff.y = 0.0
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if diff.length() > 1.5:
		var creep_dir := diff.normalized()
		velocity.x = creep_dir.x * SPEED_WALK * 1.5
		velocity.z = creep_dir.z * SPEED_WALK * 1.5
		host.set("velocity", velocity)
		ai.set("wander_direction", creep_dir)
	else:
		velocity.x = 0.0; velocity.z = 0.0
		host.set("velocity", velocity)
		ai.set("wander_direction", diff.normalized())
	return true


func _player_holds_chicken(player_node: Object) -> bool:
	var inventory := player_node.get("inventory")
	if is_instance_valid(inventory):
		var active_slot: int = player_node.get("active_slot_index") as int
		var slot_data: Object = inventory.call("get_slot_data", active_slot)
		return is_instance_valid(slot_data) and slot_data.get("item_id") == 16
	return false


func _process_campfire_snuggle(host: Object, parent: Node) -> bool:
	var host_pos: Vector3 = host.get("global_position")
	var closest_campfire := _detect_closest_village_campfire(host_pos, parent)
	if closest_campfire == null:
		return false
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WORKING)
	var fire_pos: Vector3 = closest_campfire.global_position
	var diff := fire_pos - host_pos
	diff.y = 0.0
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if diff.length() > 1.8:
		var walk_dir := diff.normalized()
		velocity.x = walk_dir.x * SPEED_CREEP
		velocity.z = walk_dir.z * SPEED_CREEP
		host.set("velocity", velocity)
		ai.set("wander_direction", walk_dir)
	else:
		velocity.x = 0.0; velocity.z = 0.0
		host.set("velocity", velocity)
		ai.set("wander_direction", diff.normalized())
	return true


func _process_default_wandering(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		wander_dir = Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU)) if randf() < 0.4 else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_WALK
		velocity.z = wander_dir.z * SPEED_WALK
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WALK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WALK)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)


func _detect_closest_village_campfire(host_pos: Vector3, world_node: Node) -> Object:
	if not is_instance_valid(world_node): return null
	var closest_fire: Object = null
	var min_dist_sq: float = RANGE_CAMPFIRE_SQ
	
	for child in world_node.get_children():
		if is_instance_valid(child) and child.name.begins_with("Prop_CAMPFIRE"):
			var dist_sq: float = host_pos.distance_squared_to(child.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest_fire = child
	return closest_fire


func _detect_closest_zombie_threat(host: Object) -> Object:
	if not host.call("is_inside_tree"): return null
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
