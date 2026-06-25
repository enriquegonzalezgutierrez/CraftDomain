# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a highly detailed Minecraft-style Oak Tree.
#              Features multi-layered organic foliage canopies.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/OakTreeBlueprint.gd
# ==============================================================================
class_name OakTreeBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Oak Tree (ID 1)
func get_structure_id() -> int:
	return 1

## Concrete Implementation: Builds a detailed multi-tiered oak tree canopy
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var trunk_height: int = 5
	
	# 1. Grow Vertical Wood Trunk
	for y in range(1, trunk_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.WOOD)
		
	# 2. Build multi-layered organic foliage cap (5x3x5 and 3x1x3 leaves layers)
	var top_y := ground_y + trunk_height
	
	# Base foliage tier (5x2x5 leaf plate centered around top trunk)
	for ly in range(0, 2):
		for lx in range(-2, 3):
			for lz in range(-2, 3):
				var px := start_x + lx
				var py := top_y + ly - 1
				var pz := start_z + lz
				
				# Skip corners deterministically to make the canopy look rounded and natural
				if abs(lx) == 2 and abs(lz) == 2:
					continue
					
				# Do not overwrite the solid wood trunk core
				if lx == 0 and lz == 0 and ly == 1:
					continue
					
				chunk.set_block(px, py, pz, BlockType.Type.LEAVES)
				
	# Top foliage tier (3x1x3 leaf dome)
	for lx in range(-1, 2):
		for lz in range(-1, 2):
			var px := start_x + lx
			var py := top_y + 1
			var pz := start_z + lz
			
			# Skip dome corners
			if abs(lx) == 1 and abs(lz) == 1:
				continue
				
			chunk.set_block(px, py, pz, BlockType.Type.LEAVES)
