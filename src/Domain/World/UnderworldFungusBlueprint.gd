# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct a glowing Giant Blue Underworld Fungus.
#              OCP COMPLIANT: Extends IStructureBlueprint dynamically.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/UnderworldFungusBlueprint.gd
# ==============================================================================
class_name UnderworldFungusBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Underworld Fungus (ID 11)
func get_structure_id() -> int:
	return 11

## Concrete Implementation: Builds a giant glowing blue fungus
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var stalk_height: int = 4
	
	# 1. Build thick stone stalk
	for y in range(1, stalk_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.STONE)
		
	# 2. Build glowing cyan fungal umbrella cap (3x1x3 plate) using NEON_CYAN blocks
	var cap_y := ground_y + stalk_height + 1
	for lx in range(-1, 2):
		for lz in range(-1, 2):
			var px := start_x + lx
			var pz := start_z + lz
			
			if chunk.is_within_bounds(px, cap_y, pz):
				chunk.set_block(px, cap_y, pz, BlockType.Type.NEON_CYAN)
				
	# 3. Add a single glowing pinnacle bulb on the top center
	if chunk.is_within_bounds(start_x, cap_y + 1, start_z):
		chunk.set_block(start_x, cap_y + 1, start_z, BlockType.Type.NEON_CYAN)
