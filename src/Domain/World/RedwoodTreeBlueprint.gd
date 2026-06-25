# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel conifer 
#              algorithm to construct a massive 12-block Redwood Tree.
#              Fully encapsulated and OCP compliant.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/RedwoodTreeBlueprint.gd
# ==============================================================================
class_name RedwoodTreeBlueprint
extends IStructureBlueprint

## Concrete Implementation: Returns the unique identifier for the Redwood Tree (ID 2)
func get_structure_id() -> int:
	return 2

## Concrete Implementation: Builds a tall conifer con sus capas de hojas triangulares
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	var trunk_height: int = 9
	
	# 1. Grow colossus wood trunk
	for y in range(1, trunk_height + 1):
		chunk.set_block(start_x, ground_y + y, start_z, BlockType.Type.WOOD)
		
	# 2. Build conifer tiered leaves (tapering upwards like a pine tree)
	var top_y := ground_y + trunk_height
	
	# Tier 1: Low massive skirt (5x5 plate at Y-4)
	_build_leaf_plate(chunk, start_x, start_z, top_y - 4, 2, true)
	
	# Tier 2: Mid plate (3x3 plate at Y-2)
	_build_leaf_plate(chunk, start_x, start_z, top_y - 2, 1, false)
	
	# Tier 3: High plate (3x3 plate at Y-1)
	_build_leaf_plate(chunk, start_x, start_z, top_y - 1, 1, true)
	
	# Tier 4: Pinnacle needle (1x2 leaf tip)
	chunk.set_block(start_x, top_y, start_z, BlockType.Type.LEAVES)
	chunk.set_block(start_x, top_y + 1, start_z, BlockType.Type.LEAVES)

## Helper to draw a flat leaf plate of a given radius, optionally clipping corners for rounding.
func _build_leaf_plate(chunk: Chunk, cx: int, cz: int, y: int, radius: int, clip_corners: bool) -> void:
	for lx in range(-radius, radius + 1):
		for lz in range(-radius, radius + 1):
			if lx == 0 and lz == 0:
				continue # Do not overwrite trunk
				
			if clip_corners and abs(lx) == radius and abs(lz) == radius:
				continue # Clip corners
				
			chunk.set_block(cx + lx, y, cz + lz, BlockType.Type.LEAVES)
