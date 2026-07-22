# ==============================================================================
# Pathfile: res://src/Domain/World/VoxelAmbientOcclusionSolver.gd
# Description: Pure Domain Service calculating smooth per-vertex ambient occlusion
#              (AO) gradient values based on 3D neighbor voxel occupancy.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelAmbientOcclusionSolver
extends RefCounted

# Pre-defined AO shadow attenuation values for the 4 occlusion levels [0..3]
const AO_FACTOR_LEVEL_0: float = 0.40 # Deep corner shadow
const AO_FACTOR_LEVEL_1: float = 0.60 # Partial corner shadow
const AO_FACTOR_LEVEL_2: float = 0.80 # Light edge shadow
const AO_FACTOR_LEVEL_3: float = 1.00 # Fully unoccluded light


## Calculates the Ambient Occlusion factor [0.40 to 1.00] for a specific vertex.
## Evaluates side A, side B, and diagonal corner block occupancy.
static func calculate_vertex_ao(side_a_solid: bool, side_b_solid: bool, corner_solid: bool) -> float:
	if side_a_solid and side_b_solid:
		return AO_FACTOR_LEVEL_0
		
	var occlusion_count := 0
	if side_a_solid: occlusion_count += 1
	if side_b_solid: occlusion_count += 1
	if corner_solid: occlusion_count += 1
	
	return _map_occlusion_count_to_factor(occlusion_count)


static func _map_occlusion_count_to_factor(occlusion_count: int) -> float:
	match occlusion_count:
		3: return AO_FACTOR_LEVEL_0
		2: return AO_FACTOR_LEVEL_1
		1: return AO_FACTOR_LEVEL_2
		_: return AO_FACTOR_LEVEL_3


## Solves vertex AO color by querying adjacent voxels around a target coordinate.
static func evaluate_corner_ao(ws: WorldState, coord_a: Vector3i, coord_b: Vector3i, corner_coord: Vector3i) -> Color:
	if ws == null:
		return Color.WHITE
		
	var side_a := BlockLibrary.is_solid(ws.get_block(coord_a))
	var side_b := BlockLibrary.is_solid(ws.get_block(coord_b))
	var corner := BlockLibrary.is_solid(ws.get_block(corner_coord))
	
	var factor := calculate_vertex_ao(side_a, side_b, corner)
	return Color(factor, factor, factor, 1.0)