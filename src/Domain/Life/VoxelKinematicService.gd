# ==============================================================================
# Pathfile: res://src/Domain/Life/VoxelKinematicService.gd
# Description: Pure Domain Service consolidating kinematic velocity vectors,
#              A* path traversal, and voxel boundary safety checks for entities.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelKinematicService
extends RefCounted


## Sets physical velocity vectors and updates the AI gaze direction on the host context.
static func apply_motion_vectors(host: Object, ai: Object, direction: Vector3, speed: float) -> void:
	if not is_instance_valid(host):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	if direction != Vector3.ZERO:
		var target_x := direction.x * speed
		var target_z := direction.z * speed
		velocity.x = lerp(velocity.x, target_x, 0.25)
		velocity.z = lerp(velocity.z, target_z, 0.25)
		if is_instance_valid(ai): 
			ai.set("wander_direction", direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 0.2)
		velocity.z = move_toward(velocity.z, 0.0, speed * 0.2)
		if is_instance_valid(ai): 
			ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


## Instantly halts the host's horizontal velocity vectors.
static func halt_movement(host: Object, ai: Object) -> void:
	if not is_instance_valid(host):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0
	velocity.z = 0.0
	host.set("velocity", velocity)
	if is_instance_valid(ai):
		ai.set("wander_direction", Vector3.ZERO)


## Navigates the host object along an A* path array.
static func navigate_along_path(host: Object, ai: Object, path: Array, path_index: int, speed: float, meta_index_key: String) -> int:
	if not is_instance_valid(host) or path_index >= path.size():
		halt_movement(host, ai)
		if is_instance_valid(host): host.set_meta("nav_stuck_time", 0.0)
		return path_index
		
	var target_node: Vector3 = path[path_index]
	var target_coord := Vector3i(floori(target_node.x), floori(target_node.y), floori(target_node.z))
	
	if _is_path_invalidated_by_voxel_changes(host, target_coord, meta_index_key):
		return path_index
		
	var host_pos: Vector3 = host.get("global_position")
	var diff := target_node - host_pos
	diff.y = 0.0
	
	if diff.length_squared() < 0.16:
		return _advance_path_node(host, path_index, meta_index_key)
		
	if _evaluate_stuck_state(host, speed):
		return _advance_path_node(host, path_index, meta_index_key, true)
		
	apply_motion_vectors(host, ai, diff.normalized(), speed)
	return path_index


## Calculates a safe, wall-free fallback direction in the voxel grid if A* pathfinding is empty.
static func get_safe_fallback_wander_direction(host: Object, ws: WorldState) -> Vector3:
	if not is_instance_valid(host) or ws == null:
		var angle := randf() * TAU
		return Vector3(cos(angle), 0.0, sin(angle)).normalized()
		
	var host_pos: Vector3 = host.get("global_position")
	var start_angle := randf() * TAU
	
	for i in range(16):
		var angle := start_angle + (float(i) / 16.0) * TAU
		var candidate := Vector3(cos(angle), 0.0, sin(angle)).normalized()
		var check_pos := host_pos + candidate * 0.8
		var feet_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.1), floori(check_pos.z))
		var chest_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 1.1), floori(check_pos.z))
		
		if not BlockLibrary.is_solid(ws.get_block(feet_coord)) and not BlockLibrary.is_solid(ws.get_block(chest_coord)):
			return candidate
			
	return Vector3.ZERO


static func _is_path_invalidated_by_voxel_changes(host: Object, target_coord: Vector3i, meta_index_key: String) -> bool:
	var world_node: Object = host.call("get_parent")
	if is_instance_valid(world_node) and "world_state" in world_node:
		var ws: WorldState = world_node.get("world_state") as WorldState
		if is_instance_valid(ws) and not _is_node_still_walkable(ws, target_coord):
			_invalidate_active_path(host, meta_index_key)
			return true
	return false


static func _advance_path_node(host: Object, current_index: int, meta_index_key: String, trigger_hop: bool = false) -> int:
	var next_idx := current_index + 1
	host.set_meta(meta_index_key, next_idx)
	host.set_meta("nav_stuck_time", 0.0)
	
	if trigger_hop:
		var velocity: Vector3 = host.get("velocity")
		velocity.y = 3.5 
		host.set("velocity", velocity)
		
	return next_idx


static func _evaluate_stuck_state(host: Object, speed: float) -> bool:
	var host_pos: Vector3 = host.get("global_position")
	var last_pos: Vector3 = host.get_meta("nav_last_pos") if host.has_meta("nav_last_pos") else host_pos
	var stuck_time: float = host.get_meta("nav_stuck_time") if host.has_meta("nav_stuck_time") else 0.0
	
	var delta: float = host.call("get_physics_process_delta_time") as float if host.has_method("get_physics_process_delta_time") else 0.016
	var dist_moved := host_pos.distance_to(last_pos)
	
	var is_stopped := dist_moved < (speed * delta * 0.1)
	stuck_time = (stuck_time + delta) if (is_stopped and speed > 0.1) else move_toward(stuck_time, 0.0, delta * 2.0)
		
	host.set_meta("nav_last_pos", host_pos)
	host.set_meta("nav_stuck_time", stuck_time)
	return stuck_time >= 0.8


static func _is_node_still_walkable(ws: WorldState, coord: Vector3i) -> bool:
	var block_below := ws.get_block(coord + Vector3i(0, -1, 0))
	var def_below := BlockLibrary.get_definition(block_below)
	if not BlockLibrary.is_solid(block_below) or (def_below != null and def_below.is_liquid):
		return false 
		
	var block_feet := ws.get_block(coord)
	var block_above := ws.get_block(coord + Vector3i(0, 1, 0))
	return not BlockLibrary.is_solid(block_feet) and not BlockLibrary.is_solid(block_above)


static func _invalidate_active_path(host: Object, meta_index_key: String) -> void:
	host.set_meta(meta_index_key, 9999) 
	if host.has_meta("guard_active_path"):
		host.set_meta("guard_active_path", [])
	if host.has_meta("villager_active_path"):
		host.set_meta("villager_active_path", [])
	if host.has_meta("quique_active_path"):
		host.set_meta("quique_active_path", [])
