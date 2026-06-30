# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a dry, leafless Dead Shrub.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                geometric block-placement math for this specific asset.
#              - Open-Closed Principle (OCP): Extends IStructureBlueprint dynamically.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/DeadShrubBlueprint.gd
# ==============================================================================
class_name DeadShrubBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Dead Shrub (ID 14)
func get_structure_id() -> int:
	return 14


## Concrete Implementation: Constructs a dry, twisted leafless woody branch.
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# Small 2-block high twisted branch shape
	chunk.set_block(start_x, ground_y + 1, start_z, BlockType.Type.WOOD)
	
	# Lateral branch extensions to create volume
	if chunk.is_within_bounds(start_x + 1, ground_y + 1, start_z):
		chunk.set_block(start_x + 1, ground_y + 1, start_z, BlockType.Type.WOOD)
	if chunk.is_within_bounds(start_x, ground_y + 2, start_z - 1):
		chunk.set_block(start_x, ground_y + 2, start_z - 1, BlockType.Type.WOOD)
