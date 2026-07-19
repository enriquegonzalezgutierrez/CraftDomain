# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCObstacleSteering.gd
# Description: Context-Based Steering Component managing local dynamic 
#              avoidance, human-like deceleration, edge anticipation, 
#              and cooperative yielding.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   kinematics and spatial raycasts, completely decoupled from GOAP goal planning.
# - Open-Closed Principle (OCP): Works polymorphically across all NPC shapes
#   and sizes by dynamically querying their collision boundaries.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NPCObstacleSteering
extends Node

const SCAN_DISTANCE: float = 1.2
const YIELD_WAIT_TIME_SEC: float = 1.5
const JUMP_RECOVERY_COOLDOWN: float = 0.4

var host: CharacterBody3D
var ai_component: Node

var _yield_timer: float = 0.0


## Injects references to coordinate steering with physics and active task states
func initialize(p_host: CharacterBody3D, p_ai_component: Node) -> void:
	host = p_host
	ai_component = p_ai_component


## Main Execution Router: Processes un-throttled context steering and kinematics
func process_steering(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(ai_component):
		return
		
	var space_state := host.get_world_3d().direct_space_state
	if space_state == null:
		return
		
	_enforce_turn_before_walk()
	_process_edge_anticipation(space_state, delta)
	
	var is_yielding := _process_dynamic_yielding(space_state, delta)
	
	if not is_yielding:
		_perform_proactive_whisker_avoidance(space_state, delta)
		
	_handle_step_climbing_and_unsticking(delta)


# ==============================================================================
# HUMAN BEHAVIOR: GAZE ANTICIPATION & DECELERATION
# ==============================================================================

## Slows down translation speed until the NPC's body has visually rotated 
## towards the intended path, simulating natural human shifting weight.
func _enforce_turn_before_walk() -> void:
	var dir: Vector3 = ai_component.get("wander_direction") as Vector3
	if dir == Vector3.ZERO:
		return
		
	var vis_comp := host.get_node_or_null("NPCVisualComponent")
	if is_instance_valid(vis_comp) and "visual_root" in vis_comp:
		var visual_root: Node3D = vis_comp.get("visual_root") as Node3D
		if is_instance_valid(visual_root):
			var current_facing := -visual_root.global_transform.basis.z.normalized()
			var alignment := current_facing.dot(dir.normalized())
			
			if alignment < 0.6:
				var throttle := clampf((alignment + 1.0) / 1.6, 0.15, 1.0)
				host.velocity.x *= throttle
				host.velocity.z *= throttle


## Senses upcoming drops and naturally decelerates before jumping or falling
func _process_edge_anticipation(space_state: PhysicsDirectSpaceState3D, delta: float) -> void:
	var flat_vel := Vector2(host.velocity.x, host.velocity.z)
	if flat_vel.length_squared() < 0.1 or not host.is_on_floor():
		return
		
	var habitat: int = host.get("entity_habitat") if "entity_habitat" in host else 0
	if habitat == 2: return 
		
	var look_ahead := host.global_position + host.velocity * 0.4
	var start_pos := look_ahead + Vector3(0.0, 0.5, 0.0)
	var end_pos := look_ahead + Vector3(0.0, -2.5, 0.0)
	
	var query := PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [host.get_rid()]
	
	var result := space_state.intersect_ray(query)
	if result.is_empty() or (start_pos.y - float(result["position"].y) > 1.2):
		host.velocity.x = lerp(host.velocity.x, 0.0, delta * 5.0)
		host.velocity.z = lerp(host.velocity.z, 0.0, delta * 5.0)


# ==============================================================================
# COOPERATIVE YIELDING (Dynamic Collision Resolution)
# ==============================================================================

## Detects if a player or another NPC is blocking the path. Stops and waits 
## patiently for 1.5s before attempting to maneuver around them.
func _process_dynamic_yielding(space_state: PhysicsDirectSpaceState3D, delta: float) -> bool:
	var dir: Vector3 = ai_component.get("wander_direction") as Vector3
	if dir == Vector3.ZERO:
		_yield_timer = 0.0
		return false
		
	var r_origin := _get_dynamic_ray_origin()
	var query := PhysicsRayQueryParameters3D.create(r_origin, r_origin + dir * SCAN_DISTANCE)
	query.exclude = [host.get_rid()]
	
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var collider: Node = result["collider"] as Node
		if is_instance_valid(collider) and collider is CharacterBody3D and collider != host:
			return _execute_yield_wait_logic(delta)
			
	_yield_timer = 0.0
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
				
	if best_normal != Vector3.ZERO:
		var flat_normal := Vector3(best_normal.x, 0.0, best_normal.z).normalized()
		if flat_normal != Vector3.ZERO:
			var steer_target := wander_dir.bounce(flat_normal).normalized()
			ai_component.set("wander_direction", wander_dir.lerp(steer_target, delta * 8.0).normalized())


func _handle_step_climbing_and_unsticking(delta: float) -> void:
	var wander_direction: Vector3 = ai_component.get("wander_direction") as Vector3
	if wander_direction == Vector3.ZERO:
		return
		
	# Symmetrical Block Check: Only attempt step-climbing if colliding with static terrain
	if _is_touching_solid_block():
		var stuck_timer: float = ai_component.get("stuck_timer") as float
		ai_component.set("stuck_timer", stuck_timer + delta)
		_evaluate_step_climbing()
	else:
		ai_component.set("stuck_timer", 0.0)


## Physics Solver: Returns true if colliding with static world geometry or low-level Chunk RIDs
func _is_touching_solid_block() -> bool:
	if not host.is_on_wall():
		return false
		
	for i in range(host.get_slide_collision_count()):
		var collision := host.get_slide_collision(i)
		var collider := collision.get_collider()
		
		# Server-side direct rendering RIDs have valid collision RIDs but no Node representation
		if collider == null and collision.get_collider_rid().is_valid():
			return true
			
		if is_instance_valid(collider) and collider is StaticBody3D:
			return true
			
	return false


func _evaluate_step_climbing() -> void:
	var wall_normal := host.get_wall_normal()
	var projected_pos := host.global_position - wall_normal * 0.8
	var target_coord := Vector3i(floori(projected_pos.x), floori(projected_pos.y) + 1, floori(projected_pos.z))
	
	var world_node := host.get_parent()
	var is_step_climbable := false
	
	if is_instance_valid(world_node) and "world_state" in world_node:
		var ws: WorldState = world_node.get("world_state") as WorldState
		if is_instance_valid(ws):
			var block_feet := ws.get_block(Vector3i(target_coord.x, target_coord.y - 1, target_coord.z))
			var block_chest := ws.get_block(target_coord)
			is_step_climbable = BlockType.is_solid(block_feet) and not BlockType.is_solid(block_chest)
			
	if is_step_climbable:
		_execute_jump_to_step(target_coord, world_node)
	else:
		_apply_wall_slide_steering(wall_normal)


func _execute_jump_to_step(target_coord: Vector3i, world_node: Node) -> void:
	var last_jump: float = host.get_meta("last_jump_time") if host.has_meta("last_jump_time") else 0.0
	var current_time := Time.get_ticks_msec() / 1000.0
	
	if (current_time - last_jump) < JUMP_RECOVERY_COOLDOWN:
		return
		
	var head_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y) + 2, floori(host.global_position.z))
	if is_instance_valid(world_node) and "world_state" in world_node:
		var ws: WorldState = world_node.get("world_state") as WorldState
		if BlockType.is_solid(ws.get_block(head_coord)):
			return 
			
	var is_jump_capable := host.call("_can_jump_to", target_coord) as bool if host.has_method("_can_jump_to") else true
	if is_jump_capable:
		var jump_vel: float = host.get("JUMP_VELOCITY") as float if "JUMP_VELOCITY" in host else 5.0
		host.velocity.y = jump_vel
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


# ==============================================================================
# INTERNAL UTILITIES
# ==============================================================================

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
