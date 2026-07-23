# ==============================================================================
# Pathfile: res://src/Domain/World/VoxelGreedyMesherSolver.gd
# Description: Pure Domain Service implementing a high-performance 2D Greedy
#              Meshing solver to merge adjacent identical voxel faces into rectangles.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelGreedyMesherSolver
extends RefCounted

const SLICE_SIZE: int = 16

## Value Object representing a compiled merged rectangular quad area
class MergedQuad:
	var block_id: int
	var start_x: int
	var start_z: int
	var width: int
	var height: int
	
	func _init(p_id: int, px: int, pz: int, pw: int, ph: int) -> void:
		block_id = p_id
		start_x = px
		start_z = pz
		width = pw
		height = ph


## Solves a 16x16 slice grid, returning a optimized list of MergedQuads.
static func solve_slice(slice_ids: PackedInt32Array, visibility_mask: PackedByteArray) -> Array[MergedQuad]:
	var quads: Array[MergedQuad] = []
	var merged := PackedByteArray()
	merged.resize(SLICE_SIZE * SLICE_SIZE)
	merged.fill(0)
	
	for z in range(SLICE_SIZE):
		for x in range(SLICE_SIZE):
			var idx := x + SLICE_SIZE * z
			if visibility_mask[idx] == 1 and merged[idx] == 0:
				_merge_quad_at(x, z, slice_ids, visibility_mask, merged, quads)
				
	return quads


static func _merge_quad_at(start_x: int, start_z: int, ids: PackedInt32Array, mask: PackedByteArray, merged: PackedByteArray, quads: Array[MergedQuad]) -> void:
	var idx := start_x + SLICE_SIZE * start_z
	var target_id := ids[idx]
	
	var w := _calculate_max_width(start_x, start_z, target_id, ids, mask, merged)
	var h := _calculate_max_height(start_x, start_z, w, target_id, ids, mask, merged)
	
	_mark_merged_area(start_x, start_z, w, h, merged)
	quads.append(MergedQuad.new(target_id, start_x, start_z, w, h))


static func _calculate_max_width(start_x: int, start_z: int, target_id: int, ids: PackedInt32Array, mask: PackedByteArray, merged: PackedByteArray) -> int:
	var w := 0
	while start_x + w < SLICE_SIZE:
		var curr_idx := (start_x + w) + SLICE_SIZE * start_z
		if mask[curr_idx] == 1 and merged[curr_idx] == 0 and ids[curr_idx] == target_id:
			w += 1
		else:
			break
	return w


static func _calculate_max_height(start_x: int, start_z: int, w: int, target_id: int, ids: PackedInt32Array, mask: PackedByteArray, merged: PackedByteArray) -> int:
	var h := 1
	while start_z + h < SLICE_SIZE:
		if _is_row_mergeable(start_x, start_z + h, w, target_id, ids, mask, merged):
			h += 1
		else:
			break
	return h


static func _is_row_mergeable(start_x: int, row_z: int, w: int, target_id: int, ids: PackedInt32Array, mask: PackedByteArray, merged: PackedByteArray) -> bool:
	for x in range(w):
		var curr_idx := (start_x + x) + SLICE_SIZE * row_z
		if mask[curr_idx] != 1 or merged[curr_idx] == 1 or ids[curr_idx] != target_id:
			return false
	return true


static func _mark_merged_area(start_x: int, start_z: int, w: int, h: int, merged: PackedByteArray) -> void:
	for z in range(h):
		for x in range(w):
			var idx := (start_x + x) + SLICE_SIZE * (start_z + z)
			merged[idx] = 1
