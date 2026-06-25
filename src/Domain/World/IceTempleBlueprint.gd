# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a majestic hollow ice spire for the polar regions.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IceTempleBlueprint.gd
# ==============================================================================
class_name IceTempleBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Ice Temple (ID 6)
func get_structure_id() -> int:
	return 6

## Concrete Implementation: Constructs a hollow, towering spire out of frozen blue ice
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var size: int = 3
	var tower_height: int = 8
	
	# 1. Solid Ice Foundations
	for x in range(size):
		var lx := start_x + x
		for z in range(size):
			var lz := start_z + z
			for fill_y in range(ground_y - 3, ground_y + 1):
				chunk.set_block(lx, fill_y, lz, BlockType.Type.ICE)
				
	# 2. Hollow Ice Walls rising high into the sky
	for y in range(1, tower_height):
		var ly := ground_y + y
		for x in range(size):
			var lx := start_x + x
			for z in range(size):
				var lz := start_z + z
				var is_edge: bool = (x == 0 or x == size - 1 or z == 0 or z == size - 1)
				
				if is_edge:
					# Create arrow slit windows on the upper floors
					var is_window: bool = (y == 4 or y == 6) and (x == 1 or z == 1)
					if is_window:
						chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					else:
						chunk.set_block(lx, ly, lz, BlockType.Type.ICE)
				else:
					# Keep the center hollow
					chunk.set_block(lx, ly, lz, BlockType.Type.AIR)
					
	# 3. Ice Battlements (Parapets) at the top deck
	var roof_y := ground_y + tower_height
	for x in range(size):
		var lx := start_x + x
		for z in range(size):
			var lz := start_z + z
			chunk.set_block(lx, roof_y, lz, BlockType.Type.ICE)
			
			var is_corner: bool = (x == 0 or x == size - 1) and (z == 0 or z == size - 1)
			if is_corner:
				if chunk.is_within_bounds(lx, roof_y + 1, lz):
					chunk.set_block(lx, roof_y + 1, lz, BlockType.Type.ICE)
