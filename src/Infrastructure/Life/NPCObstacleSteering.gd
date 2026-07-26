# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCObstacleSteering.gd
# Description: Context-Based Steering Component managing local dynamic 
#              obstacle avoidance, step climbing, and smooth wall sliding.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NPCObstacleSteering
extends Node

const SCAN_DISTANCE_FAR: float = 0.50
const SCAN_DISTANCE_CLOSE: float = 0.38
const YIELD_WAIT_TIME_SEC: float = 1.0
const JUMP_RECOVERY_COOLDOWN_SEC: float = 0.40
const MIN_WALKABLE_HEIGHT: float = 1.5

var host: CharacterBody3D
var ai_component: Node

var _yield_timer: float = 0.0
var _last_jump_time: float = 0.0


func initialize(p_host: CharacterBody3D, p_ai_component: Node) -> void:
	host = p_host
	ai_component = p_ai_component


func process_steering(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(ai_component):
		return
		
	var space_state := host.get_world_3d().direct_space_state
	if space_state == null:
		return
		
	_enforce_physical_wall_sliding()
	
	var is_yielding := _process_entity_yielding(space_state, delta)
	if not is_yielding:
		_process_whisker_deflection(space_state)
		
	_process_step_climbing()


func _enforce_physical_wall_sliding() -> void:
	if not host.is_on_wall():
		return
		
	var normal := host.get_wall_normal()
	var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
	if flat_normal == Vector3.ZERO:
		return
		
	var current_dir: Vector3 = ai_component.get("wander_direction") as Vector3
	if current_dir != Vector3.ZERO and current_dir.dot(-flat_normal) > 0.1:
		var slide_dir := current_dir.slide(flat_normal).normalized()
		if slide_dir != Vector3.ZERO:
			_apply_new_direction_and_sync_blackboard(slide_dir)


func _process_entity_yielding(space_state: PhysicsDirectSpaceState3D, delta: float) -> bool:
	var dir: Vector3 = ai_component.get("wander_direction") as Vector3
	if dir == Vector3.ZERO:
		_yield_timer = 0.0
		host.set_meta("diag_yield", false)
		return false
		
	var ray_origin := _get_ray_origin()
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + dir * SCAN_DISTANCE_FAR)
	query.exclude = [host.get_rid()]
	query.hit_back_faces = true
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty() and result["collider"] is CharacterBody3D and result["collider"] != host:
		host.set_meta("diag_yield", true)
		return _apply_yield_deceleration(delta)
			
	_yield_timer = 0.0
	host.set_meta("diag_yield", false)
	return false


func _apply_yield_deceleration(delta: float) -> bool:
	_yield_timer += delta
	if _yield_timer < YIELD_WAIT_TIME_SEC:
		host.velocity.x = lerp(host.velocity.x, 0.0, delta * 8.0)
		host.velocity.z = lerp(host.velocity.z, 0.0, delta * 8.0)
		return true 
	return false


func _process_whisker_deflection(space_state: PhysicsDirectSpaceState3D) -> void:
	if _is_navigating_macro_path():
		return 
		
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	var ray_origin := _get_ray_origin()
	var center_dir := wander_direction.normalized()
	var left_dir := center_dir.rotated(Vector3.UP, deg_to_rad(30.0))
	var right_dir := center_dir.rotated(Vector3.UP, deg_to_rad(-30.0))
	
	_evaluate_whisker_rays(space_state, ray_origin, [center_dir, left_dir, right_dir], wander_direction)


func _evaluate_whisker_rays(space_state: PhysicsDirectSpaceState3D, ray_origin: Vector3, scan_dirs: Array, wander_dir: Vector3) -> void:
	var best_normal := Vector3.ZERO
	var min_distance := 999.0
	
	for dir: Vector3 in scan_dirs:
		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + dir * SCAN_DISTANCE_FAR)
		query.collision_mask = 1 
		query.exclude = [host.get_rid()]
		
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_pos: Vector3 = result["position"] as Vector3
			var dist := ray_origin.distance_to(hit_pos)
			if dist < min_distance:
				min_distance = dist
				best_normal = result["normal"] as Vector3
				
	_apply_deflection_vector(best_normal, wander_dir)


func _apply_deflection_vector(best_normal: Vector3, wander_dir: Vector3) -> void:
	if best_normal != Vector3.ZERO:
		var flat_normal := Vector3(best_normal.x, 0.0, best_normal.z).normalized()
		if flat_normal != Vector3.ZERO:
			var dot_prod := wander_dir.normalized().dot(-flat_normal)
			if dot_prod > 0.20:
				var slide_dir := wander_dir.slide(flat_normal).normalized()
				if slide_dir == Vector3.ZERO:
					slide_dir = flat_normal.rotated(Vector3.UP, deg_to_rad(45.0)).normalized()
				_apply_new_direction_and_sync_blackboard(slide_dir)
		host.set_meta("diag_whisk", true)
	else:
		host.set_meta("diag_whisk", false)


func _apply_new_direction_and_sync_blackboard(new_dir: Vector3) -> void:
	ai_component.set("wander_direction", new_dir)
	if "active_behavior" in ai_component and ai_component.active_behavior != null:
		var bb: Variant = ai_component.active_behavior.get("_blackboard")
		if bb != null and bb.has_method("set_memory"):
			bb.call("set_memory", "wander_direction", new_dir)


func _process_step_climbing() -> void:
	if not host.is_on_wall():
		return
		
	var wall_normal := host.get_wall_normal()
	if wall_normal == Vector3.ZERO:
		return
		
	var forward_dir := Vector3(-wall_normal.x, 0.0, -wall_normal.z).normalized()
	var check_pos := host.global_position + forward_dir * 0.40
	var feet_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.1), floori(check_pos.z))
	var chest_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 1.1), floori(check_pos.z))
	
	var world_node := host.get_parent()
	if not is_instance_valid(world_node) or not "world_state" in world_node:
		return
		
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null:
		return
		
	if BlockLibrary.is_solid(ws.get_block(feet_coord)) and not BlockLibrary.is_solid(ws.get_block(chest_coord)):
		_trigger_step_jump()


func _trigger_step_jump() -> void:
	var current_time := float(Time.get_ticks_msec()) / 1000.0
	if (current_time - _last_jump_time) < JUMP_RECOVERY_COOLDOWN_SEC:
		return
		
	if host.is_on_floor():
		var jump_vel: float = host.get("JUMP_VELOCITY") as float if "JUMP_VELOCITY" in host else 5.0
		host.velocity.y = jump_vel
		_last_jump_time = current_time


func _get_ray_origin() -> Vector3:
	var height_offset: float = MIN_WALKABLE_HEIGHT * 0.4
	if "_collision_height" in host:
		height_offset = (host.get("_collision_height") as float) * 0.45
	return host.global_position + Vector3(0.0, height_offset, 0.0)


func _is_navigating_macro_path() -> bool:
	if host.has_meta("guard_active_path"):
		return not (host.get_meta("guard_active_path") as Array).is_empty()
	if host.has_meta("villager_active_path"):
		return not (host.get_meta("villager_active_path") as Array).is_empty()
	return false
