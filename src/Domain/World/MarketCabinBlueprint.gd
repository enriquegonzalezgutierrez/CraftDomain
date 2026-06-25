# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct an open wooden market stall for merchants.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/MarketCabinBlueprint.gd
# ==============================================================================
class_name MarketCabinBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Market Stall (ID 8)
func get_structure_id() -> int:
	return 8

## Concrete Implementation: Constructs a fenced merchant stall with a striped canopy
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var width: int = 4
	var depth: int = 4
	
	# Floor (Stone base)
	for x in range(width):
		var lx := start_x + x
		for z in range(depth):
			var lz := start_z + z
			chunk.set_block(lx, ground_y, lz, BlockType.Type.STONE)
			
	# Support Pillars (Wood corners, height 3)
	for y in range(1, 4):
		var ly := ground_y + y
		chunk.set_block(start_x, ly, start_z, BlockType.Type.WOOD)
		chunk.set_block(start_x + width - 1, ly, start_z, BlockType.Type.WOOD)
		chunk.set_block(start_x, ly, start_z + depth - 1, BlockType.Type.WOOD)
		chunk.set_block(start_x + width - 1, ly, start_z + depth - 1, BlockType.Type.WOOD)
		
	# Front Counter Fence (Half-height wooden barrier on z=0, y=1)
	chunk.set_block(start_x + 1, ground_y + 1, start_z, BlockType.Type.WOOD)
	chunk.set_block(start_x + 2, ground_y + 1, start_z, BlockType.Type.WOOD)
	
	# Colorful Roof (Striped Leaves/Wood canopy)
	var roof_y := ground_y + 3
	for x in range(width):
		var lx := start_x + x
		for z in range(depth):
			var lz := start_z + z
			var is_stripe: bool = (x % 2 == 0)
			if is_stripe:
				chunk.set_block(lx, roof_y, lz, BlockType.Type.LEAVES)
			else:
				chunk.set_block(lx, roof_y, lz, BlockType.Type.WOOD)
