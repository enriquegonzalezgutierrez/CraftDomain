# ==============================================================================
# Pathfile: res://src/Domain/Life/VillagerAIBehavior.gd
# Description: Specialized AI behavior strategy implementing social life routines for
#              the Common Villager NPC. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VillagerAIBehavior
extends IAIBehavior

const SPEED_PATROL: float = 1.0
const SPEED_RETREAT: float = 1.6
const COOLDOWN_CHAT_SEC: float = 8.0
const CHAT_DURATION_SEC: float = 4.0
const RANGE_SIGHT_SQ: float = 36.0 

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "villager_wander_timer"
const META_WANDER_DIR := "villager_wander_dir"
const META_PEER := "villager_peer_target"
const META_COOLDOWN := "villager_chat_cooldown"
const META_CHAT_TIMER := "villager_chat_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives daily gossip walks, night retreats, and chat animations
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_villager_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_chat_cooldown(host, delta)
	
	var parent: Node = host.call("get_parent") as Node
	if _process_shelter_retreat(host, parent, delta):
		return
		
	var target_ref: Object = null
	if host.has_meta(META_PEER):
		var val: Variant = host.get_meta(META_PEER)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			target_ref = val as Object
			
	if is_instance_valid(target_ref):
		_process_gossip_chatter(host, target_ref, delta)
	else:
		_process_gossip_scanning(host)
		_process_default_patrol(host, delta)


func _update_chat_cooldown(host: Object, delta: float) -> void:
	var chat_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if chat_cooldown > 0.0:
		chat_cooldown -= delta
		host.set_meta(META_COOLDOWN, chat_cooldown)


func _process_shelter_retreat(host: Object, parent: Node, _delta: float) -> bool:
	var is_night := CelestialService.is_night_time_static()
	var is_storming := false
	
	if is_instance_valid(parent):
		var weather_node := parent.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node) and weather_node.get("current_weather") != null:
			var w_val := int(weather_node.get("current_weather"))
			is_storming = (w_val == 1 or w_val == 2)
			
	if not is_night and not is_storming:
		return false
		
	_reset_villager_state(host)
	var host_pos: Vector3 = host.get("global_position")
	var nav_service: Object = parent.get("navigation_service") if is_instance_valid(parent) else null
	
	if _is_inside_shelter(host_pos, nav_service):
		_execute_shelter_idle(host)
	else:
		_route_shelter_retreat(host, nav_service, host_pos)
	return true


func _is_inside_shelter(host_pos: Vector3, nav_service: Object) -> bool:
	if is_instance_valid(nav_service) and "_indoor_nodes" in nav_service:
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		var indoor_nodes: Array = nav_service.get("_indoor_nodes") as Array
		return indoor_nodes.has(my_coord)
	return false


func _execute_shelter_idle(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)


func _route_shelter_retreat(host: Object, nav_service: Object, host_pos: Vector3) -> void:
	if is_instance_valid(nav_service) and nav_service.has_method("find_closest_shelter_node"):
		var shelter_pos: Vector3 = nav_service.call("find_closest_shelter_node", host_pos)
		if shelter_pos != Vector3.ZERO:
			var path: Array = nav_service.call("find_path", host_pos, shelter_pos)
			if path.size() > 1:
				var ai: Object = host.get("ai_component")
				if is_instance_valid(ai):
					ai.set("_active_path", path)
					ai.set("_current_path_index", 0)
					ai.set("current_task", TASK_WANDERING)
					ai.set("task_timer", 15.0)


func _process_gossip_chatter(host: Object, target_ref: Object, delta: float) -> bool:
	var target_node := target_ref as Node3D
	var target_domain: Object = target_node.get("domain_entity") if is_instance_valid(target_node) else null
	
	if target_domain == null or target_domain.get("is_dead") == true:
		_reset_villager_state(host)
		return true
		
	var ai: Object = host.get("ai_component")
	var host_node := host as Node3D
	if not is_instance_valid(ai) or not is_instance_valid(host_node): return false
	
	ai.set("current_task", TASK_WORKING)
	var diff: Vector3 = target_node.global_position - host_node.global_position
	diff.y = 0.0
	var dist_sq := diff.length_squared()
	
	if dist_sq > 2.5:
		_apply_computed_movement_vectors(host, diff.normalized())
	else:
		_execute_social_gossip(host, ai, diff, delta)
	return true


func _execute_social_gossip(host: Object, ai: Object, diff: Vector3, delta: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	ai.set("wander_direction", diff.normalized())
	
	var chat_timer: float = host.get_meta(META_CHAT_TIMER) as float
	chat_timer -= delta
	if chat_timer <= 0.0:
		host.set_meta(META_COOLDOWN, COOLDOWN_CHAT_SEC)
		_reset_villager_state(host)
		return
		
	if int(round(chat_timer * 10.0)) % 15 == 0:
		if host.has_method("_play_gossip_chatter"):
			host.call("_play_gossip_chatter")
			
	host.set_meta(META_CHAT_TIMER, chat_timer)


func _process_gossip_scanning(host: Object) -> void:
	var chat_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if chat_cooldown <= 0.0:
		var peer_citizen := _scan_for_nearby_peer(host)
		if peer_citizen != null:
			host.set_meta(META_PEER, peer_citizen)
			host.set_meta(META_CHAT_TIMER, CHAT_DURATION_SEC)


func _process_default_patrol(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai) or ai.get("current_task") as int == TASK_WORKING: return
	
	ai.set("current_task", TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		var angle := randf() * TAU
		var parent: Node = host.call("get_parent") as Node
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		wander_dir = candidate_dir if _is_direction_safe_goblin(host, candidate_dir, parent) else Vector3.ZERO
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
	if not host.has_meta(META_PEER): host.set_meta(META_PEER, "")
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_CHAT_TIMER): host.set_meta(META_CHAT_TIMER, 0.0)


func _reset_villager_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_PEER, "")
	host.set_meta(META_CHAT_TIMER, 0.0)
	host.set_meta(META_WANDER_TIMER, 1.0)


func _scan_for_nearby_peer(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_peer: Node3D = null
	var min_dist_sq := RANGE_SIGHT_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var name_str: String = child.get("name")
			if name_str.contains("VILLAGER") or name_str.contains("MERCHANT") or name_str.contains("FARMER") or name_str.contains("MINER") or name_str.contains("DRUID"):
				var domain: Object = child.get("domain_entity")
				if domain != null and not domain.get("is_dead"):
					var dist_sq := host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_peer = child as Node3D
	return closest_peer


func _is_direction_safe_goblin(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	return ws.get_block(block_below_coord) != 6 and ws.get_block(block_at_coord) != 6 and ws.get_block(block_below_coord) != 0
