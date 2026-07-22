# ==============================================================================
# Pathfile: res://src/Domain/Life/SpawnCoordinateSolver.gd
# Description: Pure Domain Service calculating safe 3D spawning coordinates
#              for surface structures, subterranean caves, and ocean beds.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SpawnCoordinateSolver
extends RefCounted


## Top-Down Solver: Solves the true surface Y level for organic ground and building floors.
static func solve_surface_y(world_state: WorldState, gx: int, gz: int) -> float:
	if world_state == null:
		return -1.0
		
	for y in range(31, -1, -1):
		var coord := Vector3i(gx, y, gz)
		if _is_valid_surface_ground(world_state, coord):
			return float(y) + 1.0
			
	return -1.0 


static func _is_valid_surface_ground(world_state: WorldState, coord: Vector3i) -> bool:
	var block := world_state.get_block(coord)
	var def := BlockLibrary.get_definition(block)
	if def == null or not def.is_solid or def.is_liquid:
		return false
		
	return def.is_spawn_surface or _verify_vertical_clearance(world_state, coord)


## Bottom-Up Solver: Calculates a safe subterranean cave floor Y level with ceiling.
static func solve_cave_y(world_state: WorldState, gx: int, gz: int) -> float:
	if world_state == null:
		return -1.0
		
	for y in range(1, 12): 
		var coord := Vector3i(gx, y, gz)
		if _is_valid_cave_floor(world_state, coord):
			return float(y) + 1.0
			
	return -1.0 


static func _is_valid_cave_floor(world_state: WorldState, coord: Vector3i) -> bool:
	var block := world_state.get_block(coord)
	var def := BlockLibrary.get_definition(block)
	if def == null or not def.is_solid or def.is_liquid:
		return false
		
	return _verify_vertical_clearance(world_state, coord) and _has_solid_ceiling(world_state, coord)


static func _verify_vertical_clearance(world_state: WorldState, coord: Vector3i) -> bool:
	var above1 := world_state.get_block(coord + Vector3i(0, 1, 0))
	var above2 := world_state.get_block(coord + Vector3i(0, 2, 0))
	return not BlockLibrary.is_solid(above1) and not BlockLibrary.is_solid(above2)


static func _has_solid_ceiling(world_state: WorldState, coord: Vector3i) -> bool:
	for h in range(3, 7): 
		var block := world_state.get_block(coord + Vector3i(0, h, 0))
		if BlockLibrary.is_solid(block):
			return true
	return false
