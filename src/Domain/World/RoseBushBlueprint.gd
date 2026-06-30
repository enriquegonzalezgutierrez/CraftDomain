# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a compact flowering Rose Bush.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                geometric block-placement math for this specific asset.
#              - Open-Closed Principle (OCP): Extends IStructureBlueprint dynamically.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RoseBushBlueprint.gd
# ==============================================================================
class_name RoseBushBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Rose Bush (ID 12)
func get_structure_id() -> int:
	return 12


## Concrete Implementation: Constructs a compact rounded flowering rose shrub.
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# 1. Base foliage ring at ground level (3x3 grid)
	for lx in range(-1, 2):
		for lz in range(-1, 2):
			var px := start_x + lx
			var py := ground_y + 1
			var pz := start_z + lz
			
			# Skip corners to keep the bush rounded
			if abs(lx) == 1 and abs(lz) == 1:
				continue
				
			# Deterministic variety: Dot the base ring with red rose blossoms
			var is_blossom := (lx + lz) % 2 == 0
			if is_blossom:
				chunk.set_block(px, py, pz, BlockType.Type.RED_SAND) # Red Sand represents rose buds
			else:
				chunk.set_block(px, py, pz, BlockType.Type.LEAVES)
				
	# 2. Compact dome cap (1x2 center tip)
	chunk.set_block(start_x, ground_y + 2, start_z, BlockType.Type.LEAVES)
	chunk.set_block(start_x, ground_y + 3, start_z, BlockType.Type.RED_SAND) # Top flower crown
