# ==============================================================================
# Pathfile: res://src/Domain/World/NeonPyramidBlueprint.gd
# Description: Concrete Structure Blueprint constructing stepped cybernetic 
#              pyramids with emissive neon conduit edges and adaptive foundations.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NeonPyramidBlueprint
extends IStructureBlueprint

const BASE_RADIUS: int = 2 
const HEIGHT: int = 3


## Concrete Contract: Returns the unique structure ID (7) matching the old Neon Pyramid
func get_structure_id() -> int:
	return 7


## Concrete Contract: Builds a cybernetic stepped pyramid anchored to uneven ground
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	_build_adaptive_metropolis_foundation(chunk, start_x, start_z, ground_y)
	_build_stepped_cyber_platforms(chunk, start_x, start_z, ground_y)
	_sculpt_apex_pinnacle(chunk, start_x, start_z, ground_y)


func _build_adaptive_metropolis_foundation(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	for lx_offset: int in range(-BASE_RADIUS, BASE_RADIUS + 1):
		var lx: int = start_x + lx_offset
		for lz_offset: int in range(-BASE_RADIUS, BASE_RADIUS + 1):
			var lz: int = start_z + lz_offset
			var real_ground_y: int = ground_y
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz) and chunk.get_block(lx, sy, lz) != BlockType.Type.AIR:
					real_ground_y = sy
					break
			for fill_y: int in range(real_ground_y, ground_y + 1):
				if chunk.is_within_bounds(lx, fill_y, lz):
					chunk.set_block(lx, fill_y, lz, BlockType.Type.STONE)


func _build_stepped_cyber_platforms(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	for y: int in range(HEIGHT):
		var current_radius: int = BASE_RADIUS - y
		var ly: int = ground_y + y + 1
		for lx_offset: int in range(-current_radius, current_radius + 1):
			var px: int = start_x + lx_offset
			for lz_offset: int in range(-current_radius, current_radius + 1):
				var pz: int = start_z + lz_offset
				if chunk.is_within_bounds(px, ly, pz):
					var is_edge: bool = (abs(lx_offset) == current_radius or abs(lz_offset) == current_radius)
					var conduit_type := BlockType.Type.NEON_CYAN if ((lx_offset + lz_offset) % 2 == 0) else BlockType.Type.NEON_MAGENTA
					chunk.set_block(px, ly, pz, conduit_type if is_edge else BlockType.Type.STONE)


func _sculpt_apex_pinnacle(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var top_y: int = ground_y + HEIGHT + 1
	if chunk.is_within_bounds(start_x, top_y, start_z):
		chunk.set_block(start_x, top_y, start_z, BlockType.Type.NEON_MAGENTA)
