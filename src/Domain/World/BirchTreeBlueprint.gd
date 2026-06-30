# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a white-barked Birch Tree.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                geometric block-placement math for this specific asset.
#              - Open-Closed Principle (OCP): Extends IStructureBlueprint dynamically.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/BirchTreeBlueprint.gd
# ==============================================================================
class_name BirchTreeBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Birch Tree (ID 13)
func get_structure_id() -> int:
	return 13


## Concrete Implementation: Grows a slender white-barked birch tree.
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var trunk_height: int = 6
	
	# 1. Grow Slender White Trunk (Using Snow blocks for white bark)
	for y in range(1, trunk_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.SNOW)
		
	# 2. Build layered leaf canopy (3x3 plates tapering upward)
	var top_y := ground_y + trunk_height
	
	# Base canopy tier (3x3 plate at top trunk level)
	for lx in range(-1, 2):
		for lz in range(-1, 2):
			if lx == 0 and lz == 0:
				continue # Do not overwrite trunk core
				
			var px := start_x + lx
			var py := top_y - 1
			var pz := start_z + lz
			chunk.set_block(px, py, pz, BlockType.Type.LEAVES)
			
	# Mid canopy tier (3x3 plate above trunk tip)
	for lx in range(-1, 2):
		for lz in range(-1, 2):
			var px := start_x + lx
			var py := top_y
			var pz := start_z + lz
			
			# Skip corners for rounded dome look
			if abs(lx) == 1 and abs(lz) == 1:
				continue
				
			chunk.set_block(px, py, pz, BlockType.Type.LEAVES)
			
	# Top pinnacle cap (Single leaf tip)
	chunk.set_block(start_x, top_y + 1, start_z, BlockType.Type.LEAVES)
