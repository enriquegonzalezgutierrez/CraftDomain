# ==============================================================================
# Project: CraftDomain
# Description: Concrete Structure Blueprint implementing the 3D voxel algorithm 
#              to construct an independent futuristic Cyber-Streetlight 
#              for the Neon Ruins biome.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                geometric block-placement math for this specific asset.
#              - Open-Closed Principle (OCP): Extends IStructureBlueprint dynamically.
#              HIGH-FIDELITY CYBER DESIGN:
#                - Y+1 to Y+3: Solid obsidian stone pillar.
#                - Y+4: Glowing NEON_CYAN neck connector.
#                - Y+4, Z-1: Horizontal glowing NEON_CYAN support arm.
#                - Y+3, Z-1: Hanging transparent GLASS block acting as the cyber-bell.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/CyberStreetlightBlueprint.gd
# ==============================================================================
class_name CyberStreetlightBlueprint
extends IStructureBlueprint

## Concrete Observation: Returns the unique identifier for this Cyber-Streetlight blueprint (ID 16)
func get_structure_id() -> int:
	return 16


## Concrete Implementation: Sculpts the futuristic cybernetic lamppost.
func build_structure(chunk: Chunk, start_x: int, start_z: int, ground_y: int) -> void:
	# 1. Solid obsidian-steel pedestal base (Y+1 to Y+3, Z=10)
	chunk.set_block(start_x, ground_y + 1, start_z, BlockType.Type.STONE)
	chunk.set_block(start_x, ground_y + 2, start_z, BlockType.Type.STONE)
	chunk.set_block(start_x, ground_y + 3, start_z, BlockType.Type.STONE)
	
	# 2. Glowing cybernetic cian neck (Y+4, Z=10)
	chunk.set_block(start_x, ground_y + 4, start_z, BlockType.Type.NEON_CYAN)
	
	# 3. Horizontal glowing cian arm projecting forward (Y+4, Z=9)
	if chunk.is_within_bounds(start_x, ground_y + 4, start_z - 1):
		chunk.set_block(start_x, ground_y + 4, start_z - 1, BlockType.Type.NEON_CYAN)
		
	# 4. ---> SUSPENDED GLASS CYBER BELL <---
	# Hanging transparent glass bell (Y+3, Z=9) hanging directly below the cyan neon arm.
	# The scanner will detect this GLASS block under the NEON_CYAN block!
	if chunk.is_within_bounds(start_x, ground_y + 3, start_z - 1):
		chunk.set_block(start_x, ground_y + 3, start_z - 1, BlockType.Type.GLASS)
