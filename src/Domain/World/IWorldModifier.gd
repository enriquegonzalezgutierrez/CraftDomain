# ==============================================================================
# Project: CraftDomain
# Description: Domain interface defining the contract for modifying and reading 
#              voxel blocks globally. Resolves Layer Leakage and Dependency Inversion 
#              (DIP) violations by allowing Domain strategies to interact with 
#              abstractions rather than concrete Infrastructure classes.
# SOLID COMPLIANCE: 
# - Dependency Inversion Principle (DIP): High-level domain strategies depend 
#   on this abstraction rather than concrete Infrastructure controllers.
# - Interface Segregation Principle (ISP): Declares only the block modification, 
#   block query, and hit fractions contracts required by building strategies.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IWorldModifier.gd
# ==============================================================================
class_name IWorldModifier
extends RefCounted


## Abstract Contract: Modifies a block at the specified global coordinates.
## Must be implemented by the concrete Infrastructure coordinator.
func set_block_globally(_global_pos: Vector3i, _type: BlockType.Type) -> void:
	assert(false, "[IWorldModifier] set_block_globally() must be implemented.")


## Abstract Contract: Queries the block type at the specified global coordinates.
## Allows domain strategies to inspect the target block before execution.
func get_block_globally(_global_pos: Vector3i) -> BlockType.Type:
	assert(false, "[IWorldModifier] get_block_globally() must be implemented.")
	return BlockType.Type.AIR


## Abstract Contract: Returns the fractional height Y coordinate [0.0 to 1.0] of 
## the last raycast collision. Used by strategies to solve top/bottom alignments.
func get_last_hit_fractional_y() -> float:
	assert(false, "[IWorldModifier] get_last_hit_fractional_y() must be implemented.")
	return 0.5
