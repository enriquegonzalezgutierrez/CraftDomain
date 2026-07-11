# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCObstacleSteering.gd
# Description: Infrastructure Component managing 3D whisker raycast avoidance,
#              wall collision re-routing, and intelligent step-climbing jumps.
#              Decouples all physical steering and obstacle navigation from NPCAIComponent (SRP).
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
	_handle_step_climbing_and_unsticking(delta)


func _perform_proactive_whisker_avoidance(delta: float) -> void:
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	var space_state := host.get_world_3d().direct_space_state
	if space_state == null:
		return
		
	var host_pos := host.global_position
	var r_origin := host_pos + Vector3(0.0, 0.9, 0.0) # Chest-level default
	
	var col: CollisionShape3D = host.get_node_or_null("EntityCollider") as CollisionShape3D
	if is_instance_valid(col) and col.position.y > 0.1:
		r_origin = host_pos + Vector3(0.0, col.position.y, 0.0)
		
	var center_dir := wander_direction.normalized()
	var left_dir := center_dir.rotated(Vector3.UP, deg_to_rad(30.0))
	var right_dir := center_dir.rotated(Vector3.UP, deg_to_rad(-30.0))
	
	var scan_dirs := [center_dir, left_dir, right_dir]
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
			var steer_target := wander_direction.bounce(flat_normal).normalized()
			ai_component.set("wander_direction", wander_direction.lerp(steer_target, delta * 8.0).normalized())


func _handle_step_climbing_and_unsticking(delta: float) -> void:
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	var world_node := host.get_parent()
	var stuck_timer: float = ai_component.get("stuck_timer") as float
	
	if host.is_on_wall():
		stuck_timer += delta
		ai_component.set("stuck_timer", stuck_timer)
		
		if host.is_on_floor():
			var flat_vel := Vector2(host.velocity.x, host.velocity.z)
			var is_physically_blocked := flat_vel.length() < 0.35
			
			var last_jump: float = host.get_meta("last_jump_time") if host.has_meta("last_jump_time") else 0.0
			var current_time := Time.get_ticks_msec() / 1000.0
			var can_jump := (current_time - last_jump) > JUMP_RECOVERY_COOLDOWN
			
			# Check for ceiling block above head (2.0m height) to block redundant jumps
			var head_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y) + 2, floori(host.global_position.z))
			var is_ceiling_solid := false
			if is_instance_valid(world_node) and "world_state" in world_node:
				var ws: WorldState = world_node.world_state
				if ws != null:
					is_ceiling_solid = BlockType.is_solid(ws.get_block(head_coord))
			
			if is_physically_blocked and can_jump and not is_ceiling_solid:
				var jump_vel: float = 5.0
				if "JUMP_VELOCITY" in host:
					jump_vel = host.get("JUMP_VELOCITY") as float
					
				var wall_normal := host.get_wall_normal()
				var projected_pos := host.global_position - wall_normal * 0.8
				var target_coord := Vector3i(floori(projected_pos.x), floori(projected_pos.y) + 1, floori(projected_pos.z))
				
				var is_jump_capable := host.call("_can_jump_to", target_coord) as bool if host.has_method("_can_jump_to") else true
				var is_step_climbable := false
				
				if is_instance_valid(world_node) and "world_state" in world_node and world_node.world_state != null:
					var ws: WorldState = world_node.world_state
					var block_at_step_feet := ws.get_block(Vector3i(target_coord.x, target_coord.y - 1, target_coord.z))
					var block_at_step_chest := ws.get_block(target_coord)
					is_step_climbable = BlockType.is_solid(block_at_step_feet) and not BlockType.is_solid(block_at_step_chest)
					
				if is_jump_capable and is_step_climbable:
					var v := host.velocity
					v.y = jump_vel
					host.set("velocity", v)
					host.set_meta("last_jump_time", current_time)
		
		# Escape corner loops (Stuck recovery re-direction)
		if stuck_timer > 0.35:
			ai_component.set("stuck_timer", 0.0)
			var wall_normal := host.get_wall_normal()
			var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
			if flat_normal != Vector3.ZERO:
				var slide_dir := Vector3(-flat_normal.z, 0.0, flat_normal.x) if randf() > 0.5 else Vector3(flat_normal.z, 0.0, -flat_normal.x)
				ai_component.set("wander_direction", slide_dir.normalized())
				
				if host.has_meta("avian_flight_state") == false:
					ai_component.set("_active_path", [])
					ai_component.set("current_task", 0) # TASK_IDLE = 0
					ai_component.set("task_timer", 0.1)
	else:
		ai_component.set("stuck_timer", 0.0)