# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct an underground wooden support beam and lantern.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MinePillarBlueprint.gd
# ==============================================================================
class_name MinePillarBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Mine Pillar (ID 5)
func get_structure_id() -> int:
	return 5

## Concrete Implementation: Constructs a tall wooden support beam with a lantern cap
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var post_height: int = 3
	
	# 1. Tall Wooden support post
	for y in range(1, post_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.WOOD)
		
	# 2. Glow stone lantern block at the top (Represented by a unique colored Stone block)
	chunk.set_block(start_x, ground_y + post_height + 1, start_z, BlockType.Type.STONE)
