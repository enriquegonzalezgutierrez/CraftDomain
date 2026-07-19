# ==============================================================================
# Pathfile: res://src/Domain/Life/SpawnCoordinateSolver.gd
# Description: Pure Domain Service responsible for calculating safe 3D spawning 
#              coordinates in both surface and cave layers.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively coordinate scanning.
# - Open-Closed Principle (OCP): Works polymorphically with BlockDefinition properties,
#   remaining completely closed to specific block ID list modifications.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SpawnCoordinateSolver
extends RefCounted


## Top-Down Solver: Calculates the true organic surface Y level, skipping structural roofs.
static func solve_surface_y(world_state: WorldState, gx: int, gz: int) -> float:
	for y in range(31, -1, -1):
		var coord := Vector3i(gx, y, gz)
		var block := world_state.get_block(coord)
		var def := BlockLibrary.get_definition(block)
		if def == null: continue
		
		if def.is_spawn_surface:
			if _verify_vertical_clearance(world_state, coord):
				return float(y) + 1.0
		elif not def.is_spawn_penetrable:
			break # Impenetrable hazard block (like Lava/Bedrock), abort!
			
	return -1.0 # No valid surface found


## Bottom-Up Solver: Calculates a safe cave floor Y level with air chamber and ceiling.
static func solve_cave_y(world_state: WorldState, gx: int, gz: int) -> float:
	for y in range(1, 12): # Cave layer scan from Y=1 to Y=11
		var coord := Vector3i(gx, y, gz)
		var block := world_state.get_block(coord)
		var def := BlockLibrary.get_definition(block)
		if def == null or not def.is_solid: continue
		
		# Check for solid floor + standing clearance + overhead stone ceiling
		if _verify_vertical_clearance(world_state, coord) and _has_solid_ceiling(world_state, coord):
			return float(y) + 1.0
			
	return -1.0 # No valid cave floor found


static func _verify_vertical_clearance(world_state: WorldState, coord: Vector3i) -> bool:
	var above1 := world_state.get_block(coord + Vector3i(0, 1, 0))
	var above2 := world_state.get_block(coord + Vector3i(0, 2, 0))
	return not BlockType.is_solid(above1) and not BlockType.is_solid(above2)


static func _has_solid_ceiling(world_state: WorldState, coord: Vector3i) -> bool:
	for h in range(3, 7): # Scans up to 6 blocks above for a solid ceiling
		var block := world_state.get_block(coord + Vector3i(0, h, 0))
		if BlockType.is_solid(block):
			return true
	return false
