# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Pure Business Logic / Blueprint Strategies)
# Class: WarpPipeBlueprint
# Description: OCP-compliant structure blueprint that procedurally constructs
#              retro Warp Pipes using green foliage blocks (Leaves) with 
#              adaptive stone foundations. It scans steps and terraces to grow 
#              supporting columns down to the solid ground, preventing floating pipes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only manages the geometric stepped
#   foundations and green body construction of the Warp Pipe.
# - Open-Closed Principle (OCP): Extends IStructureBlueprint. It registers as
#   structure ID 4, completely replacing the final JSON template.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WarpPipeBlueprint.gd
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
	
	# ==========================================================================
	# 1. ADAPTIVE STONE FOUNDATIONS (Solves floating on step edges)
	# ==========================================================================
	for x_offset: int in range(WIDTH):
		var lx: int = start_x + x_offset
		for z_offset: int in range(WIDTH):
			var lz: int = start_z + z_offset
			
			# Downward column scan to find real terrain surface
			var real_ground_y: int = ground_y
			for sy: int in range(ground_y, 0, -1):
				if chunk.is_within_bounds(lx, sy, lz):
					var check_block: BlockType.Type = chunk.get_block(lx, sy, lz)
					if check_block != BlockType.Type.AIR and check_block != BlockType.Type.WATER:
						real_ground_y = sy
						break
			
			# Grow stone support foundations up to the pipe start height
			for fill_y: int in range(real_ground_y, ground_y + 1):
				if chunk.is_within_bounds(lx, fill_y, lz):
					chunk.set_block(lx, fill_y, lz, BlockType.Type.STONE)

	# ==========================================================================
	# 2. GREEN PIPE BODY (Height 3, made of green foliage blocks)
	# ==========================================================================
	for y_offset: int in range(1, PIPE_HEIGHT + 1):
		var ly: int = ground_y + y_offset
		
		for x_offset: int in range(WIDTH):
			var lx: int = start_x + x_offset
			for z_offset: int in range(WIDTH):
				var lz: int = start_z + z_offset
				
				if chunk.is_within_bounds(lx, ly, lz):
					# Place green plastic-textured leaf block (ID 5)
					chunk.set_block(lx, ly, lz, BlockType.Type.LEAVES)
