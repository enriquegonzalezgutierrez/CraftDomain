# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCObstacleSteering.gd
# Description: Context-Based Steering Component managing local dynamic 
#              avoidance, step auto-jumping, and cooperative yielding.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NPCObstacleSteering
extends Node

const SCAN_DISTANCE: float = 1.2
const YIELD_WAIT_TIME_SEC: float = 1.5
const JUMP_RECOVERY_COOLDOWN: float = 0.4
const STEERING_COOLDOWN_SEC: float = 0.6

var host: CharacterBody3D
var ai_component: Node

var _yield_timer: float = 0.0


func initialize(p_host: CharacterBody3D, p_ai_component: Node) -> void:
	host = p_host
	ai_component = p_ai_component


func process_steering(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(ai_component):
		return
		
	var space_state := host.get_world_3d().direct_space_state
	if space_state == null:
		return
		
	var is_yielding := _process_dynamic_yielding(space_state, delta)
	if not is_yielding:
		_perform_proactive_whisker_avoidance(space_state, delta)
		
	_handle_step_climbing_and_unsticking(delta)


# ==============================================================================
# COOPERATIVE YIELDING (Dynamic Collision Resolution)
# ==============================================================================

func _process_dynamic_yielding(space_state: PhysicsDirectSpaceState3D, delta: float) -> bool:
	var dir: Vector3 = ai_component.get("wander_direction") as Vector3
	if dir == Vector3.ZERO:
		_yield_timer = 0.0
		host.set_meta("diag_yield", false)
		return false
		
	var r_origin := _get_dynamic_ray_origin()
	var query := PhysicsRayQueryParameters3D.create(r_origin, r_origin + dir * SCAN_DISTANCE)
	query.exclude = [host.get_rid()]
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty() and result["collider"] is CharacterBody3D and result["collider"] != host:
		host.set_meta("diag_yield", true)
		return _execute_yield_wait_logic(delta)
			
	_yield_timer = 0.0
	host.set_meta("diag_yield", false)
	return false


func _execute_yield_wait_logic(delta: float) -> bool:
	_yield_timer += delta
	if _yield_timer < YIELD_WAIT_TIME_SEC:
		host.velocity.x = lerp(host.velocity.x, 0.0, delta * 8.0)
		host.velocity.z = lerp(host.velocity.z, 0.0, delta * 8.0)
		return true 
	return false


# ==============================================================================
# WHISKER AVOIDANCE & TERRAIN KINEMATICS
# ==============================================================================

func _perform_proactive_whisker_avoidance(space_state: PhysicsDirectSpaceState3D, delta: float) -> void:
	if _is_navigating_macro_path():
		return 
		
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	var r_origin := _get_dynamic_ray_origin()
	var center_dir := wander_direction.normalized()
	var left_dir := center_dir.rotated(Vector3.UP, deg_to_rad(30.0))
	var right_dir := center_dir.rotated(Vector3.UP, deg_to_rad(-30.0))
	
	_cast_whisker_rays(space_state, r_origin, [center_dir, left_dir, right_dir], wander_direction, delta)


func _cast_whisker_rays(space_state: PhysicsDirectSpaceState3D, r_origin: Vector3, scan_dirs: Array, wander_dir: Vector3, delta: float) -> void:
	var best_normal := Vector3.ZERO
	var closest_dist := 999.0
	
	for dir: Vector3 in scan_dirs:
		var query := PhysicsRayQueryParameters3D.create(r_origin, r_origin + dir * SCAN_DISTANCE)
		query.collision_mask = 1 
		query.exclude = [host.get_rid()]
		
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			var dist := r_origin.distance_to(result["position"] as Vector3)
			if dist < closest_dist:
				closest_dist = dist
				best_normal = result["normal"] as Vector3
				
	_apply_whisker_steering(best_normal, wander_dir, delta)


func _apply_whisker_steering(best_normal: Vector3, wander_dir: Vector3, delta: float) -> void:
	var cooldown: float = host.get_meta("whisker_cooldown") if host.has_meta("whisker_cooldown") else 0.0
	cooldown -= delta
	host.set_meta("whisker_cooldown", maxf(0.0, cooldown))
	
	if best_normal != Vector3.ZERO and cooldown <= 0.0:
		var flat_normal := Vector3(best_normal.x, 0.0, best_normal.z).normalized()
		if flat_normal != Vector3.ZERO:
			var dot_prod := wander_dir.dot(-flat_normal)
			if dot_prod > 0.85:
				var bounce_dir := flat_normal.rotated(Vector3.UP, randf_range(-0.4, 0.4)).normalized()
				ai_component.set("wander_direction", bounce_dir)
				host.set_meta("whisker_cooldown", STEERING_COOLDOWN_SEC)
		host.set_meta("diag_whisk", true)
	else:
		host.set_meta("diag_whisk", false)


func _handle_step_climbing_and_unsticking(delta: float) -> void:
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	if _is_touching_solid_block():
		var stuck_timer: float = ai_component.get("stuck_timer") as float
		ai_component.set("stuck_timer", stuck_timer + delta)
		_evaluate_step_climbing()
	else:
		ai_component.set("stuck_timer", 0.0)


func _is_touching_solid_block() -> bool:
	if not host.is_on_wall():
		return false
		
	for i in range(host.get_slide_collision_count()):
		var collision := host.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider == null and collision.get_collider_rid().is_valid():
			return true
		if is_instance_valid(collider) and collider is StaticBody3D:
			return true
			
	return false


func _evaluate_step_climbing() -> void:
	var wall_normal := host.get_wall_normal()
	if wall_normal == Vector3.ZERO: return
		
	var forward_dir := Vector3(-wall_normal.x, 0.0, -wall_normal.z).normalized()
	var check_pos := host.global_position + forward_dir * 0.6
	var feet_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.1), floori(check_pos.z))
	var chest_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 1.1), floori(check_pos.z))
	var head_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y + 2.1), floori(host.global_position.z))
	
	var parent_node := host.get_parent()
	if not is_instance_valid(parent_node) or not "world_state" in parent_node: return
	var ws: WorldState = parent_node.get("world_state") as WorldState
	if ws == null: return
		
	var is_feet_solid := BlockLibrary.is_solid(ws.get_block(feet_coord))
	var is_chest_solid := BlockLibrary.is_solid(ws.get_block(chest_coord))
	var is_head_blocked := BlockLibrary.is_solid(ws.get_block(head_coord))
	
	if is_feet_solid and not is_chest_solid and not is_head_blocked:
		_execute_jump_to_step(feet_coord, parent_node)
	elif is_chest_solid:
		_apply_wall_slide_steering(wall_normal)


