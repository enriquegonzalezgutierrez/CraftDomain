# ==============================================================================
# Pathfile: res://src/Domain/World/WarpPipeBlueprint.gd
# Description: Concrete Structure Blueprint constructing retro Warp Pipes 
#              with slope-adaptive foundations and foliage bodies.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WarpPipeBlueprint
extends IStructureBlueprint

const PIPE_HEIGHT: int = 3
const WIDTH: int = 2


## Concrete Contract: Returns the unique structure ID (4) matching the old Warp Pipe
func get_structure_id() -> int:
	return 4


## Concrete Contract: Builds a green warp pipe anchored securely to step-terraces
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	_build_adaptive_foundations(chunk, start_x, start_z, ground_y)
	_build_pipe_body(chunk, start_x, start_z, ground_y)


func _build_adaptive_foundations(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	for x_offset: int in range(WIDTH):
		var lx: int = start_x + x_offset
		for z_offset: int in range(WIDTH):
			var lz: int = start_z + z_offset
			var real_ground_y: int = ground_y
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz) and chunk.get_block(lx, sy, lz) != BlockType.Type.AIR:
					real_ground_y = sy
					break
			for fill_y: int in range(real_ground_y, ground_y + 1):
				if chunk.is_within_bounds(lx, fill_y, lz):
					chunk.set_block(lx, fill_y, lz, BlockType.Type.STONE)


func _build_pipe_body(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	for y_offset: int in range(1, PIPE_HEIGHT + 1):
		var ly: int = ground_y + y_offset
		for x_offset: int in range(WIDTH):
			var lx: int = start_x + x_offset
			for z_offset: int in range(WIDTH):
				var lz: int = start_z + z_offset
				if chunk.is_within_bounds(lx, ly, lz):
					chunk.set_block(lx, ly, lz, BlockType.Type.LEAVES)
