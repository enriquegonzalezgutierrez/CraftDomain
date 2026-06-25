# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct an ancient cybernetic pyramid layered with glowing neon.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/NeonPyramidBlueprint.gd
# ==============================================================================
class_name NeonPyramidBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Neon Pyramid (ID 7)
func get_structure_id() -> int:
	return 7

## Concrete Implementation: Constructs a stepped pyramid with glowing cyan and magenta accents
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var base_radius: int = 2 # Forms a 5x5 base (radius 2)
	var height: int = 3
	
	for y in range(height):
		var current_radius: int = base_radius - y
		var ly := ground_y + y + 1
		
		for lx in range(-current_radius, current_radius + 1):
			for lz in range(-current_radius, current_radius + 1):
				var px := start_x + lx
				var pz := start_z + lz
				
				# Ensure we only write within the chunk bounds
				if not chunk.is_within_bounds(px, ly, pz):
					continue
					
				# Determine if this block is an outer corner/edge of the current step tier
				var is_edge: bool = (abs(lx) == current_radius or abs(lz) == current_radius)
				
				if is_edge:
					# Alternating Neon glowing aesthetic for edges
					if (lx + lz) % 2 == 0:
						chunk.set_block(px, ly, pz, BlockType.Type.NEON_CYAN)
					else:
						chunk.set_block(px, ly, pz, BlockType.Type.NEON_MAGENTA)
				else:
					# Core of the pyramid is dark solid stone
					chunk.set_block(px, ly, pz, BlockType.Type.STONE)
					
	# Top pinnacle (Y+4): Glowing magenta core
	var top_y := ground_y + height + 1
	if chunk.is_within_bounds(start_x, top_y, start_z):
		chunk.set_block(start_x, top_y, start_z, BlockType.Type.NEON_MAGENTA)
