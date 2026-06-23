# ==============================================================================
# Project: CraftDomain
# Description: Domain Service responsible for generating programmatic structure
#              blueprints (like village houses) inside the voxel world.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/StructureGenerator.gd
# ==============================================================================
class_name StructureGenerator
extends RefCounted

## Generates a standard rustic village house composed of Stone, Wood, and Leaves.
static func spawn_village_house(world_state: WorldState, base_pos: Vector3i) -> void:
	var width: int = 5
	var depth: int = 5
	var height: int = 4
	
	# Step 1: Foundation (Solid Stone base layer)
	for x in range(width):
		for z in range(depth):
			# Replace any air under the foundation to prevent floating houses on slopes
			for y_fill in range(-2, 1):
				world_state.set_block(base_pos + Vector3i(x, y_fill, z), BlockType.Type.STONE)
	
	# Step 2: Outer Walls (Wood block ring)
	for y in range(1, height):
		for x in range(width):
			for z in range(depth):
				# Only place blocks on the outer perimeter of the house grid
				var is_edge: bool = (x == 0 or x == width - 1 or z == 0 or z == depth - 1)
				if is_edge:
					# Create a doorway at the front center (x=2, z=0, y=1 and y=2)
					var is_doorway: bool = (x == 2 and z == 0 and (y == 1 or y == 2))
					if is_doorway:
						world_state.set_block(base_pos + Vector3i(x, y, z), BlockType.Type.AIR)
					else:
						world_state.set_block(base_pos + Vector3i(x, y, z), BlockType.Type.WOOD)
				else:
					# Hollow out the inside of the house
					world_state.set_block(base_pos + Vector3i(x, y, z), BlockType.Type.AIR)
					
	# Step 3: Flat Roof (Shubbery Leaves overhang)
	for x in range(-1, width + 1):
		for z in range(-1, depth + 1):
			world_state.set_block(base_pos + Vector3i(x, height, z), BlockType.Type.LEAVES)
