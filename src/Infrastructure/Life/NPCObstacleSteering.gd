# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCObstacleSteering.gd
# Description: Infrastructure Component managing 3D whisker raycast avoidance,
#              cliff edge sensing, and intelligent step-climbing jumps (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NPCObstacleSteering
extends Node

var host: CharacterBody3D
var ai_component: Node

const SCAN_DISTANCE: float = 1.2
const JUMP_RECOVERY_COOLDOWN: float = 0.4


## Injects references to coordinate steering with physics and active task states
func initialize(p_host: CharacterBody3D, p_ai_component: Node) -> void:
	host = p_host
	ai_component = p_ai_component


## Processes un-throttled physical steering, look-ahead whisker avoidance, and step-climbing
func process_steering(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(ai_component):
		return
		
	_perform_proactive_whisker_avoidance(delta)
	_perform_cliff_and_hazard_avoidance(delta)
	_handle_step_climbing_and_unsticking(delta)


func _perform_proactive_whisker_avoidance(delta: float) -> void:
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	var space_state := host.get_world_3d().direct_space_state
	if space_state == null:
		return
		
	var r_origin := host.global_position + Vector3(0.0, 0.9, 0.0) 
	
	var col: CollisionShape3D = host.get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.position.y > 0.1:
		r_origin = host.global_position + Vector3(0.0, col.position.y, 0.0)
		
	var center_dir := wander_direction.normalized()
	var left_dir := center_dir.rotated(Vector3.UP, deg_to_rad(30.0))
	var right_dir := center_dir.rotated(Vector3.UP, deg_to_rad(-30.0))
	
	_cast_whisker_rays(space_state, r_origin, [center_dir, left_dir, right_dir], wander_direction, delta)


func _cast_whisker_rays(space_state: PhysicsDirectSpaceState3D, r_origin: Vector3, scan_dirs: Array, wander_dir: Vector3, delta: float) -> void:
	var best_avoidance_normal := Vector3.ZERO
	var closest_hit_dist := 999.0
	
	for dir: Vector3 in scan_dirs:
		var query := PhysicsRayQueryParameters3D.create(r_origin, r_origin + dir * SCAN_DISTANCE)
		query.collision_mask = 1 
		query.exclude = [host.get_rid()]
		
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			var hit_pos: Vector3 = result["position"]
			var hit_normal: Vector3 = result["normal"]
			var dist := r_origin.distance_to(hit_pos)
			
			if dist < closest_hit_dist:
				closest_hit_dist = dist
				best_avoidance_normal = hit_normal
	
	if best_avoidance_normal != Vector3.ZERO:
		var flat_normal := Vector3(best_avoidance_normal.x, 0.0, best_avoidance_normal.z).normalized()
		if flat_normal != Vector3.ZERO:
			var steer_target := wander_dir.bounce(flat_normal).normalized()
			ai_component.set("wander_direction", wander_dir.lerp(steer_target, delta * 8.0).normalized())


## Senses empty air or hazard rifts ahead and executes a 180-degree turn
func _perform_cliff_and_hazard_avoidance(delta: float) -> void:
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	var habitat: int = host.get("entity_habitat") if "entity_habitat" in host else 0
	
	# Skip checks for flying entities (Gargoyles/Birds) or aquatic entities
	if wander_direction == Vector3.ZERO or not host.is_on_floor() or habitat == 2:
		return
		
	var space_state := host.get_world_3d().direct_space_state
	if space_state == null:
		return
		
	# Project a vertical look-ahead point 1.2m in front of the entity's feet
	var look_ahead := host.global_position + wander_direction.normalized() * 1.2
	var start_pos := look_ahead + Vector3(0.0, 0.5, 0.0) # Start slightly above feet level
	var end_pos := look_ahead + Vector3(0.0, -1.8, 0.0)  # Scan 1.8 meters down
	
	var query := PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collision_mask = 1 # Solid chunk mesh collision layer
	query.exclude = [host.get_rid()]
	
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		_execute_cliff_rebound(wander_direction, delta)


func _execute_cliff_rebound(wander_direction: Vector3, delta: float) -> void:
	# Reverse direction 180 degrees back onto safe solid ground
	var turn_dir := -wander_direction.normalized()
	# Apply slight randomized deflection to prevent getting locked in back-and-forth loops
	turn_dir = turn_dir.rotated(Vector3.UP, randf_range(-0.4, 0.4)).normalized()
	
	ai_component.set("wander_direction", turn_dir)
	
	# Apply a brief horizontal brake to prevent inertia from sliding them off the edge
	var v := host.velocity
	v.x = move_toward(v.x, 0.0, 15.0 * delta)
	v.z = move_toward(v.z, 0.0, 15.0 * delta)
	host.set("velocity", v)


func _handle_step_climbing_and_unsticking(delta: float) -> void:
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	var world_node := host.get_parent()
	var stuck_timer: float = ai_component.get("stuck_timer") as float
	
	if host.is_on_wall():
		stuck_timer += delta
		ai_component.set("stuck_timer", stuck_timer)
		
		var wall_normal := host.get_wall_normal()
		var projected_pos := host.global_position - wall_normal * 0.8
		var target_coord := Vector3i(floori(projected_pos.x), floori(projected_pos.y) + 1, floori(projected_pos.z))
		
		var is_step_climbable := false
		if is_instance_valid(world_node) and "world_state" in world_node and world_node.world_state != null:
			var ws: WorldState = world_node.world_state
			var block_at_step_feet := ws.get_block(Vector3i(target_coord.x, target_coord.y - 1, target_coord.z))
			var block_at_step_chest := ws.get_block(target_coord)
			is_step_climbable = BlockType.is_solid(block_at_step_feet) and not BlockType.is_solid(block_at_step_chest)
			
		if is_step_climbable:
			_try_step_climb(target_coord, world_node)
		else:
			_apply_wall_slide_steering(wall_normal)
	else:
		ai_component.set("stuck_timer", 0.0)


func _try_step_climb(target_coord: Vector3i, world_node: Node) -> void:
	var last_jump: float = host.get_meta("last_jump_time") if host.has_meta("last_jump_time") else 0.0
	var current_time := Time.get_ticks_msec() / 1000.0
	var can_jump := (current_time - last_jump) > JUMP_RECOVERY_COOLDOWN
	
	var head_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y) + 2, floori(host.global_position.z))
	var is_ceiling_solid := false
	if is_instance_valid(world_node) and "world_state" in world_node:
		is_ceiling_solid = BlockType.is_solid(world_node.world_state.get_block(head_coord))
		
	var is_jump_capable := host.call("_can_jump_to", target_coord) as bool if host.has_method("_can_jump_to") else true
	
	if can_jump and not is_ceiling_solid and is_jump_capable:
		var jump_vel: float = 5.0
		if "JUMP_VELOCITY" in host:
			jump_vel = host.get("JUMP_VELOCITY") as float
			
		var v := host.velocity
		v.y = jump_vel
		host.set("velocity", v)
		host.set_meta("last_jump_time", current_time)
		ai_component.set("stuck_timer", 0.0)


func _apply_wall_slide_steering(wall_normal: Vector3) -> void:
	var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	if flat_normal != Vector3.ZERO:
		var tangent_left := Vector3(-flat_normal.z, 0.0, flat_normal.x)
		var tangent_right := Vector3(flat_normal.z, 0.0, -flat_normal.x)
		
		var wander_dir: Vector3 = ai_component.get("wander_direction") as Vector3
		var chosen_slide := tangent_left if wander_dir.dot(tangent_left) > wander_dir.dot(tangent_right) else tangent_right
		
		ai_component.set("wander_direction", chosen_slide.normalized())
		ai_component.set("stuck_timer", 0.0)
