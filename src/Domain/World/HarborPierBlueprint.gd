# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a wooden dock pier extending over water.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/HarborPierBlueprint.gd
# ==============================================================================
class_name HarborPierBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Harbor Pier (ID 9)
func get_structure_id() -> int:
	return 9

## Concrete Implementation: Constructs a wooden dock pier on stone support posts
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var pier_length: int = 5
	
	for z in range(pier_length):
		var lz := start_z + z
		
		# Stone support posts driven down into the sand/water
		for y in range(ground_y - 2, ground_y + 1):
			chunk.set_block(start_x, y, lz, BlockType.Type.STONE)
			chunk.set_block(start_x + 1, y, lz, BlockType.Type.STONE)
		
		# Wooden plank walkway surface exactly at water/sand boundary level
		chunk.set_block(start_x, ground_y + 1, lz, BlockType.Type.WOOD)
		chunk.set_block(start_x + 1, ground_y + 1, lz, BlockType.Type.WOOD)
