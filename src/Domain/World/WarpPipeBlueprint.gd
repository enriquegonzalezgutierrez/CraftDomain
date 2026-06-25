# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a hollow 2x2 vertical green Warp Pipe.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/WarpPipeBlueprint.gd
# ==============================================================================
class_name WarpPipeBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Warp Pipe (ID 4)
func get_structure_id() -> int:
	return 4

## Concrete Implementation: Carves a vertical hollow pipe structure using leaves as the green voxel texture
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var pipe_height: int = 3
	for y in range(1, pipe_height + 1):
		var ly := ground_y + y
		
		# Build a hollow 2x2 ring of leaves (green plastic aesthetic)
		for px in range(2):
			for pz in range(2):
				var lx := start_x + px
				var lz := start_z + pz
				
				# Ensure we only carve within local chunk limits to prevent out-of-bounds writes
				if chunk.is_within_bounds(lx, ly, lz):
					chunk.set_block(lx, ly, lz, BlockType.Type.LEAVES)
