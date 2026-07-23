# ==============================================================================
# Pathfile: res://src/Domain/World/CyberStreetlightBlueprint.gd
# Description: Concrete Structure Blueprint constructing a futuristic 
#              Cyber-Streetlight for the Neon Ruins biome.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CyberStreetlightBlueprint
extends IStructureBlueprint


## Concrete Implementation: Returns the unique identifier for this Cyber-Streetlight blueprint (ID 16)
func get_structure_id() -> int:
	return 16


## Concrete Implementation: Sculpts the futuristic cybernetic lamppost.
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# 1. Solid obsidian-steel pedestal base (Y+1 to Y+3)
	chunk.set_block(start_x, ground_y + 1, start_z, BlockType.Type.STONE)
	chunk.set_block(start_x, ground_y + 2, start_z, BlockType.Type.STONE)
	chunk.set_block(start_x, ground_y + 3, start_z, BlockType.Type.STONE)
	
	# 2. Glowing cybernetic cyan neck (Y+4)
	chunk.set_block(start_x, ground_y + 4, start_z, BlockType.Type.NEON_CYAN)
	
	# 3. Horizontal glowing cyan arm projecting forward (Y+4, Z-1)
	if chunk.is_within_bounds(start_x, ground_y + 4, start_z - 1):
		chunk.set_block(start_x, ground_y + 4, start_z - 1, BlockType.Type.NEON_CYAN)
		
	# 4. Hanging transparent glass bell (Y+3, Z-1)
	if chunk.is_within_bounds(start_x, ground_y + 3, start_z - 1):
		chunk.set_block(start_x, ground_y + 3, start_z - 1, BlockType.Type.GLASS)
