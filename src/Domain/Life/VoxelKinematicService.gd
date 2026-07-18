# ==============================================================================
# Pathfile: res://src/Domain/Life/VoxelKinematicService.gd
# Description: Pure Domain Service consolidating common kinematic translations,
#              3D path navigation, and strict voxel boundary safety checks 
#              for all mobile entities (NPCs and Wildlife).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates physical 
#   kinematic translations and boundary calculations, DRY-ing behavioral classes.
# - Method Size Limits (Rule 4.2): All methods strictly refactored to remain < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelKinematicService
extends RefCounted


## Sets the physical velocity vector of the host and updates the AI visual gaze direction.
static func apply_motion_vectors(host: CharacterBody3D, ai: Object, direction: Vector3, speed: float) -> void:
	var velocity := host.velocity
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if is_instance_valid(ai):
			ai.set("wander_direction", direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		if is_instance_valid(ai):
			ai.set("wander_direction", Vector3.ZERO)
	host.velocity = velocity


## Instantly halts the host's horizontal velocities and resets gaze directions.
static func halt_movement(host: CharacterBody3D, ai: Object) -> void:
	var velocity := host.velocity
	velocity.x = 0.0
	velocity.z = 0.0
	host.velocity = velocity
	if is_instance_valid(ai):
		ai.set("wander_direction", Vector3.ZERO)


## Navigates the host along an A* path, updating the active index metadata on the host.
## Integrates automatic stuck detection to bypass blocked/unreachable nodes.
static func navigate_along_path(host: CharacterBody3D, ai: Object, path: Array, path_index: int, speed: float, meta_index_key: String) -> int:
	if path_index >= path.size():
		halt_movement(host, ai)
		host.set_meta("nav_stuck_ticks", 0.0)
		return path_index
		
	var target_node: Vector3 = path[path_index]
	var diff := target_node - host.global_position
	diff.y = 0.0
	
	if diff.length_squared() < 0.16:
		return _advance_path_node(host, path_index, meta_index_key)
		
	if _evaluate_stuck_state(host, speed):
		return _advance_path_node(host, path_index, meta_index_key, true)
		
	apply_motion_vectors(host, ai, diff.normalized(), speed)
	return path_index


static func _advance_path_node(host: CharacterBody3D, current_index: int, meta_index_key: String, trigger_hop: bool = false) -> int:
	var next_idx := current_index + 1
	host.set_meta(meta_index_key, next_idx)
	host.set_meta("nav_stuck_ticks", 0.0)
	
	if trigger_hop:
		var velocity := host.velocity
		velocity.y = 3.5 # Auxiliary hop to clear any corner brick lips
		host.velocity = velocity
		
	return next_idx


static func _evaluate_stuck_state(host: CharacterBody3D, speed: float) -> bool:
	var last_pos: Vector3 = host.get_meta("nav_last_pos") if host.has_meta("nav_last_pos") else host.global_position
	var stuck_ticks: float = host.get_meta("nav_stuck_ticks") if host.has_meta("nav_stuck_ticks") else 0.0
	
	var dist_moved := host.global_position.distance_to(last_pos)
	if dist_moved < 0.02 and speed > 0.1:
		stuck_ticks += 1.0
	else:
		stuck_ticks = move_toward(stuck_ticks, 0.0, 0.5)
		
	host.set_meta("nav_last_pos", host.global_position)
	host.set_meta("nav_stuck_ticks", stuck_ticks)
	
	return stuck_ticks >= 4.0


## Verifies if moving in the candidate direction is safe under voxel and habitat rules.
static func is_direction_safe(host: CharacterBody3D, ws: WorldState, direction: Vector3, check_distance: float) -> bool:
	if ws == null or direction == Vector3.ZERO:
		return true
		
	var host_pos := host.global_position
	var check_pos := host_pos + direction * check_distance
	
	var b_below := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var b_feet := Vector3i(floori(check_pos.x), floori(check_pos.y), floori(check_pos.z))
	var b_chest := Vector3i(floori(check_pos.x), floori(check_pos.y) + 1, floori(check_pos.z))
	
	# 1. Solid walls are unsafe
	if BlockType.is_solid(ws.get_block(b_feet)) and BlockType.is_solid(ws.get_block(b_chest)):
		return false
		
	return _evaluate_habitat_safety(host, ws, b_below, b_feet)


static func _evaluate_habitat_safety(host: CharacterBody3D, ws: WorldState, b_below: Vector3i, b_feet: Vector3i) -> bool:
	var block_below := ws.get_block(b_below)
	var block_feet := ws.get_block(b_feet)
	
	var habitat: int = host.get("entity_habitat") if "entity_habitat" in host else 0
	if habitat == 2: # AQUATIC
		return block_below == BlockType.Type.WATER or block_feet == BlockType.Type.WATER
		
	# Terrestrial/Amphibious safety: avoid falling into deep voids, lava or deep oceans
	var is_liquid := block_below == BlockType.Type.WATER or block_below == BlockType.Type.LAVA or block_feet == BlockType.Type.WATER
	var is_void := block_below == BlockType.Type.AIR
	
	return not is_liquid and not is_void