func _execute_jump_to_step(_target_coord: Vector3i, _world_node: Node) -> void:
	var last_jump: float = host.get_meta("last_jump_time") if host.has_meta("last_jump_time") else 0.0
	var current_time := Time.get_ticks_msec() / 1000.0
	
	if (current_time - last_jump) < JUMP_RECOVERY_COOLDOWN:
		return
		
	if host.is_on_floor():
		var jump_vel: float = host.get("JUMP_VELOCITY") as float if "JUMP_VELOCITY" in host else 5.0
		host.velocity.y = jump_vel
		host.set_meta("last_jump_time", current_time)
		ai_component.set("stuck_timer", 0.0)


func _apply_wall_slide_steering(wall_normal: Vector3) -> void:
	var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	if flat_normal != Vector3.ZERO:
		var bounce_dir := flat_normal.rotated(Vector3.UP, randf_range(-0.4, 0.4)).normalized()
		ai_component.set("wander_direction", bounce_dir)
		ai_component.set("stuck_timer", 0.0)


func _get_dynamic_ray_origin() -> Vector3:
	var height_offset: float = 0.8
	if "_collision_height" in host:
		height_offset = (host.get("_collision_height") as float) * 0.45
	return host.global_position + Vector3(0.0, height_offset, 0.0)


func _is_navigating_macro_path() -> bool:
	if host.has_meta("guard_active_path"):
		return not (host.get_meta("guard_active_path") as Array).is_empty()
	if host.has_meta("villager_active_path"):
		return not (host.get_meta("villager_active_path") as Array).is_empty()
	return false
