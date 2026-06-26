# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a massive, spotted Mario Mushroom tree.
#              SOLID COMPLIANCE: Fully encapsulated and OCP compliant.
#              UPDATED: Swapped stalk blocks to SNOW to create a solid, opaque,
#              matte white stem, eliminating the transparent "water trunk" visual bug.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/GiantMushroomBlueprint.gd
# ==============================================================================
class_name GiantMushroomBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Giant Mushroom (ID 3)
func get_structure_id() -> int:
	return 3

## Concrete Implementation: Builds a highly detailed red spotted umbrella mushroom
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var stalk_height: int = 4
	
	# 1. Build thick solid white stalk (using SNOW blocks for an opaque, matte white stem)
	for y in range(1, stalk_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.SNOW)
		
	# 2. Build majestic Red Spotted umbrella cap (5x3x5 dome)
	var cap_y := ground_y + stalk_height + 1
	
	# Cap Base rim (5x5 ring at cap bottom)
	for lx in range(-2, 3):
		for lz in range(-2, 3):
			# Leave a hollow center for the stalk tip
			if lx == 0 and lz == 0:
				continue
				
			# Clip corners for rounded dome look
			if abs(lx) == 2 and abs(lz) == 2:
				continue
				
			# Red Sandstone blocks represent the bright red mushroom skin
			chunk.set_block(start_x + lx, cap_y, start_z + lz, BlockType.Type.RED_SAND)
			
	# Cap Mid and spots (5x5 plate at cap center with white snow spots!)
	for lx in range(-2, 3):
		for lz in range(-2, 3):
			if abs(lx) == 2 and abs(lz) == 2:
				continue
				
			var px := start_x + lx
			var py := cap_y + 1
			var pz := start_z + lz
			
			# Generate deterministic white spots using spot pattern formulas
			var is_spot: bool = (abs(lx) == 1 and lz == 0) or (abs(lz) == 1 and lx == 0)
			if is_spot:
				chunk.set_block(px, py, pz, BlockType.Type.SNOW) # Spot of white snow!
			else:
				chunk.set_block(px, py, pz, BlockType.Type.RED_SAND)
				
	# Cap Dome roof (3x3 plate on top)
	for lx in range(-1, 2):
		for lz in range(-1, 2):
			var px := start_x + lx
			var py := cap_y + 2
			var pz := start_z + lz
			
			# Spot on top center
			if lx == 0 and lz == 0:
				chunk.set_block(px, py, pz, BlockType.Type.SNOW)
			else:
				chunk.set_block(px, py, pz, BlockType.Type.RED_SAND)
